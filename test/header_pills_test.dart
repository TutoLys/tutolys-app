import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

import 'path_screen_test.dart' show appUnder, exercise;

/// K1: the header's stat pills never shrink to fit; on a phone it shows the
/// two that matter most, at full size.
void main() {
  const leaf = CurriculumLeaf(
    id: 'leaf-1',
    labelFr: 'Compter',
    labelEn: '',
    stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
  );

  test('the most important first, in their own order', () {
    const level = HeaderStat(asset: 'a', label: 'Niv 3', priority: 3);
    const xp = HeaderStat(asset: 'a', label: '40 XP', priority: 0);
    const streak = HeaderStat(asset: 'a', label: '2', priority: 1);
    const quests = HeaderStat(asset: 'a', label: '1/3', priority: 2);
    final all = [level, xp, streak, quests];
    expect(
      visibleStats(all, maxWidth: 1000, compact: false, phone: false),
      all,
    );
    expect(
      visibleStats(all, maxWidth: 1000, compact: true, phone: true),
      [xp, streak],
    );
    expect(
      visibleStats(all, maxWidth: 200, compact: true, phone: false),
      [xp, streak],
    );
    expect(
      visibleStats(all, maxWidth: 50, compact: true, phone: true),
      [xp, streak],
      reason: 'a phone keeps two at full size; the name gives way',
    );
  });

  for (final width in [375.0, 768.0, 1024.0, 1950.0]) {
    testWidgets('at $width px: no shrunk text, nothing overflows', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appUnder(
          leaves: const [leaf],
          content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
          progress: const ProgressState(
            loading: false,
            totalXp: 340,
            currentStreakDays: 4,
            level: 7,
            masteries: [
              SkillMasteryDto(
                skillNodeId: 'leaf-1',
                masteryPct: 10,
                isMastered: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final header = find.byType(VillageHeader);
      expect(
        find.descendant(of: header, matching: find.byType(FittedBox)),
        findsNothing,
        reason: 'pills are never scaled',
      );
      final xp = find.descendant(of: header, matching: find.text('340 XP'));
      expect(xp, findsOneWidget);
      // Full size: the text keeps its own height, about 12 px or more.
      expect(tester.getSize(xp).height, greaterThanOrEqualTo(12));
      if (width < 600) {
        expect(
          find.descendant(of: header, matching: find.text('4')),
          findsOneWidget,
          reason: 'the streak stays beside XP',
        );
        expect(
          find.descendant(of: header, matching: find.textContaining('Niv')),
          findsNothing,
          reason: 'a phone shows XP and the streak only',
        );
      }
    });
  }
}
