import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/home/village_scene.dart';

/// The hover lift is decoration, so it has to disappear when animations are
/// reduced — otherwise "Réduire les animations" would be honoured by
/// Flutter's own transitions and quietly ignored by ours.
void main() {
  Widget harness({required bool stillness}) => MediaQuery(
        data: MediaQueryData(disableAnimations: stillness),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 580,
              child: VillageScene(
                buildings: villageBuildings(Strings.fr),
                signTitle: 'x',
                signSubtitle: 'y',
                onTapBuilding: (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('buildings animate by default', (tester) async {
    await tester.pumpWidget(harness(stillness: false));

    final slide = tester.widgetList<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide, isNotEmpty);
    expect(slide.every((s) => s.duration > Duration.zero), isTrue);
  });

  testWidgets('reduced motion collapses the lift to no animation at all',
      (tester) async {
    await tester.pumpWidget(harness(stillness: true));

    final slide = tester.widgetList<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide, isNotEmpty);
    expect(
      slide.every((s) => s.duration == Duration.zero),
      isTrue,
      reason: 'a kid who asked for less motion should not get a hover lift',
    );
    expect(
      slide.every((s) => s.offset == Offset.zero),
      isTrue,
      reason: 'and it should rest flat, not animate instantly to a lift',
    );
  });

  testWidgets('a tappable building shows a click cursor', (tester) async {
    await tester.pumpWidget(harness(stillness: false));

    final regions = tester.widgetList<MouseRegion>(find.byType(MouseRegion));
    expect(
      regions.any((r) => r.cursor == SystemMouseCursors.click),
      isTrue,
    );
  });
}
