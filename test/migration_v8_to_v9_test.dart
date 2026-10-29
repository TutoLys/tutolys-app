import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v8.dart' as v8;

/// The 8 → 9 upgrade adds `manifest_entry`, the offline window's record of
/// what is published (ADR 0095). It only adds a table: a device that cached
/// the whole grade keeps every row until its first complete sync.
void main() {
  test('upgrades to exactly the v9 schema, keeping the cache', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(8);
    final old = v8.DatabaseAtV8(schema.newConnection());
    await old.customStatement(
      "INSERT INTO exercise_cache (exercise_id, version, payload, "
      "content_hash, engine_key, skill_node_id, subject, grade, rank, "
      "cached_at) VALUES ('ex-1', 1, '{}', 'h', 'mcq', 'n1', 'MATH', 1, 0, "
      "'2026-10-29T00:00:00.000Z')",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    expect(await db.select(db.exerciseCacheTable).get(), hasLength(1));
    await db
        .into(db.manifestEntryTable)
        .insert(
          ManifestEntryTableCompanion.insert(
            askedLocale: 'fr-CA',
            exerciseId: 'ex-1',
            skillNodeId: 'n1',
            subject: 'MATH',
            grade: 1,
            rank: 0,
            engineKey: 'mcq',
            contentHash: 'h',
            locale: 'fr-CA',
            lessonGroup: const Value(null),
          ),
        );
    expect(await db.select(db.manifestEntryTable).get(), hasLength(1));
    await db.close();
  });
}
