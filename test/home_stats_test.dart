import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/home_stats.dart';

void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  test('a fresh install has zero counts', () async {
    final stats = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 19));

    final today = await stats.today();

    expect(today.exercisesCompleted, 0);
    expect(today.msPlayed, 0);
  });

  test('recording a completion accumulates count and time', () async {
    final stats = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 19, 14));

    await stats.recordExerciseCompleted(elapsedMs: 5000);
    await stats.recordExerciseCompleted(elapsedMs: 3000);

    final today = await stats.today();
    expect(today.exercisesCompleted, 2);
    expect(today.msPlayed, 8000);
  });

  test('a pure read never resets state, even on a new day', () async {
    final stats = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 19));
    await stats.recordExerciseCompleted(elapsedMs: 1000);

    final tomorrow = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 20));
    final readBack = await tomorrow.today();
    expect(readBack.exercisesCompleted, 0, reason: 'yesterday does not count as today');

    // The stored counters from yesterday must still be there — a read alone
    // must not have overwritten them.
    final sameDayAgain = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 19));
    final stillThere = await sameDayAgain.today();
    expect(stillThere.exercisesCompleted, 1);
  });

  test('the day rolling over resets counters on the next write', () async {
    final day1 = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 19));
    await day1.recordExerciseCompleted(elapsedMs: 9000);

    final day2 = HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 20));
    await day2.recordExerciseCompleted(elapsedMs: 1000);

    final today = await day2.today();
    expect(today.exercisesCompleted, 1);
    expect(today.msPlayed, 1000);
  });

  group('distinct lessons (backend ADR 0154)', () {
    test('a replay finishes the tile, not the quest', () async {
      final stats =
          HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 27));
      await stats.recordExerciseCompleted(elapsedMs: 1, exerciseId: 'a');
      await stats.recordExerciseCompleted(elapsedMs: 1, exerciseId: 'a');
      await stats.recordExerciseCompleted(elapsedMs: 1, exerciseId: 'b');

      final today = await stats.today();
      expect(today.exercisesCompleted, 3);
      expect(today.lessonsCompleted, 2);
    });

    test('a lesson with no id is not counted toward the quest', () async {
      final stats =
          HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 27));
      await stats.recordExerciseCompleted(elapsedMs: 1);
      expect((await stats.today()).lessonsCompleted, 0);
    });

    test('a new day starts the set again, per kid', () async {
      final day1 =
          HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 26));
      await day1.recordExerciseCompleted(elapsedMs: 1, exerciseId: 'a');
      final day2 =
          HomeStats(db, kidId: 'kid-1', clock: () => DateTime(2026, 10, 27));
      expect((await day2.today()).lessonsCompleted, 0);
      await day2.recordExerciseCompleted(elapsedMs: 1, exerciseId: 'a');
      expect((await day2.today()).lessonsCompleted, 1);

      final sibling =
          HomeStats(db, kidId: 'kid-2', clock: () => DateTime(2026, 10, 27));
      expect((await sibling.today()).lessonsCompleted, 0);
    });
  });
}
