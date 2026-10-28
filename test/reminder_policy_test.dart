import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/reminders/reminder_policy.dart';
import 'package:tutolys_app/features/reminders/reminder_scheduler.dart';

/// Wednesday 2026-10-28, 09:00.
final _now = DateTime(2026, 10, 28, 9);
DateTime _d(int day) => DateTime(2026, 10, day);

KidReminderInput _kid(
  String id, {
  bool enabled = true,
  int minutes = 17 * 60,
  bool english = false,
  Set<DateTime>? played,
  DateTime? enabledOn,
  int? streak,
  bool? shieldReady,
}) => KidReminderInput(
  kidId: id,
  enabled: enabled,
  minutes: minutes,
  english: english,
  playedDays: played ?? {_d(27)},
  enabledOn: enabledOn,
  streak: streak,
  shieldReady: shieldReady,
);

void main() {
  group('planReminders', () {
    test('today and tomorrow at the chosen time', () {
      final plan = planReminders(kids: [_kid('lea')], now: _now);
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 28, 17),
        DateTime(2026, 10, 29, 17),
      ]);
      expect(plan.every((r) => r.kind == ReminderKind.learn), isTrue);
    });

    test('off means nothing', () {
      expect(planReminders(kids: [_kid('lea', enabled: false)], now: _now), isEmpty);
    });

    test('a day already played gets no reminder', () {
      final plan = planReminders(
        kids: [_kid('lea', played: {_d(27), _d(28)})],
        now: _now,
      );
      expect(plan.single.at, DateTime(2026, 10, 29, 17));
    });

    test('a time already past today starts tomorrow', () {
      final plan = planReminders(
        kids: [_kid('lea', minutes: 8 * 60)],
        now: _now,
      );
      expect(plan.single.at, DateTime(2026, 10, 29, 8));
    });

    test('never outside 08:00–19:30', () {
      final early = planReminders(kids: [_kid('a', minutes: 6 * 60)], now: _now);
      final late = planReminders(kids: [_kid('a', minutes: 22 * 60)], now: _now);
      expect(early.last.at, DateTime(2026, 10, 29, 8));
      expect(late.first.at, DateTime(2026, 10, 28, 19, 30));
    });

    test('the picker offers 08:00 to 19:00, every half hour', () {
      expect(reminderSlots.first, 8 * 60);
      expect(reminderSlots.last, 19 * 60);
      expect(reminderSlots, hasLength(23));
    });

    group('back-off', () {
      test('three reminded days without play, then none', () {
        // Last played the 25th: reminders on the 26th, 27th, 28th, then
        // nothing on the 29th.
        final plan = planReminders(
          kids: [_kid('lea', played: {_d(25)})],
          now: _now,
        );
        expect(plan.single.at, DateTime(2026, 10, 28, 17));
      });

      test('a fourth day without play: paused', () {
        final plan = planReminders(
          kids: [_kid('lea', played: {_d(24)})],
          now: _now,
        );
        expect(plan, isEmpty);
      });

      test('playing again starts them again', () {
        final plan = planReminders(
          kids: [_kid('lea', played: {_d(20), _d(27)})],
          now: _now,
        );
        expect(plan, hasLength(2));
      });

      test('counts from the day they were turned on for a kid who '
          'never played', () {
        final fresh = planReminders(
          kids: [_kid('lea', played: {}, enabledOn: _d(28))],
          now: _now,
        );
        expect(fresh, hasLength(2));
        final stale = planReminders(
          kids: [_kid('lea', played: {}, enabledOn: _d(20))],
          now: _now,
        );
        expect(stale, isEmpty);
      });
    });

    group('the flame', () {
      test('today, when the streak is at risk and no shield is ready', () {
        final plan = planReminders(
          kids: [_kid('lea', streak: 4, shieldReady: false)],
          now: _now,
        );
        expect(plan.first.kind, ReminderKind.flame);
        expect(plan.last.kind, ReminderKind.learn, reason: 'tomorrow is unknown');
      });

      test('a ready shield already protects it: no flame', () {
        final plan = planReminders(
          kids: [_kid('lea', streak: 4, shieldReady: true)],
          now: _now,
        );
        expect(plan.first.kind, ReminderKind.learn);
      });

      test('unknown shield, or a streak under 2: no flame', () {
        expect(
          planReminders(kids: [_kid('a', streak: 4)], now: _now).first.kind,
          ReminderKind.learn,
        );
        expect(
          planReminders(
            kids: [_kid('a', streak: 1, shieldReady: false)],
            now: _now,
          ).first.kind,
          ReminderKind.learn,
        );
      });
    });

    group('several kids', () {
      test('within 30 minutes: one reminder, no name, French on a tie', () {
        final plan = planReminders(
          kids: [
            _kid('lea', minutes: 17 * 60),
            _kid('noah', minutes: 17 * 60 + 30, english: true),
          ],
          now: _now,
          days: 1,
        );
        expect(plan.single.kind, ReminderKind.several);
        expect(plan.single.at, DateTime(2026, 10, 28, 17));
        expect(plan.single.kidIds, ['lea', 'noah']);
        expect(plan.single.english, isFalse);
      });

      test('the language most of them play in', () {
        final plan = planReminders(
          kids: [
            _kid('a', english: true),
            _kid('b', english: true),
            _kid('c'),
          ],
          now: _now,
          days: 1,
        );
        expect(plan.single.english, isTrue);
      });

      test('far apart: one each, in their own language', () {
        final plan = planReminders(
          kids: [
            _kid('lea', minutes: 9 * 60 + 30),
            _kid('noah', minutes: 17 * 60, english: true),
          ],
          now: _now,
          days: 1,
        );
        expect(plan.map((r) => r.kind), [ReminderKind.learn, ReminderKind.learn]);
        expect(plan.map((r) => r.english), [false, true]);
      });
    });

    test('never on a class tablet', () {
      expect(
        planReminders(kids: [_kid('lea')], now: _now, classTablet: true),
        isEmpty,
      );
    });
  });

  group('the words', () {
    PlannedReminder r(ReminderKind kind, {bool english = false}) =>
        PlannedReminder(at: _now, kind: kind, english: english, kidIds: const ['a']);

    test('each kind, in its language, never naming a kid', () {
      expect(reminderText(r(ReminderKind.learn)).body, Strings.fr.reminderLearnBody);
      expect(reminderText(r(ReminderKind.flame, english: true)).body,
          Strings.en.reminderFlameBody);
      expect(reminderText(r(ReminderKind.several)).body,
          Strings.fr.reminderSeveralBody);
    });

    test('kind words: no loss, no guilt', () {
      for (final t in [Strings.fr, Strings.en]) {
        for (final body in [
          t.reminderLearnBody,
          t.reminderFlameBody,
          t.reminderSeveralBody,
        ]) {
          expect(
            body.toLowerCase(),
            isNot(matches(RegExp(r'perd|lose|lost|miss|manqu|triste|sad|!!'))),
          );
        }
      }
    });

    test('times read naturally in each language', () {
      expect(Strings.fr.reminderTimeLabel(17 * 60), '17 h');
      expect(Strings.fr.reminderTimeLabel(8 * 60 + 30), '8 h 30');
      expect(Strings.en.reminderTimeLabel(17 * 60), '5:00 PM');
      expect(Strings.en.reminderTimeLabel(8 * 60 + 30), '8:30 AM');
    });
  });

  group('platforms', () {
    test('mobile schedules, Linux only while running, web never', () {
      expect(reminderSupportFor(isWeb: true, platform: TargetPlatform.android),
          ReminderSupport.none);
      expect(reminderSupportFor(isWeb: false, platform: TargetPlatform.android),
          ReminderSupport.scheduled);
      expect(reminderSupportFor(isWeb: false, platform: TargetPlatform.iOS),
          ReminderSupport.scheduled);
      expect(reminderSupportFor(isWeb: false, platform: TargetPlatform.linux),
          ReminderSupport.whileRunning);
    });

    // testWidgets for its fake clock: the sink's timers run on it.
    testWidgets('Linux: shown when due, and a new plan replaces the old', (
      tester,
    ) async {
      final start = DateTime(2026, 10, 28, 16, 59);
      final shown = <int>[];
      final sink = RunningReminderSink(
        show: (id, _) async => shown.add(id),
        clock: () => start,
      );
      final at = DateTime(2026, 10, 28, 17);
      await sink.replaceAll([
        PlannedReminder(at: at, kind: ReminderKind.learn, english: false, kidIds: const ['a']),
        PlannedReminder(
          at: at.add(const Duration(hours: 1)),
          kind: ReminderKind.learn,
          english: false,
          kidIds: const ['a'],
        ),
      ]);
      await tester.pump(const Duration(minutes: 2));
      expect(shown, [1]);
      // A lesson was played: the new plan has nothing left today.
      await sink.replaceAll(const []);
      await tester.pump(const Duration(hours: 2));
      expect(shown, [1]);
    });
  });
}
