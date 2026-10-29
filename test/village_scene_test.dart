import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/home/village_scene.dart';

final _buildings = villageBuildings(Strings.fr);

/// The subjects only: the gallery building (ADR 0098) isn't one.
final _subjects = _buildings.where((b) => b.measured).toList();

void main() {
  Widget harness(List<VillageBuilding> buildings) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 1000,
        height: 580,
        child: VillageScene(
          buildings: buildings,
          signTitle: 'Village des Lys',
          signSubtitle: '1re année',
        ),
      ),
    ),
  );

  testWidgets('every subject gets a building, named', (tester) async {
    await tester.pumpWidget(harness(_buildings));

    expect(_subjects, hasLength(6));
    expect(_buildings, hasLength(7), reason: 'six subjects and the gallery');
    for (final b in _buildings) {
      expect(find.text(b.label), findsOneWidget);
    }
  });

  testWidgets('the sign renders', (tester) async {
    await tester.pumpWidget(harness(_buildings));
    expect(find.text('Village des Lys'), findsOneWidget);
    expect(find.text('1re année'), findsOneWidget);
    // Drawn, not an emoji (the emoji fell back to a flat glyph).
    expect(find.byKey(const ValueKey('sign-fleur-de-lys')), findsOneWidget);
  });

  testWidgets('every live building shows a track, measured or not', (
    tester,
  ) async {
    // The track is always drawn — the design needs it, and an empty bar
    // reads as "nothing recorded yet" rather than as a missing feature.
    // A subject that isn't live wears "bientôt" instead.
    await tester.pumpWidget(harness(_buildings));
    final live = _subjects.where((b) => b.live).length;

    expect(find.byType(VillageProgressBar), findsNWidgets(live));
    expect(find.byType(ComingSoonTag), findsNWidgets(_subjects.length - live));
  });

  testWidgets('an unmeasured subject reads 0/100, never an invented figure', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_buildings));

    expect(
      find.text('0/100'),
      findsNWidgets(_subjects.where((b) => b.live).length),
    );
  });

  testWidgets('a real figure renders as a filled track and its number', (
    tester,
  ) async {
    await tester.pumpWidget(harness([_buildings.first.withProgress(0.68)]));

    expect(find.text('68/100'), findsOneWidget);
    final bar = tester.widget<VillageProgressBar>(
      find.byType(VillageProgressBar),
    );
    expect(bar.value, closeTo(0.68, 0.001));
  });

  testWidgets('tapping a building reports which one', (tester) async {
    VillageBuilding? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 580,
            child: VillageScene(
              buildings: _buildings,
              signTitle: 'x',
              signSubtitle: 'y',
              onTapBuilding: (b) => tapped = b,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mathématiques'));
    expect(tapped?.label, 'Mathématiques');
  });

  group('the full program, live or coming soon', () {
    test('six subjects, all live now that CCQ has curriculum', () {
      expect(_subjects.map((b) => b.subject), [
        'MATH',
        'FR',
        'SOC',
        'EN',
        'SCI',
        'CCQ',
      ]);
      expect(_buildings.every((b) => b.live), isTrue);
    });

    test('a subject not in the list is coming soon', () {
      final noCcq = villageBuildings(
        Strings.fr,
        live: const ['MATH', 'FR', 'EN', 'SCI', 'SOC'],
      );
      expect(noCcq.where((b) => !b.live).map((b) => b.subject), ['CCQ']);
    });

    test('a subject goes live by being listed, nothing else changes', () {
      final all = villageBuildings(
        Strings.fr,
        live: const ['MATH', 'FR', 'EN', 'SCI', 'SOC', 'CCQ'],
      );
      expect(all.every((b) => b.live), isTrue);
      expect(
        all.map((b) => (b.left, b.top)),
        _buildings.map((b) => (b.left, b.top)),
        reason: 'the village keeps its shape as subjects arrive',
      );
    });

    testWidgets('a coming-soon building takes no tap and says so', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 580,
              child: VillageScene(
                buildings: [
                  villageBuildings(
                    Strings.fr,
                    live: const ['MATH', 'FR', 'EN', 'SCI', 'SOC'],
                  ).firstWhere((b) => b.subject == 'CCQ'),
                ],
                signTitle: 'x',
                signSubtitle: 'y',
                onTapBuilding: (b) => tapped = b.subject,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Image).first, warnIfMissed: false);
      expect(tapped, isNull);
      // Says why: a tooltip and the tag, in place of the bar.
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(ComingSoonTag), findsOneWidget);
      expect(find.byType(VillageProgressBar), findsNothing);
    });

    testWidgets('a live building reports its own subject', (tester) async {
      String? tapped;
      final francais = _buildings.firstWhere((b) => b.subject == 'FR');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 580,
              child: VillageScene(
                buildings: [francais],
                signTitle: 'x',
                signSubtitle: 'y',
                onTapBuilding: (b) => tapped = b.subject,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Image).first);
      expect(tapped, 'FR');
    });
  });

  group('responsive', () {
    test('full size at the design width, smaller below, never tiny', () {
      expect(villageSceneScale(1400), 1);
      expect(villageSceneScale(1100), 1);
      expect(villageSceneScale(800), closeTo(0.727, 0.001));
      expect(villageSceneScale(500), 0.62);
    });

    for (final width in [640.0, 820.0, 1100.0]) {
      testWidgets('no two pills overlap at ${width.round()}px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: (width * 0.6).clamp(400.0, 580.0),
                child: VillageScene(
                  buildings: _buildings,
                  signTitle: 'x',
                  signSubtitle: 'y',
                ),
              ),
            ),
          ),
        );

        final rects = [
          for (final b in _buildings) tester.getRect(find.text(b.label)),
        ];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              rects[i].overlaps(rects[j]),
              isFalse,
              reason: '${_buildings[i].label} / ${_buildings[j].label}',
            );
          }
        }
      });
    }
  });

  group('the fox', () {
    Widget withFox({VoidCallback? onTap}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 580,
          child: VillageScene(
            buildings: _buildings,
            signTitle: 'Village',
            signSubtitle: '',
            greeting: 'Salut !',
            onTapMascot: onTap,
          ),
        ),
      ),
    );

    testWidgets('tapping it asks for the song', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(withFox(onTap: () => taps++));
      // A button for screen readers, in the app language (English here).
      expect(find.bySemanticsLabel('Make TutoLys sing'), findsOneWidget);
      // The fox's art isn't decoded in a widget test, so it has no width
      // to tap; call the fox's own handler instead.
      tester
          .widget<GestureDetector>(
            find.descendant(
              of: find.byType(TappableMascot),
              matching: find.byType(GestureDetector),
            ),
          )
          .onTap!();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('with no handler it is decoration, not a button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(withFox());
      expect(find.bySemanticsLabel('Make TutoLys sing'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TappableMascot),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(find.byType(TappableMascot), findsOneWidget);
      semantics.dispose();
    });
  });
}
