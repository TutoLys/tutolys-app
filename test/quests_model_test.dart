import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/quests/quests_model.dart';

void main() {
  group('weekOf', () {
    test('starts on Monday and marks today and played days', () {
      // Thursday 2026-10-22.
      final today = DateTime(2026, 10, 22);
      final week = weekOf(today, {DateTime(2026, 10, 19), today});

      expect(week.first.date, DateTime(2026, 10, 19));
      expect(week.last.date, DateTime(2026, 10, 25));
      expect(week.map((d) => d.played), [
        true,
        false,
        false,
        true,
        false,
        false,
        false,
      ]);
      expect(week.where((d) => d.isToday).single.date, today);
    });

    test(
      'a Sunday is the last cell of its own week, not the first of the next',
      () {
        final sunday = DateTime(2026, 10, 25);
        final week = weekOf(sunday, const {});
        expect(week.first.date, DateTime(2026, 10, 19));
        expect(week.last.isToday, isTrue);
      },
    );
  });

  group('monthGrid', () {
    test('October 2026 starts on a Thursday: four blanks, then 31 days', () {
      final cells = monthGrid(2026, 10);
      expect(cells.take(4), everyElement(isNull));
      expect(cells[4], DateTime(2026, 10, 1));
      expect(cells.length, 4 + 31);
    });

    test('a month starting on Sunday has no blanks', () {
      // 2026-11-01 is a Sunday.
      expect(monthGrid(2026, 11).first, DateTime(2026, 11, 1));
    });
  });

  test('nextStreakGoal climbs the milestones, then by hundreds', () {
    expect(nextStreakGoal(0), 3);
    expect(nextStreakGoal(3), 7);
    expect(nextStreakGoal(4), 7);
    expect(nextStreakGoal(29), 30);
    expect(nextStreakGoal(100), 200);
    expect(nextStreakGoal(150), 200);
  });
}
