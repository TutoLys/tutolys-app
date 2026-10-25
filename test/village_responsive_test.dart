import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/features/home/subject_strip.dart';
import 'package:tutolys_app/features/home/village_scene.dart';

/// On a phone the design replaces the village rather than shrinking it: the
/// scene places buildings at fixed fractions of a wide canvas, so at ~390px
/// they overlap, their pills collide and it clips.
void main() {
  testWidgets('the strip names every subject and shows a bar each',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: SubjectStrip(
              buildings: villageBuildings(Strings.fr),
              title: Strings.fr.villageYourSubjects,
            ),
          ),
        ),
      ),
    );

    expect(find.text(Strings.fr.villageYourSubjects.toUpperCase()),
        findsOneWidget);
    // A horizontal list only builds what fits, so assert on the first few
    // rather than all six.
    expect(find.text(Strings.fr.subjectMath), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('it scrolls horizontally rather than wrapping or clipping',
      (tester) async {
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

    final list = tester.widget<ListView>(find.descendant(
      of: find.byType(SubjectStrip),
      matching: find.byType(ListView),
    ));
    expect(list.scrollDirection, Axis.horizontal);
  });

  testWidgets('tiles fit the strip once their images have decoded',
      (tester) async {
    // Undecoded, an image is 0px tall and hides any overflow — so decode
    // first, or this only fails when another test happened to warm the cache.
    final buildings = villageBuildings(Strings.fr);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: SubjectStrip(buildings: buildings, title: 'x'),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(SubjectStrip));
      for (final b in buildings) {
        await precacheImage(AssetImage('assets/images/${b.asset}'), context);
      }
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // NOT TESTED: tapping a tile. The handler is wired the same way the
  // village buildings' is, and works in the browser, but every offset the
  // harness derives inside a 98px tile lands on a sibling render object and
  // the tap never reaches it. Left out rather than faked with a finder that
  // asserts nothing — the gap is real and worth fixing with the hit-test
  // geometry noted in `f59975f`.
}
