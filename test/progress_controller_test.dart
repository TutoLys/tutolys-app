import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/data/local_db/streak_local.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/progress/grade_level.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeProgressApi extends ProgressApi {
  _FakeProgressApi() : super(dio: Dio());

  ProgressResult result = const ProgressFetched(
    ProgressSnapshot(masteries: [], currentStreakDays: 0),
  );
  int fetchCalls = 0;

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async {
    fetchCalls++;
    return result;
  }
}

SkillMasteryDto mastery(
  String id, {
  required double pct,
  bool isMastered = false,
}) {
  return SkillMasteryDto(
    skillNodeId: id,
    masteryPct: pct,
    isMastered: isMastered,
  );
}

void main() {
  late ProviderContainer container;
  late _FakeProgressApi api;
  late LocalDatabase db;

  ProviderContainer build({SessionState? session}) {
    api = _FakeProgressApi();
    db = LocalDatabase.memory();
    return ProviderContainer(
      overrides: [
        progressApiProvider.overrideWithValue(api),
        localDatabaseProvider.overrideWithValue(db),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(
            session ??
                const SessionState(
                  status: SessionStatus.paired,
                  kid: PairedKid(
                    id: 'k1',
                    displayName: 'Yelhan',
                    gradeLevel: 1,
                  ),
                  accessToken: 'token',
                ),
          ),
        ),
      ],
    );
  }

  tearDown(() async {
    // Same reasoning as path_controller_test's tearDown: build() fires an
    // unawaited `_load` microtask, which must drain before dispose().
    await pumpEventQueue();
    container.dispose();
    await db.close();
  });

  test('counts only mastered skills, not every skill with any data', () async {
    container = build();
    api.result = ProgressFetched(
      ProgressSnapshot(
        masteries: [
          mastery('a', pct: 95, isMastered: true),
          mastery('b', pct: 40, isMastered: false),
          mastery('c', pct: 82, isMastered: true),
        ],
        currentStreakDays: 4,
      ),
    );

    await container.read(progressControllerProvider.notifier).refresh();

    final state = container.read(progressControllerProvider);
    expect(state.loading, isFalse);
    expect(state.totalSkills, 3);
    expect(state.masteredCount, 2);
    expect(state.currentStreakDays, 4);
  });

  test(
    'offline with no local play history estimates a streak of zero',
    () async {
      container = build();
      api.result = const ProgressOffline();

      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.loading, isFalse);
      expect(state.offline, isTrue);
      expect(state.isStreakEstimated, isTrue);
      expect(state.currentStreakDays, 0);
      expect(state.totalSkills, 0);
    },
  );

  test(
    'offline falls back to a real estimate from local play history',
    () async {
      container = build();
      // `ProgressController`'s own offline fallback has no clock injection
      // point — it uses the real wall clock, same as production — so this
      // seeds against `DateTime.now()` too rather than a fixed date, which
      // would only coincidentally agree with "today" on the day this was
      // written.
      final now = DateTime.now();
      await StreakLocal(db, kidId: 'k1', clock: () => now).recordPlayedToday();
      await StreakLocal(db, kidId: 'k1',
        clock: () => now.subtract(const Duration(days: 1)),
      ).recordPlayedToday();
      api.result = const ProgressOffline();

      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.isStreakEstimated, isTrue);
      expect(state.currentStreakDays, 2);
    },
  );

  group('the streak shown never trails this device (ADR 0032)', () {
    Future<void> playedTodayAndYesterday() async {
      final now = DateTime.now();
      await StreakLocal(db, kidId: 'k1', clock: () => now).recordPlayedToday();
      await StreakLocal(
        db,
        kidId: 'k1',
        clock: () => now.subtract(const Duration(days: 1)),
      ).recordPlayedToday();
    }

    test('a server still missing today\'s play shows the local 2', () async {
      container = build();
      await playedTodayAndYesterday();
      api.result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: 1),
      );

      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.currentStreakDays, 2);
      expect(state.isStreakEstimated, isFalse, reason: 'online: no ~');
    });

    test('a larger server streak (freezes, another device) wins', () async {
      container = build();
      await playedTodayAndYesterday();
      api.result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: 9),
      );

      await container.read(progressControllerProvider.notifier).refresh();

      expect(container.read(progressControllerProvider).currentStreakDays, 9);
    });

    test('server unknown and nothing local stays a dash', () async {
      container = build();
      api.result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: null),
      );

      await container.read(progressControllerProvider.notifier).refresh();

      expect(
        container.read(progressControllerProvider).currentStreakDays,
        isNull,
      );
    });
  });

  group('the grade level (ADR 0033)', () {
    /// 98 grade-1 leaves, one lesson on the first, finished on this device.
    Future<void> seedOneSkillDone() async {
      await db.batch((b) {
        for (var i = 0; i < 98; i++) {
          b.insert(
            db.skillNodeTable,
            SkillNodeTableCompanion.insert(
              id: 'leaf-$i',
              labelFr: 'n$i',
              labelEn: '',
              stableKey: 'mathematique/x/b:A/o:$i',
              subject: 'MATH',
              grade: 1,
            ),
          );
        }
      });
      await db
          .into(db.exerciseCacheTable)
          .insert(
            ExerciseCacheTableCompanion.insert(
              exerciseId: 'ex-0',
              version: 1,
              payload: jsonEncode({
                'exercise_id': 'ex-0',
                'skill_node_id': 'leaf-0',
                'subject': 'MATH',
                'engine_key': 'mcq',
                'rank': 0,
                'locale': 'fr-CA',
              }),
              contentHash: 'h',
              engineKey: 'mcq',
              skillNodeId: 'leaf-0',
              subject: 'MATH',
              grade: 1,
              rank: 0,
              cachedAt: DateTime.utc(2026, 10, 25),
            ),
          );
      await NodeProgressLocal(
        db,
        kidId: 'k1',
      ).recordCompleted('leaf-0', perfect: true, exerciseId: 'ex-0');
    }

    test('a skill finished here raises the level before the server', () async {
      container = build();
      await seedOneSkillDone();
      // An older backend: its XP level must not leak in as a grade level.
      api.result = ProgressFetched(
        ProgressSnapshot.fromJson({
          'masteries': const [],
          'current_streak_days': 0,
          'total_xp': 500,
          'level': 6,
        }),
      );

      await container.read(progressControllerProvider.notifier).refresh();
      await pumpEventQueue();

      final state = container.read(progressControllerProvider);
      expect(state.level, 2, reason: '1 + floor(98 × 1 / 98)');
      expect((state.skillsCompleted, state.skillsTotal), (1, 98));
      expect(state.totalXp, 500, reason: 'XP stays, as points only');
    });

    test('a level already shown in this grade never goes down', () async {
      container = build();
      await GradeLevelStore(db, kidId: 'k1', grade: 1).write(high: 5);
      api.result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [],
          currentStreakDays: 0,
          level: 1,
          skillsCompleted: 0,
          skillsTotal: 526,
        ),
      );

      await container.read(progressControllerProvider.notifier).refresh();
      await pumpEventQueue();

      expect(container.read(progressControllerProvider).level, 5);
    });
  });

  group('a failed read never looks like lost progress', () {
    const good = ProgressFetched(
      ProgressSnapshot(
        masteries: [
          SkillMasteryDto(skillNodeId: 'a', masteryPct: 95, isMastered: true),
        ],
        currentStreakDays: 4,
        freezesAvailable: 1,
        dailyQuest: DailyQuestDto(target: 3, progress: 3, completed: true),
        totalXp: 240,
      ),
    );

    test('a 500 after a good read keeps every value, marked stale', () async {
      container = build();
      api.result = good;
      await container.read(progressControllerProvider.notifier).refresh();

      api.result = const ProgressFailed('500');
      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.totalXp, 240);
      expect(state.currentStreakDays, 4);
      expect(state.masteredCount, 1);
      expect(state.freezesAvailable, 1);
      expect(state.dailyQuest?.completed, isTrue, reason: 'quest not dropped');
      expect(state.stale, isTrue);
    });

    test('offline after a good read shows the last good read too', () async {
      container = build();
      api.result = good;
      await container.read(progressControllerProvider.notifier).refresh();

      api.result = const ProgressOffline();
      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.totalXp, 240);
      expect(state.offline, isTrue);
    });

    test('a degraded read keeps what it left empty; XP never drops', () async {
      container = build();
      api.result = good;
      await container.read(progressControllerProvider.notifier).refresh();

      api.result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: null, totalXp: 0),
      );
      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.currentStreakDays, 4);
      expect(state.dailyQuest, isNotNull);
      expect(state.totalXp, 240);
      expect(state.stale, isFalse, reason: 'the read itself succeeded');
    });
  });

  test('unauthorized shows nothing rather than an error state', () async {
    container = build();
    api.result = const ProgressUnauthorized();

    await container.read(progressControllerProvider.notifier).refresh();

    final state = container.read(progressControllerProvider);
    expect(state.loading, isFalse);
    expect(state.currentStreakDays, isNull);
  });

  test(
    'no paired kid: stays non-loading with nothing to show, no network call',
    () async {
      container = build(session: const SessionState.unpaired());

      await container.read(progressControllerProvider.notifier).refresh();

      expect(container.read(progressControllerProvider).loading, isFalse);
      expect(api.fetchCalls, 0);
    },
  );

  test(
    'a null streak from a successful fetch is distinct from offline',
    () async {
      container = build();
      api.result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: null),
      );

      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.offline, isFalse);
      expect(state.currentStreakDays, isNull);
    },
  );

  test(
    'freeze balance and daily quest pass through from a real fetch',
    () async {
      container = build();
      api.result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [],
          currentStreakDays: 4,
          freezesAvailable: 2,
          dailyQuest: DailyQuestDto(target: 3, progress: 2, completed: false),
        ),
      );

      await container.read(progressControllerProvider.notifier).refresh();

      final state = container.read(progressControllerProvider);
      expect(state.freezesAvailable, 2);
      expect(state.dailyQuest?.target, 3);
      expect(state.dailyQuest?.progress, 2);
      expect(state.dailyQuest?.completed, isFalse);
    },
  );

  test('offline has no opinion on freeze balance or the daily quest', () async {
    container = build();
    api.result = const ProgressOffline();

    await container.read(progressControllerProvider.notifier).refresh();

    final state = container.read(progressControllerProvider);
    expect(state.freezesAvailable, isNull);
    expect(state.dailyQuest, isNull);
  });
}
