import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/path/review.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

import 'path_screen_test.dart' show appUnder, exercise, openCarte;

/// OW3: a « Révision » row on the Carte, from evidence only, 3 at most.
void main() {
  CachedSkillNode leaf(String id) => CachedSkillNode(
    id: id,
    labelFr: 'Leçon $id',
    labelEn: '',
    stableKey: 'mathematique/x/b:A/o:$id',
    subject: 'MATH',
    grade: 1,
  );

  SkillMasteryDto m(String id, String? status, double pct) =>
      SkillMasteryDto(
        skillNodeId: id,
        masteryPct: pct,
        isMastered: false,
        status: status,
      );

  group('reviewLeaves', () {
    final leaves = [for (final id in 'abcdef'.split('')) leaf(id)];
    final playable = {for (final l in leaves) l.id};

    test('only struggling or watch, struggling first, then lower mastery', () {
      final got = reviewLeaves(
        masteries: [
          m('a', 'watch', 30),
          m('b', 'struggling', 50),
          m('c', 'learning', 10),
          m('d', 'struggling', 20),
          m('e', null, 5),
        ],
        leaves: leaves,
        playable: playable,
      );
      expect(got.map((l) => l.id), ['d', 'b', 'a']);
    });

    test('capped at 3 per subject', () {
      final got = reviewLeaves(
        masteries: [
          for (final id in 'abcdef'.split('')) m(id, 'struggling', 10),
        ],
        leaves: leaves,
        playable: playable,
      );
      expect(got, hasLength(reviewCapPerSubject));
    });

    test('no status served: no evidence, no review', () {
      final got = reviewLeaves(
        masteries: [m('a', null, 0), m('b', null, 5)],
        leaves: leaves,
        playable: playable,
      );
      expect(got, isEmpty);
    });

    test('another subject\'s skill, or one with no lesson, is left out', () {
      final got = reviewLeaves(
        masteries: [m('zz', 'struggling', 0), m('a', 'struggling', 0)],
        leaves: leaves,
        playable: const {'b'},
      );
      expect(got, isEmpty);
    });

    test('the status survives the progress cache', () {
      final back = SkillMasteryDto.fromJson(m('a', 'watch', 40).toJson());
      expect(back.status, 'watch');
      expect(m('a', null, 40).toJson().containsKey('status'), isFalse);
    });
  });

  group('the Carte', () {
    const leaves = [
      CurriculumLeaf(
        id: 'leaf-1',
        labelFr: 'Compter',
        labelEn: '',
        stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
      ),
      CurriculumLeaf(
        id: 'leaf-2',
        labelFr: 'Comparer',
        labelEn: '',
        stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:2',
      ),
    ];
    final content = {
      'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1'),
      'ex-2': exercise(id: 'ex-2', skillNodeId: 'leaf-2'),
    };

    testWidgets('a struggling skill gets a « Révision » row that plays it', (
      tester,
    ) async {
      await openCarte(
        tester,
        appUnder(
          leaves: leaves,
          content: content,
          masteries: [m('leaf-1', 'struggling', 20)],
        ),
      );
      expect(find.byKey(const ValueKey('carte-review')), findsOneWidget);
      expect(find.text('Révision'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('carte-review-leaf-2')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('carte-review-leaf-1')));
      await tester.pumpAndSettle();
      final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
      expect(play.node.id, 'leaf-1');
    });

    testWidgets('no evidence: no row', (tester) async {
      await openCarte(
        tester,
        appUnder(
          leaves: leaves,
          content: content,
          masteries: [m('leaf-1', null, 20), m('leaf-2', 'learning', 40)],
        ),
      );
      expect(find.byKey(const ValueKey('carte-review')), findsNothing);
    });
  });
}
