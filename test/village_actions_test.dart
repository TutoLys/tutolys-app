import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/home/village_scene.dart';

/// Village is the screen a kid lands on, so everything that looks tappable
/// has to be tappable. These were all decoration until now.
void main() {
  testWidgets('a building reports the tap', (tester) async {
    VillageBuilding? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 580,
            child: VillageScene(
              // One building: at this size the six overlap, and a tap meant
              // for one lands on its neighbour's pill.
              buildings: [villageBuildings(Strings.fr).first],
              signTitle: 'x',
              signSubtitle: 'y',
              onTapBuilding: (b) => tapped = b,
            ),
          ),
        ),
      ),
    );

    // Tap the building itself, not its pill: the pill is translated up over
    // the artwork, so an offset derived from the label can land outside it.
    await tester.tap(find.byType(Image).first);
    expect(tapped?.label, Strings.fr.subjectMath);
  });

  testWidgets('a building with no handler does not pretend to be a button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 580,
            child: VillageScene(
              buildings: villageBuildings(Strings.fr),
              signTitle: 'x',
              signSubtitle: 'y',
            ),
          ),
        ),
      ),
    );

    final regions = tester.widgetList<MouseRegion>(find.byType(MouseRegion));
    expect(
      regions.any((r) => r.cursor == SystemMouseCursors.click),
      isFalse,
      reason: 'a click cursor over something that does nothing is a lie',
    );
  });
}
