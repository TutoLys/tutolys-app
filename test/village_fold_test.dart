import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/village_nav.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/home/subject_progress.dart';
import 'package:tutolys_app/features/home/village_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

/// Hafid, 2026-11-10: fold the quest panel and the sidebar so the 3D
/// village gets the room (ADR 0126).

void size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double navWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('village-nav-column'))).width;

Widget nav({
  required int fold,
  ValueChanged<int>? onFold,
  bool reduced = true,
}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(
        body: VillageNavShell(
          destinations: const [
            VillageDestination(label: 'Village', asset: 'asset-village.png'),
            VillageDestination(label: 'Carte', asset: 'asset-carte.png'),
          ],
          currentIndex: 0,
          onSelect: (_) {},
          fold: fold,
          onFold: onFold,
          shrinkLabel: 'Réduire',
          hideLabel: 'Masquer',
          expandLabel: 'Agrandir',
          showLabel: 'Afficher',
          child: const SizedBox.expand(key: ValueKey('page')),
        ),
      ),
    ),
  ),
);

const _quests = [
  DailyQuestItem(
    kind: QuestKind.challenge,
    target: 3,
    progress: 3,
    done: true,
    xpReward: 15,
  ),
  DailyQuestItem(
    kind: QuestKind.exercises,
    target: 5,
    progress: 2,
    done: false,
    xpReward: 15,
  ),
];

Widget village() => ProviderScope(
  overrides: [
    localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
    questBoardProvider.overrideWith(
      (ref) async => QuestBoard(
        quests: _quests,
        weekCompleted: 0,
        unlocked: const {},
        today: DateTime(2026, 11, 10),
      ),
    ),
    subjectProgressProvider.overrideWith((ref) async => const {}),
  ],
  child: MaterialApp(
    theme: TutolysTheme.village(),
    locale: const Locale('fr', 'CA'),
    supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: const Scaffold(body: VillageScreen()),
      ),
    ),
  ),
);

void main() {
  group('the sidebar', () {
    testWidgets('wide: open, rail, hidden, and back in one tap', (
      tester,
    ) async {
      size(tester, const Size(1400, 900));
      final asked = <int>[];

      await tester.pumpWidget(nav(fold: 0, onFold: asked.add));
      expect(navWidth(tester), VillageMetrics.sidebarWidth);
      await tester.tap(find.byKey(const ValueKey('village-nav-fold')));
      expect(asked, [1]);

      await tester.pumpWidget(nav(fold: 1, onFold: asked.add));
      await tester.pump();
      expect(navWidth(tester), VillageMetrics.railWidth);
      await tester.tap(find.byKey(const ValueKey('village-nav-expand')));
      await tester.tap(find.byKey(const ValueKey('village-nav-fold')));
      expect(asked, [1, 0, 2]);

      await tester.pumpWidget(nav(fold: 2, onFold: asked.add));
      await tester.pump();
      expect(navWidth(tester), lessThan(40));
      expect(find.text('Village'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('village-nav-show')));
      expect(asked, [1, 0, 2, 0]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rail centres a short label in its column', (
      tester,
    ) async {
      size(tester, const Size(1400, 900));
      await tester.pumpWidget(nav(fold: 1));
      await tester.pump();
      // « Carte » is narrower than the 76px row: it used to hug the left.
      expect(
        tester.getCenter(find.text('Carte')).dx,
        closeTo(VillageMetrics.railWidth / 2, 1),
      );
    });

    testWidgets('tablet: the rail folds to hidden; no wider step', (
      tester,
    ) async {
      size(tester, const Size(900, 900));
      final asked = <int>[];
      await tester.pumpWidget(nav(fold: 0, onFold: asked.add));
      expect(navWidth(tester), VillageMetrics.railWidth);
      expect(find.byKey(const ValueKey('village-nav-expand')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('village-nav-fold')));
      expect(asked, [2]);
    });

    testWidgets('phone: the bottom bar, whatever the fold', (tester) async {
      size(tester, const Size(390, 844));
      await tester.pumpWidget(nav(fold: 2, onFold: (_) {}));
      expect(find.byKey(const ValueKey('village-nav-column')), findsNothing);
      expect(find.byKey(const ValueKey('village-nav-strip')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animates, and the page re-fits as it goes', (tester) async {
      size(tester, const Size(1400, 900));
      await tester.pumpWidget(nav(fold: 0, reduced: false));
      final pageBefore = tester.getSize(find.byKey(const ValueKey('page')));
      await tester.pumpWidget(nav(fold: 1, reduced: false));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = navWidth(tester);
      expect(mid, lessThan(VillageMetrics.sidebarWidth));
      expect(mid, greaterThan(VillageMetrics.railWidth));
      await tester.pumpAndSettle();
      expect(navWidth(tester), VillageMetrics.railWidth);
      final pageAfter = tester.getSize(find.byKey(const ValueKey('page')));
      expect(
        pageAfter.width - pageBefore.width,
        VillageMetrics.sidebarWidth - VillageMetrics.railWidth,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: instant', (tester) async {
      size(tester, const Size(1400, 900));
      await tester.pumpWidget(nav(fold: 0));
      await tester.pumpWidget(nav(fold: 2));
      await tester.pump();
      expect(navWidth(tester), lessThan(40));
    });
  });

  group('the quest panel', () {
    final panel = find.byKey(const ValueKey('village-quest-panel'));
    final tab = find.byKey(const ValueKey('village-quests-unfold'));
    final column = find.byKey(const ValueKey('village-quest-column'));

    testWidgets('folds to a tab with the count, the scene takes the width, '
        'and it is kept for the kid', (tester) async {
      size(tester, const Size(1400, 900));
      await tester.pumpWidget(village());
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(tester.getSize(column).width, 300);
      final scene = find.byKey(const ValueKey('village-scene-box'));
      final before = tester.getSize(scene).width;

      await tester.tap(find.byKey(const ValueKey('village-quests-fold')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(tab, findsOneWidget);
      expect(
        find.byKey(const ValueKey('village-quests-tab-count')),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(tester.getSize(column).width, lessThan(80));
      expect(tester.getSize(scene).width, greaterThan(before + 200));

      final container = ProviderScope.containerOf(tester.element(column));
      expect(container.read(settingsControllerProvider).questsFolded, isTrue);

      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(container.read(settingsControllerProvider).questsFolded, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below the side-by-side width there is nothing to fold', (
      tester,
    ) async {
      size(tester, const Size(1000, 800));
      await tester.pumpWidget(village());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('village-quests-fold')), findsNothing);
      expect(column, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
