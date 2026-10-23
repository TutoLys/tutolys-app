import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/streak_local.dart';

void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  test('no play history at all is a streak of zero', () async {
    final streak = StreakLocal(db);
    expect(await streak.currentStreak(), 0);
  });

  test('recording today alone is a streak of one', () async {
    final now = DateTime.utc(2026, 10, 21, 9);
    final streak = StreakLocal(db, clock: () => now);

    await streak.recordPlayedToday();

    expect(await streak.currentStreak(), 1);
  });

  test('recording the same day twice is still one day, not two', () async {
    final now = DateTime.utc(2026, 10, 21, 9);
    final streak = StreakLocal(db, clock: () => now);

    await streak.recordPlayedToday();
    await StreakLocal(db, clock: () => now.add(const Duration(hours: 3))).recordPlayedToday();

    expect(await streak.currentStreak(), 1);
  });

  test('consecutive days count up, read from a later day', () async {
    final day0 = DateTime.utc(2026, 10, 21, 9);
    for (final offset in [2, 1, 0]) {
      await StreakLocal(
        db,
        clock: () => day0.subtract(Duration(days: offset)),
      ).recordPlayedToday();
    }

    expect(await StreakLocal(db, clock: () => day0).currentStreak(), 3);
  });

  test('a gap of exactly one day (yesterday) still counts — the plan\'s own grace', () async {
    final today = DateTime.utc(2026, 10, 21, 9);
    await StreakLocal(
      db,
      clock: () => today.subtract(const Duration(days: 1)),
    ).recordPlayedToday();

    expect(await StreakLocal(db, clock: () => today).currentStreak(), 1);
  });

  test('a gap of two or more days resets to zero', () async {
    final today = DateTime.utc(2026, 10, 21, 9);
    await StreakLocal(
      db,
      clock: () => today.subtract(const Duration(days: 2)),
    ).recordPlayedToday();

    expect(await StreakLocal(db, clock: () => today).currentStreak(), 0);
  });

  test('a gap in the middle of the history breaks the streak at that point', () async {
    final today = DateTime.utc(2026, 10, 21, 9);
    // Played today and yesterday, then a real gap, then an older day —
    // only the unbroken run back from today counts.
    for (final offset in [0, 1, 3]) {
      await StreakLocal(
        db,
        clock: () => today.subtract(Duration(days: offset)),
      ).recordPlayedToday();
    }

    expect(await StreakLocal(db, clock: () => today).currentStreak(), 2);
  });
}
