import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

Map<String, Object?> diag(String code) => {'code': code, 'taxonomy_version': 1};

// "Léa a 7 billes. Elle en donne 3. Combien lui en reste-t-il ?"
const takeAway = <String, Object?>{
  'mode': 'free',
  'start': {'mat': 7},
  'supply': false,
  'target': {'removed': 3},
  'near_misses': [
    {
      'when': {'removed': 4},
      'diagnosis': {'code': 'math.sub.one_too_many', 'taxonomy_version': 1},
    },
  ],
};

// 12 cookies shared fairly between 3 friends.
const share = <String, Object?>{
  'mode': 'plates',
  'plates': 3,
  'start': {
    'mat': 12,
    'plates': [0, 0, 0],
  },
  'supply': false,
  'target': {'per_plate': 4, 'mat': 0},
  'symbol': '🍪',
  'near_misses': [
    {
      'when': {'per_plate': 3, 'mat': 3},
      'diagnosis': {'code': 'math.share.stopped_early', 'taxonomy_version': 1},
    },
  ],
};

const array = <String, Object?>{
  'mode': 'array',
  'target': {'rows': 3, 'cols': 4},
  'near_misses': [
    {
      'when': {'rows': 4, 'cols': 3},
      'diagnosis': {
        'code': 'math.array.rows_cols_swapped',
        'taxonomy_version': 1,
      },
    },
  ],
};

// 24 as groups of ten.
const tens = <String, Object?>{
  'mode': 'plates',
  'plates': 3,
  'ten_frames': true,
  'target': {
    'plates': [10, 10, 4],
  },
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'counters_board',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Partage les 12 biscuits entre les 3 amis.'},
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
        eraseEngine(const CountersBoardEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [CountersBoardEvaluator()]),
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
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

CountersContent parsed(Map<String, Object?> config) =>
    const CountersBoardEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const CountersBoardEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = CountersBoardEngine();
  const evaluator = CountersBoardEvaluator();

  CountersState apply(CountersState s, List<CountersAction> actions) {
    for (final a in actions) {
      s = engine.reduce(s, a).state;
    }
    return s;
  }

  group('parse', () {
    test('reads every mode', () {
      expect(parsed(takeAway).startTotal, 7);
      expect(parsed(share).hasMat, isTrue);
      expect(parsed(share).symbol, '🍪');
      expect(parsed(array).mode, CountersMode.array);
      expect(parsed(tens).plateCap, 10);
      expect(parsed(tens).hasMat, isFalse);
    });

    test('rejects targets that cannot be met', () {
      expect(
        reason({
          ...takeAway,
          'target': {'removed': 9},
        }),
        contains('more than the counters'),
      );
      expect(
        reason({
          ...takeAway,
          'target': {'total': 9},
        }),
        contains('no supply'),
      );
      expect(
        reason({
          ...takeAway,
          'target': {'total': 5, 'removed': 3},
        }),
        contains('disagree'),
      );
      expect(
        reason({
          ...share,
          'target': {'per_plate': 5, 'mat': 0},
        }),
        contains('more counters than there are'),
      );
      expect(
        reason({
          ...share,
          'target': {'per_plate': 4, 'total': 11, 'mat': 0},
        }),
        contains('add up'),
      );
      expect(
        reason({
          ...tens,
          'target': {'per_plate': 11},
        }),
        contains('more than a plate holds'),
      );
      expect(
        reason({
          ...array,
          'target': {'rows': 8, 'cols': 2},
        }),
        contains('max_rows'),
      );
      expect(
        reason({
          ...array,
          'target': {'rows': 3, 'cols': 4, 'total': 13},
        }),
        contains('rows × cols'),
      );
      expect(
        reason({
          ...takeAway,
          'target': {'rows': 2},
        }),
        contains('mode array'),
      );
      expect(
        reason({
          ...tens,
          'target': {'mat': 2},
        }),
        contains('needs a mat'),
      );
      expect(
        reason({
          ...takeAway,
          'target': {'colour': 2},
        }),
        contains('unknown rule'),
      );
      expect(
        reason({...takeAway, 'target': <String, Object?>{}}),
        contains('at least one'),
      );
      expect(
        reason({
          ...takeAway,
          'near_misses': [
            {
              'when': {'removed': 4},
            },
          ],
        }),
        contains('near_miss'),
      );
      expect(
        reason({
          ...share,
          'counter': {'shape': 'star'},
        }),
        contains('not both'),
      );
    });
  });

  group('the board', () {
    test('take away: only what is there; removed is measured', () {
      final c = parsed(takeAway);
      var s = engine.initialize(c, const EngineSeed(1));
      expect(engine.reduce(s, const AddCounter(CountersArea.mat)).state.mat, 7);
      s = apply(s, [
        for (var i = 0; i < 4; i++) const TakeCounter(CountersArea.mat),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.incorrect);
      expect(r.itemResults, {'removed': false});
      expect(r.errors.single.code, 'math.sub.one_too_many');
    });

    test('sharing: + on a plate takes from the pile; a near miss is named', () {
      final c = parsed(share);
      var s = engine.initialize(c, const EngineSeed(1));
      s = apply(s, [
        for (var p = 0; p < 3; p++)
          for (var i = 0; i < 3; i++) AddCounter(p),
      ]);
      expect(s.mat, 3);
      expect(s.plates, [3, 3, 3]);
      var r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.errors.single.code, 'math.share.stopped_early');
      s = apply(s, [for (var p = 0; p < 3; p++) AddCounter(p)]);
      // The pile is empty and there's no supply: nothing more to add.
      expect(engine.reduce(s, const AddCounter(0)).state.plates, [4, 4, 4]);
      r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
      // − on a plate puts the counter back on the pile.
      expect(engine.reduce(s, const TakeCounter(1)).state.mat, 1);
      // A drag between plates.
      final moved = engine.reduce(s, const MoveCounter(0, 2)).state;
      expect(moved.plates, [3, 4, 5]);
    });

    test('ten-frames hold ten; the reserve supplies the rest', () {
      final c = parsed(tens);
      var s = engine.initialize(c, const EngineSeed(1));
      s = apply(s, [
        for (var i = 0; i < 12; i++) const AddCounter(0),
        for (var i = 0; i < 10; i++) const AddCounter(1),
        for (var i = 0; i < 4; i++) const AddCounter(2),
      ]);
      expect(s.plates, [10, 10, 4]);
      expect(
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
      // Dragged back to the reserve: gone.
      expect(
        engine
            .reduce(s, const MoveCounter(2, CountersArea.reserve))
            .state
            .plates,
        [10, 10, 3],
      );
    });

    test('ten-frames compare plates in any order; plates keep order', () {
      final c = parsed(tens);
      expect(c.target.platesAnyOrder, isTrue);
      final shuffled = BlanksAnswer({
        'plate_0': '4',
        'plate_1': '10',
        'plate_2': '10',
      });
      expect(evaluator.evaluate(c, shuffled, ctx).outcome, Outcome.correct);
      final ordered = parsed({
        ...tens,
        'target': {
          'plates': [10, 10, 4],
          'plates_any_order': false,
        },
      });
      expect(
        evaluator.evaluate(ordered, shuffled, ctx).outcome,
        Outcome.incorrect,
      );
      final plates = parsed({
        'mode': 'plates',
        'plates': 2,
        'target': {
          'plates': [2, 5],
        },
      });
      expect(plates.target.platesAnyOrder, isFalse);
      expect(
        evaluator
            .evaluate(
              plates,
              BlanksAnswer({'plate_0': '5', 'plate_1': '2'}),
              ctx,
            )
            .outcome,
        Outcome.incorrect,
      );
    });

    test('arrays: swapped rows and columns are wrong, unless either_way', () {
      final c = parsed(array);
      var s = apply(engine.initialize(c, const EngineSeed(1)), [
        const SetRows(4),
        const SetCols(3),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.incorrect);
      expect(r.errors.single.code, 'math.array.rows_cols_swapped');
      final loose = parsed({
        ...array,
        'target': {'rows': 3, 'cols': 4, 'either_way': true},
      });
      expect(
        evaluator.evaluate(loose, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
      s = engine.reduce(s, const SetRows(9)).state;
      expect(s.rows, 4);
      expect(
        engine.extractAnswer(engine.initialize(c, const EngineSeed(1))),
        isNull,
      );
    });

    test('snapshot round-trips and refuses an impossible board', () {
      final c = parsed(share);
      final s = apply(engine.initialize(c, const EngineSeed(1)), [
        const AddCounter(0),
        const AddCounter(1),
      ]);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.plates, [1, 1, 0]);
      expect(back.mat, 10);
      expect(engine.restore(c, {...engine.snapshot(s), 'mat': 20}), isNull);
      expect(
        engine.restore(c, {...engine.snapshot(s), 'solved': true}),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('share out with the + buttons: wrong, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(share);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> add(int plate, int times) async {
        for (var i = 0; i < times; i++) {
          await tester.tap(find.byKey(ValueKey('counters-add-$plate')));
          await settle(tester);
        }
      }

      await add(0, 5);
      await add(1, 4);
      await add(2, 3);
      expect(find.bySemanticsLabel(RegExp('Assiette 1 : 5 jetons')), findsOne);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('counters-take-0')));
      await settle(tester);
      await add(2, 1);
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

    testWidgets('drag a counter from the reserve onto a ten-frame', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(tens);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final from = tester.getCenter(
        find.byWidgetPredicate(
          (w) => w is Draggable<int> && w.data == CountersArea.reserve,
        ),
      );
      final to = tester.getCenter(
        find.byKey(const ValueKey('counters-area-1')),
      );
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump();
      }
      await g.up();
      await settle(tester);
      expect((c.current!.state as CountersState).plates, [0, 1, 0]);
      c.dispose();
    });

    testWidgets('an array and three plates fit a phone', (tester) async {
      tallView(tester, width: 375);
      for (final config in [array, share]) {
        final (c, _) = controllerFor(config);
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c));
        if (config == array) {
          for (var i = 0; i < 6; i++) {
            await tester.tap(find.byKey(const ValueKey('counters-rows-plus')));
            await tester.tap(find.byKey(const ValueKey('counters-cols-plus')));
            await settle(tester);
          }
        }
        expect(tester.takeException(), isNull);
        c.dispose();
      }
    });
  });
}
