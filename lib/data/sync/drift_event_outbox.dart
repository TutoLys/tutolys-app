import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engine_sdk/engine_sdk.dart';

import '../local_db/database.dart';

/// The real outbox: durable, idempotent, append-only.
///
/// Implements the interface `engine_sdk` declares, so engines and the telemetry
/// client never learn that storage exists. Swapping the in-memory
/// implementation for this one changes nothing above it.
class DriftEventOutbox implements EventOutbox {
  DriftEventOutbox(this.db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final LocalDatabase db;
  final DateTime Function() _now;

  @override
  Future<void> add(Map<String, Object?> event) async {
    final eventId = event['event_id'] as String;

    await db.into(db.eventOutboxTable).insert(
          EventOutboxTableCompanion.insert(
            eventId: eventId,
            payload: jsonEncode(event),
            queuedAt: _now(),
          ),
          // Idempotent, matching the server. A retry inside the app must not
          // enqueue a second copy, and re-adding must not reset the attempt
          // count or resurrect an already-delivered event.
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<List<Map<String, Object?>>> pending({int limit = 50}) async {
    final now = _now();

    final rows = await (db.select(db.eventOutboxTable)
          ..where((t) => t.deliveredAt.isNull())
          // Respect backoff: an event that failed recently is not retried
          // until its window opens, or one bad event would be hammered.
          ..where(
            (t) => t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerOrEqualValue(now),
          )
          // Oldest first, so a report can reconstruct the attempt sequence.
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)])
          ..limit(limit))
        .get();

    return rows
        .map((row) => jsonDecode(row.payload) as Map<String, Object?>)
        .toList(growable: false);
  }

  @override
  Future<void> markDelivered(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    final now = _now();
    await (db.update(db.eventOutboxTable)
          ..where((t) => t.eventId.isIn(eventIds)))
        .write(EventOutboxTableCompanion(deliveredAt: Value(now)));
  }

  @override
  Future<int> depth() async {
    final count = db.eventOutboxTable.eventId.count();
    final query = db.selectOnly(db.eventOutboxTable)
      ..addColumns([count])
      ..where(db.eventOutboxTable.deliveredAt.isNull());

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Record a failed upload attempt and set the next retry window.
  ///
  /// Backoff is per event rather than global, so one permanently-rejected
  /// event cannot hold up everything queued behind it.
  Future<void> recordFailure(
    List<String> eventIds, {
    required String error,
    required Duration Function(int attempts) backoff,
  }) async {
    if (eventIds.isEmpty) return;

    final rows = await (db.select(db.eventOutboxTable)
          ..where((t) => t.eventId.isIn(eventIds)))
        .get();

    await db.batch((batch) {
      for (final row in rows) {
        final attempts = row.attempts + 1;
        batch.update(
          db.eventOutboxTable,
          EventOutboxTableCompanion(
            attempts: Value(attempts),
            nextRetryAt: Value(_now().add(backoff(attempts))),
            lastError: Value(error),
          ),
          where: (t) => t.eventId.equals(row.eventId),
        );
      }
    });
  }

  /// Drop acknowledged rows older than [keepFor].
  ///
  /// Delivered rows linger briefly so a crash mid-acknowledgement cannot lose
  /// the record of what already went out and cause a re-send. They are swept
  /// later rather than deleted on the spot.
  Future<int> pruneDelivered({Duration keepFor = const Duration(hours: 6)}) {
    final cutoff = _now().subtract(keepFor);
    return (db.delete(db.eventOutboxTable)
          ..where((t) => t.deliveredAt.isNotNull())
          ..where((t) => t.deliveredAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Events that have failed enough times to be worth surfacing.
  ///
  /// Never dropped silently — the product is the data, so a stuck event is
  /// reported rather than discarded (plan §8).
  Future<List<OutboxEvent>> stuck({int afterAttempts = 10}) {
    return (db.select(db.eventOutboxTable)
          ..where((t) => t.deliveredAt.isNull())
          ..where((t) => t.attempts.isBiggerOrEqualValue(afterAttempts)))
        .get();
  }

  static const _droppedCountKey = 'outbox_capacity.dropped_total';
  static const _lastDropAtKey = 'outbox_capacity.last_dropped_at';

  /// A hard ceiling on undelivered rows, so a backend outage lasting months
  /// (not the days/weeks the backoff schedule is tuned for) cannot grow
  /// local storage without bound on a device that may have very little to
  /// spare.
  ///
  /// A deliberate, narrow softening of "never drop an event silently" (see
  /// this class's own doc and [stuck]): past this ceiling, the oldest
  /// undelivered rows are evicted — but every eviction is counted and
  /// timestamped (see [capacityDropStats]), never just deleted and
  /// forgotten. "Never silently" becomes "never *unaccounted*": the data
  /// itself can be gone, but the fact that it happened, when, and how much
  /// never is. A kid playing normally, even through a real multi-week
  /// outage, will not come close to the default ceiling — this exists for
  /// "the device sat unreachable for the better part of a year," not the
  /// realistic case.
  ///
  /// Returns the number of rows evicted (0 if under the cap).
  Future<int> enforceCapacityCap({int maxRows = 10000}) async {
    final total = await depth();
    if (total <= maxRows) return 0;

    final overflow = total - maxRows;
    final toEvict = await (db.select(db.eventOutboxTable)
          ..where((t) => t.deliveredAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)])
          ..limit(overflow))
        .get();

    if (toEvict.isEmpty) return 0;

    final now = _now();
    final stats = await capacityDropStats();

    await db.transaction(() async {
      await (db.delete(db.eventOutboxTable)
            ..where((t) => t.eventId.isIn(toEvict.map((row) => row.eventId))))
          .go();

      await db.batch((batch) {
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            key: _droppedCountKey,
            value: '${stats.totalDropped + toEvict.length}',
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            key: _lastDropAtKey,
            value: now.toIso8601String(),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      });
    });

    return toEvict.length;
  }

  /// How many events have ever been evicted by [enforceCapacityCap], and
  /// when the most recent eviction happened. Zero/null means it has never
  /// triggered — the overwhelmingly common case.
  Future<({int totalDropped, DateTime? lastDroppedAt})> capacityDropStats() async {
    final rows = await (db.select(db.appStateTable)
          ..where((t) => t.key.isIn([_droppedCountKey, _lastDropAtKey])))
        .get();
    final byKey = {for (final row in rows) row.key: row.value};

    final rawDate = byKey[_lastDropAtKey];
    return (
      totalDropped: int.tryParse(byKey[_droppedCountKey] ?? '') ?? 0,
      lastDroppedAt: rawDate == null ? null : DateTime.tryParse(rawDate),
    );
  }
}
