import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/features/home/subject_strip.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

import 'path_screen_test.dart' show appUnder, exercise;

const _one = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);

/// A2: Village's gold "Continuer" starts the frontier's activity and names
/// it; with nothing open it still leads to the Carte.
void main() {
  testWidgets('names the frontier and plays it in one tap', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        leaves: const [_one],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('recommend-title'))).data,
      'Mathématiques · Arithmétique',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('recommend-skill'))).data,
      'Compter',
    );
    expect(find.byKey(const ValueKey('recommend-building')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recommend-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('nothing open: Continuer leads to the Carte', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appUnder(leaves: const [_one], content: const {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recommend-skill')), findsNothing);
    expect(
      find.byKey(const ValueKey('carte-path')).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('recommend-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsNothing);
    // IndexedStack builds every tab; only the shown one is hittable.
    expect(
      find.byKey(const ValueKey('carte-path')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('A6: on a phone it comes first, its button full width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        leaves: const [_one],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('recommend-continue'));
    expect(button, findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      lessThan(tester.getTopLeft(find.byType(SubjectStrip)).dy),
      reason: 'above the subjects, not under the quests',
    );
    expect(tester.getSize(button).width, greaterThan(280));
    expect(tester.takeException(), isNull);
  });
}
