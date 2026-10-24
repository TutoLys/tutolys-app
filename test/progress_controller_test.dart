import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/local_db/streak_local.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
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
