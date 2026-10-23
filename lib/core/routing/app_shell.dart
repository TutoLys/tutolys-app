import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/sync/outbox_flusher.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../../features/pairing/pairing_controller.dart';
import '../../features/pairing/pairing_screen.dart';
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
  // Captured once, in initState: `ref.read` inside `dispose()` is unsafe
  // (the widget is being unmounted), so the instance itself — not another
  // provider read — is what dispose/lifecycle callbacks act on.
  late final OutboxFlusher _flusher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Read the secure store and refresh once the first frame is up, so launch
    // shows a splash rather than a blank window.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).restore();
    });
    _flusher = ref.read(outboxFlusherProvider);
    // Started unconditionally (outside tests), before pairing status is even
    // known: flush() itself no-ops without an access token (see
    // OutboxFlusher), so starting early just means it is already ticking the
    // moment pairing succeeds rather than missing the first interval.
    if (ref.read(outboxFlusherAutoStartProvider)) {
      _flusher.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // A revoked device token pauses the flusher (see OutboxFlusher) until the
    // app re-pairs — the only path that ever replaces that token.
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next.status == SessionStatus.paired) {
        _flusher.resume();
      }
    });

    return AnimatedSwitcher(
      duration: Motion.normal,
      child: switch (session.status) {
        SessionStatus.checking => const _Splash(),
        SessionStatus.unpaired => const PairingScreen(),
        SessionStatus.paired => const _PairedShell(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: TutolysMascot(size: 120)));
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
  const _PairedShell();

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
