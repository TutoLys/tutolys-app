import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engine_sdk/engine_sdk.dart';

import '../sync/drift_event_outbox.dart';
import 'database.dart';

/// [ActivitySessionStore] on the app's drift database.
///
/// [commit] is the reason this exists: a step's outbox events and the
/// session's new snapshot land in **one transaction**, so there is no
/// moment at which the outbox holds a step the snapshot doesn't know about
/// (or the reverse). See `ActivitySessionStore.commit` for why that gap
/// would otherwise duplicate events at the server.
class DriftActivitySessionStore implements ActivitySessionStore {
  DriftActivitySessionStore(
    this.db, {
    required this.kidId,
    DateTime Function()? clock,
  }) : _outbox = DriftEventOutbox(db, kidId: kidId, clock: clock),
       _now = clock ?? DateTime.now;

  final LocalDatabase db;

  /// The kid this store writes for. A snapshot for another kid is refused:
  /// writing one child's session under another's outbox scope would upload
  /// it with the wrong device token.
  final String kidId;
  final DriftEventOutbox _outbox;
  final DateTime Function() _now;

  @override
  Future<void> commit({
    required List<Map<String, Object?>> events,
    required SessionSnapshot snapshot,
  }) async {
    if (snapshot.kidId != kidId) {
      throw ArgumentError(
        'snapshot belongs to ${snapshot.kidId}, store is scoped to $kidId',
      );
    }
    await db.transaction(() async {
      for (final e in events) {
        await _outbox.add(e);
      }
      if (snapshot.state.phase.isTerminal) {
        await (db.delete(db.activitySessionTable)..where(
              (t) => t.activitySessionId.equals(snapshot.activitySessionId),
            ))
            .go();
      } else {
        await db
            .into(db.activitySessionTable)
            .insertOnConflictUpdate(
              ActivitySessionTableCompanion.insert(
                activitySessionId: snapshot.activitySessionId,
                kidId: snapshot.kidId,
                exerciseId: snapshot.exerciseId,
                snapshot: jsonEncode(snapshot.toJson()),
                updatedAt: _now(),
              ),
            );
      }
    });
  }

  @override
  Future<SessionSnapshot?> live({
    required String kidId,
    required String exerciseId,
  }) async {
    final rows =
        await (db.select(db.activitySessionTable)
              ..where(
                (t) => t.kidId.equals(kidId) & t.exerciseId.equals(exerciseId),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    for (final row in rows) {
      final snap = _decode(row);
      if (snap != null) return snap;
    }
    return null;
  }

  @override
  Future<List<SessionSnapshot>> allLive(String kidId) async {
    final rows = await (db.select(
      db.activitySessionTable,
    )..where((t) => t.kidId.equals(kidId))).get();
    return [for (final row in rows) ?_decode(row)];
  }

  @override
  Future<void> remove(String activitySessionId) => (db.delete(
    db.activitySessionTable,
  )..where((t) => t.activitySessionId.equals(activitySessionId))).go();

  SessionSnapshot? _decode(ActivitySessionRow row) {
    try {
      return SessionSnapshot.fromJson(
        jsonDecode(row.snapshot) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }
}
