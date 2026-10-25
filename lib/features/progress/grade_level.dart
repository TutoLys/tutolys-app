import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../data/local_db/database.dart';

/// The level of a school year (Hafid, 2026-10-25): 1 to 99, from the share
/// of the grade's skills the kid has completed. 99 only when every one is;
/// a new grade starts again at 1. XP is points only and has no part in it.
///
/// A skill counts as completed when every lesson on it is finished — the
/// backend's rule for `skills_completed`, applied here to this device's own
/// record so a finished lesson moves the level at once (ADR 0033).
int gradeLevelFor(int completed, int total) {
  if (total <= 0) return 1;
  final done = completed.clamp(0, total);
  return 1 + (98 * done) ~/ total;
}

/// How far through the current level, 0..1 (1 at level 99).
double gradeLevelProgress(int completed, int total) {
  if (total <= 0) return 0;
  final done = completed.clamp(0, total);
  if (done == total) return 1;
  final x = 98 * done / total;
  return x - x.floor();
}

/// What the header and Progrès show.
class GradeLevel {
  const GradeLevel({
    required this.level,
    required this.completed,
    required this.total,
    required this.progress,
  });

  final int level;
  final int completed;
  final int total;

  /// Toward the next level, 0..1.
  final double progress;
}

/// Local and server, merged by the progression rule: local-instant,
/// server-authoritative, monotonic.
///
/// - The denominator is the server's `skills_total` when known: the device
///   only caches the subjects it has synced, so its own count can be short,
///   which would inflate the level. Otherwise the larger of the device's
///   count and the last server total it saw.
/// - Completed is whichever source counts more.
/// - The level never goes below a value already shown in this grade
///   ([highWater]) or the server's.
GradeLevel? mergeGradeLevel({
  required int localCompleted,
  required int localTotal,
  int? serverCompleted,
  int? serverTotal,
  int? serverLevel,
  int? lastServerTotal,
  int highWater = 0,
}) {
  final total = serverTotal ?? math.max(localTotal, lastServerTotal ?? 0);
  if (total <= 0) return null;
  final completed = math.min(
    math.max(localCompleted, serverCompleted ?? 0),
    total,
  );
  final formula = gradeLevelFor(completed, total);
  final level = [formula, serverLevel ?? 0, highWater].reduce(math.max);
  return GradeLevel(
    level: level,
    completed: completed,
    total: total,
    // Held up by the high-water mark or the server, the bar restarts at 0
    // rather than claiming progress toward a level it already shows.
    progress: level == formula ? gradeLevelProgress(completed, total) : 0,
  );
}

/// Per kid and per grade, in `app_state`: the highest level shown and the
/// last server total. Keyed by grade, so a new grade starts from nothing.
class GradeLevelStore {
  const GradeLevelStore(this.db, {required this.kidId, required this.grade});

  final LocalDatabase db;
  final String kidId;
  final int grade;

  String get _highKey => 'grade_level.$grade.high';
  String get _totalKey => 'grade_level.$grade.total';

  Future<(int high, int? total)> read() async {
    final rows =
        await (db.select(db.appStateTable)..where(
              (t) => t.kidId.equals(kidId) & t.key.isIn([_highKey, _totalKey]),
            ))
            .get();
    final values = {for (final r in rows) r.key: int.tryParse(r.value)};
    return (values[_highKey] ?? 0, values[_totalKey]);
  }

  Future<void> write({required int high, int? total}) async {
    final now = DateTime.now();
    await db.batch((b) {
      for (final (key, value) in [
        (_highKey, high),
        if (total != null) (_totalKey, total),
      ]) {
        b.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: key,
            value: '$value',
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
