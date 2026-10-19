import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/path/path_screen.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

CachedSkillNode node({String id = 'leaf-1', String label = 'Lire un nombre'}) {
  return CachedSkillNode(
    id: id,
    labelFr: label,
    labelEn: '',
    stableKey: 'mathematique/$id',
    subject: 'MATH',
    grade: 1,
  );
}

Widget appUnder(GoRouter router) {
  return ProviderScope(
    child: MediaQuery(
      // Reduce motion in tests: the mascot's idle breath repeats forever
      // otherwise, and `pumpAndSettle` would never settle. Same reasoning
      // as `pairing_test.dart`'s own `appUnder`.
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp.router(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  testWidgets('starts on the path screen', (tester) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    expect(find.byType(PathScreen), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });

  testWidgets('pushing /play with a node shows that node on the play screen', (
    tester,
  ) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    router.push('/play', extra: node(label: 'Compter jusqu’à 10'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.text('Compter jusqu’à 10'), findsWidgets);
  });

  testWidgets('popping from play returns to the path screen', (tester) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    router.push('/play', extra: node());
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(PathScreen), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });
}
