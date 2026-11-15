import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);
const engine = CalculatorEngine();
const evaluator = CalculatorEvaluator();

CalculatorContent parsed(Map<String, Object?> config) =>
    engine.parse(config).valueOrNull!;

CalcKey k(String label) => CalcKey.values.firstWhere((c) => c.label == label);

/// Presses keys by their labels: "48×12=" or a list for multi-character keys.
CalculatorState keys(CalculatorState s, Object presses) {
  final labels = presses is String
      ? presses.split('')
      : (presses as List<String>);
  for (final l in labels) {
    s = engine.reduce(s, PressKey(k(l))).state;
  }
  return s;
}

EvaluationResult grade(CalculatorContent c, CalculatorState s) =>
    evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);

void main() {
  final key = parsed({'task': 'key', 'expression': '48 × 12'});
  final blank = engine.initialize(key, const EngineSeed(1));

  group('parse', () {
    for (final (why, bad) in <(String, Map<String, Object?>)>[
      ('no task', {'expression': '1 + 2'}),
      ('key without an expression', {'task': 'key'}),
      ('a lone number', {'task': 'key', 'expression': '12'}),
      ('no spaces', {'task': 'key', 'expression': '48×12'}),
      ('divides by zero', {'task': 'key', 'expression': '4 ÷ 0'}),
      ('decimals not on', {'task': 'key', 'expression': '2,5 + 1'}),
      ('negative without sign', {'task': 'key', 'expression': '-3 + 5'}),
      (
        'key with an answer',
        {'task': 'key', 'expression': '1 + 2', 'answer': '3'},
      ),
      ('repair without start', {'task': 'repair', 'expression': '48 × 12'}),
      (
        'repair with no mistake',
        {'task': 'repair', 'expression': '48 × 12', 'start': '12 × 48'},
      ),
      ('solve without answer', {'task': 'solve'}),
      (
        'solve with trailing zero',
        {'task': 'solve', 'answer': '2,50', 'decimals': true},
      ),
      (
        'require_memory without memory',
        {'task': 'solve', 'answer': '3', 'require_memory': true},
      ),
      ('flag not a bool', {'task': 'solve', 'answer': '3', 'memory': 'yes'}),
    ]) {
      test('refuses $why', () {
        expect(engine.parse(bad).valueOrNull, isNull, reason: why);
      });
    }

    test('works the answer out, and accepts - for −', () {
      expect(key.answer, '576');
      final neg = parsed({'task': 'key', 'expression': '3 - 5', 'sign': true});
      expect(neg.expression, ['3', '−', '5']);
      expect(neg.answer, '−2');
    });
  });

  group('the calculator', () {
    String result(CalculatorState s) => s.result!;

    test('× and ÷ before + and −', () {
      expect(result(keys(blank, '2+3×4=')), '14');
      expect(result(keys(blank, '20−8÷4=')), '18');
    });

    test('decimals are exact', () {
      final dec = engine.initialize(
        parsed({'task': 'solve', 'answer': '0,3', 'decimals': true}),
        const EngineSeed(1),
      );
      expect(result(keys(dec, '0,1+0,2=')), '0,3');
      expect(result(keys(blank, '7÷3=')), '2,33333333');
    });

    test('÷ 0 shows E, and an operation after E does nothing', () {
      final e = keys(blank, '5÷0=');
      expect(result(e), 'E');
      expect(engine.reduce(e, PressKey(CalcKey.add)).state, same(e));
    });

    test('a meaningless key changes nothing and emits nothing', () {
      for (final l in ['=', '×', '⌫', 'C']) {
        final t = engine.reduce(blank, PressKey(k(l)));
        expect(t.state, same(blank), reason: l);
        expect(t.events, isEmpty, reason: l);
      }
    });

    test('a second operation replaces the first; ⌫ takes one character', () {
      final s = keys(blank, '48+×');
      expect(s.tokens, ['48', '×']);
      expect(keys(s, '⌫').tokens, ['48']);
      expect(keys(s, '⌫⌫').tokens, ['4']);
    });

    test('after =, a digit starts again and an operation continues', () {
      final done = keys(blank, '48×12=');
      expect(keys(done, '3').tokens, ['3']);
      expect(keys(done, '+').tokens, ['576', '+']);
    });

    test('a number holds 8 digits', () {
      expect(keys(blank, '123456789').tokens, ['12345678']);
    });

    test('memory: M+ keeps a result, MR brings it back', () {
      final mem = engine.initialize(
        parsed({
          'task': 'solve',
          'answer': '86',
          'memory': true,
          'require_memory': true,
        }),
        const EngineSeed(1),
      );
      var s = keys(mem, ['6', '×', '7', '=', 'M+']);
      expect(s.memory, '42');
      s = keys(s, ['C', '4', '4', '+', 'MR', '=']);
      expect(s.result, '86');
      expect(s.recalled, isTrue);
      expect(keys(s, ['M−']).memory, '−44');
      expect(keys(s, ['MC']).memory, isNull);
    });

    test('+/− flips the number being keyed', () {
      final signed = engine.initialize(
        parsed({'task': 'solve', 'answer': '−2', 'sign': true}),
        const EngineSeed(1),
      );
      final s = keys(signed, ['3', '+/−', '+', '1', '=']);
      expect(s.result, '−2');
    });
  });

  group('grading', () {
    test('key: the asked line is right, swapped × too', () {
      expect(grade(key, keys(blank, '48×12=')).outcome, Outcome.correct);
      expect(grade(key, keys(blank, '12×48=')).outcome, Outcome.correct);
    });

    test('key: typing the answer is not keying the calculation', () {
      final r = grade(key, keys(blank, '576='));
      expect(r.outcome, Outcome.incorrect);
    });

    test('key: a wrong operation or digit is a misread key', () {
      final r = grade(key, keys(blank, '48+12='));
      expect(r.outcome, Outcome.incorrect);
      expect(r.feedbackCode, 'math.calculator.key_misread');
      expect(
        grade(key, keys(blank, '49×12=')).feedbackCode,
        'math.calculator.key_misread',
      );
    });

    test('key: right keys in the wrong order', () {
      final div = parsed({'task': 'key', 'expression': '48 ÷ 12'});
      final s = keys(engine.initialize(div, const EngineSeed(1)), '12÷48=');
      expect(grade(div, s).feedbackCode, 'math.calculator.key_order');
    });

    test('nothing to check before =', () {
      expect(engine.extractAnswer(keys(blank, '48×12')), isNull);
    });

    test('repair: opens on the mistake; fixing it is right', () {
      final repair = parsed({
        'task': 'repair',
        'expression': '48 × 12',
        'start': '48 + 12',
      });
      final open = engine.initialize(repair, const EngineSeed(1));
      expect(open.tokens, ['48', '+', '12']);
      expect(grade(repair, keys(open, '=')).outcome, Outcome.incorrect);
      final fixed = keys(open, '⌫⌫⌫×12=');
      expect(grade(repair, fixed).outcome, Outcome.correct);
    });

    test('solve: right without MR is partial when memory is the point', () {
      final solve = parsed({
        'task': 'solve',
        'answer': '86',
        'memory': true,
        'require_memory': true,
      });
      final s = keys(engine.initialize(solve, const EngineSeed(1)), '6×7+44=');
      final r = grade(solve, s);
      expect(r.outcome, Outcome.partial);
      expect(r.feedbackCode, 'math.calculator.memory_not_used');
    });
  });

  test('snapshot and restore round-trip', () {
    final mem = parsed({'task': 'solve', 'answer': '86', 'memory': true});
    final s = keys(engine.initialize(mem, const EngineSeed(1)), [
      '4',
      '2',
      'M+',
      '+',
      '1',
    ]);
    final back = engine.restore(mem, engine.snapshot(s))!;
    expect(back.tokens, s.tokens);
    expect(back.memory, '42');
    expect(
      engine.restore(mem, {
        'tokens': ['x'],
      }),
      isNull,
    );
  });

  testWidgets('in the shell: key 48 × 12, then Bravo; a phone fits', (
    tester,
  ) async {
    for (final size in [const Size(900, 1400), const Size(360, 780)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ActivitySessionController(
        envelope: QuestionEnvelope.parse({
          'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          'version': 1,
          'content_hash': 'h',
          'engine_key': 'calculator',
          'engine_min_version': 1,
          'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
          'subject': 'MATH',
          'grade': 3,
          'rank': 0,
          'prompt': {'text': 'Calcule 48 × 12 avec la calculatrice.'},
          'config': {'task': 'key', 'expression': '48 × 12', 'memory': true},
        }).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(engine)]),
        evaluators: EvaluatorRegistry(const [evaluator]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      await tester.runAsync(controller.start);
      await tester.pumpWidget(
        MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: LearningActivityView(
              controller: controller,
              locale: fr,
              onDone: () {},
            ),
          ),
        ),
      );
      for (final id in ['d4', 'd8', 'mul', 'd1', 'd2', 'equals']) {
        await tester.ensureVisible(find.byKey(ValueKey('calc-key-$id')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('calc-key-$id')));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
      }
      expect(find.text('48 × 12'), findsOneWidget);
      expect(find.text('576'), findsOneWidget);
      await tester.tap(find.text('VALIDER'));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      expect(find.text('Bravo !'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      controller.dispose();
      await tester.pumpWidget(const SizedBox());
    }
  });
}
