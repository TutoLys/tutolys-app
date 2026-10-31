import 'package:drift/drift.dart';

import '../../core/time/quebec_day.dart';
import 'database.dart';

/// Offline streak estimate, reconciled with the backend whenever a live
/// read succeeds (plan §5.8: "streaks work offline and reconcile with the
/// backend on sync — backend is source of truth").
///
/// The local estimate exists for exactly one reason: so a kid who opens the
/// app with no network still sees *a* real streak number — computed from
/// their own device's play history — rather than a dash. It is never
/// written back to the backend and never overrides a successful live read;
/// `ProgressController` only reaches for it when the live fetch fails.
class StreakLocal {
  const StreakLocal(this.db, {required this.kidId, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LocalDatabase db;

  /// Whose streak. Required rather than defaulted so a shared tablet cannot
  /// extend one sibling's streak because the other played (ADR 0014).
  final String kidId;

  final DateTime Function() _clock;

  /// Québec's day, the same one quests and counters use (K8).
  String _todayIso() => quebecIsoDay(_clock());

  /// Call once per finished exercise (completed, not abandoned — same rule
  /// `HomeStats.recordExerciseCompleted` already follows). Idempotent: a
  /// second completion the same day is a no-op, not a second row.
  Future<void> recordPlayedToday() async {
    await db
        .into(db.playedDateTable)
        .insert(
          PlayedDateTableCompanion.insert(kidId: kidId, date: _todayIso()),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Today, as a local calendar date with no time part — the same "today"
  /// [recordPlayedToday] writes, so a caller comparing against
  /// [playedDays] cannot drift by a timezone.
  DateTime today() => DateTime.parse(_todayIso());

  /// Every local calendar day this kid completed an exercise on this
  /// device, for drawing — Quêtes' week strip and the streak calendar.
  ///
  /// All of them rather than a range: the table holds one row per day ever
  /// played, so a whole school year is a few hundred rows, and one read
  /// lets the calendar page between months without going back to the DB.
  ///
  /// This device only. Play on a sibling's tablet, or a gap a streak freeze
  /// bridged server-side, is not here — the streak *number* comes from the
  /// backend, this only marks the days.
  Future<Set<DateTime>> playedDays() async {
    final rows = await (db.select(db.playedDateTable)
          ..where((t) => t.kidId.equals(kidId)))
        .get();
    return {for (final r in rows) DateTime.parse(r.date)};
  }

  /// Consecutive local calendar days with at least one completed exercise,
  /// counted back from today — the same algorithm and one-day grace as
  /// telemetry's `kid_streak` (still-active as long as yesterday, not just
  /// today, was played), so the estimate and the backend's own truth read
  /// the same way to a kid even before they've reconciled.
  Future<int> currentStreak() async {
    final rows = await (db.select(db.playedDateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    if (rows.isEmpty) return 0;

    final playedDates = rows.map((r) => DateTime.parse(r.date)).toList();
    final today = DateTime.parse(_todayIso());
    final mostRecent = playedDates.first;

    if (today.difference(mostRecent).inDays > 1) return 0;

    var streak = 1;
    for (var i = 0; i < playedDates.length - 1; i++) {
      final gap = playedDates[i].difference(playedDates[i + 1]).inDays;
      if (gap == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
