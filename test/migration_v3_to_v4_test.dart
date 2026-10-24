import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v3.dart' as v3;

/// The 3 → 4 upgrade (ADR 0014) is the one change in this feature that can
/// destroy a kid's data: before v4 every local row was implicitly the single
/// paired kid's, and the migration has to give them an owner without losing
/// the streak they built or the events still queued for upload.
///
/// These run against a *real* v3 database built from the dumped schema, not
/// against a fresh v4 one — which is the whole point, and what
/// `kid_scoping_test.dart` cannot tell you.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const lea = 'kid-lea';

  /// A v3 database with one of everything the migration has to carry.
  Future<void> seedV3(v3.DatabaseAtV3 db) async {
    await db.customStatement(
      "INSERT INTO played_date (date) VALUES ('2026-10-22'), ('2026-10-23')",
    );
    await db.customStatement(
      'INSERT INTO engine_settings (engine_key, setting_key, value) '
      "VALUES ('mcq', 'hints', 'true')",
    );
    await db.customStatement(
      'INSERT INTO event_outbox (event_id, payload, queued_at, attempts) '
      "VALUES ('ev-1', '{\"event_id\":\"ev-1\"}', '2026-10-23T10:00:00.000Z', 0)",
    );
    // The mixed table: one key belongs to the kid, one to the device.
    await db.customStatement(
      'INSERT INTO app_state (key, value, updated_at) VALUES '
      "('home_stats.exercises_completed', '7', '2026-10-23T10:00:00.000Z'), "
      "('outbox_capacity.dropped_total', '12', '2026-10-23T10:00:00.000Z')",
    );
  }

  /// Build a v3 database, seed it, then migrate it to v4 as [owner].
  Future<LocalDatabase> migrateSeeded({required String? owner}) async {
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await seedV3(oldDb);
    await oldDb.close();

    final db = LocalDatabase(schema.newConnection(), migrationKidId: owner);
    await verifier.migrateAndValidate(db, 4);
    return db;
  }

  group('a device that was already paired', () {
    test('the schema itself matches v4 exactly after migrating', () async {
      // `migrateAndValidate` throws if the migrated shape differs from the
      // dumped v4 schema in any column, type or constraint.
      final db = await migrateSeeded(owner: lea);
      await db.close();
    });

    test("the kid's streak history survives, owned by them", () async {
      final db = await migrateSeeded(owner: lea);
      addTearDown(db.close);

      final rows = await db.select(db.playedDateTable).get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.kidId == lea), isTrue);
      expect(
        rows.map((r) => r.date),
        containsAll(<String>['2026-10-22', '2026-10-23']),
      );
    });

    test('queued events survive, owned by them', () async {
      final db = await migrateSeeded(owner: lea);
      addTearDown(db.close);

      final row = await db.select(db.eventOutboxTable).getSingle();
      expect(row.eventId, 'ev-1');
      expect(
        row.kidId,
        lea,
        reason: 'an unowned event would upload under whoever pairs next',
      );
    });

    test('engine settings survive, owned by them', () async {
      final db = await migrateSeeded(owner: lea);
      addTearDown(db.close);

      final row = await db.select(db.engineSettingsTable).getSingle();
      expect(row.kidId, lea);
      expect(row.engineKey, 'mcq');
      expect(row.value, 'true');
    });

    test(
      'app_state splits: the kid keeps home stats, the device keeps capacity',
      () async {
        final db = await migrateSeeded(owner: lea);
        addTearDown(db.close);

        final rows = await db.select(db.appStateTable).get();
        final byKey = {for (final r in rows) r.key: r};

        expect(
          byKey['home_stats.exercises_completed']!.kidId,
          lea,
          reason: "today's count is the kid's, not the tablet's",
        );
        expect(byKey['home_stats.exercises_completed']!.value, '7');

        expect(
          byKey['outbox_capacity.dropped_total']!.kidId,
          deviceScope,
          reason: 'the outbox ceiling is a disk budget for the whole device',
        );
        expect(byKey['outbox_capacity.dropped_total']!.value, '12');
      },
    );

    test('an unknown app_state key defaults to the device, not the kid',
        () async {
      // The migration moves a whitelist (`home_stats.%`) rather than moving
      // everything and exempting a blocklist, so a key added later cannot be
      // silently attributed to whoever happened to be paired.
      final schema = await verifier.schemaAt(3);
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO app_state (key, value, updated_at) VALUES "
        "('something.added.later', 'x', '2026-10-23T10:00:00.000Z')",
      );
      await oldDb.close();

      final db = LocalDatabase(schema.newConnection(), migrationKidId: lea);
      await verifier.migrateAndValidate(db, 4);
      addTearDown(db.close);

      final row = await db.select(db.appStateTable).getSingle();
      expect(row.kidId, deviceScope);
    });
  });

  group('a device that was never paired', () {
    test('pre-v4 rows are dropped rather than given a stranger an owner',
        () async {
      final db = await migrateSeeded(owner: null);
      addTearDown(db.close);

      expect(await db.select(db.playedDateTable).get(), isEmpty);
      expect(await db.select(db.eventOutboxTable).get(), isEmpty);
      expect(await db.select(db.engineSettingsTable).get(), isEmpty);
      expect(
        await db.select(db.appStateTable).get(),
        isEmpty,
        reason: 'backfilling would credit the next kid with a stranger\'s play',
      );
    });
  });
}
