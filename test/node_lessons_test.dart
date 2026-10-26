import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/features/path/node_lessons.dart';
import 'package:tutolys_app/features/path/path_controller.dart';

Map<String, Object?> lesson(String id, int rank, [String locale = 'fr-CA']) => {
  'exercise_id': id,
  'skill_node_id': 'n',
  'engine_key': 'mcq',
  'rank': rank,
  'locale': locale,
};

NodeProgress progress(Set<String>? ids) => NodeProgress(
  skillNodeId: 'n',
  plays: ids?.length ?? 1,
  lastCompletedAt: DateTime(2026, 10, 25),
  everPerfect: false,
  exerciseIds: ids,
);

void main() {
  final four = [
    lesson('l0', 0),
    lesson('l1', 1),
    lesson('l2', 2),
    lesson('l3', 3),
  ];

  group('a node with several lessons', () {
    test('never played: the first lesson, 0 of 4', () {
      final n = nodeLessons(four, null);
      expect(n.next['exercise_id'], 'l0');
      expect((n.doneCount, n.total), (0, 4));
      expect(n.complete, isFalse);
    });

    test('plays the first unfinished lesson in rank order', () {
      final n = nodeLessons(four, progress({'l0', 'l2'}));
      expect(n.next['exercise_id'], 'l1');
      expect(n.doneCount, 2);
      expect(n.complete, isFalse);
    });

    test('complete only when every lesson is; then a replay of the first', () {
      final n = nodeLessons(four, progress({'l0', 'l1', 'l2', 'l3'}));
      expect(n.complete, isTrue);
      expect(n.next['exercise_id'], 'l0');
    });

    test('a finished exercise no longer on the node does not count', () {
      final n = nodeLessons(four, progress({'gone', 'l0'}));
      expect(n.doneCount, 1);
    });

    test('a record from before lessons were tracked counts the first', () {
      final n = nodeLessons(four, progress(null));
      expect(n.done, {'l0'});
      expect(n.next['exercise_id'], 'l1');
    });
  });

  test('pickLessons keeps every rank, in order, in the asked language', () {
    final picked = pickLessons([
      lesson('r0-fr', 0),
      lesson('r0-en', 0, 'en-CA'),
      lesson('r1-fr', 1),
    ], locale: 'en-CA');
    expect(picked['n']!.map((e) => e['exercise_id']), ['r0-en', 'r1-fr']);
  });

  test('recordCompleted remembers each lesson finished on a node', () async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final local = NodeProgressLocal(db, kidId: 'k1');

    await local.recordCompleted('n', perfect: false, exerciseId: 'l0');
    await local.recordCompleted('n', perfect: true, exerciseId: 'l1');
    await local.recordCompleted('n', perfect: false, exerciseId: 'l0');

    final p = (await local.all())['n']!;
    expect(p.exerciseIds, {'l0', 'l1'});
    expect(p.plays, 3);
    expect(p.everPerfect, isTrue);
  });

  group('a lesson counts once, whatever language it was played in', () {
    // The backend's lesson_group is the original (French) exercise's id,
    // shared by its English twin.
    Map<String, Object?> twin(String id, String group, String locale) => {
      ...lesson(id, 0, locale),
      'lesson_group': group,
    };

    test('French completions count on the English lessons', () {
      final en = [
        twin('en-0', 'fr-0', 'en-CA'),
        {...twin('en-1', 'fr-1', 'en-CA'), 'rank': 1},
      ];
      final n = nodeLessons(en, progress({'fr-0'}));
      expect((n.doneCount, n.total), (1, 2));
      expect(n.next['exercise_id'], 'en-1');
    });

    test('an English completion counts on the French lesson', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final local = NodeProgressLocal(db, kidId: 'k1');
      await local.recordCompleted(
        'n',
        perfect: false,
        exerciseId: 'en-0',
        lessonGroup: 'fr-0',
      );
      final p = (await local.all())['n']!;
      expect(p.exerciseIds, {'en-0', 'fr-0'});

      final fr = [
        twin('fr-0', 'fr-0', 'fr-CA'),
        {...twin('fr-1', 'fr-1', 'fr-CA'), 'rank': 1},
      ];
      expect(nodeLessons(fr, p).doneCount, 1);
    });

    test('a lesson done in both languages still counts once', () {
      final en = [twin('en-0', 'fr-0', 'en-CA')];
      final n = nodeLessons(en, progress({'fr-0', 'en-0'}));
      expect((n.doneCount, n.total), (1, 1));
      expect(n.complete, isTrue);
    });
  });
}
