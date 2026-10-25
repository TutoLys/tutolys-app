import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/progress/grade_level.dart';

void main() {
  group('level = 1 + floor(98 × completed / all skills of the grade)', () {
    test('starts at 1, and 99 only when every skill is done', () {
      expect(gradeLevelFor(0, 526), 1);
      expect(gradeLevelFor(526, 526), 99);
      expect(gradeLevelFor(525, 526), 98, reason: 'one short is not 99');
    });

    test('grade 1: six skills reach level 2', () {
      expect(gradeLevelFor(5, 526), 1);
      expect(gradeLevelFor(6, 526), 2);
    });

    test('no grade to measure is level 1, never a division by zero', () {
      expect(gradeLevelFor(0, 0), 1);
      expect(gradeLevelProgress(0, 0), 0);
    });

    test('progress toward the next level', () {
      expect(gradeLevelProgress(1, 196), closeTo(0.5, 1e-9));
      expect(gradeLevelProgress(196, 196), 1);
    });
  });

  group('merging local and server', () {
    test('a finished lesson counts before the server knows', () {
      final g = mergeGradeLevel(
        localCompleted: 6,
        localTotal: 526,
        serverCompleted: 0,
        serverTotal: 526,
        serverLevel: 1,
      )!;
      expect(g.level, 2);
      expect(g.completed, 6);
    });

    test('the server\'s total wins: a short local cache never inflates', () {
      // Only Science synced: 6 of 30 cached leaves done would be level 20.
      final g = mergeGradeLevel(
        localCompleted: 6,
        localTotal: 30,
        serverTotal: 526,
      )!;
      expect(g.total, 526);
      expect(g.level, 2);
    });

    test('offline, the last server total still applies', () {
      final g = mergeGradeLevel(
        localCompleted: 6,
        localTotal: 30,
        lastServerTotal: 526,
      )!;
      expect(g.level, 2);
    });

    test('never below a level already shown in this grade', () {
      final g = mergeGradeLevel(
        localCompleted: 0,
        localTotal: 526,
        serverTotal: 526,
        highWater: 4,
      )!;
      expect(g.level, 4);
      expect(g.progress, 0, reason: 'no made-up progress past a held level');
    });

    test('a higher server level is adopted', () {
      final g = mergeGradeLevel(
        localCompleted: 0,
        localTotal: 526,
        serverTotal: 526,
        serverLevel: 3,
      )!;
      expect(g.level, 3);
    });

    test('nothing to measure yet: no level at all', () {
      expect(mergeGradeLevel(localCompleted: 0, localTotal: 0), isNull);
    });
  });

  test(
    'the remembered level is per grade, so a new grade starts at 1',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      await GradeLevelStore(
        db,
        kidId: 'k1',
        grade: 1,
      ).write(high: 12, total: 526);

      expect(await GradeLevelStore(db, kidId: 'k1', grade: 1).read(), (
        12,
        526,
      ));
      expect(await GradeLevelStore(db, kidId: 'k1', grade: 2).read(), (
        0,
        null,
      ));
      expect(await GradeLevelStore(db, kidId: 'k2', grade: 1).read(), (
        0,
        null,
      ));
    },
  );
}
