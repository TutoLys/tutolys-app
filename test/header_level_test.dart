import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

Widget header(List<HeaderStat> stats, {bool compact = false}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: VillageHeader(
      name: 'Yelhan',
      subtitle: '1re année',
      stats: stats,
      compact: compact,
    ),
  ),
);

void main() {
  group('level from /me/progress', () {
    test('parses the level and the XP through it', () {
      final s = ProgressSnapshot.fromJson({
        'masteries': const [],
        'current_streak_days': 2,
        'total_xp': 105,
        'level': 2,
        'xp_into_level': 5,
        'xp_to_next_level': 95,
      });
      expect(s.level, 2);
      expect(s.xpIntoLevel, 5);
      expect(s.xpToNextLevel, 95);
    });

    test('progress through the level is into / (into + toNext)', () {
      const state = ProgressState(level: 2, xpIntoLevel: 25, xpToNextLevel: 75);
      expect(state.levelProgress, 0.25);
    });

    test('no level, no progress: never a made-up bar', () {
      expect(const ProgressState().levelProgress, isNull);
      expect(
        const ProgressState(xpIntoLevel: 5, xpToNextLevel: 95).levelProgress,
        isNull,
        reason: 'figures without a level are not shown',
      );
    });

    test('a backend without level progress still parses', () {
      final s = ProgressSnapshot.fromJson({
        'masteries': const [],
        'current_streak_days': null,
        'total_xp': 30,
        'level': 1,
      });
      expect(s.xpIntoLevel, isNull);
    });
  });

  group('the header pill', () {
    testWidgets('shows the level with its XP track', (tester) async {
      await tester.pumpWidget(
        header(const [
          HeaderStat(
            asset: 'asset-xpstar.webp',
            label: 'Niv. 2',
            progress: 0.25,
            tooltip: '105 XP · encore 95 XP pour le niveau 3',
          ),
        ]),
      );

      expect(find.text('Niv. 2'), findsOneWidget);
      final bar = tester.widget<VillageProgressBar>(
        find.byType(VillageProgressBar),
      );
      expect(bar.value, 0.25);
      expect(
        find.byTooltip('105 XP · encore 95 XP pour le niveau 3'),
        findsOneWidget,
      );
    });

    testWidgets('the track is dropped on a compact header, as in the design', (
      tester,
    ) async {
      await tester.pumpWidget(
        header(const [
          HeaderStat(
            asset: 'asset-xpstar.webp',
            label: 'Niv. 2',
            progress: 0.25,
          ),
        ], compact: true),
      );

      expect(find.text('Niv. 2'), findsOneWidget);
      expect(find.byType(VillageProgressBar), findsNothing);
    });

    testWidgets('a pill with no progress has no track', (tester) async {
      await tester.pumpWidget(
        header(const [HeaderStat(asset: 'asset-flame.webp', label: '2')]),
      );
      expect(find.byType(VillageProgressBar), findsNothing);
    });
  });

  group('the phone gear', () {
    testWidgets('opens Réglages', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: VillageHeader(
              name: 'Yelhan',
              subtitle: '',
              stats: const [],
              compact: true,
              onSettings: () => opened++,
              settingsLabel: 'Réglages',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('header-settings')));
      expect(opened, 1);
      expect(find.byTooltip('Réglages'), findsOneWidget);
    });

    testWidgets('no gear when the nav already lists Réglages', (tester) async {
      await tester.pumpWidget(header(const []));
      expect(find.byKey(const ValueKey('header-settings')), findsNothing);
    });

    testWidgets('fits a 360px phone with all three pills', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: VillageHeader(
              name: 'Yelhan',
              subtitle: '',
              compact: true,
              onSettings: () {},
              settingsLabel: 'Réglages',
              stats: const [
                HeaderStat(asset: 'asset-xpstar.webp', label: 'Niv. 12'),
                HeaderStat(asset: 'asset-flame.webp', label: '14'),
                HeaderStat(asset: 'asset-target.webp', label: '0/3 quêtes'),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
