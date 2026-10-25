import 'package:drift_dev/api/migrations_native.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/drift_activity_session_store.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v4.dart' as v4;

/// The 4 → 5 upgrade adds `activity_session` (ADR 0019). It only adds a
/// table, so the real risk is the usual one: an existing user's queued
/// events and streak must come through untouched.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('upgrades to exactly the v5 schema, keeping existing rows', () async {
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    await old.customStatement(
      'INSERT INTO event_outbox (event_id, kid_id, payload, queued_at, attempts) '
      "VALUES ('ev-1', 'kid-lea', '{\"event_id\":\"ev-1\"}', '2026-10-24T10:00:00.000Z', 0)",
    );
    await old.customStatement(
      "INSERT INTO played_date (kid_id, date) VALUES ('kid-lea', '2026-10-24')",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    expect(await db.select(db.eventOutboxTable).get(), hasLength(1));
    expect(await db.select(db.playedDateTable).get(), hasLength(1));
    expect(await db.select(db.activitySessionTable).get(), isEmpty);
    await db.close();
  });

  group('DriftActivitySessionStore', () {
    late LocalDatabase db;
    late DriftActivitySessionStore store;

    setUp(() {
      db = LocalDatabase.memory();
      store = DriftActivitySessionStore(db, kidId: 'kid-lea');
    });
    tearDown(() => db.close());

    SessionSnapshot snap(
      SessionPhase phase, {
      String kid = 'kid-lea',
      String id = '3b1f0c3e-6c55-4c5e-9d0e-1a2b3c4d5e6f',
    }) => SessionSnapshot(
      activitySessionId: id,
      kidId: kid,
      exerciseId: 'ex-1',
      exerciseVersion: 1,
      contentHash: 'h',
      seed: 9,
      state: SessionState(phase: phase, questionCount: 2),
      engineState: const {
        'order': ['b', 'a'],
      },
      activeMs: 1500,
      updatedAt: DateTime.utc(2026, 10, 25),
    );

    test('a commit writes the events and the snapshot together', () async {
      await store.commit(
        events: [
          {'event_id': 'e1', 'event_type': 'exercise_start'},
        ],
        snapshot: snap(SessionPhase.awaitingInteraction),
      );
      final live = await store.live(kidId: 'kid-lea', exerciseId: 'ex-1');
      expect(live!.engineState, {
        'order': ['b', 'a'],
      });
      expect(live.activeMs, 1500);
      final rows = await db.select(db.eventOutboxTable).get();
      expect(rows.single.kidId, 'kid-lea');
    });

    test('a failing transaction writes neither half', () async {
      final bad = SessionSnapshot.fromJson(
        snap(SessionPhase.awaitingInteraction).toJson(),
      )!;
      // An event without an event_id fails inside the transaction, after the
      // first event was already inserted — the whole step must roll back.
      await expectLater(
        store.commit(
          events: [
            {'event_id': 'e1'},
            {'no_id': true},
          ],
          snapshot: bad,
        ),
        throwsA(anything),
      );
      expect(await db.select(db.eventOutboxTable).get(), isEmpty);
      expect(await db.select(db.activitySessionTable).get(), isEmpty);
    });

    test('a terminal commit removes the session row', () async {
      await store.commit(
        events: const [],
        snapshot: snap(SessionPhase.awaitingInteraction),
      );
      await store.commit(
        events: const [],
        snapshot: snap(SessionPhase.completed),
      );
      expect(await store.allLive('kid-lea'), isEmpty);
    });

    test('sessions are per kid, and a foreign snapshot is refused', () async {
      await store.commit(
        events: const [],
        snapshot: snap(SessionPhase.awaitingInteraction),
      );
      expect(await store.allLive('kid-sam'), isEmpty);
      expect(
        () => store.commit(
          events: const [],
          snapshot: snap(SessionPhase.awaitingInteraction, kid: 'kid-sam'),
        ),
        throwsArgumentError,
      );
    });

    test('an unreadable row is skipped, not thrown', () async {
      await db
          .into(db.activitySessionTable)
          .insert(
            ActivitySessionTableCompanion.insert(
              activitySessionId: 'junk',
              kidId: 'kid-lea',
              exerciseId: 'ex-1',
              snapshot: '{not json',
              updatedAt: DateTime.utc(2026, 10, 26),
            ),
          );
      expect(await store.live(kidId: 'kid-lea', exerciseId: 'ex-1'), isNull);
      expect(await store.allLive('kid-lea'), isEmpty);
    });
  });
}
