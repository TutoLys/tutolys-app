import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/progress/local_xp.dart';

/// N7: a série's XP shows in the header at once; the server stays the
/// authority. N6: one fox everywhere.
void main() {
  late LocalDatabase db;
  var now = DateTime.utc(2026, 10, 31, 18);
  setUp(() {
    db = LocalDatabase.memory();
    now = DateTime.utc(2026, 10, 31, 18);
  });
  tearDown(() => db.close());
  LocalXp xp() => LocalXp(db, kidId: 'k1', clock: () => now);

  test('a credit shows now, and holds until the server reaches it', () async {
    expect(await xp().credit(shown: 0, earned: 8), 8);
    expect(await xp().reconcile(0), 8, reason: 'ledger not paid yet');
    expect(await xp().reconcile(8), 8);
    expect(await xp().reconcile(5), 5, reason: 'floor gone once reached');
  });

  test('two séries in a row add up', () async {
    await xp().credit(shown: 100, earned: 8);
    expect(await xp().credit(shown: 108, earned: 5), 113);
    expect(await xp().credit(shown: 100, earned: 5), 118);
  });

  test('a server that lowers its total on purpose wins', () async {
    await xp().credit(shown: 390, earned: 8);
    expect(await xp().reconcile(98), 98);
  });

  test('a floor never outlives a day', () async {
    await xp().credit(shown: 10, earned: 8);
    now = now.add(const Duration(hours: 25));
    expect(await xp().reconcile(10), 10);
  });

  test('another kid\'s floor is not mine', () async {
    await xp().credit(shown: 0, earned: 8);
    expect(await LocalXp(db, kidId: 'noah').reconcile(3), 3);
  });

  test('N6: the off-model renders are out of the fox\'s pose slots', () {
    expect(villageFox.assets.keys, contains('pose.default'));
    for (final pose in [
      'pose.celebrating',
      'pose.victory',
      'pose.encouraging',
    ]) {
      expect(villageFox.assets.containsKey(pose), isFalse, reason: pose);
    }
  });
}
