import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_shelf.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

/// "Le chat / Mon lapin" + "dort / saute" + "dans le jardin / sur le lit",
/// and "dormir", which fits nowhere: it isn't conjugated.
const free = <String, Object?>{
  'tiles': [
    {'id': 'chat', 'label': 'Le chat'},
    {'id': 'lapin', 'label': 'Mon lapin'},
    {'id': 'dort', 'label': 'dort'},
    {'id': 'saute', 'label': 'saute'},
    {'id': 'jardin', 'label': 'dans le jardin.'},
    {'id': 'lit', 'label': 'sur le lit.'},
    {'id': 'dormir', 'label': 'dormir'},
  ],
  'frame': [
    ['chat', 'lapin'],
    ['dort', 'saute'],
    ['jardin', 'lit'],
  ],
};

void main() {
  const engine = ComposeSlotsEngine();
  const evaluator = ComposeBuildEvaluator();
  ComposeContent parsed(Map<String, Object?> c) => engine.parse(c).valueOrNull!;
  String? reason(Map<String, Object?> c) => switch (engine.parse(c)) {
    ParseInvalid(:final reason) => reason,
    _ => null,
  };

  test('a frame replaces the target and sizes the slots', () {
    final c = parsed(free);
    expect(c.slotCount, 3);
    expect(c.target, isEmpty);
    expect(engine.initialize(c, const EngineSeed(1)).slots, hasLength(3));
  });

  test('refuses a frame that mixes with target or reuses a tile', () {
    expect(
      reason({
        ...free,
        'target': ['chat'],
      }),
      contains('replaces target'),
    );
    expect(
      reason({
        ...free,
        'frame': [
          ['chat', 'lapin'],
          ['chat', 'dort'],
        ],
      }),
      contains('one frame slot'),
    );
    expect(
      reason({
        ...free,
        'frame': [
          ['chat', 'nope'],
        ],
      }),
      contains('exist in tiles'),
    );
    expect(reason({...free, 'frame': <Object>[]}), contains('1 to 8'));
  });

  test('any pick across the slots is right; a misfit is not', () {
    final c = parsed(free);
    for (final picks in [
      ['chat', 'dort', 'jardin'],
      ['lapin', 'saute', 'lit'],
      ['lapin', 'dort', 'jardin'],
    ]) {
      final r = evaluator.evaluate(c, OrderingAnswer(picks), ctx);
      expect(r.outcome, Outcome.correct, reason: '$picks');
    }
    final r = evaluator.evaluate(
      c,
      OrderingAnswer(const ['chat', 'dormir', 'lit']),
      ctx,
    );
    expect(r.outcome, Outcome.partial);
    expect(r.itemResults, {'0': true, '1': false, '2': true});
    // Right tiles in the wrong slot are wrong there.
    final swapped = evaluator.evaluate(
      c,
      OrderingAnswer(const ['dort', 'chat', 'lit']),
      ctx,
    );
    expect(swapped.itemResults, {'0': false, '1': false, '2': true});
  });

  testWidgets('a free sentence plays in the shell and can be kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shelf = FakeShelf();
    final c = ActivitySessionController(
      envelope: QuestionEnvelope.parse({
        'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
        'version': 1,
        'content_hash': 'h',
        'engine_key': 'compose_build',
        'engine_min_version': 1,
        'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
        'subject': 'FR',
        'grade': 1,
        'rank': 0,
        'prompt': {'text': 'Invente une phrase.'},
        'config': {...free, 'creation': true},
      }).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([eraseEngine(engine)]),
      evaluators: EvaluatorRegistry(const [evaluator]),
      store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
      appVersion: '0.2.0',
      seed: 3,
    );
    await tester.runAsync(c.start);
    await tester.pumpWidget(
      CreationShelfScope(
        shelf: shelf,
        child: MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: LearningActivityView(
              controller: c,
              locale: fr,
              onDone: () {},
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.pump();
    }

    for (final id in ['lapin', 'saute', 'lit']) {
      await tester.tap(find.byKey(ValueKey('compose-tile-$id')));
      await settle();
    }
    await tester.tap(find.text('VALIDER'));
    await settle();
    expect(find.text('Bravo !'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creation-keep')));
    await settle();
    expect(shelf.items.single.payload, {
      'labels': ['Mon lapin', 'saute', 'sur le lit.'],
    });
    c.dispose();
  });
}
