import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The animation contract (plan PLAN_GRADES_2_6_ENGINES §3.3): engines
/// report their moments as runtime events, and the shell, not the engine,
/// owns the idle prompt and the board's character.
const fr = Locale('fr');

Map<String, Object?> envelope(String engine, Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': engine,
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 2,
  'rank': 0,
  'prompt': {'text': 'Essaie !'},
  'config': config,
};

ActivitySessionController controller(
  String key,
  Map<String, Object?> config,
  ErasedEngine engine,
  Evaluator<Object?, AnswerValue> evaluator,
) => ActivitySessionController(
  envelope: QuestionEnvelope.parse(envelope(key, config)).valueOrNull!,
  kidId: 'kid',
  engines: LearningEngineRegistry([engine]),
  evaluators: EvaluatorRegistry([evaluator]),
  store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
  appVersion: '0.2.0',
  seed: 3,
);

Widget app(ActivitySessionController c, {BoardActorBuilder? boardActor}) =>
    MaterialApp(
      theme: TutolysTheme.village(),
      home: Scaffold(
        body: LearningActivityView(
          controller: c,
          locale: fr,
          onDone: () {},
          boardActor: boardActor,
        ),
      ),
    );

const balance = <String, Object?>{
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

const compose = <String, Object?>{
  'tiles': [
    {'id': 'a', 'label': 'ma'},
    {'id': 'b', 'label': 'man'},
  ],
  'target': ['a', 'b'],
};

const grid = <String, Object?>{
  'rows': 2,
  'cols': 2,
  'start': {'row': 0, 'col': 0},
  'goal': {'row': 1, 'col': 1},
  'max_moves': 4,
};

void main() {
  group('reveal', () {
    test('a balance scale tips, for a wrong value and when solved', () async {
      final c = controller(
        'balance_scale',
        balance,
        eraseEngine(const BalanceScaleEngine()),
        const BalanceScaleEvaluator(),
      );
      final seen = <RuntimeEvent>[];
      final sub = c.events.listen(seen.add);
      await c.start();
      await c.dispatch(const PickBalanceChoice('b'));
      await c.submit();
      await c.proceed();
      await c.dispatch(const PickBalanceChoice('a'));
      await c.submit();
      await pumpEventQueue();
      final tips = [
        for (final e in seen)
          if (e is RevealEvent) e,
      ];
      expect(tips.map((e) => (e.what, e.itemId)), [('tip', 'b'), ('tip', 'a')]);
      // Right after the verdict it belongs to.
      final i = seen.indexOf(tips.last);
      expect(seen[i - 1], isA<AnswerEvaluated>());
      expect(tips.every((e) => !e.category.isDurable), isTrue);
      await sub.cancel();
      c.dispose();
    });

    test('a compare scale stays level on a wrong sign', () {
      const engine = BalanceScaleEngine();
      final content = engine.parse(const {
        'left': {
          'terms': [34],
        },
        'right': {
          'terms': [43],
        },
      }).valueOrNull!;
      final s = engine.initialize(content, const EngineSeed(1));
      final picked = engine.reduce(s, const PickBalanceChoice('gt')).state;
      const wrong = EvaluationResult(
        outcome: Outcome.incorrect,
        score: 0,
        attemptNumber: 1,
        evaluator: 'x',
      );
      final after = engine.applyFeedback(picked, wrong);
      expect(engine.revealsAfterFeedback(picked, after, wrong), isEmpty);
    });

    test('an experiment shows its outcome', () {
      const engine = ExperimentLabEngine();
      final content = engine.parse(water).valueOrNull!;
      final s = engine.initialize(content, const EngineSeed(1));
      final t = engine.reduce(s, const RunExperiment());
      expect(t.events.whereType<RevealEvent>().single.what, 'outcome');
    });

    test('the discussion clue appears with a reveal, once', () {
      const engine = PassageReaderEngine();
      final content = engine.parse(const {
        'task': 'discuss',
        'sentences': [
          {'id': 's1', 'text': 'Le tonnerre gronde.'},
          {'id': 's2', 'text': 'La fenêtre est ouverte.'},
        ],
        'question': 'Pourquoi Pompon se cache-t-il ?',
        'options': [
          {'id': 'peur', 'label': 'Il a peur.'},
          {'id': 'froid', 'label': 'Il a froid.'},
        ],
        'takes': [
          {'id': 'lea', 'character': 'lea', 'text': 'Peur.', 'cites': 's1'},
          {'id': 'omar', 'character': 'omar', 'text': 'Froid.', 'cites': 's2'},
        ],
        'clue': {'id': 'c1', 'text': 'Il sort après l’orage.'},
      }).valueOrNull!;
      var s = engine.initialize(content, const EngineSeed(1));
      final reveals = <RevealEvent>[];
      for (final a in [
        const DiscussPickFirst('peur'),
        const DiscussCite('lea', 's1'),
        const DiscussCite('omar', 's2'),
      ]) {
        final t = engine.reduce(s, a);
        reveals.addAll(t.events.whereType<RevealEvent>());
        s = t.state;
      }
      expect(reveals.map((e) => (e.what, e.itemId)), [('clue', 'c1')]);
    });

    test('a checked walk ends with a reveal at the goal', () async {
      final c = controller(
        'path_planner',
        grid,
        eraseEngine(const PathPlannerEngine()),
        const PathPlannerEvaluator(),
      );
      final seen = <RuntimeEvent>[];
      final sub = c.events.listen(seen.add);
      await c.start();
      for (final m in ['right', 'down']) {
        await c.dispatch(AddPathMove(m));
      }
      await c.submit();
      await pumpEventQueue();
      final walk = seen.whereType<RevealEvent>().single;
      expect((walk.what, walk.itemId), ('walk', 'goal'));
      await sub.cancel();
      c.dispose();
    });
  });

  group('idle', () {
    testWidgets('the shell emits the idle event, then draws the hand', (
      tester,
    ) async {
      final c = controller(
        'compose_build',
        compose,
        eraseEngine(const ComposeSlotsEngine()),
        const ComposeBuildEvaluator(),
      );
      await tester.runAsync(c.start);
      final seen = <RuntimeEvent>[];
      final sub = c.events.listen(seen.add);
      await tester.pumpWidget(app(c));
      final hand = find.byKey(const ValueKey('idle-hand'));
      await tester.pump(IdleHandHint.wait - const Duration(milliseconds: 200));
      expect(hand, findsNothing);
      expect(seen.whereType<IdlePrompted>(), isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      final idle = seen.whereType<IdlePrompted>().single;
      expect(idle.afterMs, IdleHandHint.wait.inMilliseconds);
      expect(idle.targetId, isNotNull, reason: 'the engine names its tile');
      expect(hand, findsOneWidget);
      unawaited(sub.cancel());
      c.dispose();
    });

    testWidgets('an engine on its own still shows the hand, with no event', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TutolysTheme.village(),
          home: const Scaffold(
            body: Center(
              child: IdleHandHint(
                show: true,
                child: SizedBox.square(dimension: 64),
              ),
            ),
          ),
        ),
      );
      await tester.pump(IdleHandHint.wait + const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('idle-hand')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('board actor', () {
    testWidgets('Foxy on the grid comes from the host', (tester) async {
      final c = controller(
        'path_planner',
        grid,
        eraseEngine(const PathPlannerEngine()),
        const PathPlannerEvaluator(),
      );
      await tester.runAsync(c.start);
      final roles = <String>[];
      await tester.pumpWidget(
        app(
          c,
          boardActor: (context, role, size) {
            roles.add(role);
            return SizedBox.square(
              key: const ValueKey('host-actor'),
              dimension: size,
            );
          },
        ),
      );
      expect(find.byKey(const ValueKey('host-actor')), findsOneWidget);
      expect(roles.toSet(), {'walker'});
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('path-foxy')),
          matching: find.byType(TutolysMascot),
        ),
        findsNothing,
      );
      c.dispose();
    });

    testWidgets('by default the fox is happy once the walk is right', (
      tester,
    ) async {
      final c = controller(
        'path_planner',
        grid,
        eraseEngine(const PathPlannerEngine()),
        const PathPlannerEvaluator(),
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      MascotMood mood() => tester
          .widget<TutolysMascot>(
            find.descendant(
              of: find.byKey(const ValueKey('path-foxy')),
              matching: find.byType(TutolysMascot),
            ),
          )
          .mood;
      expect(mood(), MascotMood.idle);
      await tester.runAsync(() async {
        for (final m in ['right', 'down']) {
          await c.dispatch(AddPathMove(m));
        }
        await c.submit();
        await pumpEventQueue();
      });
      await tester.pump();
      expect(mood(), MascotMood.correct);
      c.dispose();
    });
  });
}

const water = <String, Object?>{
  'scene': 'water',
  'variables': [
    {
      'id': 'chaleur',
      'label': 'Température',
      'values': [
        {'id': 'froid', 'label': 'Congélateur'},
        {'id': 'piece', 'label': 'Cuisine'},
        {'id': 'chaud', 'label': 'Sur le feu'},
      ],
    },
  ],
  'outcomes': [
    {
      'when': {'chaleur': 'froid'},
      'label': 'L’eau devient de la glace.',
      'look': 'ice',
    },
    {
      'when': {'chaleur': 'piece'},
      'label': 'L’eau reste liquide.',
      'look': 'liquid',
    },
    {
      'when': {'chaleur': 'chaud'},
      'label': 'L’eau devient de la vapeur.',
      'look': 'steam',
    },
  ],
  'options': [
    {'id': 'a', 'label': 'La chaleur change l’état de l’eau.'},
    {'id': 'b', 'label': 'L’eau ne change jamais.'},
  ],
  'correct': 'a',
};
