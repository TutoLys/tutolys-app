/// TutoLys's day ends at midnight in Québec (K8, Hafid 2026-10-31): quests,
/// the streak and the daily counters all roll over together then, whatever
/// timezone the device is set to.
///
/// America/Toronto's rule, written out rather than loading a tz database for
/// one zone: UTC−5, and UTC−4 from the second Sunday of March at 2:00 to the
/// first Sunday of November at 2:00 (the rule since 2007). If Québec ever
/// changes it, this function changes with an app update.
library;

/// [instant] (default: now) as a wall clock in Québec. The result's fields
/// are Québec's year, month, day and time, so its date is TutoLys's "today".
/// Use it for calendar days, never to measure durations.
DateTime quebecNow([DateTime? instant]) {
  final utc = (instant ?? DateTime.now()).toUtc();
  final wall = utc.subtract(Duration(hours: _isDaylight(utc) ? 4 : 5));
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
  );
}

/// Québec's calendar day for [instant] (default: now), with no time part.
DateTime quebecToday([DateTime? instant]) {
  final q = quebecNow(instant);
  return DateTime(q.year, q.month, q.day);
}

/// Québec's calendar day for [instant] as `yyyy-mm-dd`, the format every
/// local day key uses.
String quebecIsoDay([DateTime? instant]) =>
    quebecNow(instant).toIso8601String().substring(0, 10);

bool _isDaylight(DateTime utc) {
  final y = utc.year;
  // 2:00 standard time is 7:00 UTC; 2:00 daylight time is 6:00 UTC.
  final start = DateTime.utc(y, 3, _nthSunday(y, 3, 2), 7);
  final end = DateTime.utc(y, 11, _nthSunday(y, 11, 1), 6);
  return !utc.isBefore(start) && utc.isBefore(end);
}

int _nthSunday(int year, int month, int n) {
  final first = DateTime.utc(year, month, 1);
  return 1 + (DateTime.sunday - first.weekday) % 7 + 7 * (n - 1);
}
