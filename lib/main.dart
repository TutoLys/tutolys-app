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

void main() {
  // Before anything else: a release build still pointed at localhost must
  // crash loudly here, not silently ship broken to a real user.
  assertReleaseConfigIsReal(
    isReleaseMode: kReleaseMode,
    apiBaseUrl: apiBaseUrl,
    telemetryBaseUrl: telemetryBaseUrl,
  );

  // `driftDatabase` (drift_flutter) opens lazily — resolving the real file
  // path/IndexedDB name happens on first query, not here — so this no
  // longer needs to be async ahead of `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

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

class TutolysApp extends StatelessWidget {
  const TutolysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TutoLys',
      debugShowCheckedModeBanner: false,

      // French first: the product launches in Quebec. English is second, not
      // the fallback-by-default that most scaffolds give you.
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // The kid-facing register. The adult shell uses TutolysTheme.adult().
      theme: TutolysTheme.learner(),
      home: const AppShell(),
    );
  }
}
