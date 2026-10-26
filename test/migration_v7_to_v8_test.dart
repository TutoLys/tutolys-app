import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v7.dart' as v7;

/// The 7 → 8 upgrade adds `creation`, "Mes créations" (ADR 0036). It only
/// adds a table: what was there stays, and the new store works at once.
void main() {
  test('upgrades to exactly the v8 schema, keeping existing rows', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await old.customStatement(
      "INSERT INTO played_date (kid_id, date) VALUES ('lea', '2026-10-25')",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    expect(await db.select(db.playedDateTable).get(), hasLength(1));
    final shelf = CreationStore(db, kidId: 'lea');
    await shelf.save(
      engineKey: 'compose_build',
      exerciseId: 'ex-1',
      payload: {
        'words': ['Le', 'chat'],
      },
    );
    expect(await shelf.list(), hasLength(1));
    await db.close();
  });
}
