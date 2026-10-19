import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_shell.dart';
import 'data/local_db/database.dart';
import 'features/pairing/pairing_controller.dart';

void main() {
  // `driftDatabase` (drift_flutter) opens lazily — resolving the real file
  // path/IndexedDB name happens on first query, not here — so this no
  // longer needs to be async ahead of `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  final db = openLocalDatabase();

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
