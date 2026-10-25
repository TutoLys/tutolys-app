import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend samples' shapes.
const numbers = <String, Object?>{
  'left': {
    'terms': [34],
  },
  'right': {
    'terms': [43],
  },
};

const expressions = <String, Object?>{
  'left': {
    'terms': [3, 2],
    'op': '+',
  },
  'right': {
    'terms': [6, 1],
    'op': '-',
  },
};

const counters = <String, Object?>{
  'left': {
    'terms': [7],
    'symbol': '🍎',
  },
  'right': {
    'terms': [5],
    'symbol': '🍎',
  },
  'signs': ['lt', 'gt'],
};

const missing = <String, Object?>{
  'mode': 'balance',
  'left': {
    'terms': [4, 1],
    'op': '+',
  },
  'right': {
    'terms': [1, null],
    'op': '+',
  },
  'options': [
    {'id': 'a', 'value': 4},
    {'id': 'b', 'value': 5},
    {'id': 'c', 'value': 1},
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'balance_scale',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Quel signe va au milieu ?'},
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
        eraseEngine(const BalanceScaleEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [BalanceScaleEvaluator()]),
      store: InMemoryActivitySessionStore(outbox),
      appVersion: '0.2.0',
      seed: 3,
    ),
    outbox,
  );
}

Widget app(ActivitySessionController c, {bool still = false}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(
      body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
    ),
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

BalanceContent parsed(Map<String, Object?> config) =>
    const BalanceScaleEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const BalanceScaleEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

double panTop(WidgetTester tester, String side) =>
    tester.getTopLeft(find.byKey(ValueKey('balance-pan-$side'))).dy;

void main() {
  const engine = BalanceScaleEngine();

  group('parse', () {
    test('the right sign comes from the values, never the content', () {
      expect(parsed(numbers).correctId, 'lt');
      expect(parsed(expressions).correctId, 'eq');
      expect(parsed(counters).correctId, 'gt');
      expect(parsed(counters).choices, ['lt', 'gt']);
      expect(parsed(numbers).choices, ['lt', 'gt', 'eq']);
    });

    test('the missing term is the one option that levels the scale', () {
      final c = parsed(missing);
      expect(c.mode, BalanceMode.balance);
      expect(c.correctId, 'a', reason: '4 + 1 = 1 + 4');
      expect(c.left.text(), '4 + 1');
      expect(c.right.text(), '1 + ?');
      expect(c.right.text(gap: '4'), '1 + 4');
    });

    test('rejects what cannot be played', () {
      expect(
        reason({
          ...numbers,
          'signs': ['gt', 'eq'],
        }),
        contains('not among the signs'),
      );
      expect(
        reason({
          ...numbers,
          'signs': ['lt'],
        }),
        contains('2 or 3'),
      );
      expect(
        reason({
          'left': {
            'terms': [101],
          },
          'right': {
            'terms': [1],
          },
        }),
        contains('0 to 100'),
      );
      expect(
        reason({
          'left': {
            'terms': [1, 2, 3],
          },
          'right': {
            'terms': [1],
          },
        }),
        contains('1 or 2 terms'),
      );
      expect(
        reason({
          'left': {
            'terms': [21],
            'symbol': '🍎',
          },
          'right': {
            'terms': [1],
          },
        }),
        contains('20 counters'),
      );
      expect(
        reason({
          'left': {
            'terms': [2, 5],
            'op': '-',
          },
          'right': {
            'terms': [1],
          },
        }),
        contains('below zero'),
      );
      expect(
        reason({...missing, 'mode': 'compare', 'options': null}),
        contains('no missing term'),
      );
      expect(
        reason({
          ...missing,
          'options': [
            {'id': 'a', 'value': 3},
            {'id': 'b', 'value': 5},
          ],
        }),
        contains('Exactly one option'),
      );
      expect(
        reason({
          ...missing,
          'options': [
            {'id': 'a', 'value': 4},
            {'id': 'b', 'value': 4},
          ],
        }),
        contains('unique'),
      );
      expect(
        reason({
          ...missing,
          'signs': ['lt', 'gt'],
        }),
        contains('belong to mode compare'),
      );
      expect(reason({...numbers, 'mode': 'weigh'}), contains('compare or'));
    });
  });

  group('initialize and reduce', () {
    test('signs keep < > =; options shuffle, the same per seed', () {
      expect(engine.initialize(parsed(numbers), const EngineSeed(9)).order, [
        'lt',
        'gt',
        'eq',
      ]);
      final orders = {
        for (var seed = 0; seed < 12; seed++)
          engine.initialize(parsed(missing), EngineSeed(seed)).order.join(),
      };
      expect(orders.length, greaterThan(1));
    });

    test('a new pick replaces the last; a tried one is ignored', () {
      var s = engine.initialize(parsed(numbers), const EngineSeed(1));
      s = engine.reduce(s, const PickBalanceChoice('gt')).state;
      s = engine.reduce(s, const PickBalanceChoice('lt')).state;
      expect(s.selected, 'lt');
      final tried = s.copyWith(tried: {'eq'});
      expect(engine.reduce(tried, const PickBalanceChoice('eq')).events, []);
      expect(engine.reduce(s, const PickBalanceChoice('zz')).events, []);
    });
  });

  group('BalanceScaleEvaluator', () {
    const evaluator = BalanceScaleEvaluator();

    test('grades against the derived sign and records the pick', () {
      final c = parsed(numbers);
      final right = evaluator.evaluate(c, const SingleChoiceAnswer('lt'), ctx);
      expect(right.outcome, Outcome.correct);
      expect(right.evaluator, 'balance_scale.exact@1');
      final reversed = evaluator.evaluate(
        c,
        const SingleChoiceAnswer('gt'),
        ctx,
      );
      expect(reversed.outcome, Outcome.incorrect);
      expect(reversed.itemResults, {'gt': false});
    });

    test('a wrong value is remembered so the scale can tip for it', () {
      final c = parsed(missing);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const PickBalanceChoice('b')).state;
      s = engine.applyFeedback(
        s,
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx),
      );
      expect(s.tried, {'b'});
      expect(s.lastWrong, 'b');
      expect(s.selected, isNull);
      expect(c.weigh('b'), (5, 6), reason: '4 + 1 against 1 + 5');
    });
  });

  group('snapshot', () {
    test('round-trips, and rejects an impossible one', () {
      final c = parsed(missing);
      final s = engine
          .initialize(c, const EngineSeed(4))
          .copyWith(tried: {'b'}, lastWrong: 'b', selected: 'c');
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.order, s.order);
      expect(back.lastWrong, 'b');
      expect(back.selected, 'c');
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'tried': ['a'],
        }),
        isNull,
        reason: 'the right value can never have been tried wrong',
      );
      expect(
        engine.restore(parsed(numbers), {
          ...engine.snapshot(
            engine.initialize(parsed(numbers), const EngineSeed(1)),
          ),
          'order': ['eq', 'lt', 'gt'],
        }),
        isNull,
        reason: 'signs are never reordered',
      );
    });
  });

  group('in the shell', () {
    testWidgets('compare: level while choosing, tips once right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(numbers);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, still: true));
      expect(find.text('34'), findsOneWidget);
      expect(panTop(tester, 'left'), panTop(tester, 'right'));

      await tester.tap(find.byKey(const ValueKey('balance-choice-gt')));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('balance-middle')),
          matching: find.text('>'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(
        panTop(tester, 'left'),
        panTop(tester, 'right'),
        reason: 'a wrong sign never reveals the answer by tipping',
      );

      await tester.tap(find.byKey(const ValueKey('balance-choice-lt')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(
        panTop(tester, 'right'),
        greaterThan(panTop(tester, 'left')),
        reason: '43 is heavier: the right pan goes down',
      );
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .map((e) => e['is_correct']);
      expect(attempts, [false, true]);
      c.dispose();
    });

    testWidgets('balance: a wrong value tips the scale its way', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(missing);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, still: true));
      expect(find.text('1 + ?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('balance-choice-b')));
      await settle(tester);
      expect(find.text('1 + 5'), findsOneWidget);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(
        panTop(tester, 'right'),
        greaterThan(panTop(tester, 'left')),
        reason: '1 + 5 is too heavy',
      );
      expect(find.bySemanticsLabel(RegExp('penche à droite')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('balance-choice-a')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(panTop(tester, 'left'), panTop(tester, 'right'));
      c.dispose();
    });

    testWidgets('counters: only < and > are offered', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(counters);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, still: true));
      expect(find.text('🍎'), findsNWidgets(12));
      expect(find.byKey(const ValueKey('balance-choice-eq')), findsNothing);
      c.dispose();
    });

    testWidgets('signs and pans are spoken in words', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(expressions);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, still: true));
      expect(find.bySemanticsLabel('plus petit que'), findsOneWidget);
      expect(find.bySemanticsLabel('égal à'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Plateau de gauche : 3 + 2. Plateau de droite : 6 moins 1. '
          'La balance est en équilibre.',
        ),
        findsOneWidget,
      );
      c.dispose();
    });

    testWidgets('20 counters a side fit a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'left': {
          'terms': [20],
          'symbol': '🍎',
        },
        'right': {
          'terms': [19],
          'symbol': '🍐',
        },
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
