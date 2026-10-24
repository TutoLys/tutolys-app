import 'dart:math';

import 'package:dio/dio.dart';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/telemetry_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/sync/drift_event_outbox.dart';
import 'package:tutolys_app/data/sync/outbox_flusher.dart';

/// A telemetry service that can be taken offline.
///
/// Mirrors the real server's two behaviours that the outbox depends on:
/// idempotency (a re-sent event is reported `duplicate`, not an error) and
/// per-event outcomes.
class FakeTelemetryServer extends TelemetryApi {
  // A real Dio that is never used: the only method that would touch it is
  // overridden below.
  FakeTelemetryServer() : super(dio: Dio());

  /// Event ids the server holds. A set, because the server is idempotent.
  final Set<String> stored = {};

  bool offline = false;
  bool unauthorized = false;

  /// A server-side failure (503). Unlike offline, this escalates the backoff.
  bool retryable = false;

  int uploadCalls = 0;

  /// Ids the server will always refuse, whatever happens.
  final Set<String> alwaysReject = {};

  /// Counts how many times each id was presented, to prove nothing is
  /// delivered twice.
  final Map<String, int> presented = {};

  @override
  Future<UploadResult> uploadBatch({
    required List<Map<String, Object?>> events,
    required String accessToken,
  }) async {
    uploadCalls++;

    if (offline) return const UploadOffline();
    if (unauthorized) return const UploadUnauthorized();
    if (retryable) return const UploadRetryable('HTTP 503');

    final delivered = <String>[];
    final rejected = <String, String>{};

    for (final event in events) {
      final id = event['event_id'] as String;
      presented.update(id, (n) => n + 1, ifAbsent: () => 1);

      if (alwaysReject.contains(id)) {
        rejected[id] = 'permanently invalid';
        continue;
      }
      // Idempotent: already-held ids are reported delivered, not failed.
      stored.add(id);
      delivered.add(id);
    }

    return UploadProcessed(delivered: delivered, rejected: rejected);
  }
}

void main() {
  late LocalDatabase db;
  late DriftEventOutbox outbox;
  late FakeTelemetryServer server;
  late OutboxFlusher flusher;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 10, 16, 12);
    db = LocalDatabase.memory();
    outbox = DriftEventOutbox(db, kidId: 'kid-1', clock: () => now);
    server = FakeTelemetryServer();
    flusher = OutboxFlusher(
      outbox: outbox,
      api: server,
      accessToken: () => 'token',
      // Seeded, so a failing run is reproducible despite the jitter.
      random: Random(42),
      clock: () => now,
    );
  });

  tearDown(() async {
    flusher.stop();
    await db.close();
  });

  /// Advance the fake clock past any backoff window.
  void advance(Duration by) => now = now.add(by);

  Map<String, Object?> event(String id, {String type = 'attempt'}) => {
        'schema_version': 1,
        'event_id': id,
        'event_ts': now.toIso8601String(),
        'session_id': 'session-1',
        'event_type': type,
        'app_version': '0.1.0',
      };

  group('durability', () {
    test('an event is on disk the moment it is logged', () async {
      await outbox.add(event('e1'));

      // Not buffered: killing the app here must not lose it.
      expect(await outbox.depth(), 1);
    });

    test('adding the same event twice enqueues it once', () async {
      await outbox.add(event('e1'));
      await outbox.add(event('e1'));

      expect(await outbox.depth(), 1);
    });

    test('re-adding a delivered event does not resurrect it', () async {
      await outbox.add(event('e1'));
      await outbox.markDelivered(['e1']);

      await outbox.add(event('e1'));

      expect(await outbox.depth(), 0, reason: 'a replay must not re-queue');
    });

    test('pending comes back oldest first', () async {
      for (var i = 0; i < 5; i++) {
        await outbox.add(event('e$i'));
        advance(const Duration(seconds: 1));
      }

      final pending = await outbox.pending();

      expect(
        pending.map((e) => e['event_id']).toList(),
        ['e0', 'e1', 'e2', 'e3', 'e4'],
        reason: 'ordering is what lets a report reconstruct the attempt '
            'sequence',
      );
    });
  });

  group('A4 acceptance: offline mid-session, then back online', () {
    test('20 exercises offline all arrive exactly once', () async {
      // A session's worth of play with no network: 20 exercises, each a start,
      // two attempts and a completion.
      server.offline = true;

      final expected = <String>[];
      for (var exercise = 0; exercise < 20; exercise++) {
        for (final part in ['start', 'a1', 'a2', 'complete']) {
          final id = 'ex$exercise-$part';
          expected.add(id);
          await outbox.add(event(id));
          advance(const Duration(milliseconds: 500));
        }
        // The flusher keeps trying throughout, and keeps failing.
        await flusher.flush();
      }

      expect(expected, hasLength(80));
      expect(await outbox.depth(), 80, reason: 'nothing may be dropped offline');
      expect(server.stored, isEmpty);

      // Network returns.
      server.offline = false;

      // Drain. Each pass takes one batch of 50, and backoff windows have to
      // open, so the clock moves between passes.
      for (var pass = 0; pass < 20; pass++) {
        advance(const Duration(minutes: 1));
        await flusher.flush();
        if (await outbox.depth() == 0) break;
      }

      expect(await outbox.depth(), 0, reason: 'every event must land');
      expect(server.stored.length, 80);
      expect(server.stored, containsAll(expected));

      // The heart of the criterion: exactly once, not at-least-once.
      final deliveredTwice = server.presented.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();
      expect(
        deliveredTwice,
        isEmpty,
        reason: 'these were presented to the server more than once',
      );
    });

    test('a resend after a lost acknowledgement is deduped, not duplicated',
        () async {
      // The realistic failure: the server stored the batch but the response
      // never arrived, so the client retries events the server already has.
      await outbox.add(event('e1'));
      server.stored.add('e1'); // server already holds it

      await flusher.flush();

      // Reported as duplicate and cleared, not retried forever.
      expect(await outbox.depth(), 0);
      expect(server.stored, {'e1'});
    });
  });

  group('backoff', () {
    test('a failed event is not retried immediately', () async {
      server.offline = true;
      await outbox.add(event('e1'));

      await flusher.flush();
      final callsAfterFirst = server.uploadCalls;

      // Same instant: the backoff window has not opened.
      await flusher.flush();

      expect(server.uploadCalls, callsAfterFirst,
          reason: 'retried inside its own backoff window');
      expect(await outbox.depth(), 1);
    });

    test('the retry window opens as time passes', () async {
      server.offline = true;
      await outbox.add(event('e1'));
      await flusher.flush();

      advance(const Duration(minutes: 5));
      server.offline = false;
      await flusher.flush();

      expect(await outbox.depth(), 0);
    });

    test('offline retries on a flat, short window rather than escalating',
        () async {
      // Deliberate: losing Wi-Fi is not the events' fault and fixes itself, so
      // escalating to minutes would delay a sync that could have happened as
      // soon as the network returned.
      server.offline = true;
      await outbox.add(event('e1'));

      final windows = <Duration>[];
      for (var attempt = 0; attempt < 4; attempt++) {
        await flusher.flush();
        final row = (await db.select(db.eventOutboxTable).get()).single;
        windows.add(row.nextRetryAt!.difference(now));
        advance(const Duration(hours: 1));
      }

      // Every window sits inside the flush interval, however many failures.
      expect(windows, everyElement(lessThanOrEqualTo(flusher.interval)));
    });

    test('a server error escalates the backoff', () async {
      // A 503 may mean the server is struggling, so repeated failure must back
      // off further rather than pile on.
      server.retryable = true;
      await outbox.add(event('e1'));

      final windows = <Duration>[];
      for (var attempt = 0; attempt < 5; attempt++) {
        await flusher.flush();
        final row = (await db.select(db.eventOutboxTable).get()).single;
        windows.add(row.nextRetryAt!.difference(now));
        advance(const Duration(hours: 1)); // always reopen the window
      }

      expect(windows.last, greaterThan(windows.first),
          reason: 'repeated failure must back off further');
    });

    test('jitter keeps a classroom from retrying in lockstep', () async {
      // Thirty tablets that lost Wi-Fi together must not all return at the
      // same instant.
      final windows = <int>{};

      for (var device = 0; device < 30; device++) {
        final deviceDb = LocalDatabase.memory();
        final deviceOutbox = DriftEventOutbox(deviceDb, kidId: 'kid-1', clock: () => now);
        final deviceFlusher = OutboxFlusher(
          outbox: deviceOutbox,
          api: FakeTelemetryServer()..offline = true,
          accessToken: () => 'token',
          random: Random(device),
          clock: () => now,
        );

        await deviceOutbox.add(event('e$device'));
        await deviceFlusher.flush();

        final row = (await deviceDb.select(deviceDb.eventOutboxTable).get()).single;
        windows.add(row.nextRetryAt!.millisecondsSinceEpoch);
        await deviceDb.close();
      }

      // With sub-second precision preserved (see storeDateTimeAsText), 30
      // devices land on 30 distinct instants. Before that fix drift truncated
      // to whole seconds and they collapsed into ~20 buckets.
      expect(windows.length, 30,
          reason: 'retry times are clustered; jitter is not working');
    });
  });

  group('failure handling', () {
    test('an event the server will never accept is kept, not dropped', () async {
      await outbox.add(event('bad'));
      server.alwaysReject.add('bad');

      for (var i = 0; i < 12; i++) {
        await flusher.flush();
        advance(const Duration(hours: 1));
      }

      // Never silently deleted — the product is the data.
      expect(await outbox.depth(), 1);
      final stuck = await outbox.stuck(afterAttempts: 10);
      expect(stuck, hasLength(1));
      expect(stuck.single.lastError, contains('invalid'));
    });

    test('one bad event does not block the good ones behind it', () async {
      server.alwaysReject.add('bad');
      await outbox.add(event('bad'));
      advance(const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        await outbox.add(event('good$i'));
        advance(const Duration(seconds: 1));
      }

      await flusher.flush();

      expect(server.stored, {'good0', 'good1', 'good2'});
      expect(await outbox.depth(), 1, reason: 'only the bad event remains');
    });

    test('a revoked credential pauses rather than spinning', () async {
      server.unauthorized = true;
      await outbox.add(event('e1'));

      await flusher.flush();
      final callsAfterPause = server.uploadCalls;
      await flusher.flush();
      await flusher.flush();

      expect(flusher.isPaused, isTrue);
      expect(server.uploadCalls, callsAfterPause,
          reason: 'kept hammering the server with a dead credential');
      expect(await outbox.depth(), 1, reason: 'events must survive the pause');
    });

    test('re-pairing resumes uploads', () async {
      server.unauthorized = true;
      await outbox.add(event('e1'));
      await flusher.flush();

      server.unauthorized = false;
      flusher.resume();
      await flusher.flush();

      expect(await outbox.depth(), 0);
    });

    test('nothing is uploaded while unpaired', () async {
      final unpaired = OutboxFlusher(
        outbox: outbox,
        api: server,
        accessToken: () => null,
        random: Random(1),
        clock: () => now,
      );
      await outbox.add(event('e1'));

      await unpaired.flush();

      expect(server.uploadCalls, 0);
      expect(await outbox.depth(), 1, reason: 'queued until the app pairs');
    });

    test('concurrent flushes do not double-send', () async {
      for (var i = 0; i < 3; i++) {
        await outbox.add(event('e$i'));
      }

      await Future.wait([flusher.flush(), flusher.flush(), flusher.flush()]);

      expect(server.uploadCalls, 1, reason: 'overlapping flushes must coalesce');
      expect(server.presented.values, everyElement(1));
    });
  });

  group('batching and housekeeping', () {
    test('a batch is capped so a weak connection can finish it', () async {
      for (var i = 0; i < 120; i++) {
        await outbox.add(event('e$i'));
        advance(const Duration(milliseconds: 100));
      }

      await flusher.flush();

      expect(server.stored.length, 50, reason: 'one batch per flush');
      expect(await outbox.depth(), 70);
    });

    test('delivered rows are kept briefly, then swept', () async {
      await outbox.add(event('e1'));
      await flusher.flush();

      // Retained, so a crash mid-acknowledgement cannot cause a re-send.
      expect(await db.select(db.eventOutboxTable).get(), hasLength(1));

      advance(const Duration(hours: 7));
      final pruned = await outbox.pruneDelivered();

      expect(pruned, 1);
      expect(await db.select(db.eventOutboxTable).get(), isEmpty);
    });

    test('health reports depth, stuck count and pause state', () async {
      await outbox.add(event('e1'));
      await outbox.add(event('e2'));

      final health = await flusher.health();

      expect(health.depth, 2);
      expect(health.stuck, 0);
      expect(health.paused, isFalse);
      expect(health.isHealthy, isTrue);
    });

    test('health goes unhealthy once events are stuck', () async {
      server.alwaysReject.add('bad');
      await outbox.add(event('bad'));
      for (var i = 0; i < 11; i++) {
        await flusher.flush();
        advance(const Duration(hours: 1));
      }

      final health = await flusher.health();

      expect(health.stuck, 1);
      expect(health.isHealthy, isFalse);
    });
  });

  group('capacity cap', () {
    test('under the cap, nothing is evicted', () async {
      for (var i = 0; i < 5; i++) {
        await outbox.add(event('e$i'));
      }

      final evicted = await outbox.enforceCapacityCap(maxRows: 10);

      expect(evicted, 0);
      expect(await outbox.depth(), 5);
      final stats = await outbox.capacityDropStats();
      expect(stats.totalDropped, 0);
      expect(stats.lastDroppedAt, isNull);
    });

    test('over the cap, the oldest rows are evicted down to the ceiling', () async {
      for (var i = 0; i < 10; i++) {
        await outbox.add(event('e$i'));
        advance(const Duration(seconds: 1));
      }

      final evicted = await outbox.enforceCapacityCap(maxRows: 6);

      expect(evicted, 4);
      expect(await outbox.depth(), 6);
      final remaining = await db.select(db.eventOutboxTable).get();
      // Oldest 4 (e0-e3) gone; newest 6 (e4-e9) survive.
      expect(
        remaining.map((r) => r.eventId).toSet(),
        {'e4', 'e5', 'e6', 'e7', 'e8', 'e9'},
      );
    });

    test('an eviction is counted and timestamped, never silent', () async {
      for (var i = 0; i < 10; i++) {
        await outbox.add(event('e$i'));
      }

      await outbox.enforceCapacityCap(maxRows: 6);

      final stats = await outbox.capacityDropStats();
      expect(stats.totalDropped, 4);
      expect(stats.lastDroppedAt, now);
    });

    test('the drop counter accumulates across repeated evictions', () async {
      for (var i = 0; i < 10; i++) {
        await outbox.add(event('first-$i'));
      }
      await outbox.enforceCapacityCap(maxRows: 6);

      advance(const Duration(days: 1));
      for (var i = 0; i < 10; i++) {
        await outbox.add(event('second-$i'));
      }
      await outbox.enforceCapacityCap(maxRows: 6);

      final stats = await outbox.capacityDropStats();
      // First call: 10 -> 6 (4 evicted). Second call starts from 6 + 10 new
      // = 16 -> 6 (10 evicted). 4 + 10 = 14, not reset by the second call.
      expect(stats.totalDropped, 14);
      expect(stats.lastDroppedAt, now); // the most recent eviction's time
    });

    test(
      'flush() enforces the cap even while sustained-offline '
      '(the scenario this exists for)',
      () async {
        server.offline = true;
        for (var i = 0; i < 10; i++) {
          await outbox.add(event('e$i'));
        }
        final cappedFlusher = OutboxFlusher(
          outbox: outbox,
          api: server,
          accessToken: () => 'token',
          maxOutboxRows: 6,
          random: Random(42),
          clock: () => now,
        );

        // UploadOffline never reaches the success branch pruneDelivered
        // lives in — this is exactly the path that would have silently
        // skipped the cap if it had been nested there instead of in
        // `finally`.
        await cappedFlusher.flush();

        expect(await outbox.depth(), 6);
      },
    );

    test('flush() enforces the cap even while paused', () async {
      final pausedFlusher = OutboxFlusher(
        outbox: outbox,
        api: server,
        accessToken: () => 'token',
        maxOutboxRows: 3,
        random: Random(42),
        clock: () => now,
      );
      server.unauthorized = true;
      await outbox.add(event('trigger-pause'));
      await pausedFlusher.flush(); // 401 -> _paused = true
      expect(pausedFlusher.isPaused, isTrue);

      // A kid can keep playing while the device's credential sits revoked —
      // PlayScreen's writes to the outbox aren't gated by pairing state.
      for (var i = 0; i < 5; i++) {
        await outbox.add(event('while-paused-$i'));
      }

      await pausedFlusher.flush();

      expect(pausedFlusher.isPaused, isTrue, reason: 'still paused, not retried');
      expect(await outbox.depth(), lessThanOrEqualTo(3));
    });

    test('isHealthy turns false once a capacity eviction has happened', () async {
      for (var i = 0; i < 10; i++) {
        await outbox.add(event('e$i'));
      }

      final healthyBefore = await flusher.health();
      expect(healthyBefore.isHealthy, isTrue);

      await outbox.enforceCapacityCap(maxRows: 6);
      final healthAfter = await flusher.health();

      expect(healthAfter.droppedForCapacity, 4);
      expect(healthAfter.lastDroppedForCapacityAt, now);
      expect(healthAfter.isHealthy, isFalse);
    });
  });

  group('the telemetry client writes only to the outbox', () {
    test('a full engine run lands in the outbox and uploads once', () async {
      // The engine SDK knows nothing about storage; it calls the telemetry
      // client, which writes here. This is the seam A3 built and A4 fills in.
      final client = TelemetryClient(
        outbox: outbox,
        sessionId: 'session-1',
        appVersion: '0.1.0',
        clock: () => now,
      );

      await client.logSessionStart();
      await client.startExercise(
        const ExerciseIdentity(
          exerciseId: '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          exerciseVersion: 1,
          engineKey: 'mcq',
          engineVersion: 1,
          skillNodeId: 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
          subject: 'MATH',
          grade: 1,
          rank: 0,
        ),
      );
      await client.logAttempt(answer: {'option_id': 'b'}, isCorrect: false);
      await client.logAttempt(answer: {'option_id': 'a'}, isCorrect: true);
      await client.logComplete();
      await client.logSessionEnd();

      expect(await outbox.depth(), 6);

      await flusher.flush();

      expect(await outbox.depth(), 0);
      expect(server.stored.length, 6);
      expect(server.presented.values, everyElement(1));
    });
  });
}
