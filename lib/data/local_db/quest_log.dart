import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Which daily quests this kid finished on which day, and when each
/// achievement was first earned — the history Quêtes needs for "Badge de la
/// semaine", "50 quêtes" and "Réussites récentes".
///
/// Kept in `app_state` under the kid's own owner (ADR 0014), two JSON keys,
/// never pruned. Both are **monotonic**: a quest once completed stays
/// completed for that day, and an achievement once earned is never taken
/// back — a streak that later breaks does not un-earn "Série de 3 jours".
///
/// Local to this device, like `played_date`: play on another device does
/// not count here. The backend has no quest or achievement history to read
/// from yet (app ADR 0015).
class QuestLog {
  const QuestLog(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _questsKey = 'quests.completed';
  static const _achievementsKey = 'achievements.unlocked';

  /// Day (`yyyy-mm-dd`) → the quest keys completed that day.
  Future<Map<String, Set<String>>> completedByDay() async {
    final raw = await _read(_questsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries)
        e.key: {for (final k in e.value as List<dynamic>) k as String},
    };
  }

  /// Adds [keys] to [day]'s completions. Returns the merged history.
  Future<Map<String, Set<String>>> recordCompleted(
    String day,
    Iterable<String> keys,
  ) async {
    final history = await completedByDay();
    final before = history[day]?.length ?? 0;
    final merged = (history[day] ?? <String>{})..addAll(keys);
    history[day] = merged;
    if (merged.length != before) {
      await _write(_questsKey, jsonEncode({
        for (final e in history.entries) e.key: e.value.toList()..sort(),
      }));
    }
    return history;
  }

  /// Achievement key → the day it was first earned (`yyyy-mm-dd`).
  Future<Map<String, String>> unlocked() async {
    final raw = await _read(_achievementsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  /// Records [keys] as earned on [day], keeping the first date of any
  /// already earned. Returns the merged map.
  Future<Map<String, String>> recordUnlocked(
    String day,
    Iterable<String> keys,
  ) async {
    final current = await unlocked();
    var changed = false;
    for (final k in keys) {
      if (current.containsKey(k)) continue;
      current[k] = day;
      changed = true;
    }
    if (changed) await _write(_achievementsKey, jsonEncode(current));
    return current;
  }

  Future<String?> _read(String key) async {
    final row = await (db.select(db.appStateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => db
      .into(db.appStateTable)
      .insert(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: key,
          value: value,
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
