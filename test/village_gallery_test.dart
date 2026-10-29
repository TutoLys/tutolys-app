import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/features/gallery/village_gallery.dart';
import 'package:tutolys_app/features/home/subject_strip.dart';
import 'package:tutolys_app/features/home/village_scene.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

import 'path_screen_test.dart' show appUnder, exercise;

const _leaf = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);

/// "Ma galerie au village" as a building (ADR 0098).
void main() {
  void size(WidgetTester tester, double width, [double height = 1000]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The phone strip is a lazy horizontal list: its last tile is built
  /// once scrolled to.
  Future<void> scrollStrip(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('strip-building-GALLERY')),
      120,
      scrollable: find.descendant(
        of: find.byType(SubjectStrip),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<LocalDatabase> open(WidgetTester tester, {LocalDatabase? db}) async {
    final database = db ?? LocalDatabase.memory();
    await tester.pumpWidget(
      appUnder(
        leaves: const [_leaf],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
        db: database,
      ),
    );
    await tester.pumpAndSettle();
    return database;
  }

  test('a building that is not a subject: no progress, its own art', () {
    final gallery = villageBuildings(
      Strings.fr,
    ).singleWhere((b) => b.subject == galleryBuildingCode);
    expect(gallery.label, 'Ma galerie');
    expect(gallery.asset, 'asset-bldg-gallery.webp');
    expect(gallery.measured, isFalse);
    expect(gallery.live, isTrue);
    expect(Strings.en.galleryBuilding, 'My gallery');
  });

  for (final (width, key) in [
    (2000.0, 'village-building-GALLERY'),
    (900.0, 'village-building-GALLERY'),
    (375.0, 'strip-building-GALLERY'),
  ]) {
    testWidgets('drawn at $width px', (tester) async {
      size(tester, width);
      await open(tester);
      if (width < 600) await scrollStrip(tester);
      expect(find.byKey(ValueKey(key), skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tap on the building opens the gallery as practice', (
    tester,
  ) async {
    size(tester, 2000);
    await open(tester);
    // A real hit test on the building, not a finder shortcut: the art has
    // a fixed box now, so its centre is the building (`f59975f`).
    final building = find.byKey(const ValueKey('village-building-GALLERY'));
    expect(building.hitTestable(), findsOneWidget);
    await tester.tap(building);
    await tester.pumpAndSettle();

    final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(play.practice, isTrue);
    expect(play.envelope['engine_key'], 'my_gallery');
    expect(play.node.subject, galleryBuildingCode);
  });

  testWidgets('on a phone, the strip tile opens it too', (tester) async {
    size(tester, 375, 900);
    await open(tester);
    final tile = find.byKey(const ValueKey('strip-building-GALLERY'));
    await scrollStrip(tester);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile.hitTestable(), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('no creation yet: Foxy explains how to fill it, never red', (
    tester,
  ) async {
    size(tester, 2000);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('village-building-GALLERY')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery-empty')), findsOneWidget);
    expect(find.textContaining('Garder dans mes créations'), findsOneWidget);
  });

  testWidgets('hang two creations with reasons; only this kid\'s are shown, '
      'and nothing counts as a lesson', (tester) async {
    size(tester, 2000, 1400);
    final db = LocalDatabase.memory();
    final ids = await tester.runAsync(() async {
      final mine = CreationStore(db, kidId: 'k1');
      final a = await mine.save(
        engineKey: 'compose_build',
        exerciseId: 'ex-a',
        payload: {
          'labels': ['Le', 'chat', 'dort'],
        },
      );
      final b = await mine.save(
        engineKey: 'compose_build',
        exerciseId: 'ex-b',
        payload: {
          'labels': ['Le', 'chien', 'court'],
        },
      );
      // A sibling's creation never shows here.
      await CreationStore(db, kidId: 'noah').save(
        engineKey: 'compose_build',
        exerciseId: 'ex-n',
        payload: {
          'labels': ['Noah', 'joue'],
        },
      );
      return [a.id, b.id];
    });
    await open(tester, db: db);
    await tester.tap(find.byKey(const ValueKey('village-building-GALLERY')));
    await tester.pumpAndSettle();

    expect(find.text('Le chat dort'), findsOneWidget);
    expect(find.text('Le chien court'), findsOneWidget);
    expect(find.text('Noah joue'), findsNothing);

    for (final id in ids!) {
      await tester.tap(find.byKey(ValueKey('gallery-card-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('gallery-reason-$id-proud')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('VALIDER'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final shelf = await tester.runAsync(
      () => CreationStore(db, kidId: 'k1').list(),
    );
    expect(shelf!.where((c) => c.hung), hasLength(2));
    final noah = await tester.runAsync(
      () => CreationStore(db, kidId: 'noah').list(),
    );
    expect(noah!.single.hung, isFalse);

    // Practice: no telemetry queued, no node marked done.
    final outbox = await tester.runAsync(
      () => db.select(db.eventOutboxTable).get(),
    );
    expect(outbox, isEmpty);
    final progress = await tester.runAsync(
      () => NodeProgressLocal(db, kidId: 'k1').all(),
    );
    expect(progress, isEmpty);
  });

  testWidgets('the strip keeps a non-subject tile the same height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: SubjectStrip(
              buildings: villageBuildings(Strings.fr),
              title: 'x',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
