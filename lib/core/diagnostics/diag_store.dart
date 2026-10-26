import 'package:drift/drift.dart';

import '../../data/local_db/database.dart';
import 'boot_log.dart';
import 'diag_log.dart';

/// Where the latest copy of the error log lives: `app_state`, device scope.
const diagStateKey = 'diag.last_run';

/// Loads what the previous run recorded into [log], then keeps this run's
/// log saved (ADR 0038). A database that never answers just means no
/// saving: everything still reaches the console and the in-memory log.
Future<void> startDiagPersistence(LocalDatabase db, DiagLog log) async {
  final row =
      await (db.select(db.appStateTable)..where(
            (t) => t.kidId.equals(deviceScope) & t.key.equals(diagStateKey),
          ))
          .getSingleOrNull()
          .timeout(BootLog.localTimeout);
  log.restore(row?.value);

  Future<void> write(String json) => db
      .into(db.appStateTable)
      .insertOnConflictUpdate(
        AppStateTableCompanion.insert(
          kidId: deviceScope,
          key: diagStateKey,
          value: json,
          updatedAt: DateTime.now(),
        ),
      );

  // This run starts clean, so a clean run doesn't keep showing the last
  // one's errors as "previous".
  await write(DiagLog.encode(log.entries)).timeout(BootLog.localTimeout);
  log.onChanged = DiagPersister(write: write).schedule;
}
