import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/streak_local.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';

/// The days this kid played on this device, plus what "today" is.
///
/// Watches the progress controller for the same reason
/// `subjectProgressProvider` does: every place that ends a play session
/// already refreshes progress, so re-reading here on each refresh keeps the
/// week strip current without a second invalidation path.
class PlayedDays {
  const PlayedDays({required this.today, required this.days});

  final DateTime today;
  final Set<DateTime> days;

  bool get playedToday => days.contains(today);
}

final playedDaysProvider = FutureProvider<PlayedDays>((ref) async {
  ref.watch(progressControllerProvider);
  final local = StreakLocal(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  );
  return PlayedDays(today: local.today(), days: await local.playedDays());
});

/// One cell of the week strip.
class WeekDay {
  const WeekDay({
    required this.date,
    required this.played,
    required this.isToday,
  });

  final DateTime date;
  final bool played;
  final bool isToday;
}

/// The current week, Monday first — the design's strip reads L M M J V S D.
List<WeekDay> weekOf(DateTime today, Set<DateTime> played) {
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      _day(monday, i, today, played),
  ];
}

WeekDay _day(DateTime monday, int i, DateTime today, Set<DateTime> played) {
  // Calendar arithmetic, not `add(Duration)`: a DST change inside the week
  // would otherwise land a cell on 23:00 the day before.
  final date = DateTime(monday.year, monday.month, monday.day + i);
  return WeekDay(
    date: date,
    played: played.contains(date),
    isToday: date == today,
  );
}

/// A month as calendar cells, Sunday first — the design's calendar reads
/// D L M M J V S, unlike the Monday-first week strip, and both are kept as
/// drawn. Leading nulls pad the first week.
List<DateTime?> monthGrid(int year, int month) {
  final first = DateTime(year, month);
  final leading = first.weekday % 7; // Sunday → 0
  final days = DateTime(year, month + 1, 0).day;
  return [
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= days; d++) DateTime(year, month, d),
  ];
}

/// The streak milestone the goal bar aims at: the next of these, then every
/// hundred. Display only — nothing is awarded at a milestone, and the
/// backend has no goal concept; this just gives the bar an end.
const streakMilestones = [3, 7, 14, 30, 50, 100];

int nextStreakGoal(int streak) {
  for (final m in streakMilestones) {
    if (streak < m) return m;
  }
  return (streak ~/ 100 + 1) * 100;
}
