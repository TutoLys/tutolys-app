import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Whether a message is an idea or a problem.
enum FeedbackKind {
  idea,
  bug;

  String get wire => name;
}

/// One message waiting to be sent.
class QueuedFeedback {
  const QueuedFeedback({
    required this.clientId,
    required this.kind,
    required this.text,
    required this.context,
    required this.createdAt,
  });

  /// Sent with the message so a retry of one already stored is ignored.
  final String clientId;
  final FeedbackKind kind;
  final String text;

  /// The allowlisted context only (`FeedbackContext.toJson`).
  final Map<String, String> context;
  final DateTime createdAt;

  Map<String, Object?> toBody() => {
    'client_id': clientId,
    'kind': kind.wire,
    'text': text,
    'context': context,
  };

  Map<String, Object?> _toJson() => {
    ...toBody(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static QueuedFeedback _fromJson(Map<String, dynamic> json) => QueuedFeedback(
    clientId: json['client_id'] as String,
    kind: FeedbackKind.values.byName(json['kind'] as String),
    text: json['text'] as String,
    context: (json['context'] as Map<String, dynamic>).cast<String, String>(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Ideas and bug reports a guardian sent while the device was offline (app
/// ADR 0104). **Its own store, never the telemetry outbox**: the text is
/// what a child typed and is personal data, and telemetry must never hold
/// it.
///
/// One JSON key in `app_state` under the kid's own owner, so it goes when
/// the kid is removed from the device (`KidLocalData.wipe`) and a sibling's
/// message is never sent under another child's token. Capped at [maxQueued];
/// past that the oldest is dropped and counted, never silently.
class FeedbackQueue {
  const FeedbackQueue(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const maxQueued = 20;
  static const _queueKey = 'feedback.queue';
  static const _evictedKey = 'feedback.evicted_total';

  Future<List<QueuedFeedback>> pending() async {
    final raw = await _read(_queueKey);
    if (raw == null) return const [];
    return [
      for (final item in jsonDecode(raw) as List<dynamic>)
        QueuedFeedback._fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> add(QueuedFeedback item) => db.transaction(() async {
    final items = [...await pending(), item];
    final over = items.length - maxQueued;
    if (over > 0) {
      items.removeRange(0, over);
      final evicted = int.tryParse(await _read(_evictedKey) ?? '') ?? 0;
      await _write(_evictedKey, '${evicted + over}');
    }
    await _save(items);
  });

  Future<void> remove(String clientId) => db.transaction(() async {
    final items = await pending();
    await _save([
      for (final i in items)
        if (i.clientId != clientId) i,
    ]);
  });

  /// How many messages the cap has dropped on this device, ever.
  Future<int> evictedTotal() async =>
      int.tryParse(await _read(_evictedKey) ?? '') ?? 0;

  Future<void> _save(List<QueuedFeedback> items) async {
    if (items.isNotEmpty) {
      return _write(
        _queueKey,
        jsonEncode([for (final i in items) i._toJson()]),
      );
    }
    await (db.delete(
      db.appStateTable,
    )..where((t) => t.kidId.equals(kidId) & t.key.equals(_queueKey))).go();
  }

  Future<String?> _read(String key) async {
    final row =
        await (db.select(db.appStateTable)
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
