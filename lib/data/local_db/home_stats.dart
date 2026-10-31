import 'package:drift/drift.dart';

import '../../core/time/quebec_day.dart';
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
  const HomeStats(this.db, {required this.kidId, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LocalDatabase db;

  /// Whose counters. `app_state` holds both per-kid and device-level keys,
  /// so every read and write here is scoped — otherwise two siblings on one
  /// tablet would share "today's" exercise count (ADR 0014).
  final String kidId;

  final DateTime Function() _clock;

  static const _dateKey = 'home_stats.date';
  static const _completedKey = 'home_stats.exercises_completed';
  static const _msKey = 'home_stats.ms_played';
  static const _lessonsKey = 'home_stats.lesson_ids';

  /// Québec's day, so the counters roll over at its midnight (K8).
  String _today() => quebecIsoDay(_clock());

  /// Call once per finished exercise (completed, not abandoned — an
  /// abandoned run taught nothing worth counting as "played today").
  ///
  /// [exerciseId] is the lesson's id. "Résous 5 exercices" counts distinct
  /// lessons a day, as the backend that pays it does (backend ADR 0154), so
  /// replaying one lesson five times doesn't finish it. A lesson with no id
  /// still counts toward the tile's total, but not toward the quest.
  Future<void> recordExerciseCompleted({
    required int elapsedMs,
    String? exerciseId,
  }) async {
    final today = _today();
    final current = await _read();

    final sameDay = current.date == today;
    final completed = (sameDay ? current.exercisesCompleted : 0) + 1;
    final ms = (sameDay ? current.msPlayed : 0) + elapsedMs;
    final lessons = {
      if (sameDay) ...current.lessonIds,
      ?exerciseId,
    };

    await _write(
      date: today,
      exercisesCompleted: completed,
      msPlayed: ms,
      lessonIds: lessons,
    );
  }

  /// Today's counters — zero if the stored date isn't today, without
  /// writing anything (a pure read never resets state on its own).
  ///
  /// `exercisesCompleted` counts every finish (Home's tile);
  /// `lessonsCompleted` counts distinct lessons (the quest).
  Future<({int exercisesCompleted, int lessonsCompleted, int msPlayed})>
  today() async {
    final current = await _read();
    if (current.date != _today()) {
      return (exercisesCompleted: 0, lessonsCompleted: 0, msPlayed: 0);
    }
    return (
      exercisesCompleted: current.exercisesCompleted,
      lessonsCompleted: current.lessonIds.length,
      msPlayed: current.msPlayed,
    );
  }

  Future<
    ({String? date, int exercisesCompleted, int msPlayed, Set<String> lessonIds})
  >
  _read() async {
    final rows = await (db.select(db.appStateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..where(
            (t) => t.key.isIn([_dateKey, _completedKey, _msKey, _lessonsKey]),
          ))
        .get();
    final byKey = {for (final row in rows) row.key: row.value};
    final lessons = byKey[_lessonsKey] ?? '';
    return (
      date: byKey[_dateKey],
      exercisesCompleted: int.tryParse(byKey[_completedKey] ?? '') ?? 0,
      msPlayed: int.tryParse(byKey[_msKey] ?? '') ?? 0,
      lessonIds: {
        for (final id in lessons.split('\n'))
          if (id.isNotEmpty) id,
      },
    );
  }

  Future<void> _write({
    required String date,
    required int exercisesCompleted,
    required int msPlayed,
    required Set<String> lessonIds,
  }) async {
    final now = _clock();
    await db.batch((batch) {
      for (final entry in {
        _dateKey: date,
        _completedKey: '$exercisesCompleted',
        _msKey: '$msPlayed',
        // Lesson ids are UUIDs: a newline never appears in one.
        _lessonsKey: lessonIds.join('\n'),
      }.entries) {
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            kidId: kidId,
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
