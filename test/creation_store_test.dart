import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';

/// "Mes créations" (ADR 0036): per kid, capped with counted eviction, hung
/// creations kept, nothing leaving the device.
void main() {
  late LocalDatabase db;
  late DateTime now;
  var ids = 0;

  CreationStore store(String kid, {int max = 200}) => CreationStore(
    db,
    kidId: kid,
    maxPerKid: max,
    clock: () => now = now.add(const Duration(seconds: 1)),
    newId: () => 'c${ids++}',
  );

  Future<Creation> save(CreationStore s, {String engine = 'compose_build'}) =>
      s.save(
        engineKey: engine,
        exerciseId: 'ex-1',
        payload: {
          'words': ['Le', 'chat', 'dort'],
          'n': ids,
        },
      );

  setUp(() {
    db = LocalDatabase.memory();
    now = DateTime(2026, 10, 26, 9);
    ids = 0;
  });
  tearDown(() => db.close());

  test('saves the engine\'s payload and reads it back as made', () async {
    final s = store('lea');
    final made = await s.save(
      engineKey: 'pattern_machine',
      exerciseId: 'ex-7',
      payloadVersion: 2,
      payload: {
        'cells': [1, 2, 1, 2],
        'colour': 'blue',
      },
    );

    final [back] = await s.list();
    expect(back.id, made.id);
    expect(back.engineKey, 'pattern_machine');
    expect(back.exerciseId, 'ex-7');
    expect(back.payloadVersion, 2);
    expect(back.payload, {
      'cells': [1, 2, 1, 2],
      'colour': 'blue',
    });
    expect(back.hung, isFalse);
    // What save() hands back is the stored shape, not the caller's map,
    // so an engine can draw it straight away.
    expect(made.payload, back.payload);
    expect(made.payload, isNot(same(back.payload)));
  });

  test('lists newest first, filtered by engine and by hung', () async {
    final s = store('lea');
    final a = await save(s);
    final b = await save(s, engine: 'geometry_lab');
    final c = await save(s);
    await s.setHung(a.id, true);

    expect([for (final x in await s.list()) x.id], [c.id, b.id, a.id]);
    expect(
      [
        for (final x in await s.list(engineKeys: {'compose_build'})) x.id,
      ],
      [c.id, a.id],
    );
    expect([for (final x in await s.list(hung: true)) x.id], [a.id]);
    expect(await s.list(limit: 1), hasLength(1));
  });

  test('a sibling never sees another child\'s creations', () async {
    await save(store('lea'));
    expect(await store('sami').list(), isEmpty);

    final [mine] = await store('lea').list();
    await store('sami').remove(mine.id);
    await store('sami').setHung(mine.id, true);
    final [still] = await store('lea').list();
    expect(still.hung, isFalse);
  });

  test('at most three hung; a fourth is refused, not swapped', () async {
    final s = store('lea');
    final made = [for (var i = 0; i < 4; i++) await save(s)];
    for (final c in made.take(3)) {
      await s.setHung(c.id, true);
    }
    expect(() => s.setHung(made[3].id, true), throwsStateError);

    await s.setHung(made[0].id, false);
    await s.setHung(made[3].id, true);
    expect(await s.list(hung: true), hasLength(3));
  });

  test('rejects a payload that is too big or not JSON', () async {
    final s = store('lea');
    expect(
      () => s.save(
        engineKey: 'compose_build',
        exerciseId: 'ex-1',
        payload: {'text': 'x' * (CreationShelf.maxPayloadBytes + 1)},
      ),
      throwsArgumentError,
    );
    expect(
      () => s.save(
        engineKey: 'compose_build',
        exerciseId: 'ex-1',
        payload: {'when': DateTime(2026)},
      ),
      throwsArgumentError,
    );
    expect(await s.list(), isEmpty);
  });

  test(
    'past the cap, the oldest un-hung go, and every one is counted',
    () async {
      final s = store('lea', max: 3);
      final first = await save(s);
      final second = await save(s);
      await s.setHung(first.id, true);
      await save(s);
      await save(s);
      await save(s);

      final kept = await s.list();
      expect(kept, hasLength(3));
      expect(kept.map((c) => c.id), contains(first.id));
      expect(kept.map((c) => c.id), isNot(contains(second.id)));

      final stats = await s.evictionStats();
      expect(stats.totalEvicted, 2);
      expect(stats.lastEvictedAt, isNotNull);
      expect((await store('sami').evictionStats()).totalEvicted, 0);
    },
  );

  testWidgets('the scope hands an engine the shelf, or nothing', (
    tester,
  ) async {
    CreationShelf? seen;
    Widget probe() => Builder(
      builder: (context) {
        seen = CreationShelfScope.maybeOf(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(probe());
    expect(seen, isNull);

    final shelf = store('lea');
    await tester.pumpWidget(CreationShelfScope(shelf: shelf, child: probe()));
    expect(seen, same(shelf));
  });
}
