import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/progress_api.dart';
import '../../data/local_db/quest_log.dart';
import '../home/home_controller.dart';
import '../home/subject_progress.dart';
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart' show pathSubjects;
import '../progress/progress_controller.dart';
import 'quests_model.dart';

/// The three daily quests, the weekly badge, the achievements and the
/// streak rewards the design draws on Quêtes — each measured on something
/// the app really records (app ADR 0015):
///
/// | quest | measured on |
/// |---|---|
/// | the daily challenge | the backend's `daily_quest` (ADR 0019) |
/// | "Résous 5 exercices" | `HomeStats`' distinct lessons finished today |
/// | "Joue 10 minutes" | `HomeStats`' play time today |
///
/// Progress is measured here, so it's instant and offline. What a quest
/// takes and what it pays come from the backend's `quests` (backend ADR
/// 0154): the backend is the one that pays, so a quest it doesn't serve
/// shows no reward chip ("Joue 10 minutes", for now). See the 2026-10-27
/// revision of app ADR 0015.
///
/// A quest's completion is written to [QuestLog] the first time it is seen
/// complete, which is what the weekly badge and "50 quêtes" count.
enum QuestKind { challenge, exercises, minutes }

/// Each kind of quest's icon, the same everywhere it appears (Village's
/// quest tiles, the end-of-exercise celebration).
IconData questIconFor(QuestKind kind) => switch (kind) {
  QuestKind.challenge => Icons.bolt_rounded,
  QuestKind.exercises => Icons.task_alt_rounded,
  QuestKind.minutes => Icons.timer_outlined,
};

/// The backend's name for each kind in its `quests` list.
const _servedKind = {
  QuestKind.challenge: 'daily_challenge',
  QuestKind.exercises: 'exercises',
  QuestKind.minutes: 'minutes',
};

class DailyQuestItem {
  const DailyQuestItem({
    required this.kind,
    required this.target,
    required this.progress,
    required this.done,
    this.xpReward,
  });

  final QuestKind kind;
  final int target;
  final int progress;
  final bool done;

  /// The XP the backend pays for it, as it serves it. Null when the backend
  /// doesn't pay this quest (or hasn't said): then no chip, rather than a
  /// promise nobody keeps.
  final int? xpReward;

  String get key => kind.name;
}

/// The targets used until the backend serves its own.
const exercisesQuestTarget = 5;
const minutesQuestTarget = 10;

List<DailyQuestItem> buildDailyQuests({
  required DailyQuestDto? challenge,
  required int lessonsToday,
  required int msToday,
  List<QuestDefinitionDto>? served,
}) {
  final byKind = {for (final d in served ?? const []) d.kind: d};
  QuestDefinitionDto? def(QuestKind k) => byKind[_servedKind[k]];
  final minutes = msToday ~/ 60000;
  final lessonsTarget = def(QuestKind.exercises)?.target ?? exercisesQuestTarget;
  final minutesTarget = def(QuestKind.minutes)?.target ?? minutesQuestTarget;
  return [
    if (challenge != null)
      DailyQuestItem(
        kind: QuestKind.challenge,
        target: challenge.target,
        progress: challenge.progress.clamp(0, challenge.target),
        done: challenge.completed,
        xpReward: def(QuestKind.challenge)?.xp,
      ),
    DailyQuestItem(
      kind: QuestKind.exercises,
      target: lessonsTarget,
      progress: lessonsToday.clamp(0, lessonsTarget),
      done: lessonsToday >= lessonsTarget,
      xpReward: def(QuestKind.exercises)?.xp,
    ),
    DailyQuestItem(
      kind: QuestKind.minutes,
      target: minutesTarget,
      progress: minutes.clamp(0, minutesTarget),
      done: minutes >= minutesTarget,
      xpReward: def(QuestKind.minutes)?.xp,
    ),
  ];
}

/// The eight achievements the design's badge grid names, in its order.
enum Achievement {
  streak3,
  questMaster,
  level10,
  streak7,
  allSubjects50,
  level20,
  quests50,
  explorer,
}

/// Every subject with curriculum: the Carte's own list, so an achievement
/// over "all subjects" counts the same subjects the kid can actually play.
final realSubjects = pathSubjects.toSet();

/// Which achievements the kid's real data earns right now. Unlocks are
/// recorded once and never revoked, so this only ever adds.
Set<Achievement> earnedAchievements({
  required int? streak,
  required int? level,
  required Map<String, Set<String>> history,
  required Map<String, double> subjectProgress,
  required Set<String> playedSubjects,
}) {
  final total = history.values.fold<int>(0, (n, s) => n + s.length);
  return {
    if ((streak ?? 0) >= 3) Achievement.streak3,
    if ((streak ?? 0) >= 7) Achievement.streak7,
    if ((level ?? 0) >= 10) Achievement.level10,
    if ((level ?? 0) >= 20) Achievement.level20,
    if (history.values.any((day) => day.length >= QuestKind.values.length))
      Achievement.questMaster,
    if (total >= 50) Achievement.quests50,
    if (realSubjects.every((s) => (subjectProgress[s] ?? 0) >= 0.5))
      Achievement.allSubjects50,
    if (playedSubjects.containsAll(realSubjects)) Achievement.explorer,
  };
}

/// "Badge de la semaine": 15 quests finished Monday to Sunday.
const weeklyBadgeTarget = 15;

int completedInWeek(Map<String, Set<String>> history, DateTime today) {
  final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
  var n = 0;
  for (var i = 0; i < 7; i++) {
    n += history[isoDay(DateTime(monday.year, monday.month, monday.day + i))]
            ?.length ??
        0;
  }
  return n;
}

String isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

/// The key a weekly badge is recorded under: `week:<that Monday>`.
String weeklyBadgeKey(DateTime today) => 'week:${isoDay(
      DateTime(today.year, today.month, today.day - (today.weekday - 1)),
    )}';

/// One earned thing for "Réussites récentes": an achievement or a week's
/// badge, and the day it was earned.
class EarnedItem {
  const EarnedItem({required this.key, required this.day, this.achievement});

  final String key;
  final String day;

  /// Null for a weekly badge.
  final Achievement? achievement;
}

class QuestBoard {
  const QuestBoard({
    required this.quests,
    required this.weekCompleted,
    required this.unlocked,
    required this.today,
  });

  final List<DailyQuestItem> quests;
  final int weekCompleted;

  /// Every recorded unlock: achievement names and `week:` keys → the day.
  final Map<String, String> unlocked;
  final DateTime today;

  int get openCount => quests.where((q) => !q.done).length;
  int get doneCount => quests.length - openCount;

  bool has(Achievement a) => unlocked.containsKey(a.name);

  bool get weeklyBadgeEarned => unlocked.containsKey(weeklyBadgeKey(today));

  /// Most recent first.
  List<EarnedItem> get recent {
    final byName = {for (final a in Achievement.values) a.name: a};
    final items = [
      for (final e in unlocked.entries)
        EarnedItem(key: e.key, day: e.value, achievement: byName[e.key]),
    ]..sort((a, b) => b.day.compareTo(a.day));
    return items;
  }
}

final questLogProvider = Provider<QuestLog>(
  (ref) => QuestLog(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  ),
);

/// Re-evaluated whenever progress refreshes — which every play session
/// already triggers — so a quest finished in a session is recorded then.
final questBoardProvider = FutureProvider<QuestBoard>((ref) async {
  final progress = ref.watch(progressControllerProvider);
  final played = await ref.watch(playedDaysProvider.future);
  final bySubject = await ref.watch(subjectProgressProvider.future);
  final stats = await ref.watch(homeStatsProvider).today();
  final log = ref.watch(questLogProvider);
  final today = played.today;
  final day = isoDay(today);

  final quests = buildDailyQuests(
    challenge: progress.dailyQuest,
    lessonsToday: stats.lessonsCompleted,
    msToday: stats.msPlayed,
    served: progress.questDefinitions,
  );
  final history = await log.recordCompleted(
    day,
    [for (final q in quests) if (q.done) q.key],
  );

  final db = ref.watch(localDatabaseProvider);
  final ids = {for (final m in progress.masteries) m.skillNodeId};
  final playedSubjects = ids.isEmpty
      ? const <String>{}
      : {
          for (final row in await (db.select(db.skillNodeTable)
                ..where((t) => t.id.isIn(ids)))
              .get())
            row.subject,
        };

  final week = completedInWeek(history, today);
  final unlocked = await log.recordUnlocked(day, [
    for (final a in earnedAchievements(
      streak: progress.currentStreakDays,
      level: progress.level,
      history: history,
      subjectProgress: bySubject,
      playedSubjects: playedSubjects,
    ))
      a.name,
    if (week >= weeklyBadgeTarget) weeklyBadgeKey(today),
  ]);

  return QuestBoard(
    quests: quests,
    weekCompleted: week,
    unlocked: unlocked,
    today: today,
  );
});
