import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/features/progress/progress_cache.dart';
import 'package:tutolys_app/features/quests/streak_detail.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 9);

  StreakFreezeDto f({int balance = 0, DateTime? next, bool? earned}) =>
      StreakFreezeDto(
        balance: balance,
        maxBalance: 2,
        nextGrantAt: next,
        earnedSinceLastGrant: earned,
      );

  group('shieldRecharge', () {
    test('a date ahead counts whole days, rounded up', () {
      final r = shieldRecharge(
        f(next: now.add(const Duration(days: 2, hours: 1))),
        now,
      );
      expect(r, isA<RechargeInDays>().having((r) => r.days, 'days', 3));
    });

    test('an hour away is still "1 day", never 0', () {
      final r = shieldRecharge(f(next: now.add(const Duration(hours: 1))), now);
      expect((r! as RechargeInDays).days, 1);
    });

    test('a date ahead wins over "earned"', () {
      final r = shieldRecharge(
        f(next: now.add(const Duration(days: 1)), earned: false),
        now,
      );
      expect(r, isA<RechargeInDays>());
    });

    test('no date and not earned: play a lesson', () {
      expect(shieldRecharge(f(earned: false), now), isA<RechargeNeedsPlay>());
    });

    test('no date and earned: due soon', () {
      expect(shieldRecharge(f(earned: true), now), isA<RechargeDueSoon>());
    });

    test('earned unknown: nothing to say', () {
      expect(shieldRecharge(f(), now), isNull);
    });

    test('a date already past (a cached read) is as if not served', () {
      final r = shieldRecharge(
        f(next: now.subtract(const Duration(days: 1)), earned: true),
        now,
      );
      expect(r, isA<RechargeDueSoon>());
    });

    test('full: no shield is coming, so nothing', () {
      expect(
        shieldRecharge(
          f(balance: 2, next: now.add(const Duration(days: 3))),
          now,
        ),
        isNull,
      );
    });
  });

  group('the payload', () {
    final json = <String, Object?>{
      'masteries': const [],
      'current_streak_days': 3,
      'total_xp': 40,
      'streak_freeze': {
        'balance': 1,
        'max_balance': 2,
        'last_granted_at': '2026-10-24T09:00:00Z',
        'next_grant_at': '2026-10-31T09:00:00Z',
        'earned_since_last_grant': null,
      },
      'quests': [
        {'kind': 'daily_challenge', 'target': 3, 'xp': 10},
        {'kind': 'exercises', 'target': 5, 'xp': 10},
      ],
    };

    test('parses streak_freeze and quests', () {
      final s = ProgressSnapshot.fromJson(json);
      expect(s.streakFreeze!.balance, 1);
      expect(s.streakFreeze!.maxBalance, 2);
      expect(s.streakFreeze!.nextGrantAt, DateTime.utc(2026, 10, 31, 9));
      expect(s.streakFreeze!.earnedSinceLastGrant, isNull);
      expect([for (final q in s.quests!) q.kind], ['daily_challenge', 'exercises']);
      expect(s.quests![1].xp, 10);
    });

    test('round-trips through the cache shape', () {
      final back = ProgressSnapshot.fromJson(
        ProgressSnapshot.fromJson(json).toJson(),
      );
      expect(back.streakFreeze!.lastGrantedAt, DateTime.utc(2026, 10, 24, 9));
      expect(back.quests!.length, 2);
    });

    test('an older backend serves neither', () {
      final s = ProgressSnapshot.fromJson(const {'masteries': []});
      expect(s.streakFreeze, isNull);
      expect(s.quests, isNull);
    });

    test('a fresh read\'s shield is never filled from the cache', () {
      final cached = ProgressSnapshot.fromJson({
        ...json,
        'streak_freeze': {
          'balance': 1,
          'max_balance': 2,
          'earned_since_last_grant': false,
        },
      });
      final fresh = ProgressSnapshot.fromJson(const {'masteries': []});
      final merged = mergeWithCached(fresh, cached);
      expect(merged.streakFreeze, isNull);
      expect(merged.quests!.length, 2, reason: 'definitions may be cached');
    });

    test('withoutEarned keeps everything else', () {
      final w = f(balance: 1, next: now, earned: false).withoutEarned();
      expect(w.earnedSinceLastGrant, isNull);
      expect(w.balance, 1);
      expect(w.nextGrantAt, now);
    });
  });
}
