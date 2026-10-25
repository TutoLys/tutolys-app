import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/home_stats.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/quests/quest_celebration.dart';

class _Progress extends ProgressController {
  _Progress(this._state);
  final ProgressState _state;
  @override
  ProgressState build() => _state;
  @override
  Future<void> refresh() async {}
}

void main() {
  late LocalDatabase db;
  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  ProviderContainer containerWith({DailyQuestDto? challenge}) {
    final c = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        activeKidIdProvider.overrideWithValue('kid-1'),
        progressControllerProvider.overrideWith(
          () => _Progress(ProgressState(loading: false, dailyQuest: challenge)),
        ),
        celebrationRowsProvider.overrideWith(questCelebrationRows),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<CelebrationRowData>> rows(ProviderContainer c) {
    final sub = c.listen(celebrationRowsProvider, (_, _) {});
    addTearDown(sub.close);
    return c.read(celebrationRowsProvider.future);
  }

  test('counts include the exercise just finished', () async {
    final stats = HomeStats(db, kidId: 'kid-1');
    await stats.recordExerciseCompleted(elapsedMs: 60000);
    // The one the celebration is for: written before it builds.
    await stats.recordExerciseCompleted(elapsedMs: 120000);

    final r = await rows(containerWith());
    expect(r.map((x) => (x.value, x.max)), [(2, 5), (3, 10)]);
    expect(r.first.label, 'Résous 5 exercices');
  });

  test(
    'the server challenge shows only once it is done, never stale',
    () async {
      final open = await rows(
        containerWith(
          challenge: const DailyQuestDto(
            target: 3,
            progress: 1,
            completed: false,
          ),
        ),
      );
      expect(open, hasLength(2), reason: 'its number would lag the exercise');

      final done = await rows(
        containerWith(
          challenge: const DailyQuestDto(
            target: 3,
            progress: 3,
            completed: true,
          ),
        ),
      );
      expect(done.first.value, 3);
      expect(done.first.max, 3);
    },
  );

  test(
    'a second celebration recomputes rather than reusing the first',
    () async {
      final c = containerWith();
      final stats = HomeStats(db, kidId: 'kid-1');
      await stats.recordExerciseCompleted(elapsedMs: 1000);

      var sub = c.listen(celebrationRowsProvider, (_, _) {});
      expect((await c.read(celebrationRowsProvider.future)).first.value, 1);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      await stats.recordExerciseCompleted(elapsedMs: 1000);
      sub = c.listen(celebrationRowsProvider, (_, _) {});
      addTearDown(sub.close);
      expect((await c.read(celebrationRowsProvider.future)).first.value, 2);
    },
  );
}
