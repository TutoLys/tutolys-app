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
  group('grade level from /me/progress (ADR 0033)', () {
    test('parses the level and its skills', () {
      final s = ProgressSnapshot.fromJson({
        'masteries': const [],
        'current_streak_days': 2,
        'total_xp': 105,
        'level': 7,
        'skills_completed': 33,
        'skills_total': 526,
      });
      expect(s.level, 7);
      expect(s.skillsCompleted, 33);
      expect(s.skillsTotal, 526);
    });

    test('an older backend\'s XP level is not taken for a grade level', () {
      final s = ProgressSnapshot.fromJson({
        'masteries': const [],
        'current_streak_days': null,
        'total_xp': 105,
        'level': 2,
        'xp_into_level': 5,
        'xp_to_next_level': 95,
      });
      expect(s.level, isNull);
    });

    test('no level, no progress: never a made-up bar', () {
      expect(const ProgressState().levelProgress, isNull);
    });
  });

  group('the header pill', () {
    testWidgets('shows the level with its track to the next one', (tester) async {
      await tester.pumpWidget(
        header(const [
          HeaderStat(
            asset: 'asset-xpstar.webp',
            label: 'Niv. 2',
            progress: 0.25,
            tooltip: '33 notions réussies sur 526 en 1re année',
          ),
        ]),
      );

      expect(find.text('Niv. 2'), findsOneWidget);
      final bar = tester.widget<VillageProgressBar>(
        find.byType(VillageProgressBar),
      );
      expect(bar.value, 0.25);
      expect(
        find.byTooltip('33 notions réussies sur 526 en 1re année'),
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
