import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/node_progress_local.dart';
import '../home/home_controller.dart';
import '../play/learning_platform_providers.dart';
import '../progress/progress_controller.dart';
import '../settings/settings_controller.dart';
import 'quest_board.dart';
import 'quests_screen.dart' show questTitle;

/// The quest rows the end-of-exercise celebration shows ("Résous 5
/// exercices 3/5"), installed over the play screen's empty
/// `celebrationRowsProvider` in `main.dart` (app ADR 0022's hook).
///
/// Real quests only, and every number includes the exercise just finished:
/// - The two local quests read `HomeStats`, which the play screen writes
///   before the celebration builds. The provider forgets its value whenever
///   no celebration is listening, so each celebration computes afresh
///   rather than showing the previous one's numbers; it also re-runs when
///   `nodeProgressProvider` is refreshed, which happens after that write.
/// - The daily challenge comes from the server, which only learns of this
///   exercise after telemetry upload. Its number would be stale, so it shows
///   only once it is already done: never a figure that is out of date.
Future<List<CelebrationRowData>> questCelebrationRows(Ref ref) async {
  // Forget this value once no celebration is listening (scheduled: Riverpod
  // forbids invalidating from inside a life-cycle callback).
  ref.onCancel(
    () => Future.microtask(() {
      if (ref.mounted) ref.invalidateSelf();
    }),
  );
  ref.watch(nodeProgressProvider);

  final t = ref.watch(settingsControllerProvider.select((s) => s.english))
      ? Strings.en
      : Strings.fr;
  final stats = await ref.read(homeStatsProvider).today();
  final progress = ref.read(progressControllerProvider);
  final quests = buildDailyQuests(
    challenge: progress.dailyQuest,
    lessonsToday: stats.lessonsCompleted,
    msToday: stats.msPlayed,
    served: progress.questDefinitions,
  );

  return [
    for (final q in quests)
      if (q.kind != QuestKind.challenge || q.done)
        CelebrationRowData(
          icon: questIconFor(q.kind),
          label: questTitle(t, q),
          value: q.progress,
          max: q.target,
        ),
  ];
}
