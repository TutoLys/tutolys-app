import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_shell.dart';
import 'core/startup/release_config_guard.dart';
import 'data/local_db/database.dart';
import 'data/local_db/session_store.dart';
import 'data/sync/outbox_flusher_provider.dart' show telemetryBaseUrl;
import 'features/pairing/pairing_controller.dart';
import 'features/settings/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything else: a release build still pointed at localhost must
  // fail visibly, not silently ship broken to a real user.
  //
  // Shown on screen rather than thrown. Throwing here is invisible on web —
  // an uncaught error in `main` just leaves the splash up forever, which
  // reads as a hang and cost a real session chasing the environment
  // instead (2026-10-24). `assertReleaseConfigIsReal` still throws, for
  // tests and for anything that wants the hard failure.
  final configError = releaseConfigError(
    isReleaseMode: kReleaseMode,
    apiBaseUrl: apiBaseUrl,
    telemetryBaseUrl: telemetryBaseUrl,
  );
  if (configError != null) {
    runApp(MisconfiguredApp(message: configError));
    return;
  }

  // Whose rows are already on disk. Needed only by the 3 -> 4 migration
  // (ADR 0014), which has to give pre-v4 rows an owner.
  //
  // Passed as a callback, never awaited here: blocking `runApp` on the
  // platform secure store would hold the app on its splash screen if that
  // read were ever slow, with nothing on screen to say why. drift opens
  // lazily and runs the migration on the first query, so the read happens
  // there instead — and only on the one boot that actually upgrades.
  final db = openLocalDatabase(
    migrationKidId: () async => (await SessionStore().pairedKid())?.id,
  );

  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(db)],
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
      home: const AppShell(),
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
