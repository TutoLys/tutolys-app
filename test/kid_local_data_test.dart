import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/kid_local_data.dart';
import 'package:tutolys_app/data/sync/drift_event_outbox.dart';

/// Removing a kid erases every kid-scoped row and nothing else (ADR 0037).
void main() {
  late LocalDatabase db;
  final at = DateTime(2026, 10, 26, 9);

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  Future<void> seed(String kid) async {
    await DriftEventOutbox(db, kidId: kid).add({'event_id': 'ev-$kid'});
    await db
        .into(db.playedDateTable)
        .insert(
          PlayedDateTableCompanion.insert(kidId: kid, date: '2026-10-25'),
        );
    await db
        .into(db.engineSettingsTable)
        .insert(
          EngineSettingsTableCompanion.insert(
            kidId: kid,
            engineKey: 'mcq',
            settingKey: 'hints',
            value: 'true',
          ),
        );
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: kid,
            key: 'home_stats.today',
            value: '3',
            updatedAt: at,
          ),
        );
    await db
        .into(db.activitySessionTable)
        .insert(
          ActivitySessionTableCompanion.insert(
            activitySessionId: 'as-$kid',
            kidId: kid,
            exerciseId: 'ex-1',
            snapshot: '{}',
            updatedAt: at,
          ),
        );
    await CreationStore(db, kidId: kid).save(
      engineKey: 'compose_build',
      exerciseId: 'ex-1',
      payload: {
        'words': ['Le', 'chat'],
      },
    );
  }

  Future<int> rowsOf(String kid) async {
    var n = 0;
    n += (await (db.select(
      db.eventOutboxTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    n += (await (db.select(
      db.playedDateTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    n += (await (db.select(
      db.engineSettingsTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    n += (await (db.select(
      db.appStateTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    n += (await (db.select(
      db.activitySessionTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    n += (await (db.select(
      db.creationTable,
    )..where((t) => t.kidId.equals(kid))).get()).length;
    return n;
  }

  test('erases every kid-scoped row of that kid, and nothing else', () async {
    await seed('lea');
    await seed('sami');
    await db
        .into(db.appStateTable)
        .insert(
          AppStateTableCompanion.insert(
            kidId: deviceScope,
            key: 'outbox_capacity.dropped_total',
            value: '0',
            updatedAt: at,
          ),
        );
    expect(await rowsOf('lea'), 6);

    await KidLocalData(db, kidId: 'lea').wipe();

    expect(await rowsOf('lea'), 0);
    expect(await rowsOf('sami'), 6);
    expect(await rowsOf(deviceScope), 1);
  });

  test('the summary counts unsent results and creations', () async {
    await seed('lea');
    final outbox = DriftEventOutbox(db, kidId: 'lea');
    await outbox.add({'event_id': 'ev-2'});
    await outbox.markDelivered(['ev-2']);

    final summary = await KidLocalData(db, kidId: 'lea').summary();
    expect(summary.unsentResults, 1);
    expect(summary.creations, 1);
    expect(await KidLocalData(db, kidId: 'nobody').summary(), (
      unsentResults: 0,
      creations: 0,
    ));
  });
}
