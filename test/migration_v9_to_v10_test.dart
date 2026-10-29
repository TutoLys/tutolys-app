import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/local_inbox.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v9.dart' as v9;

/// The 9 → 10 upgrade adds `local_notification`, the offline inbox
/// (ADR 0097). It only adds a table: what was there stays.
void main() {
  test('upgrades to exactly the v10 schema, keeping existing rows', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());
    await old.customStatement(
      "INSERT INTO played_date (kid_id, date) VALUES ('lea', '2026-10-29')",
    );
    await old.close();

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 10);

    expect(await db.select(db.playedDateTable).get(), hasLength(1));
    final inbox = LocalInbox(db, kidId: 'lea');
    expect(await inbox.add('achievement:streak3', 'streak_milestone'), isTrue);
    expect(await inbox.list(), hasLength(1));
    await db.close();
  });
}
