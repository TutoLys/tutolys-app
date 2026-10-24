import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/home/village_scene.dart';

void main() {
  Widget harness(List<VillageBuilding> buildings) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 580,
            child: VillageScene(
              buildings: buildings,
              signTitle: '🍁 Village des Érables',
              signSubtitle: '1re année',
            ),
          ),
        ),
      );

  testWidgets('every subject gets a building, named', (tester) async {
    await tester.pumpWidget(harness(villageBuildings));

    expect(villageBuildings, hasLength(6));
    for (final b in villageBuildings) {
      expect(find.text(b.label), findsOneWidget);
    }
  });

  testWidgets('the sign renders', (tester) async {
    await tester.pumpWidget(harness(villageBuildings));
    expect(find.text('🍁 Village des Érables'), findsOneWidget);
    expect(find.text('1re année'), findsOneWidget);
  });

  testWidgets('every building shows a track, measured or not', (tester) async {
    // The track is always drawn — the design needs it, and an empty bar
    // reads as "nothing recorded yet" rather than as a missing feature.
    await tester.pumpWidget(harness(villageBuildings));

    expect(
      find.byType(LinearProgressIndicator),
      findsNWidgets(villageBuildings.length),
    );
  });

  testWidgets('an unmeasured subject reads 0/100, never an invented figure',
      (tester) async {
    await tester.pumpWidget(harness(villageBuildings));

    expect(find.text('0/100'), findsNWidgets(villageBuildings.length));
  });

  testWidgets('a real figure renders as a filled track and its number',
      (tester) async {
    await tester.pumpWidget(
      harness([villageBuildings.first.withProgress(0.68)]),
    );

    expect(find.text('68/100'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
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
              buildings: villageBuildings,
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
}
