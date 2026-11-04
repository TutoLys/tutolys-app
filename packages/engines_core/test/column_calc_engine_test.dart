import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);
const engine = ColumnCalcEngine();
const evaluator = ColumnCalcEvaluator();

ColumnContent parsed(String op, String a, String b) => engine.parse({
  'op': op,
  'operands': [a, b],
}).valueOrNull!;

/// Type [number] into [row], right to left, from the row's first cell.
ColumnState type(ColumnState s, String row, String number) {
  s = engine.reduce(s, TapColumnCell('${row}_0')).state;
  for (final d in number.split('').reversed) {
    s = engine.reduce(s, TapColumnDigit(d)).state;
  }
  return s;
}

EvaluationResult grade(ColumnContent c, ColumnState s) =>
    evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);

void main() {
  group('parse computes the expected rows', () {
    test('a sum and a difference, naturals and decimals', () {
      expect(
        parsed('add', '478', '256').rows.single.expected.reversed.join(),
        '734',
      );
      final dec = parsed('add', '12,5', '3,75');
      expect(dec.decimals, 2);
      expect(dec.operands, ['1250', '375']);
      expect(dec.rows.single.expected.reversed.join(), '1625');
      expect(
        parsed('sub', '503', '178').rows.single.expected.reversed.join(),
        '325',
      );
      expect(
        parsed('sub', '0,8', '0,5').rows.single.expected.reversed.join(),
        '03',
      );
    });

    test(
      'a product by two digits has two partial rows, the second shifted',
      () {
        final c = parsed('mul', '243', '36');
        expect(c.rows.map((r) => r.id), ['p0', 'p1', 'r']);
        expect(c.rows[0].expected.reversed.join(), '1458');
        expect(c.rows[1].expected.reversed.join(), '7290');
        expect(c.rows[2].expected.reversed.join(), '8748');
        expect(parsed('mul', '243', '6').rows.map((r) => r.id), ['r']);
      },
    );

    test('a division has a quotient and a remainder', () {
      final c = parsed('div', '857', '6');
      expect(c.rows[0].expected.reversed.join(), '142');
      expect(c.rows[1].expected.reversed.join(), '5');
    });

    for (final (why, config) in <(String, Map<String, Object?>)>[
      (
        'a negative difference',
        {
          'op': 'sub',
          'operands': ['12', '30'],
        },
      ),
      (
        'a division by zero',
        {
          'op': 'div',
          'operands': ['12', '0'],
        },
      ),
      (
        'a three-digit multiplier',
        {
          'op': 'mul',
          'operands': ['12', '345'],
        },
      ),
      (
        'a number that is not one',
        {
          'op': 'add',
          'operands': ['12', 'douze'],
        },
      ),
    ]) {
      test('refuses $why', () {
        expect(engine.parse(config), isA<ParseInvalid<ColumnContent>>());
      });
    }

    test('a decimal product is an app update, not a content bug', () {
      expect(
        engine.parse({
          'op': 'mul',
          'operands': ['1,5', '3'],
        }),
        isA<ParseUnsupported<ColumnContent>>(),
      );
    });
  });

  group('filling', () {
    test('digits go right to left along the row', () {
      final c = parsed('add', '478', '256');
      final s = type(engine.initialize(c, const EngineSeed(1)), 'r', '734');
      expect(s.cells, {'r_0': '4', 'r_1': '3', 'r_2': '7'});
      expect(grade(c, s).outcome, Outcome.correct);
    });

    test('scratch boxes take a carry and are never graded', () {
      final c = parsed('add', '478', '256');
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapColumnCell('s_1')).state;
      s = engine.reduce(s, const TapColumnDigit('1')).state;
      s = type(s, 'r', '734');
      final r = grade(c, s);
      expect(r.itemResults.keys, isNot(contains('s_1')));
      expect(r.outcome, Outcome.correct);
      expect(engine.applyFeedback(s, r).cells['s_1'], '1');
    });

    test('VALIDER waits for every graded cell; erase empties one', () {
      final c = parsed('sub', '503', '178');
      var s = type(engine.initialize(c, const EngineSeed(1)), 'r', '25');
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const TapColumnCell('r_0')).state;
      s = engine.reduce(s, const EraseColumnCell()).state;
      expect(s.cells.containsKey('r_0'), isFalse);
      expect(engine.reduce(s, const TapColumnCell('x_9')).state, s);
    });

    test('a snapshot round-trips; a locked wrong digit is refused', () {
      final c = parsed('add', '478', '256');
      final s = type(engine.initialize(c, const EngineSeed(1)), 'r', '73');
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(engine.snapshot(back), engine.snapshot(s));
      expect(
        engine.restore(c, {
          'cells': {'r_0': '9'},
          'locked': ['r_0'],
        }),
        isNull,
      );
    });
  });

  group('the named slips', () {
    String? slip(String op, String a, String b, Map<String, String> rows) {
      final c = parsed(op, a, b);
      var s = engine.initialize(c, const EngineSeed(1));
      for (final e in rows.entries) {
        s = type(s, e.key, e.value);
      }
      final r = grade(c, s);
      expect(r.outcome, isNot(Outcome.correct));
      return r.feedbackCode;
    }

    test('the carry forgotten', () {
      expect(slip('add', '478', '256', {'r': '624'}), 'math.add.no_regroup');
    });

    test('the smaller digit from the larger', () {
      expect(
        slip('sub', '503', '178', {'r': '475'}),
        'math.sub.smaller_from_larger',
      );
    });

    test('the second product not shifted', () {
      expect(
        slip('mul', '243', '36', {'p0': '1458', 'p1': '0729', 'r': '2187'}),
        'math.mul.partial_not_shifted',
      );
    });

    test('a remainder too big', () {
      // 857 ÷ 16 = 53 r 9; one too few in the quotient leaves 57.
      expect(
        slip('div', '857', '16', {'q': '52', 'm': '57'}),
        'math.div.remainder_too_big',
      );
      expect(
        slip('div', '857', '6', {'q': '141', 'm': '7'}),
        'math.div.remainder_too_big',
      );
    });

    test(
      'a remainder row is as wide as the divisor; its leading 0 is optional',
      () {
        final c = parsed('div', '857', '16');
        expect(c.rows.last.width, 2);
        var s = type(engine.initialize(c, const EngineSeed(1)), 'q', '53');
        s = type(s, 'm', '9');
        expect(grade(c, s).outcome, Outcome.correct);
      },
    );

    test('any other wrong answer is unclassified, with partial credit', () {
      final c = parsed('add', '478', '256');
      final s = type(engine.initialize(c, const EngineSeed(1)), 'r', '735');
      final r = grade(c, s);
      expect(r.outcome, Outcome.partial);
      expect(r.feedbackCode, isNull);
      expect(r.errors.single.isUnclassified, isTrue);
      final after = engine.applyFeedback(s, r);
      expect(after.locked, {'r_1', 'r_2'});
      expect(after.cells.containsKey('r_0'), isFalse);
    });
  });

  testWidgets('in the shell: a product, keyed in, then Bravo', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ActivitySessionController(
      envelope: QuestionEnvelope.parse({
        'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
        'version': 1,
        'content_hash': 'h',
        'engine_key': 'column_calc',
        'engine_min_version': 1,
        'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
        'subject': 'MATH',
        'grade': 5,
        'rank': 0,
        'prompt': {'text': 'Calcule.'},
        'config': {
          'op': 'mul',
          'operands': ['243', '36'],
        },
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
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
        ),
      ),
    );
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
    }

    // Nothing selected: the first digit goes in the first product's units.
    for (final d in '8541'.split('')) {
      await tap('column-key-$d');
    }
    for (final d in '0927'.split('')) {
      await tap('column-key-$d');
    }
    for (final d in '8478'.split('')) {
      await tap('column-key-$d');
    }
    await tester.tap(find.text('VALIDER'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(find.text('Bravo !'), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  group('the separator follows the lesson, not the app', () {
    Future<void> show(
      WidgetTester tester, {
      required Locale app,
      required String lesson,
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse({
          'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          'version': 1,
          'content_hash': 'h',
          'engine_key': 'column_calc',
          'engine_min_version': 1,
          'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
          'subject': 'MATH',
          'grade': 3,
          'rank': 0,
          'locale': lesson,
          'prompt': {'text': 'Add.'},
          'config': {
            'op': 'add',
            'operands': ['2,4', '1,3'],
          },
        }).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(engine)]),
        evaluators: EvaluatorRegistry(const [evaluator]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      addTearDown(c.dispose);
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: LearningActivityView(
              controller: c,
              locale: app,
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an English lesson draws a point', (tester) async {
      await show(tester, app: const Locale('en'), lesson: 'en-CA');
      expect(find.text('.'), findsWidgets);
      expect(find.text(','), findsNothing);
    });

    testWidgets('a French lesson in an English app keeps its comma', (
      tester,
    ) async {
      await show(tester, app: const Locale('en'), lesson: 'fr-CA');
      expect(find.text(','), findsWidgets);
      expect(find.text('.'), findsNothing);
    });

    testWidgets('an English lesson in a French app keeps its point', (
      tester,
    ) async {
      await show(tester, app: fr, lesson: 'en-CA');
      expect(find.text('.'), findsWidgets);
      expect(find.text(','), findsNothing);
    });
  });
}
