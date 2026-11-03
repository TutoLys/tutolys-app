import 'package:flutter/painting.dart' show Color;

import '../../core/i18n/strings.dart';
import '../../core/time/quebec_day.dart';
import '../../data/api/progress_api.dart';

/// The four divisions of the personal league (backend ADR 0207). The wire
/// carries the key; the app owns the names, in both languages.
enum LeagueDivision { bronze, silver, gold, diamond }

LeagueDivision divisionOf(String key) => LeagueDivision.values.firstWhere(
  (d) => d.name == key,
  orElse: () => LeagueDivision.bronze,
);

/// The division one step up, or null at the top.
LeagueDivision? nextDivision(LeagueDivision d) =>
    d == LeagueDivision.diamond ? null : LeagueDivision.values[d.index + 1];

String divisionName(Strings t, LeagueDivision d) => switch (d) {
  LeagueDivision.bronze => t.leagueBronze,
  LeagueDivision.silver => t.leagueSilver,
  LeagueDivision.gold => t.leagueGold,
  LeagueDivision.diamond => t.leagueDiamond,
};

/// Medal colours. Bronze is a warm brown, never a red; Diamant takes the
/// design's own blue rather than an invented cyan.
Color medalColor(LeagueDivision d, Color gold, Color blue) => switch (d) {
  LeagueDivision.bronze => const Color(0xFFB7793F),
  LeagueDivision.silver => const Color(0xFF9AA7B8),
  LeagueDivision.gold => gold,
  LeagueDivision.diamond => blue,
};

/// The one line under the league about effort. Only ever good news or the
/// kid's own progress: never a comparison downward, never "below".
sealed class EffortLine {
  const EffortLine();
}

/// More XP than [percentile] % of the kids of [grade] who played this week.
class EffortPercentile extends EffortLine {
  const EffortPercentile(this.percentile, this.grade);
  final int percentile;
  final int grade;
}

/// This week is already past last week, by [xp].
class EffortAheadOfLastWeek extends EffortLine {
  const EffortAheadOfLastWeek(this.xp);
  final int xp;
}

/// This week's own XP, with encouragement.
class EffortKeepGoing extends EffortLine {
  const EffortKeepGoing(this.xp);
  final int xp;
}

/// Nothing yet this week, or a division just lost: a fresh start.
class EffortFreshStart extends EffortLine {
  const EffortFreshStart();
}

/// Which effort line to show. A served percentile wins; otherwise the kid
/// against themselves. Last week is a whole week and this one a partial
/// one, so "more than last week" shows only once it's true.
EffortLine effortLine(LeagueDto league, EffortPercentileDto? percentile) {
  if (percentile != null) {
    return EffortPercentile(percentile.percentile, percentile.grade);
  }
  final xp = league.xpThisWeek;
  final last = league.lastWeek;
  if (last != null && xp > last.xp) return EffortAheadOfLastWeek(xp - last.xp);
  if (xp > 0) return EffortKeepGoing(xp);
  return const EffortFreshStart();
}

String effortText(Strings t, EffortLine line) => switch (line) {
  EffortPercentile(:final percentile, :final grade) => t.effortPercentile(
    percentile,
    grade,
  ),
  EffortAheadOfLastWeek(:final xp) => t.effortAheadOfLastWeek(xp),
  EffortKeepGoing(:final xp) => t.effortKeepGoing(xp),
  EffortFreshStart() => t.effortFreshStart,
};

/// Whole Québec days until the week ends: 1 on Sunday, 7 on Monday.
int leagueDaysLeft(LeagueDto league, {DateTime? now}) {
  final DateTime end;
  if (league.weekEnd case final e?) {
    end = quebecToday(e);
  } else {
    final s = DateTime.parse(league.weekStart);
    end = DateTime(s.year, s.month, s.day + 7);
  }
  final today = quebecToday(now);
  // Calendar days, counted in UTC so a DST change can't make one 23 hours.
  final days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return days.clamp(1, 7);
}

/// A promotion worth celebrating: last week moved the kid up. Placement,
/// holding and demotion are never announced (ADR 0207: a seven-year-old is
/// not told they dropped).
typedef LeaguePromotion = ({String weekStart, LeagueDivision division});

LeaguePromotion? promotionOf(LeagueDto? league) {
  final last = league?.lastWeek;
  if (last == null || last.outcome != 'promoted') return null;
  return (weekStart: last.weekStart, division: divisionOf(last.division));
}

/// The fact key the backend dedupes a promotion on, `league:<week_start>`.
String leagueFactKey(String weekStart) => 'league:$weekStart';
