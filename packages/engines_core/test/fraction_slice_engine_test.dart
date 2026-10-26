import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const en = Locale('en');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// Three of four slices coloured.
const identify = <String, Object?>{
  'shape': 'pizza',
  'parts': 4,
  'shaded': 3,
  'options': [
    {'id': 'a', 'num': 3, 'den': 4},
    {'id': 'b', 'num': 1, 'den': 4},
    {'id': 'c', 'num': 3, 'den': 8},
  ],
  'shuffle': false,
};

// Colour a half of a bar cut in 6.
const shade = <String, Object?>{
  'shape': 'bar',
  'mode': 'shade',
  'parts': 6,
  'target': {'num': 1, 'den': 2},
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'fraction_slice',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Quelle partie de la pizza est colorée ?'},
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
        eraseEngine(const FractionSliceEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [FractionSliceEvaluator()]),
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
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

FractionContent parsed(Map<String, Object?> config) =>
    const FractionSliceEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const FractionSliceEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = FractionSliceEngine();
  const evaluator = FractionSliceEvaluator();

  group('Fraction', () {
    test('reads in words', () {
      expect(const Fraction(3, 4).words(fr), 'trois quarts');
      expect(const Fraction(1, 2).words(fr), 'un demi');
      expect(const Fraction(2, 3).words(fr), 'deux tiers');
      expect(const Fraction(5, 8).words(fr), 'cinq huitièmes');
      expect(const Fraction(1, 2).words(en), 'one half');
      expect(const Fraction(3, 2).words(en), 'three halves');
      expect(const Fraction(2, 3).words(en), 'two thirds');
    });
  });

  group('parse', () {
    test('derives the right option from the coloured parts', () {
      expect(parsed(identify).correctId, 'a');
      expect(parsed(shade).partsToShade, 3);
      // 2 of 4 coloured: 1/2 is right, by value.
      expect(
        parsed({
          ...identify,
          'shaded': 2,
          'options': [
            {'id': 'h', 'num': 1, 'den': 2},
            {'id': 'q', 'num': 1, 'den': 4},
          ],
        }).correctId,
        'h',
      );
    });

    test('rejects what cannot be played', () {
      expect(reason({...identify, 'parts': 9}), contains('2 to 8'));
      expect(reason({...identify, 'shaded': 5}), contains('1 to parts'));
      expect(
        reason({
          ...identify,
          'options': [
            {'id': 'a', 'num': 3, 'den': 4},
            {'id': 'b', 'num': 6, 'den': 8},
          ],
        }),
        contains('same fraction'),
      );
      expect(
        reason({
          ...identify,
          'options': [
            {'id': 'a', 'num': 1, 'den': 4},
            {'id': 'b', 'num': 1, 'den': 2},
          ],
        }),
        contains('Exactly one'),
      );
      expect(
        reason({
          ...shade,
          'target': {'num': 1, 'den': 4},
        }),
        contains('multiple'),
      );
      expect(reason({...shade, 'shaded': 2}), contains('identify'));
      expect(reason({...identify, 'shape': 'cake'}), contains('pizza or bar'));
    });
  });

  group('reduce and grade', () {
    test('shade: any parts count; a wrong count stays on the board', () {
      final c = parsed(shade);
      var s = engine.initialize(c, const EngineSeed(1));
      for (final i in [0, 4]) {
        s = engine.reduce(s, ToggleSlice(i)).state;
      }
      var r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.incorrect);
      expect(r.itemResults, {'count': false});
      s = engine.applyFeedback(s, r);
      expect(s.shaded, {0, 4});
      s = engine.reduce(s, const ToggleSlice(5)).state;
      r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
      s = engine.applyFeedback(s, r);
      expect(engine.reduce(s, const ToggleSlice(1)).state.shaded, {0, 4, 5});
    });

    test('identify ignores taps on parts', () {
      final c = parsed(identify);
      final s = engine.initialize(c, const EngineSeed(1));
      expect(engine.reduce(s, const ToggleSlice(0)).state.shaded, isEmpty);
    });

    test('snapshot round-trips both modes', () {
      final ci = parsed(identify);
      final si = engine
          .initialize(ci, const EngineSeed(1))
          .copyWith(
            pick: const PickState(order: ['a', 'b', 'c'], tried: {'b'}),
          );
      expect(engine.restore(ci, engine.snapshot(si))!.pick.tried, {'b'});
      final cs = parsed(shade);
      final ss = engine
          .initialize(cs, const EngineSeed(1))
          .copyWith(shaded: {1, 2});
      expect(engine.restore(cs, engine.snapshot(ss))!.shaded, {1, 2});
      expect(
        engine.restore(cs, {...engine.snapshot(ss), 'shade_solved': true}),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('identify: wrong, then right, in words', (tester) async {
      tallView(tester);
      final (c, outbox) = controllerFor({...identify, 'display': 'words'});
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('trois quarts'), findsOne);
      expect(
        find.bySemanticsLabel(RegExp('coupée en 4 parts égales, 3 colorées')),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('fraction-choice-c')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('fraction-choice-a')));
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

    testWidgets('shade: tapping parts of a pizza on a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'shape': 'pizza',
        'mode': 'shade',
        'parts': 8,
        'target': {'num': 1, 'den': 4},
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('fraction-part-2')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('fraction-part-6')));
      await settle(tester);
      expect(find.text('2 / 8'), findsOne);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });
  });
}
