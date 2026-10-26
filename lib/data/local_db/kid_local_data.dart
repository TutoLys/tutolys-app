import 'package:drift/drift.dart';

import 'database.dart';

/// Everything one kid has on this device, and the one way to erase it
/// (ADR 0037).
///
/// Erases every kid-scoped row: queued events, streak days, engine
/// settings, the kid's own `app_state` keys, unfinished sessions and
/// "Mes créations". Leaves alone what the device shares between kids:
/// the content caches, and `app_state` rows owned by [deviceScope].
class KidLocalData {
  const KidLocalData(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  /// What the guardian is told before choosing: play results that haven't
  /// reached the server yet, and the creations kept in the gallery.
  Future<({int unsentResults, int creations})> summary() async {
    final unsent = db.eventOutboxTable.eventId.count();
    final unsentRow =
        await (db.selectOnly(db.eventOutboxTable)
              ..addColumns([unsent])
              ..where(
                db.eventOutboxTable.kidId.equals(kidId) &
                    db.eventOutboxTable.deliveredAt.isNull(),
              ))
            .getSingle();
    final made = db.creationTable.id.count();
    final madeRow =
        await (db.selectOnly(db.creationTable)
              ..addColumns([made])
              ..where(db.creationTable.kidId.equals(kidId)))
            .getSingle();
    return (
      unsentResults: unsentRow.read(unsent) ?? 0,
      creations: madeRow.read(made) ?? 0,
    );
  }

  /// Erases all of it, in one transaction, so a crash can't leave half a
  /// kid behind.
  Future<void> wipe() => db.transaction(() async {
    await (db.delete(
      db.eventOutboxTable,
    )..where((t) => t.kidId.equals(kidId))).go();
    await (db.delete(
      db.playedDateTable,
    )..where((t) => t.kidId.equals(kidId))).go();
    await (db.delete(
      db.engineSettingsTable,
    )..where((t) => t.kidId.equals(kidId))).go();
    await (db.delete(
      db.activitySessionTable,
    )..where((t) => t.kidId.equals(kidId))).go();
    await (db.delete(
      db.creationTable,
    )..where((t) => t.kidId.equals(kidId))).go();
    await (db.delete(
      db.appStateTable,
    )..where((t) => t.kidId.equals(kidId))).go();
  });
}
