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

  testWidgets('unknown progress shows no percentage at all', (tester) async {
    // The design mocks "68/100" under each building. Nothing measures
    // per-subject mastery yet, so rendering any number here would make the
    // most-looked-at figure on the home screen fiction.
    await tester.pumpWidget(harness(villageBuildings));

    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a real figure renders as a track and a percentage',
      (tester) async {
    await tester.pumpWidget(
      harness([villageBuildings.first.withProgress(0.68)]),
    );

    expect(find.text('68%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
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
