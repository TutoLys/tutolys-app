import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/time/quebec_day.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';

/// K8: one day boundary, midnight in Québec, whatever the device's zone.
void main() {
  group('quebecIsoDay', () {
    test('20:05 EDT is still the same day (UTC has rolled over)', () {
      // 2026-10-29 20:05 EDT = 2026-10-30 00:05 UTC.
      expect(quebecIsoDay(DateTime.utc(2026, 10, 30, 0, 5)), '2026-10-29');
    });

    test('the day turns at Québec midnight, in summer time', () {
      expect(quebecIsoDay(DateTime.utc(2026, 10, 30, 3, 59)), '2026-10-29');
      expect(quebecIsoDay(DateTime.utc(2026, 10, 30, 4, 0)), '2026-10-30');
    });

    test('and in winter time, an hour later in UTC', () {
      expect(quebecIsoDay(DateTime.utc(2026, 1, 15, 4, 59)), '2026-01-14');
      expect(quebecIsoDay(DateTime.utc(2026, 1, 15, 5, 0)), '2026-01-15');
    });

    test('summer time starts on the second Sunday of March at 2:00', () {
      // 2026-03-08: 06:59 UTC is 01:59 EST; 07:00 UTC is 03:00 EDT.
      expect(quebecNow(DateTime.utc(2026, 3, 8, 6, 59)).hour, 1);
      expect(quebecNow(DateTime.utc(2026, 3, 8, 7, 0)).hour, 3);
    });

    test('and ends on the first Sunday of November at 2:00', () {
      // 2026-11-01: 05:59 UTC is 01:59 EDT; 06:00 UTC is 01:00 EST.
      expect(quebecNow(DateTime.utc(2026, 11, 1, 5, 59)).hour, 1);
      expect(quebecNow(DateTime.utc(2026, 11, 1, 6, 0)).hour, 1);
      expect(quebecNow(DateTime.utc(2026, 11, 1, 6, 0)).minute, 0);
    });

    test('a device set to Paris still counts Québec days', () {
      // 02:00 in Paris on the 30th is 21:00 on the 29th in Québec.
      final paris = DateTime.utc(2026, 10, 30, 1);
      expect(quebecToday(paris), DateTime(2026, 10, 29));
    });
  });

  group('keepDoneToday', () {
    const challenge = DailyQuestItem(
      kind: QuestKind.challenge,
      target: 3,
      progress: 0,
      done: false,
      xpReward: 20,
    );
    const minutes = DailyQuestItem(
      kind: QuestKind.minutes,
      target: 10,
      progress: 4,
      done: false,
    );

    test('a quest finished earlier today stays finished', () {
      final kept = keepDoneToday([challenge, minutes], {'challenge'});
      expect(kept.first.done, isTrue);
      expect(kept.first.progress, 3);
      expect(kept.first.xpReward, 20);
      expect(kept.last.done, isFalse);
      expect(kept.last.progress, 4);
    });

    test('nothing finished today changes nothing', () {
      expect(keepDoneToday([challenge], const {}).single, same(challenge));
    });
  });
}
