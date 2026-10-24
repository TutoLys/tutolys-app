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

Future<void> main() async {
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
  // (ADR 0014), which has to give pre-v4 rows an owner — and which runs on
  // the database's first query, i.e. as soon as the first screen builds.
  // Reading it here, before the database is opened, is what keeps an
  // existing kid's streak and queued events from being discarded on
  // upgrade. It lives in the platform secure store, so it cannot be read
  // from inside the migration itself.
  final pairedKid = await SessionStore().pairedKid();
  final db = openLocalDatabase(migrationKidId: pairedKid?.id);

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
