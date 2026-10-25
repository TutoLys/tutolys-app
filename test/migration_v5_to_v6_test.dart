import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v5.dart' as v5;

/// The 5 → 6 upgrade adds `asset_cache` (ADR 0027). It only adds a table,
/// so the risk is the usual one: existing rows must come through untouched.
void main() {
  test('upgrades to exactly the v6 schema, keeping existing rows', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await old.customStatement(
      'INSERT INTO event_outbox (event_id, kid_id, payload, queued_at, attempts) '
      "VALUES ('ev-1', 'kid-lea', '{\"event_id\":\"ev-1\"}', '2026-10-25T10:00:00.000Z', 0)",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);

    expect(await db.select(db.eventOutboxTable).get(), hasLength(1));
    expect(await db.select(db.assetCacheTable).get(), isEmpty);
    await db.close();
  });
}
