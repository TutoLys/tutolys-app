import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v10.dart' as v10;

/// The 10 → 11 upgrade adds the kid's short labels to `skill_node_cache`
/// (AM9). Cached leaves survive with them empty, and the Carte trims the
/// full label until the next sync brings short ones.
void main() {
  test('upgrades to exactly the v11 schema, keeping cached leaves', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());
    await old.customStatement(
      'INSERT INTO skill_node_cache (id, label_fr, label_en, stable_key, subject, grade) '
      "VALUES ('leaf-1', 'Compter', '', 'mathematique/x/b:A/o:1', 'MATH', 1)",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 11);

    final row = (await db.select(db.skillNodeTable).get()).single;
    expect(row.labelFr, 'Compter');
    expect(row.shortLabelFr, isNull);
    expect(row.shortLabelEn, isNull);
    await db.close();
  });
}
