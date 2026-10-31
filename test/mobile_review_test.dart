import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/core/routing/village_nav.dart';
import 'package:tutolys_app/features/path/skill_path.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';
import 'package:tutolys_app/features/quests/quests_screen.dart';

/// The 2026-10-31 mobile review (`Platforms/ux-review/mobile-2026-10-31.md`):
/// AM8 (a way back), AM10 (dark contrast), AM15 (an empty state) and K2
/// (no red badge).
void main() {
  Widget themed(Widget child, {bool dark = false}) => MaterialApp(
    theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),
    home: Scaffold(body: child),
  );

  group('AM8: the phone header has a way back', () {
    testWidgets('a 48px ← that calls back, and a selected gear', (
      tester,
    ) async {
      var back = 0;
      await tester.pumpWidget(
        themed(
          VillageHeader(
            name: 'Léa',
            subtitle: '',
            stats: const [],
            compact: true,
            onSettings: () {},
            settingsLabel: 'Réglages',
            settingsActive: true,
            onBack: () => back++,
            backLabel: 'Retour',
          ),
        ),
      );
      final arrow = find.byKey(const ValueKey('header-back'));
      expect(tester.getSize(arrow), const Size(48, 48));
      expect(find.byTooltip('Retour'), findsOneWidget);
      await tester.tap(arrow);
      expect(back, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Réglages')),
        isSemantics(isButton: true, isSelected: true),
      );
    });

    testWidgets('no ← unless the shell asks for one', (tester) async {
      await tester.pumpWidget(
        themed(const VillageHeader(name: 'Léa', subtitle: '', stats: [])),
      );
      expect(find.byKey(const ValueKey('header-back')), findsNothing);
    });
  });

  group('K2: count badges are gold, never red', () {
    testWidgets('the Quêtes badge', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          VillageNavShell(
            destinations: const [
              VillageDestination(label: 'Village', asset: 'asset-village.png'),
              VillageDestination(
                label: 'Quêtes',
                asset: 'asset-quetes.png',
                badge: 3,
              ),
            ],
            currentIndex: 0,
            onSelect: (_) {},
            child: const SizedBox(),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('3'), matching: find.byType(Container))
            .first,
      );
      final fill = (box.decoration! as BoxDecoration).color;
      expect(fill, VillagePalette.light.gold);
      expect(fill, isNot(const Color(0xFFEF4444)));
    });
  });

  group('AM10: dark mode keeps locked nodes and tracks visible', () {
    Widget path({required bool dark}) => themed(
      SingleChildScrollView(
        child: SkillPath(
          nodes: const [
            PathNode(id: 'a', label: 'Compter', state: PathNodeState.available),
            PathNode(
              id: 'l',
              label: 'Pile ou face',
              state: PathNodeState.locked,
            ),
          ],
          compact: true,
          statusLabel: (n) => '',
          continueLabel: 'Continuer',
        ),
      ),
      dark: dark,
    );

    Opacity lockedOpacity(WidgetTester tester) => tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.lock_outline_rounded),
            matching: find.byType(Opacity),
          )
          .first,
    );

    testWidgets('dark: no half opacity, a filled orb with a visible ring', (
      tester,
    ) async {
      await tester.pumpWidget(path(dark: true));
      expect(lockedOpacity(tester).opacity, 1);
      final orb = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byIcon(Icons.lock_outline_rounded),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final d = orb.decoration as BoxDecoration;
      expect(d.color, VillageDarkColors.lockedFill);
      expect((d.border! as Border).top.color, VillageDarkColors.lockedRing);
    });

    testWidgets('light keeps the design\'s half opacity', (tester) async {
      await tester.pumpWidget(path(dark: false));
      expect(lockedOpacity(tester).opacity, 0.5);
    });

    test('the dark track is lifted off the card', () {
      double lum(Color c) => c.computeLuminance();
      double ratio(Color a, Color b) {
        final (hi, lo) = lum(a) > lum(b) ? (a, b) : (b, a);
        return (lum(hi) + 0.05) / (lum(lo) + 0.05);
      }

      expect(
        ratio(VillageDarkColors.track, VillageDarkColors.surface),
        greaterThan(1.8),
      );
      expect(
        ratio(VillageDarkColors.lockedRing, VillageDarkColors.surface),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('AM15: « Réussites récentes » says how to earn one', () {
    testWidgets('nothing earned: a sentence above the padlocks', (
      tester,
    ) async {
      await tester.pumpWidget(themed(const RecentAchievementsCard(earned: [])));
      expect(find.byKey(const ValueKey('recent-empty')), findsOneWidget);
    });

    testWidgets('one earned: no sentence', (tester) async {
      await tester.pumpWidget(
        themed(
          const RecentAchievementsCard(
            earned: [EarnedItem(key: 'w1', day: '2026-10-31')],
          ),
        ),
      );
      expect(find.byKey(const ValueKey('recent-empty')), findsNothing);
    });
  });
}
