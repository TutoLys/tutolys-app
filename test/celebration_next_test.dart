import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

import 'path_screen_test.dart' show appUnder, exercise, openCarte;

class _Silent implements AudioCoordinator {
  @override
  PlaybackHandle play(AudioRequest request) => _Done();
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> stopChannel(AudioChannel channel) async {}
  @override
  Stream<PlaybackStatus> get status => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

class _Done implements PlaybackHandle {
  @override
  int get requestId => 0;
  @override
  Future<PlaybackPhase> get done => Future.value(PlaybackPhase.completed);
  @override
  Future<void> stop() async {}
}

final _quiet = [audioCoordinatorProvider.overrideWithValue(_Silent())];

/// A lesson the real mcq engine plays: two choices, « 4 » right.
Map<String, Object?> lesson(String id, String leaf) => {
  ...exercise(id: id, skillNodeId: leaf),
  'config': const {
    'options': [
      {'id': 'a', 'label': '4'},
      {'id': 'b', 'label': '5'},
    ],
    'correct': 'a',
    'shuffle': false,
  },
};

/// G12: « Suivant » on the celebration plays the Carte's next lesson.
void main() {
  const compter = CurriculumLeaf(
    id: 'leaf-1',
    labelFr: 'Compter',
    labelEn: '',
    stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
  );
  const comparer = CurriculumLeaf(
    id: 'leaf-2',
    labelFr: 'Comparer',
    labelEn: '',
    stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:2',
  );

  /// The game's drift reads and writes need real time to land.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> finishLesson(WidgetTester tester) async {
    await settle(tester);
    await tester.tap(find.text('4'));
    await settle(tester);
    await tester.tap(find.text('VALIDER'));
    await settle(tester);
    await tester.tap(find.text('CONTINUER').last);
    await settle(tester);
  }

  testWidgets('« Suivant » plays the next skill; the map is one tap away', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        overrides: _quiet,
        leaves: const [compter, comparer],
        content: {
          'ex-1': lesson('ex-1', 'leaf-1'),
          'ex-2': lesson('ex-2', 'leaf-2'),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-1')));
    await tester.pumpAndSettle();
    await finishLesson(tester);

    expect(find.byKey(const ValueKey('complete-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('complete-back-to-map')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complete-next')));
    await settle(tester);

    final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(play.node.id, 'leaf-2');
  });

  testWidgets('nothing left to play: the single Continuer back to the map', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        overrides: _quiet,
        leaves: const [compter],
        content: {'ex-1': lesson('ex-1', 'leaf-1')},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-1')));
    await tester.pumpAndSettle();
    await finishLesson(tester);

    expect(find.byKey(const ValueKey('complete-next')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('complete-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsNothing);
  });
}
