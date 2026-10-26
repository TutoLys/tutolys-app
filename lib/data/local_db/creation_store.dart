import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/pairing/pairing_controller.dart';
import 'database.dart';

/// The active kid's shelf, or null before anyone has paired. The play
/// screen puts it above every engine (`CreationShelfScope`).
final creationShelfProvider = Provider<CreationShelf?>((ref) {
  final kidId = ref.watch(activeKidIdProvider);
  if (kidId == null) return null;
  return CreationStore(ref.watch(localDatabaseProvider), kidId: kidId);
});

/// "Mes créations": one kid's [CreationShelf], on the device only (app ADR
/// 0036). Never uploaded, to the backend or to telemetry (D6).
class CreationStore implements CreationShelf {
  CreationStore(
    this.db, {
    required this.kidId,
    this.maxPerKid = defaultMaxPerKid,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final LocalDatabase db;

  /// Whose creations. Required so a sibling's drawing never lands in
  /// another child's gallery (ADR 0014).
  final String kidId;

  /// Per-kid ceiling. A child making one thing a day takes over six months
  /// to reach it; it exists so storage can't grow without bound.
  final int maxPerKid;

  static const defaultMaxPerKid = 200;

  final DateTime Function() _clock;
  final String Function() _newId;

  static const _evictedCountKey = 'creations.evicted_total';
  static const _lastEvictedAtKey = 'creations.last_evicted_at';

  @override
  Future<Creation> save({
    required String engineKey,
    required String exerciseId,
    required Map<String, Object?> payload,
    int payloadVersion = 1,
  }) async {
    final String encoded;
    try {
      encoded = jsonEncode(payload);
    } on JsonUnsupportedObjectError catch (e) {
      throw ArgumentError.value(payload, 'payload', 'not JSON-encodable: $e');
    }
    if (utf8.encode(encoded).length > CreationShelf.maxPayloadBytes) {
      throw ArgumentError.value(
        payload,
        'payload',
        'over ${CreationShelf.maxPayloadBytes} bytes encoded',
      );
    }

    final row = CreationRow(
      id: _newId(),
      kidId: kidId,
      engineKey: engineKey,
      exerciseId: exerciseId,
      payloadVersion: payloadVersion,
      payload: encoded,
      hung: false,
      createdAt: _clock(),
    );
    await db.transaction(() async {
      await db.into(db.creationTable).insert(row);
      await _enforceCap();
    });
    return _toCreation(row);
  }

  @override
  Future<List<Creation>> list({
    Set<String>? engineKeys,
    bool? hung,
    int? limit,
  }) async {
    final query = db.select(db.creationTable)
      ..where((t) => t.kidId.equals(kidId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (engineKeys != null) {
      query.where((t) => t.engineKey.isIn(engineKeys));
    }
    if (hung != null) query.where((t) => t.hung.equals(hung));
    if (limit != null) query.limit(limit);
    return [for (final row in await query.get()) _toCreation(row)];
  }

  @override
  Future<void> setHung(String id, bool hung) => db.transaction(() async {
    final row = await _mine(id).getSingleOrNull();
    if (row == null || row.hung == hung) return;
    if (hung) {
      final alreadyHung = await list(hung: true);
      if (alreadyHung.length >= CreationShelf.maxHung) {
        throw StateError(
          '${CreationShelf.maxHung} creations are already hung; '
          'take one down first',
        );
      }
    }
    await (db.update(db.creationTable)
          ..where((t) => t.kidId.equals(kidId) & t.id.equals(id)))
        .write(CreationTableCompanion(hung: Value(hung)));
  });

  @override
  Future<void> remove(String id) => (db.delete(
    db.creationTable,
  )..where((t) => t.kidId.equals(kidId) & t.id.equals(id))).go();

  /// How many of this kid's creations the cap has ever evicted, and when
  /// it last did. Never silent: the creation is gone, the fact isn't.
  Future<({int totalEvicted, DateTime? lastEvictedAt})> evictionStats() async {
    final rows =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId))
              ..where((t) => t.key.isIn([_evictedCountKey, _lastEvictedAtKey])))
            .get();
    final byKey = {for (final row in rows) row.key: row.value};
    final rawDate = byKey[_lastEvictedAtKey];
    return (
      totalEvicted: int.tryParse(byKey[_evictedCountKey] ?? '') ?? 0,
      lastEvictedAt: rawDate == null ? null : DateTime.tryParse(rawDate),
    );
  }

  SimpleSelectStatement<$CreationTableTable, CreationRow> _mine(String id) =>
      db.select(db.creationTable)
        ..where((t) => t.kidId.equals(kidId) & t.id.equals(id));

  /// Past [maxPerKid], evicts the oldest *un-hung* creations and counts
  /// them. A hung one is never evicted: the child chose to keep it.
  Future<void> _enforceCap() async {
    final count = db.creationTable.id.count();
    final total =
        (await (db.selectOnly(db.creationTable)
                  ..addColumns([count])
                  ..where(db.creationTable.kidId.equals(kidId)))
                .getSingle())
            .read(count) ??
        0;
    if (total <= maxPerKid) return;

    final toEvict =
        await (db.select(db.creationTable)
              ..where((t) => t.kidId.equals(kidId) & t.hung.equals(false))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(total - maxPerKid))
            .get();
    if (toEvict.isEmpty) return;

    await (db.delete(
      db.creationTable,
    )..where((t) => t.id.isIn(toEvict.map((r) => r.id)))).go();

    final stats = await evictionStats();
    final now = _clock();
    await db.batch((batch) {
      for (final (key, value) in [
        (_evictedCountKey, '${stats.totalEvicted + toEvict.length}'),
        (_lastEvictedAtKey, now.toIso8601String()),
      ]) {
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: key,
            value: value,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Creation _toCreation(CreationRow row) => Creation(
    id: row.id,
    engineKey: row.engineKey,
    exerciseId: row.exerciseId,
    payloadVersion: row.payloadVersion,
    payload: (jsonDecode(row.payload) as Map).cast<String, Object?>(),
    hung: row.hung,
    createdAt: row.createdAt,
  );
}
