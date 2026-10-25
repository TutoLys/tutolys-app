import 'package:drift/drift.dart';

import '../local_db/database.dart';

/// When each subject's lessons last synced, so a Carte showing cached
/// content after a failed sync can say how old it is.
///
/// Device scope, keyed by subject and grade like the content cache itself:
/// siblings of the same grade share the lessons, so they share this too.
class ContentFreshness {
  ContentFreshness(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDatabase db;
  final DateTime Function() _clock;

  static String _key(String subject, int grade) =>
      'content.synced_at.$subject.$grade';

  Future<DateTime> markSynced(String subject, int grade) async {
    final now = _clock();
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: deviceScope,
            key: _key(subject, grade),
            value: now.toUtc().toIso8601String(),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
    return now;
  }

  /// Null when this subject has never synced on this device.
  Future<DateTime?> lastSynced(String subject, int grade) async {
    final row =
        await (db.select(db.appStateTable)..where(
              (t) =>
                  t.kidId.equals(deviceScope) &
                  t.key.equals(_key(subject, grade)),
            ))
            .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value)?.toLocal();
  }
}
