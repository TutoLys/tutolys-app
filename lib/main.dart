import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart' show AudioOutputKeepAlive;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/diagnostics/boot_log.dart';
import 'core/diagnostics/crash_reporting.dart';
import 'core/diagnostics/diag_log.dart';
import 'core/diagnostics/diag_store.dart';
import 'core/routing/app_shell.dart';
import 'core/startup/storage_problem.dart';
import 'core/routing/paired_router.dart' show rememberLaunchLocation;
import 'core/startup/release_config_guard.dart';
import 'features/launch/boot_handoff.dart';
import 'data/local_db/database.dart';
import 'data/local_db/session_store.dart';
import 'data/sync/outbox_flusher_provider.dart' show telemetryBaseUrl;
import 'features/pairing/pairing_controller.dart';
import 'features/play/learning_platform_providers.dart'
    show celebrationRowsProvider;
import 'features/quests/quest_celebration.dart';
import 'features/settings/settings_controller.dart';

void main() {
  // Every uncaught error reaches the console and the on-device log
  // (ADR 0038): framework errors, platform errors, and this zone.
  runZonedGuarded(_main, DiagLog.instance.onZoneError);
}

void _main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  DiagLog.instance.installHooks();
  // Off unless built with a DSN; then the hooks above also forward here
  // (ADR 0052). Never awaited: crash reporting must not hold the launch.
  startCrashReporting().catchError(
    (Object e, StackTrace s) => recordCaught('crash_reporting', e, s),
  ).ignore();
  // From the first tap, keep the audio output awake (web only), so the first
  // read-aloud isn't clipped while the OS wakes the sink (ADR 0043).
  AudioOutputKeepAlive.instance.armOnFirstGesture();

  // Hold the native splash until Flutter's first frame is up.
  //
  // `AppShell` removes it on that first frame, where `LaunchFlow`'s loader
  // takes over: the same night sky, emblem, wordmark and bar, continuing
  // from where the web page's own bar stopped (ADR 0018). Before ADR 0018
  // the splash was held until the session resolved; the loader now does
  // that waiting, with real progress on screen instead of a still image.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // The page the browser was on (`#/carte`…), read before anything can
  // reset the URL, so a refresh reopens it instead of the Village.
  rememberLaunchLocation(Uri.base);

  // Before anything else: a release build still pointed at localhost must
  // fail visibly, not silently ship broken to a real user.
  //
  // Shown on screen rather than thrown. Throwing here is invisible on web —
  // an uncaught error in `main` just leaves the splash up forever, which
  // reads as a hang and cost a real session chasing the environment
  // instead (2026-10-24). `assertReleaseConfigIsReal` still throws, for
  // tests and for anything that wants the hard failure.
  final configStep = BootLog.instance.start('config_guard');
  final configError = releaseConfigError(
    isReleaseMode: kReleaseMode,
    apiBaseUrl: apiBaseUrl,
    telemetryBaseUrl: telemetryBaseUrl,
  );
  BootLog.instance.finish(
    configStep,
    configError == null ? BootOutcome.ok : BootOutcome.error,
    configError,
  );
  if (configError != null) {
    runApp(MisconfiguredApp(message: configError));
    return;
  }

  unawaited(_openAndRun());
}

/// Opens the local store, then runs the app on it. A store that won't open
/// even on a fresh worker gets its own screen, never the app pretending to
/// be offline (K5, ADR 0099).
Future<void> _openAndRun() async {
  // Whose rows are already on disk. Needed only by the 3 -> 4 migration
  // (ADR 0014), which has to give pre-v4 rows an owner. A callback, so the
  // secure store is read only on the one boot that actually upgrades.
  final opened = await BootLog.instance.run(
    'db_open',
    () => openLocalDatabaseWithRetry(
      assetVersion: gitSha.isEmpty ? appVersion : '$appVersion+$gitSha',
      open: (version) => openLocalDatabase(
        migrationKidId: () async => (await SessionStore().pairedKid())?.id,
        assetVersion: version,
      ),
    ),
  );
  if (opened.retried) {
    recordCaught(
      'db_open_retry',
      opened.error ?? 'first open failed; a fresh worker opened it',
    );
  }
  if (!opened.ok) {
    FlutterNativeSplash.remove();
    runApp(StorageProblemApp(onRetry: _openAndRun));
    return;
  }
  final db = opened.db;
  startDiagPersistence(db, DiagLog.instance).catchError(
    (Object e, StackTrace s) => recordCaught('diag_store', e, s),
  ).ignore();

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        // The celebration's quest rows (app ADR 0022's hook).
        celebrationRowsProvider.overrideWith(questCelebrationRows),
      ],
      child: const TutolysApp(),
    ),
  );
}

class TutolysApp extends ConsumerWidget {
  const TutolysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Réglages' language choice, applied here because `Strings.of` resolves
    // from `Localizations.localeOf` — setting the locale on MaterialApp is
    // the whole mechanism, and every `context.s` below it follows.
    final english = ref.watch(
      settingsControllerProvider.select((s) => s.english),
    );
    final dark = ref.watch(
      settingsControllerProvider.select((s) => s.darkTheme),
    );
    final reduceMotion = ref.watch(
      settingsControllerProvider.select((s) => s.reduceMotion),
    );

    // The web page's HTML loader speaks before Flutter can, so it reads the
    // language from the last run (ADR 0018). No-op off the web.
    rememberBootLocale(english ? 'en' : 'fr');

    return MaterialApp(
      title: 'TutoLys',
      debugShowCheckedModeBanner: false,

      // French first: the product launches in Quebec. English is second, not
      // the fallback-by-default that most scaffolds give you — a kid has to
      // choose English in Réglages to get it.
      locale: english ? const Locale('en', 'CA') : const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // The kid-facing register, as the 2026-10-24 design draws it. The
      // pages inside have not all been redesigned yet, so expect a seam
      // until each one lands — the chrome is correct, the contents are
      // still the A7.2 layer. TutolysTheme.learner() goes when the last
      // page has moved across.
      theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),

      // "Réduire les animations" is applied here, as Flutter's own
      // `MediaQuery.disableAnimations` rather than a flag each widget has to
      // remember to check. Everything that already honours the platform's
      // reduce-motion setting — implicit animations, route transitions,
      // `AnimatedSwitcher`, and anything reading
      // `MediaQuery.disableAnimationsOf` — follows for free.
      //
      // OR-ed with the platform's own value, never replacing it: a child
      // whose OS is set to reduce motion must keep that even if this
      // in-app toggle is off. The app may add a reason to disable
      // animations; it may not take one away.
      builder: (context, child) {
        return ReduceMotionScope(
          reduceMotion: reduceMotion,
          child: const _RootNavigator(),
        );
      },
    );
  }
}

/// The app's root navigator, holding [AppShell] and nothing else.
///
/// Built by hand in `MaterialApp.builder` rather than given as `home`, so
/// that `MaterialApp` has no navigator of its own. Page URLs (`/village`,
/// `/carte`…) belong to the paired router nested inside AppShell, and a
/// `home` navigator would compete with it for the browser's: it was handed
/// the URL as an initial route it could not match ("Could not navigate to
/// initial route" on every refresh), and every back-button or address-bar
/// change as a named route it could not build (a null-check crash in
/// `_onUnknownRoute`). With no app-level navigator, both go straight to the
/// paired router. This one still gives dialogs, tooltips and the pairing
/// screen the Overlay they need.
class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }
}

/// What a developer sees instead of a splash screen that never clears.
///
/// Deliberately plain: no theme, no localisation, no provider scope. It has
/// to render even when the thing that is misconfigured is the app itself,
/// and it is never reachable by a kid — a real release build with real
/// `--dart-define` values never constructs it.
class MisconfiguredApp extends StatelessWidget {
  const MisconfiguredApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build misconfigured',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Réglages' "Réduire les animations", OR-ed into Flutter's own
/// `MediaQuery.disableAnimations`, so every consumer reading it follows,
/// games included. It can add a reason to reduce motion, never take the
/// platform's away.
class ReduceMotionScope extends StatelessWidget {
  const ReduceMotionScope({
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: child,
    );
  }
}
