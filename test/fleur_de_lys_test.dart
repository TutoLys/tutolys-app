import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/widgets/fleur_de_lys.dart';
import 'package:tutolys_app/features/about/about_screen.dart';

void main() {
  Widget app(Widget child, {ThemeData? theme, Locale? locale}) => MaterialApp(
    theme: theme ?? TutolysTheme.village(),
    locale: locale,
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );

  testWidgets('sized by height, at the drawing ratio, silent to readers', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Center(child: FleurDeLys(size: 27))));
    final box = tester.getSize(find.byType(FleurDeLys));
    expect(box.height, 27);
    expect(box.width, closeTo(25, 0.01));
    // Decoration next to words that already say it.
    expect(tester.getSemantics(find.byType(FleurDeLys)).label, isEmpty);
  });

  for (final (name, theme) in [
    ('light', TutolysTheme.village()),
    ('dark', TutolysTheme.villageDark()),
  ]) {
    for (final size in [10.0, 15.0, 120.0]) {
      testWidgets('paints without error, $name, ${size}px', (tester) async {
        await tester.pumpWidget(
          app(
            Center(child: FleurDeLys(size: size)),
            theme: theme,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (locale, line) in [
    (const Locale('fr'), 'Fait au Québec'),
    (const Locale('en'), 'Made in Québec'),
  ]) {
    testWidgets('À propos signs off with the drawn lys, $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const AboutScreen(), locale: locale));
      expect(find.text(line), findsOneWidget);
      expect(find.byKey(const ValueKey('about-fleur-de-lys')), findsOneWidget);
    });
  }
}
