import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// One notification the app wrote itself (ADR 0097).
class LocalNotification {
  const LocalNotification({
    required this.factKey,
    required this.type,
    required this.params,
    required this.createdAt,
    required this.isRead,
  });

  final String factKey;
  final String type;
  final Map<String, Object?> params;
  final DateTime createdAt;
  final bool isRead;
}

/// The kid's own inbox on this device: written the moment the app learns
/// something, with or without a connection (ADR 0097).
///
/// Per kid ([kidId]), so a sibling never sees another's. Idempotent by fact
/// key: the quest board re-evaluates often, and the same fact must land
/// once. A read made offline is remembered ([readPending]) until the server
/// has it.
class LocalInbox {
  const LocalInbox(this.db, {required this.kidId, this.clock});

  final LocalDatabase db;
  final String kidId;
  final DateTime Function()? clock;

  DateTime _now() => (clock ?? DateTime.now)();

  static const _readPendingKey = 'notifications.read_pending';

  /// Writes [factKey] once. True when it is new.
  Future<bool> add(
    String factKey,
    String type, {
    Map<String, Object?> params = const {},
  }) async {
    final inserted = await db
        .into(db.localNotificationTable)
        .insert(
          LocalNotificationTableCompanion.insert(
            kidId: kidId,
            factKey: factKey,
            type: type,
            params: Value(jsonEncode(params)),
            createdAt: _now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  /// Newest first.
  Future<List<LocalNotification>> list() async {
    final rows =
        await (db.select(db.localNotificationTable)
              ..where((t) => t.kidId.equals(kidId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return [
      for (final r in rows)
        LocalNotification(
          factKey: r.factKey,
          type: r.type,
          params: _decode(r.params),
          createdAt: r.createdAt,
          isRead: r.readAt != null,
        ),
    ];
  }

  /// Reads everything here, and remembers that the server must hear it.
  Future<void> markAllRead() async {
    await db.transaction(() async {
      await (db.update(db.localNotificationTable)
            ..where((t) => t.kidId.equals(kidId) & t.readAt.isNull()))
          .write(LocalNotificationTableCompanion(readAt: Value(_now())));
      await _setPending(true);
    });
  }

  /// Marks [factKeys] read here, without queueing anything: the server
  /// already says they are.
  Future<void> markRead(Iterable<String> factKeys) async {
    final keys = factKeys.toList();
    if (keys.isEmpty) return;
    await (db.update(db.localNotificationTable)..where(
          (t) =>
              t.kidId.equals(kidId) &
              t.factKey.isIn(keys) &
              t.readAt.isNull(),
        ))
        .write(LocalNotificationTableCompanion(readAt: Value(_now())));
  }

  /// A read the server hasn't heard yet.
  Future<bool> readPending() async {
    final row =
        await (db.select(db.appStateTable)..where(
              (t) => t.kidId.equals(kidId) & t.key.equals(_readPendingKey),
            ))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> clearReadPending() => _setPending(false);

  /// The highest level already announced at [grade], or null before the
  /// first look (when nothing is announced: a kid upgrading to this build
  /// doesn't get "level 7" for a level reached long ago).
  Future<int?> levelSeen(int grade) async {
    final row =
        await (db.select(db.appStateTable)..where(
              (t) =>
                  t.kidId.equals(kidId) &
                  t.key.equals('notifications.level_seen.g$grade'),
            ))
            .getSingleOrNull();
    return int.tryParse(row?.value ?? '');
  }

  Future<void> setLevelSeen(int grade, int level) => db
      .into(db.appStateTable)
      .insertOnConflictUpdate(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: 'notifications.level_seen.g$grade',
          value: '$level',
          updatedAt: _now(),
        ),
      );

  Future<void> _setPending(bool pending) => db
      .into(db.appStateTable)
      .insertOnConflictUpdate(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: _readPendingKey,
          value: '$pending',
          updatedAt: _now(),
        ),
      );

  static Map<String, Object?> _decode(String raw) {
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return const {};
    }
  }
}
