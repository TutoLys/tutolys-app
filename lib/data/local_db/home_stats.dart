import 'package:drift/drift.dart';

import 'database.dart';

/// Today's real, countable play stats — never a mastery/XP judgment, just a
/// count and a sum over what actually happened today.
///
/// Deliberately not read from `EventOutboxTable`: delivered events there are
/// pruned after as little as 6 hours (`DriftEventOutbox.pruneDelivered`,
/// crash-safety design, not analytics storage), so a kid opening the app
/// later the same day could find "today's" real activity already gone. This
/// uses `AppStateTable`'s existing key/value store instead — a running
/// counter that survives independently of outbox delivery, reset only by
/// the date actually rolling over.
class HomeStats {
  const HomeStats(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LocalDatabase db;
  final DateTime Function() _clock;

  static const _dateKey = 'home_stats.date';
  static const _completedKey = 'home_stats.exercises_completed';
  static const _msKey = 'home_stats.ms_played';

  String _today() => _clock().toIso8601String().substring(0, 10);

  /// Call once per finished exercise (completed, not abandoned — an
  /// abandoned run taught nothing worth counting as "played today").
  Future<void> recordExerciseCompleted({required int elapsedMs}) async {
    final today = _today();
    final current = await _read();

    final sameDay = current.date == today;
    final completed = (sameDay ? current.exercisesCompleted : 0) + 1;
    final ms = (sameDay ? current.msPlayed : 0) + elapsedMs;

    await _write(date: today, exercisesCompleted: completed, msPlayed: ms);
  }

  /// Today's counters — zero if the stored date isn't today, without
  /// writing anything (a pure read never resets state on its own).
  Future<({int exercisesCompleted, int msPlayed})> today() async {
    final current = await _read();
    if (current.date != _today()) {
      return (exercisesCompleted: 0, msPlayed: 0);
    }
    return (exercisesCompleted: current.exercisesCompleted, msPlayed: current.msPlayed);
  }

  Future<({String? date, int exercisesCompleted, int msPlayed})> _read() async {
    final rows = await (db.select(db.appStateTable)
          ..where((t) => t.key.isIn([_dateKey, _completedKey, _msKey])))
        .get();
    final byKey = {for (final row in rows) row.key: row.value};
    return (
      date: byKey[_dateKey],
      exercisesCompleted: int.tryParse(byKey[_completedKey] ?? '') ?? 0,
      msPlayed: int.tryParse(byKey[_msKey] ?? '') ?? 0,
    );
  }

  Future<void> _write({
    required String date,
    required int exercisesCompleted,
    required int msPlayed,
  }) async {
    final now = _clock();
    await db.batch((batch) {
      for (final entry in {
        _dateKey: date,
        _completedKey: '$exercisesCompleted',
        _msKey: '$msPlayed',
      }.entries) {
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
