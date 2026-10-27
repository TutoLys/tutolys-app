import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../diagnostics/boot_log.dart';
import '../../data/sync/outbox_flusher.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../../features/launch/launch_flow.dart';
import '../../features/pairing/pairing_controller.dart';
import '../../features/pairing/pairing_screen.dart';
import '../../features/passcode/passcode_entry_screen.dart';
import '../../features/passcode/passcode_service.dart';
import '../../features/pairing/who_is_playing_screen.dart';
import '../../features/settings/settings_controller.dart';
import 'paired_router.dart';

/// Chooses the screen from the session state.
///
/// Deliberately a state switch rather than go_router redirects for this
/// decision: "am I paired?" is the app's single most important question, and
/// expressing it as one exhaustive switch means there is no URL that can land
/// an unpaired device on a play screen. Routing within the paired shell is
/// go_router's job (A7 onward).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  /// The flusher for the active kid. *Followed*, not captured once: the
  /// provider builds a new flusher whenever the active kid changes — which
  /// happens after this widget's initState on every launch, because the
  /// session restores on the first frame. Capturing it in initState bound
  /// the running flusher to the "nobody paired yet" outbox scope for the
  /// whole run, so no event was ever uploaded (ADR 0020).
  ///
  /// Held in a field (not re-read) because `ref.read` inside `dispose()` is
  /// unsafe — the widget is being unmounted.
  late OutboxFlusher _flusher;
  late final ProviderSubscription<OutboxFlusher> _flusherSubscription;

  /// Whether this cold start's loader and welcome screen are behind us.
  /// Never reset: signing out or re-pairing later in the same run goes
  /// straight to the screen it needs, not back through the title screen.
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Read the secure store and refresh once the first frame is up, so launch
    // shows a splash rather than a blank window.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The Flutter loader is on screen from the first frame and looks the
      // same as the native one, so the native splash can go now — the
      // loader, not the splash, is what waits for the session (ADR 0018).
      BootLog.instance.mark('first_frame');
      FlutterNativeSplash.remove();
      BootLog.instance.mark('splash_release');
      _restore();
    });
    // Started unconditionally (outside tests), before pairing status is even
    // known: flush() itself no-ops without an access token (see
    // OutboxFlusher). Each replacement is started as it arrives; the
    // provider stops the one it replaces.
    final autoStart = ref.read(outboxFlusherAutoStartProvider);
    _flusherSubscription = ref.listenManual<OutboxFlusher>(
      outboxFlusherProvider,
      (previous, next) {
        previous?.stop();
        _flusher = next;
        if (autoStart) next.start();
      },
      fireImmediately: true,
    );
  }

  /// Restores the session as a boot step (ADR 0038). A restore that never
  /// finishes is recorded as a timeout, and the loader's stuck screen
  /// names it.
  void _restore() {
    BootLog.instance
        .run(
          'session_restore',
          ref.read(sessionControllerProvider.notifier).restore,
          timeout: BootLog.networkTimeout + BootLog.localTimeout,
        )
        .ignore();
  }

  /// "Réessayer" on the stuck screen: boot again from the session.
  void _retryBoot() {
    BootLog.instance.reset();
    ref.invalidate(storedSettingsProvider);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flusherSubscription.close();
    _flusher.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The last events of a session are the most interesting ones — an
    // abandoned exercise, a run of wrong answers — so they must not wait for
    // a timer tick that may never come once the app is backgrounded.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _flusher.flushNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final settingsReady = ref.watch(settingsReadyProvider);

    // The app is ready to show once the session has resolved and, for a
    // paired kid, their settings have been read. Waiting for the settings
    // too means the first frame is already in the kid's theme and language,
    // instead of drawing light and turning dark a moment later.
    final ready = switch (session.status) {
      SessionStatus.checking => false,
      SessionStatus.unpaired => true,
      SessionStatus.paired => settingsReady,
    };

    // A revoked device token pauses the flusher (see OutboxFlusher) until the
    // app re-pairs — the only path that ever replaces that token.
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next.status == SessionStatus.paired) {
        _flusher.resume();
      }
      // A picker is about to show: learn every kid's picture passcode, so
      // one set in the portal is asked for from this choice on (B-A0.5).
      final picking = next.status == SessionStatus.paired &&
          next.hasSeveralKids &&
          (previous?.status != SessionStatus.paired ||
              (next.stage == ProfileStage.choosing &&
                  previous?.stage != ProfileStage.choosing));
      if (picking && ref.read(passcodeSyncEnabledProvider)) {
        ref.read(passcodeServiceProvider).syncAll().ignore();
      }
    });

    if (!_launched) {
      return _switch(LaunchFlow(
        key: const ValueKey('launch'),
        stage: switch (session.status) {
          SessionStatus.checking => LaunchStage.restoring,
          _ when !ready => LaunchStage.sessionResolved,
          _ => LaunchStage.ready,
        },
        kidName: session.status == SessionStatus.paired ? session.kid?.displayName : null,
        // Several kids: the welcome screen is the picker, so a cold start
        // never greets the last kid who played (ADR 0024).
        kids: session.status == SessionStatus.paired && session.hasSeveralKids
            ? session.kids
            : null,
        onPickKid: _enterAs,
        onAddProfile: () {
          ref.read(sessionControllerProvider.notifier).addProfile();
          setState(() => _launched = true);
        },
        onFinished: () => setState(() => _launched = true),
        onRetry: _retryBoot,
      ));
    }

    return _switch(switch (session.status) {
        // Session resolved but the kid's settings not read yet: stay blank
        // behind the splash rather than drawing in the default theme.
        _ when !ready => const _Splash(),
        SessionStatus.checking => const _Splash(),
        SessionStatus.unpaired => const PairingScreen(),
        SessionStatus.paired => switch (session.stage) {
            ProfileStage.choosing => const WhoIsPlayingScreen(
                key: ValueKey('who-is-playing'),
              ),
            ProfileStage.adding => PairingScreen(
                key: const ValueKey('add-profile'),
                onCancel: ref
                    .read(sessionControllerProvider.notifier)
                    .chooseProfile,
              ),
            // Keyed on the kid: switching kid builds a fresh router and
            // fresh pages, so no screen keeps the last kid's state.
            ProfileStage.none => _PairedShell(
                key: ValueKey('paired-${session.kid?.id}'),
              ),
          },
      });
  }

  /// Leaves the launch screen as [kidId]. The switch (and its token
  /// refresh) finishes first, so the shell is only ever built for the kid
  /// who was tapped and nothing of the last kid's loads in between.
  ///
  /// On launch every kid is asked for their picture passcode, the last one
  /// to play included: the device doesn't know who picked it up.
  Future<void> _enterAs(String kidId) async {
    final session = ref.read(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    final kid = session.kids.firstWhere((k) => k.id == kidId);
    final ok = await confirmItsMe(context, ref, kid);
    if (ok == null || !mounted) return;
    if (kidId == session.kid?.id && ok.accessToken == null) {
      controller.closeProfileStage();
    } else {
      await controller.switchTo(
        kidId,
        accessToken: ok.accessToken,
        expiresIn: ok.expiresIn,
      );
    }
    if (mounted) setState(() => _launched = true);
  }

  /// One switcher for every top-level screen, launch included, so the
  /// welcome screen cross-fades into pairing or the Village rather than
  /// cutting to it.
  Widget _switch(Widget child) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.normal,
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    // Only reachable after launch, if the session is re-checked later in the
    // run; the launch loader covers every wait before that.
    return const SizedBox.shrink();
  }
}

/// Owns the paired-branch router's lifetime.
///
/// A fresh `GoRouter` per entry into the paired state, not one cached for
/// the app's whole lifetime: a kid can forget the device and re-pair later
/// in the same app session, and re-entering `/play`'s stale location from a
/// prior pairing (rather than starting back at `/path`) would be a real,
/// confusing bug. Giving this its own `StatefulWidget` means
/// `AnimatedSwitcher` creates (and `State.dispose` tears down) a new router
/// every time this branch is (re-)entered, the same way it already does for
/// `PairingScreen`/`PathScreen` themselves.
class _PairedShell extends StatefulWidget {
  const _PairedShell({super.key});

  @override
  State<_PairedShell> createState() => _PairedShellState();
}

class _PairedShellState extends State<_PairedShell> {
  late final GoRouter _router = buildPairedRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `Router.withConfig`, not a nested `MaterialApp.router`: this inherits
    // the outer `MaterialApp`'s theme/localizations/Directionality instead
    // of needing its own copy of all three.
    return Router.withConfig(config: _router);
  }
}
