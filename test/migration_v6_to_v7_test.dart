import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v6.dart' as v6;

/// The 6 → 7 upgrade adds document order, strand and area to
/// `skill_node_cache` (backend ADR 0044). Cached leaves must survive with
/// those columns empty, so the Carte falls back to its own table until the
/// next sync refills them.
void main() {
  test('upgrades to exactly the v7 schema, keeping cached leaves', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    await old.customStatement(
      'INSERT INTO skill_node_cache (id, label_fr, label_en, stable_key, subject, grade) '
      "VALUES ('leaf-1', 'Compter', '', 'mathematique/x/b:A/o:1', 'MATH', 1)",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 7);

    final row = (await db.select(db.skillNodeTable).get()).single;
    expect(row.labelFr, 'Compter');
    expect(row.docOrder, isNull);
    expect(row.areaLabelFr, isNull);
    await db.close();
  });
}
