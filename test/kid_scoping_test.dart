import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/home_stats.dart';
import 'package:tutolys_app/data/local_db/streak_local.dart';
import 'package:tutolys_app/data/sync/drift_event_outbox.dart';

/// Two kids sharing one device must not see or affect each other's data
/// (ADR 0014). Every test here would have passed trivially before the
/// `kid_id` columns existed — that is the point of them.
void main() {
  late LocalDatabase db;

  const lea = 'kid-lea';
  const noah = 'kid-noah';

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  Map<String, Object?> event(String id) => {
        'event_id': id,
        'event_type': 'exercise_complete',
      };

  group('streaks', () {
    test("one sibling playing does not extend the other's streak", () async {
      final day = DateTime(2026, 10, 24);
      await StreakLocal(db, kidId: lea, clock: () => day).recordPlayedToday();

      expect(
        await StreakLocal(db, kidId: lea, clock: () => day).currentStreak(),
        1,
      );
      expect(
        await StreakLocal(db, kidId: noah, clock: () => day).currentStreak(),
        0,
        reason: 'Noah has never played; Léa playing is not his streak',
      );
    });

    test('each kid keeps their own run of days', () async {
      final today = DateTime(2026, 10, 24);
      final yesterday = today.subtract(const Duration(days: 1));

      await StreakLocal(db, kidId: lea, clock: () => yesterday)
          .recordPlayedToday();
      await StreakLocal(db, kidId: lea, clock: () => today).recordPlayedToday();
      await StreakLocal(db, kidId: noah, clock: () => today).recordPlayedToday();

      expect(
        await StreakLocal(db, kidId: lea, clock: () => today).currentStreak(),
        2,
      );
      expect(
        await StreakLocal(db, kidId: noah, clock: () => today).currentStreak(),
        1,
      );
    });

    test('the same date for two kids is two rows, not a key collision',
        () async {
      final day = DateTime(2026, 10, 24);
      await StreakLocal(db, kidId: lea, clock: () => day).recordPlayedToday();
      await StreakLocal(db, kidId: noah, clock: () => day).recordPlayedToday();

      final rows = await db.select(db.playedDateTable).get();
      expect(rows, hasLength(2));
    });
  });

  group("today's stats", () {
    test("one kid's completed exercises are not counted for the other",
        () async {
      final day = DateTime(2026, 10, 24, 9);

      await HomeStats(db, kidId: lea, clock: () => day)
          .recordExerciseCompleted(elapsedMs: 5000);
      await HomeStats(db, kidId: lea, clock: () => day)
          .recordExerciseCompleted(elapsedMs: 3000);

      final leaToday = await HomeStats(db, kidId: lea, clock: () => day).today();
      expect(leaToday.exercisesCompleted, 2);
      expect(leaToday.msPlayed, 8000);

      final noahToday =
          await HomeStats(db, kidId: noah, clock: () => day).today();
      expect(noahToday.exercisesCompleted, 0);
      expect(noahToday.msPlayed, 0);
    });
  });

  group('outbox', () {
    test("pending returns only the owning kid's events", () async {
      await DriftEventOutbox(db, kidId: lea).add(event('e-lea'));
      await DriftEventOutbox(db, kidId: noah).add(event('e-noah'));

      final leaPending = await DriftEventOutbox(db, kidId: lea).pending();
      expect(leaPending.map((e) => e['event_id']), ['e-lea']);

      final noahPending = await DriftEventOutbox(db, kidId: noah).pending();
      expect(noahPending.map((e) => e['event_id']), ['e-noah']);
    });

    test('depth counts only the owning kid', () async {
      final leaBox = DriftEventOutbox(db, kidId: lea);
      await leaBox.add(event('a'));
      await leaBox.add(event('b'));
      await DriftEventOutbox(db, kidId: noah).add(event('c'));

      expect(await leaBox.depth(), 2);
      expect(await DriftEventOutbox(db, kidId: noah).depth(), 1);
    });

    test('an event is stored against the kid who played it', () async {
      await DriftEventOutbox(db, kidId: lea).add(event('e-lea'));

      final row = await db.select(db.eventOutboxTable).getSingle();
      expect(
        row.kidId,
        lea,
        reason: 'the flusher uploads with this kid\'s token',
      );
    });

    test(
      'the capacity ceiling is a device budget, not a per-kid one',
      () async {
        // Three rows across two kids. A per-kid count would see 2 and 1 and
        // leave a cap of 2 untouched; the device holds 3 and must evict.
        await DriftEventOutbox(db, kidId: lea).add(event('a'));
        await DriftEventOutbox(db, kidId: lea).add(event('b'));
        await DriftEventOutbox(db, kidId: noah).add(event('c'));

        final evicted =
            await DriftEventOutbox(db, kidId: noah).enforceCapacityCap(
          maxRows: 2,
        );

        expect(
          evicted,
          1,
          reason: 'three undelivered rows on disk against a ceiling of two',
        );
      },
    );

    test('eviction accounting belongs to the device, not to a kid', () async {
      await DriftEventOutbox(db, kidId: lea).add(event('a'));
      await DriftEventOutbox(db, kidId: lea).add(event('b'));
      await DriftEventOutbox(db, kidId: noah).enforceCapacityCap(maxRows: 1);

      final stats = await DriftEventOutbox(db, kidId: lea).capacityDropStats();
      expect(stats.totalDropped, greaterThan(0));

      final rows = await db.select(db.appStateTable).get();
      final capacityRows =
          rows.where((r) => r.key.startsWith('outbox_capacity.'));
      expect(capacityRows, isNotEmpty);
      expect(
        capacityRows.every((r) => r.kidId == deviceScope),
        isTrue,
        reason: 'the ceiling is disk, so its counters are device-level',
      );
    });
  });
}
