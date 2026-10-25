import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pairing/pairing_controller.dart';
import 'database.dart';

/// What this device knows about one skill node the kid has played.
class NodeProgress {
  const NodeProgress({
    required this.skillNodeId,
    required this.plays,
    required this.lastCompletedAt,
    required this.everPerfect,
  });

  final String skillNodeId;

  /// Completed runs of an exercise on this node (abandoned ones don't count).
  final int plays;
  final DateTime lastCompletedAt;

  /// At least one run answered every question right on the first try.
  final bool everPerfect;

  Map<String, Object?> toJson() => {
    'plays': plays,
    'last_completed_at': lastCompletedAt.toUtc().toIso8601String(),
    'ever_perfect': everPerfect,
  };

  static NodeProgress? fromJson(String skillNodeId, String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return NodeProgress(
        skillNodeId: skillNodeId,
        plays: j['plays'] as int,
        lastCompletedAt: DateTime.parse(j['last_completed_at'] as String),
        everPerfect: j['ever_perfect'] == true,
      );
    } on Object {
      return null;
    }
  }
}

/// Which nodes this kid has finished an exercise on, known **the moment the
/// exercise ends** — for Carte to mark them done without waiting.
///
/// Server mastery is the authority on *mastered*, but it arrives late: it
/// needs telemetry upload, the 15-minute `refresh_mastery` job and an 80%
/// mastery score. A child who just finished a node should see it change
/// now. This is that local, immediate fact — "played to the end here" — and
/// deliberately nothing more: it never claims mastery.
///
/// Stored per kid in `app_state` (ADR 0014), one `node_progress.<id>` key
/// per node, so it needs no migration and survives outbox pruning.
class NodeProgressLocal {
  const NodeProgressLocal(
    this.db, {
    required this.kidId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalDatabase db;
  final String kidId;
  final DateTime Function() _clock;

  static const _prefix = 'node_progress.';

  Future<void> recordCompleted(
    String skillNodeId, {
    required bool perfect,
  }) async {
    final key = '$_prefix$skillNodeId';
    final existing =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(key)))
            .getSingleOrNull();
    final before = existing == null
        ? null
        : NodeProgress.fromJson(skillNodeId, existing.value);
    final now = _clock();
    final next = NodeProgress(
      skillNodeId: skillNodeId,
      plays: (before?.plays ?? 0) + 1,
      lastCompletedAt: now,
      everPerfect: (before?.everPerfect ?? false) || perfect,
    );
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: key,
            value: jsonEncode(next.toJson()),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Every node this kid has completed here, by skill node id.
  Future<Map<String, NodeProgress>> all() async {
    final rows = await (db.select(
      db.appStateTable,
    )..where((t) => t.kidId.equals(kidId) & t.key.like('$_prefix%'))).get();
    final out = <String, NodeProgress>{};
    for (final row in rows) {
      final id = row.key.substring(_prefix.length);
      final progress = NodeProgress.fromJson(id, row.value);
      if (progress != null) out[id] = progress;
    }
    return out;
  }
}

/// The active kid's completed nodes. The play screen invalidates it after
/// every completed exercise, so a page watching it updates on return.
final nodeProgressProvider = FutureProvider<Map<String, NodeProgress>>((ref) {
  final kidId = ref.watch(activeKidIdProvider);
  if (kidId == null) return const {};
  return NodeProgressLocal(
    ref.watch(localDatabaseProvider),
    kidId: kidId,
  ).all();
});
