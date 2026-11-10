import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tutolys_app/core/routing/village_shell.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/home/village_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
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

/// Minimal, valid exercise envelope — same shape
/// `packages/engine_sdk/test/exercise_runner_test.dart` uses. This router
/// test only cares that `/play` renders `PlayScreen` with the right node;
/// it is not exercising engine content, so "fake-a" (an engine the app has
/// never heard of) is fine — `ExerciseRunner` shows its own friendly
/// fallback for that rather than crashing.
Map<String, Object?> envelope() {
  return {
    'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
    'version': 1,
    'engine_key': 'fake-a',
    'engine_min_version': 1,
    'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
    'subject': 'MATH',
    'grade': 1,
    'rank': 0,
    'locale': 'fr-CA',
    'prompt': {'text': 'Quel nombre ?', 'audio_ref': null, 'image_ref': null},
    'config': const {},
    'assets': const [],
  };
}

Widget appUnder(GoRouter router) {
  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
    ],
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
  testWidgets('starts on the home shell, home tab selected', (tester) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    expect(find.byType(VillageShell), findsOneWidget);
    expect(find.byType(VillageScreen), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
    // IndexedStack keeps every tab built — selection means Village's own
    // content is actually hit-testable, not just present in the tree.
    expect(
      find.byKey(const ValueKey('village-body')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('pushing /play with a node shows that node on the play screen', (
    tester,
  ) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    router.push(
      '/play',
      extra: PlayRequest(
        node: node(label: 'Compter jusqu’à 10'),
        envelope: envelope(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
    // The design's exercise chrome has no title bar (ADR 0019), so the node
    // isn't drawn as text any more; what routing owes is that it arrives.
    expect(
      tester.widget<PlayScreen>(find.byType(PlayScreen)).node.labelFr,
      'Compter jusqu’à 10',
    );
  });

  testWidgets('popping from play returns to the home shell', (tester) async {
    final router = buildPairedRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appUnder(router));
    await tester.pumpAndSettle();

    router.push(
      '/play',
      extra: PlayRequest(node: node(), envelope: envelope()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(VillageShell), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });

  group('every page has its own URL', () {
    int shownIndex(WidgetTester tester) => tester
        .widget<IndexedStack>(
          find.descendant(
            of: find.byType(VillageShell),
            matching: find.byType(IndexedStack),
          ),
        )
        .index!;

    testWidgets('a refresh on a page comes back to that page', (tester) async {
      // A refresh rebuilds the router from the browser URL, which is what
      // `initialLocation` stands in for here.
      for (final (i, page) in VillageShell.pages.indexed) {
        final router = GoRouter(
          initialLocation: '/$page',
          routes: buildPairedRouter().configuration.routes,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(appUnder(router));
        await tester.pumpAndSettle();

        expect(shownIndex(tester), i, reason: '/$page');
      }
    });

    testWidgets('switching pages changes the URL, and keeps the pages alive', (
      tester,
    ) async {
      final router = buildPairedRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(appUnder(router));
      await tester.pumpAndSettle();
      final shell = tester.state(find.byType(VillageShell));

      router.go('/progres');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/progres');
      expect(shownIndex(tester), VillageShell.pages.indexOf('progres'));
      expect(
        tester.state(find.byType(VillageShell)),
        same(shell),
        reason:
            'one shell for every page: rebuilding it per URL would '
            're-fire every page\'s load',
      );
    });

    testWidgets('a nav tap goes through the URL', (tester) async {
      final router = buildPairedRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(appUnder(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil').first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/profil');
    });

    for (final old in ['/', '/home', '/nowhere']) {
      testWidgets('$old lands on the Village', (tester) async {
        final router = GoRouter(
          initialLocation: old,
          routes: buildPairedRouter().configuration.routes,
          redirect: (context, state) =>
              state.uri.path == '/' ? '/village' : null,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(appUnder(router));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/village');
        expect(
          find.byKey(const ValueKey('village-body')).hitTestable(),
          findsOneWidget,
        );
      });
    }

    testWidgets('a refresh during a game goes to the Carte, not a crash', (
      tester,
    ) async {
      // The play request lives only in memory, so a reload has none.
      final router = GoRouter(
        initialLocation: '/play',
        routes: buildPairedRouter().configuration.routes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(appUnder(router));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/carte');
      expect(find.byType(PlayScreen), findsNothing);
    });
  });

  group('launch location (a browser refresh)', () {
    testWidgets('the page in the URL at launch is the first page shown', (
      tester,
    ) async {
      rememberLaunchLocation(Uri.parse('http://127.0.0.1:8080/#/progres'));
      final router = buildPairedRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(appUnder(router));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/progres');
    });

    testWidgets('it is used once: a re-pair starts at the Village', (
      tester,
    ) async {
      rememberLaunchLocation(Uri.parse('http://127.0.0.1:8080/#/progres'));
      buildPairedRouter().dispose();

      final again = buildPairedRouter();
      addTearDown(again.dispose);
      await tester.pumpWidget(appUnder(again));
      await tester.pumpAndSettle();

      expect(again.state.uri.path, '/village');
    });

    testWidgets('no fragment (desktop) means the Village', (tester) async {
      rememberLaunchLocation(Uri.parse('file:///home/kid/app/'));
      final router = buildPairedRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(appUnder(router));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/village');
    });
  });
}
