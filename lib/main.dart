import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: TutolysApp()));
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
