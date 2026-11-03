import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);
const engine = BaseTenEngine();
const evaluator = BaseTenEvaluator();
const c = BaseTenPlace.c;
const d = BaseTenPlace.d;
const u = BaseTenPlace.u;

BaseTenContent parsed(Map<String, Object?> config) =>
    engine.parse(config).valueOrNull!;

BaseTenState run(BaseTenState s, List<BaseTenAction> actions) {
  for (final a in actions) {
    s = engine.reduce(s, a).state;
  }
  return s;
}

EvaluationResult grade(BaseTenContent content, BaseTenState s) =>
    evaluator.evaluate(content, engine.extractAnswer(s)!, ctx);

void main() {
  final represent = parsed({
    'places': ['c', 'd', 'u'],
    'target': {'value': '234'},
  });

  group('parse', () {
    for (final (why, bad) in <(String, Map<String, Object?>)>[
      (
        'places out of order',
        {
          'places': ['u', 'd'],
          'target': {'value': '12'},
        },
      ),
      (
        'a gap in the places',
        {
          'places': ['c', 'u'],
          'target': {'value': '12'},
        },
      ),
      (
        'a value finer than the board',
        {
          'places': ['d', 'u'],
          'target': {'value': '2,5'},
        },
      ),
      (
        'exact and value that disagree',
        {
          'places': ['d', 'u'],
          'target': {
            'value': '23',
            'exact': {'d': 2, 'u': 4},
          },
        },
      ),
      (
        'no supply and a start worth something else',
        {
          'places': ['d', 'u'],
          'supply': false,
          'start': {'d': 1, 'u': 3},
          'target': {'value': '23'},
        },
      ),
    ]) {
      test('refuses $why', () {
        expect(engine.parse(bad), isA<ParseInvalid<BaseTenContent>>());
      });
    }

    test('decimals: tenths and hundredths count in hundredths', () {
      final dec = parsed({
        'places': ['u', 'di', 'ci'],
        'target': {'value': '2,05'},
      });
      expect(dec.value, 205);
      expect(dec.worth({u: 2, BaseTenPlace.ci: 5}), 205);
    });
  });

  group('the board', () {
    test('any arrangement worth the value is right', () {
      final s0 = engine.initialize(represent, const EngineSeed(1));
      final canonical = run(s0, [
        for (var i = 0; i < 2; i++) const AddBlock(c),
        for (var i = 0; i < 3; i++) const AddBlock(d),
        for (var i = 0; i < 4; i++) const AddBlock(u),
      ]);
      expect(grade(represent, canonical).outcome, Outcome.correct);
      final odd = run(s0, [
        for (var i = 0; i < 2; i++) const AddBlock(c),
        for (var i = 0; i < 2; i++) const AddBlock(d),
        for (var i = 0; i < 14; i++) const AddBlock(u),
      ]);
      expect(grade(represent, odd).outcome, Outcome.correct);
    });

    test('an exchange keeps the value and reveals', () {
      final s = run(engine.initialize(represent, const EngineSeed(1)), const [
        AddBlock(c),
      ]);
      final t = engine.reduce(s, const BreakBlock(c));
      expect(t.state.count(c), 0);
      expect(t.state.count(d), 10);
      expect(t.events.whereType<RevealEvent>().single.what, 'exchange');
      final back = engine.reduce(t.state, const GroupBlocks(d)).state;
      expect((back.count(c), back.count(d)), (1, 0));
    });

    test('no exchange past the cap or off the edge', () {
      var s = engine.initialize(represent, const EngineSeed(1));
      s = run(s, [
        const AddBlock(d),
        for (var i = 0; i < 10; i++) const AddBlock(u),
      ]);
      expect(
        identical(engine.reduce(s, const BreakBlock(d)).state, s),
        isTrue,
        reason: '10 + 10 ones is over 19',
      );
      expect(identical(engine.reduce(s, const BreakBlock(u)).state, s), isTrue);
      expect(
        identical(engine.reduce(s, const GroupBlocks(c)).state, s),
        isTrue,
      );
    });

    test('exact: the value right but not exchanged is the named slip', () {
      final exchange = parsed({
        'places': ['d', 'u'],
        'supply': false,
        'start': {'d': 1, 'u': 15},
        'target': {
          'exact': {'d': 2, 'u': 5},
        },
      });
      final s0 = engine.initialize(exchange, const EngineSeed(1));
      expect(
        engine.reduce(s0, const AddBlock(u)).state,
        same(s0),
        reason: 'no supply',
      );
      final r = grade(exchange, s0);
      expect(r.outcome, Outcome.incorrect);
      expect(r.feedbackCode, 'math.place_value.not_exchanged');
      final done = run(s0, const [GroupBlocks(u)]);
      expect(grade(exchange, done).outcome, Outcome.correct);
    });

    test('a snapshot round-trips', () {
      final s = run(engine.initialize(represent, const EngineSeed(1)), const [
        AddBlock(c),
        AddBlock(u),
      ]);
      final back = engine.restore(represent, engine.snapshot(s))!;
      expect(engine.snapshot(back), engine.snapshot(s));
      expect(
        engine.restore(represent, {
          'counts': {'c': 25, 'd': 0, 'u': 0},
        }),
        isNull,
      );
    });
  });

  testWidgets('in the shell: build 234, then Bravo; a phone fits', (
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
          'engine_key': 'base_ten',
          'engine_min_version': 1,
          'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
          'subject': 'MATH',
          'grade': 2,
          'rank': 0,
          'prompt': {'text': 'Montre 234 avec les blocs.'},
          'config': {
            'places': ['c', 'd', 'u'],
            'target': {'value': '234'},
          },
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
      Future<void> add(String place, int n) async {
        for (var i = 0; i < n; i++) {
          await tester.tap(find.byKey(ValueKey('base-ten-add-$place')));
          await tester.runAsync(() => pumpEventQueue());
          await tester.pump();
        }
      }

      await add('c', 2);
      await add('d', 3);
      await add('u', 4);
      expect(find.text('234'.substring(0, 1)), findsWidgets);
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
