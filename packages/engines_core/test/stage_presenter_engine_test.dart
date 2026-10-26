import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const volumeStops = ['Chuchoter', 'Doucement', 'Normal', 'Fort', 'Crier'];

// The whole school in the gym: a loud (not shouting) voice, normal pace,
// facing them.
const gym = <String, Object?>{
  'scenario': {'room': 'gym', 'audience': 'school'},
  'controls': [
    {
      'id': 'order',
      'type': 'order',
      'label': 'Mets ta présentation en ordre',
      'parts': [
        {'id': 'hello', 'label': 'Bonjour, je vais parler de mon chien.'},
        {'id': 'picture', 'label': 'Je montre la photo.'},
        {'id': 'end', 'label': 'Merci ! Avez-vous des questions ?'},
      ],
    },
    {
      'id': 'volume',
      'type': 'slider',
      'label': 'Ta voix',
      'stops': volumeStops,
      'target': [3, 3],
      'start': 1,
    },
    {
      'id': 'face',
      'type': 'choice',
      'label': 'Où regardes-tu ?',
      'options': [
        {'id': 'public', 'label': 'Vers le public'},
        {'id': 'feuille', 'label': 'Ma feuille'},
      ],
      'correct': ['public'],
    },
  ],
  'reactions': {
    'volume': 'Au fond du gymnase, on n’entend rien !',
    'ok': 'Bravo ! Toute l’école applaudit.',
  },
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'stage_presenter',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'EN',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Tu présentes ton chien à toute l’école.'},
  'config': config,
};

(ActivitySessionController, InMemoryEventOutbox) controllerFor(
  Map<String, Object?> config,
) {
  final outbox = InMemoryEventOutbox();
  return (
    ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(config)).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([
        eraseEngine(const StagePresenterEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [StagePresenterEvaluator()]),
      store: InMemoryActivitySessionStore(outbox),
      appVersion: '0.2.0',
      seed: 3,
    ),
    outbox,
  );
}

Widget app(ActivitySessionController c) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
  ),
);

void tallView(WidgetTester tester, {double width = 1000}) {
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

StageContent parsed(Map<String, Object?> config) =>
    const StagePresenterEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const StagePresenterEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = StagePresenterEngine();
  const evaluator = StagePresenterEvaluator();

  StageState inOrder(StageState s) {
    const right = ['hello', 'picture', 'end'];
    for (var target = 0; target < right.length; target++) {
      while (s.order.indexOf(right[target]) > target) {
        s = engine.reduce(s, MoveStagePart(right[target], -1)).state;
      }
    }
    return s;
  }

  group('parse', () {
    test('reads the scenario and controls', () {
      final c = parsed(gym);
      expect(c.room, StageRoom.gym);
      expect(c.controls.map((x) => x.runtimeType), [
        StageOrder,
        StageSlider,
        StageChoice,
      ]);
      final s = engine.initialize(c, const EngineSeed(1));
      expect(s.order, isNot(['hello', 'picture', 'end']));
      expect(s.values, {'volume': 1});
    });

    test('rejects controls with nothing to do', () {
      final controls = (gym['controls']! as List).cast<Map<String, Object?>>();
      expect(
        reason({
          ...gym,
          'scenario': {'room': 'moon', 'audience': 'school'},
        }),
        contains('scenario'),
      );
      expect(
        reason({
          ...gym,
          'controls': [
            controls[0],
            {
              ...controls[1],
              'target': [0, 4],
            },
          ],
        }),
        contains('Every stop is right'),
      );
      expect(
        reason({
          ...gym,
          'controls': [
            {...controls[1], 'start': 3},
          ],
        }),
        contains('start is a stop outside'),
      );
      expect(
        reason({
          ...gym,
          'controls': [
            {
              ...controls[2],
              'correct': ['public', 'feuille'],
            },
          ],
        }),
        contains('Every option is right'),
      );
      expect(
        reason({
          ...gym,
          'controls': [
            {...controls[0], 'type': 'dance'},
          ],
        }),
        contains('order, slider or choice'),
      );
    });
  });

  group('the audience reacts', () {
    test('each control is an item; proxy evidence', () {
      final c = parsed(gym);
      var s = engine.initialize(c, const EngineSeed(1));
      s = inOrder(s);
      s = engine.reduce(s, const PickStageOption('face', 'feuille')).state;
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {'order': true, 'volume': false, 'face': false});
      expect(r.evidence, EvidenceLevel.proxy);
      s = engine.applyFeedback(s, r);
      expect(s.reactions['volume'], StageReaction.cantHear);
      expect(s.reactions['face'], StageReaction.puzzled);
      expect(s.locked, {'order'});
      expect(s.picks, isEmpty);
      expect(
        engine.reduce(s, const MoveStagePart('end', -1)).state.order,
        s.order,
      );
      s = engine.reduce(s, const SetStageSlider('volume', 4)).state;
      s = engine.reduce(s, const PickStageOption('face', 'public')).state;
      final shout = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(shout.itemResults['volume'], isFalse);
      expect(
        StagePresenterEngine.react(c.control('volume'), '4'),
        StageReaction.tooMuch,
      );
      s = engine.reduce(s, const SetStageSlider('volume', 3)).state;
      expect(
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
    });

    test('snapshot round-trips', () {
      final c = parsed(gym);
      final s = engine
          .reduce(
            engine.initialize(c, const EngineSeed(1)),
            const SetStageSlider('volume', 2),
          )
          .state;
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.values, {'volume': 2});
      expect(back.order, s.order);
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'values': {'volume': 9},
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('plan for the gym: the back row can\'t hear, then applause', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(gym);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> tap(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await settle(tester);
      }

      final order = [...(c.current!.state as StageState).order];
      for (final (target, id) in ['hello', 'picture', 'end'].indexed) {
        var at = order.indexOf(id);
        while (at > target) {
          await tap('stage-up-$id');
          at--;
        }
        order
          ..remove(id)
          ..insert(target, id);
      }
      await tap('stage-option-face-public');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Au fond du gymnase, on n’entend rien !'), findsOne);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      final slider = find.byKey(const ValueKey('stage-slider-volume'));
      final box = tester.getRect(slider);
      await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
      await settle(tester);
      expect((c.current!.state as StageState).values['volume'], 3);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(
        outbox.all
            .where((e) => e['event_type'] == 'attempt')
            .map((e) => e['is_correct']),
        [false, true],
      );
      c.dispose();
    });

    testWidgets('fits a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(gym);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
