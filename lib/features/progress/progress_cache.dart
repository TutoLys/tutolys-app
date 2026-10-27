import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';

/// The last good `/me/progress`, per kid, in `app_state`.
///
/// A failed read must never look like lost progress (Hafid, 2026-10-25: a
/// three-minute backend 500 showed XP 0, streak "–" and a vanished daily
/// challenge, and he thought his data was gone). When a read fails, the
/// app shows this instead; when a read succeeds but leaves fields empty,
/// they're filled from it ([mergeWithCached]). ADR 0033.
class ProgressCache {
  ProgressCache(this.db, {required this.kidId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDatabase db;
  final String kidId;
  final DateTime Function() _clock;

  static const _key = 'progress.last_snapshot';

  String _today() => _clock().toIso8601String().substring(0, 10);

  /// The cached snapshot, or null. A daily quest saved on another day is
  /// dropped: yesterday's challenge is not today's.
  Future<ProgressSnapshot?> read() async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(_key)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final j = jsonDecode(row.value) as Map<String, Object?>;
      final snapshot = Map<String, Object?>.of(
        j['snapshot']! as Map<String, Object?>,
      );
      if (j['day'] != _today()) snapshot['daily_quest'] = null;
      return ProgressSnapshot.fromJson(snapshot);
    } on Object {
      return null; // unreadable: as if never cached
    }
  }

  Future<void> write(ProgressSnapshot snapshot) async {
    final now = _clock();
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: _key,
            value: jsonEncode({'day': _today(), 'snapshot': snapshot.toJson()}),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

/// A fresh read, with what it left empty taken from [cached].
///
/// The backend degrades gracefully: when it can't reach telemetry, the
/// streak, freeze balance and daily quest come back null. That means
/// "unknown this time", not "gone", so the last known values stay.
///
/// XP is taken as read. It used to be "the larger stands", on the theory
/// that a ledger never shrinks, but `total_xp` is never null and never
/// degraded, and the backend can lower it on purpose: XP option A
/// recomputed every total (Léa 390 → 98, backend ADR 0047), and the old
/// rule kept showing the pre-recompute number forever. Mastery is the
/// server's own table and is also taken as read.
ProgressSnapshot mergeWithCached(
  ProgressSnapshot fresh,
  ProgressSnapshot? cached,
) {
  if (cached == null) return fresh;
  final hasLevel = fresh.skillsTotal != null;
  return ProgressSnapshot(
    masteries: fresh.masteries,
    currentStreakDays: fresh.currentStreakDays ?? cached.currentStreakDays,
    freezesAvailable: fresh.freezesAvailable ?? cached.freezesAvailable,
    dailyQuest: fresh.dailyQuest ?? cached.dailyQuest,
    // Never filled from the cache: its balance never degrades, and its
    // "earned" null means "don't say", which a cached guess would undo.
    streakFreeze: fresh.streakFreeze,
    quests: fresh.quests ?? cached.quests,
    totalXp: fresh.totalXp,
    level: hasLevel ? fresh.level : cached.level,
    skillsCompleted: hasLevel ? fresh.skillsCompleted : cached.skillsCompleted,
    skillsTotal: hasLevel ? fresh.skillsTotal : cached.skillsTotal,
  );
}
