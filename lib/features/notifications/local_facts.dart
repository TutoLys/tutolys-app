import '../progress/weekly_league.dart';
import '../quests/quest_board.dart';

/// One thing worth a notification, keyed by its fact (ADR 0097).
typedef NotificationFact = ({
  String factKey,
  String type,
  Map<String, Object?> params,
});

/// Notification types the app writes itself. The backend's
/// `daily_quest_completed` is reused, so the same fact from both sources
/// dedupes on `daily_quest:<day>`.
abstract final class LocalNotificationType {
  static const dailyQuest = 'daily_quest_completed';
  static const quest = 'quest_completed';
  static const achievement = 'achievement_earned';
  static const streak = 'streak_milestone';
  static const level = 'level_reached';

  /// The backend's own type (ADR 0207), so its promotion and the app's
  /// dedupe on `league:<week_start>`.
  static const league = 'league_promoted';
}

/// The facts behind what just changed on the quest board: quests newly
/// done today ([newQuests], `QuestKind` names), achievements newly earned
/// ([newUnlocks], `QuestLog` keys), and a level newly reached.
///
/// Fact keys follow the backend's `<kind>:<identity>` format:
/// `daily_quest:<day>` (the backend's own), `quest:<day>:<kind>`,
/// `achievement:<key>`, `level:g<grade>:<n>`, `league:<week_start>`.
List<NotificationFact> notificationFacts({
  required String day,
  Iterable<String> newQuests = const [],
  Iterable<String> newUnlocks = const [],
  Map<String, int> questTargets = const {},
  int? levelReached,
  int? grade,
  LeaguePromotion? promotion,
}) => [
  for (final q in newQuests)
    if (q == QuestKind.challenge.name)
      (
        factKey: 'daily_quest:$day',
        type: LocalNotificationType.dailyQuest,
        params: const {},
      )
    else
      (
        factKey: 'quest:$day:$q',
        type: LocalNotificationType.quest,
        params: {'quest': q, 'target': ?questTargets[q]},
      ),
  for (final key in newUnlocks)
    switch (key) {
      // The Série rewards: the chest at 3 days, "Gardien de la flamme" at 7.
      'streak3' || 'streak7' => (
        factKey: 'achievement:$key',
        type: LocalNotificationType.streak,
        params: {'days': key == 'streak3' ? 3 : 7},
      ),
      _ => (
        factKey: 'achievement:$key',
        type: LocalNotificationType.achievement,
        params: {'achievement': key},
      ),
    },
  if (levelReached != null && grade != null)
    (
      factKey: 'level:g$grade:$levelReached',
      type: LocalNotificationType.level,
      params: {'level': levelReached},
    ),
  if (promotion != null)
    (
      factKey: leagueFactKey(promotion.weekStart),
      type: LocalNotificationType.league,
      params: {'division': promotion.division.name},
    ),
];
