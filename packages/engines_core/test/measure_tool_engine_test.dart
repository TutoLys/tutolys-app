import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const en = Locale('en');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// A pencil from 2 to 9: the classic "it ends at 9" mistake is option b.
const ruler = <String, Object?>{
  'instrument': 'ruler',
  'start': 2,
  'length': 7,
  'max': 12,
  'options': [
    {'id': 'a', 'value': 7},
    {'id': 'b', 'value': 9},
    {'id': 'c', 'value': 2},
  ],
  'shuffle': false,
};

const blocks = <String, Object?>{
  'instrument': 'ruler',
  'unit': 'block',
  'unit_label': 'cubes',
  'length': 5,
  'max': 10,
  'options': [
    {'id': 'a', 'value': 4},
    {'id': 'b', 'value': 5},
  ],
};

const clock = <String, Object?>{
  'instrument': 'clock',
  'time': '3:30',
  'options': [
    {'id': 'a', 'value': '3:30'},
    {'id': 'b', 'value': '6:15'},
    {'id': 'c', 'value': '6:00'},
  ],
};

const thermometer = <String, Object?>{
  'instrument': 'thermometer',
  'min': -10,
  'max': 30,
  'step': 2,
  'value': 18,
  'options': [
    {'id': 'a', 'value': 18},
    {'id': 'b', 'value': 20},
    {'id': 'c', 'value': 16},
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'measure_tool',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Combien mesure le crayon ?'},
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
      engines: LearningEngineRegistry([eraseEngine(const MeasureToolEngine())]),
      evaluators: EvaluatorRegistry(const [MeasureToolEvaluator()]),
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

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

MeasureContent parsed(Map<String, Object?> config) =>
    const MeasureToolEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const MeasureToolEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = MeasureToolEngine();
  const evaluator = MeasureToolEvaluator();

  group('parse', () {
    test('derives the right option from the instrument', () {
      expect(parsed(ruler).correctId, 'a');
      expect(parsed(blocks).correctId, 'b');
      expect(parsed(clock).correctId, 'a');
      expect(parsed(thermometer).correctId, 'a');
    });

    test('labels follow the instrument and the language', () {
      expect(parsed(ruler).label('a', fr), '7 cm');
      expect(parsed(blocks).label('b', fr), '5 cubes');
      expect(parsed(thermometer).label('a', fr), '18 °C');
      expect(parsed(clock).label('a', fr), '3 h 30');
      expect(parsed(clock).label('c', fr), '6 h');
      expect(parsed(clock).label('a', en), '3:30');
      expect(MeasureContent.parseTime('12:00'), 0);
      expect(MeasureContent.parseTime('12:07'), isNull);
      expect(MeasureContent.parseTime('13:00'), isNull);
    });

    test('rejects what cannot be read', () {
      expect(reason({...ruler, 'instrument': 'scale'}), contains('ruler'));
      expect(reason({...ruler, 'length': 11}), contains('runs off'));
      expect(reason({...ruler, 'max': 30}), contains('5 to 20'));
      expect(reason({...ruler, 'unit': 'm'}), contains('cm or block'));
      expect(reason({...clock, 'time': '3:07'}), contains('5-minute'));
      expect(reason({...thermometer, 'value': 19}), contains('graduation'));
      expect(reason({...thermometer, 'step': 3}), contains('step'));
      expect(
        reason({
          ...ruler,
          'options': [
            {'id': 'a', 'value': 8},
            {'id': 'b', 'value': 9},
          ],
        }),
        contains('Exactly one'),
      );
      expect(
        reason({
          ...ruler,
          'options': [
            {'id': 'a', 'value': 7},
            {'id': 'b', 'value': 7},
          ],
        }),
        contains('unique'),
      );
      expect(
        reason({
          ...ruler,
          'options': [
            {'id': 'a', 'value': 7},
          ],
        }),
        contains('2 to 4'),
      );
    });
  });

  group('pick and grade', () {
    test('wrong goes amber and stays out; right solves', () {
      final c = parsed(ruler);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const PickChoice('b')).state;
      final wrong = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(wrong.outcome, Outcome.incorrect);
      expect(wrong.evaluator, 'measure_tool.exact@1');
      s = engine.applyFeedback(s, wrong);
      expect(s.tried, {'b'});
      expect(engine.reduce(s, const PickChoice('b')).state.selected, isNull);
      s = engine.reduce(s, const PickChoice('a')).state;
      final right = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      s = engine.applyFeedback(s, right);
      expect(s.solved, isTrue);
      expect(engine.extractAnswer(s), isNull);
    });

    test('snapshot round-trips and refuses a tried right answer', () {
      final c = parsed(clock);
      final s = engine
          .initialize(c, const EngineSeed(1))
          .copyWith(tried: {'b'}, selected: 'c');
      expect(engine.restore(c, engine.snapshot(s))!.tried, {'b'});
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'tried': ['a'],
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    for (final (name, config) in [
      ('ruler', ruler),
      ('blocks', blocks),
      ('clock', clock),
      ('thermometer', thermometer),
    ]) {
      for (final width in [375.0, 1000.0]) {
        testWidgets('$name draws at ${width.toInt()} px', (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (c, _) = controllerFor(config);
          await tester.runAsync(c.start);
          await tester.pumpWidget(app(c));
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('measure-instrument')), findsOne);
          c.dispose();
        });
      }
    }

    testWidgets('the ruler: wrong, then right', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (c, outbox) = controllerFor(ruler);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.bySemanticsLabel(RegExp('Une règle de 0 à 12 cm')), findsOne);
      await tester.tap(find.byKey(const ValueKey('measure-choice-b')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('measure-choice-a')));
      await settle(tester);
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
  });
}
