import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// 4×4. Start top-left, goal bottom-right, a wall in the way, and the
// park must be passed.
//   S . . .
//   . # P .
//   . # . .
//   . . . G
const grid = <String, Object?>{
  'rows': 4,
  'cols': 4,
  'start': {'row': 0, 'col': 0},
  'goal': {'row': 3, 'col': 3},
  'walls': [
    {'row': 1, 'col': 1},
    {'row': 2, 'col': 1},
  ],
  'landmarks': [
    {'id': 'parc', 'row': 1, 'col': 2, 'label': 'Parc'},
    {'id': 'ecole', 'row': 3, 'col': 0, 'label': 'École'},
  ],
  'must_visit': ['parc'],
  'max_moves': 8,
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'path_planner',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Aide Foxy à aller au drapeau en passant par le parc.'},
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
      engines: LearningEngineRegistry([eraseEngine(const PathPlannerEngine())]),
      evaluators: EvaluatorRegistry(const [PathPlannerEvaluator()]),
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

PathContent parsed(Map<String, Object?> config) =>
    const PathPlannerEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const PathPlannerEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = PathPlannerEngine();
  const evaluator = PathPlannerEvaluator();

  group('parse', () {
    test('finds the shortest route through the must-visit landmark', () {
      // right, right, down (park), down, down, right = 6.
      expect(parsed(grid).shortest, 6);
      expect(parsed({...grid, 'must_visit': <String>[]}).shortest, 6);
    });

    test('rejects what cannot be solved or played', () {
      expect(reason({...grid, 'max_moves': 5}), contains('takes 6 moves'));
      expect(
        reason({
          ...grid,
          'walls': [
            {'row': 0, 'col': 1},
            {'row': 1, 'col': 0},
          ],
        }),
        contains('No route'),
      );
      expect(reason({...grid, 'rows': 9}), contains('2 to 7'));
      expect(
        reason({
          ...grid,
          'goal': {'row': 0, 'col': 0},
        }),
        contains('different'),
      );
      expect(
        reason({
          ...grid,
          'must_visit': ['zoo'],
        }),
        contains('must_visit'),
      );
      expect(
        reason({
          ...grid,
          'landmarks': [
            {'id': 'a', 'row': 1, 'col': 2, 'label': 'A'},
            {'id': 'b', 'row': 1, 'col': 2, 'label': 'B'},
          ],
          'must_visit': <String>[],
        }),
        contains('unique'),
      );
      expect(reason({...grid, 'directions': 'diagonal'}), contains('arrows'));
    });
  });

  group('judging a route', () {
    test('any route that follows the rules is right', () {
      final c = parsed(grid);
      final short = ['right', 'right', 'down', 'down', 'down', 'right'];
      final long = [
        'right',
        'right',
        'right',
        'down',
        'left',
        'down',
        'right',
        'down',
      ];
      for (final route in [short, long]) {
        final r = evaluator.evaluate(c, OrderingAnswer(route), ctx);
        expect(r.outcome, Outcome.correct, reason: '$route');
      }
    });

    test('each broken rule is its own item', () {
      final c = parsed(grid);
      // Down the left side: reaches the goal but skips the park.
      final skip = evaluator.evaluate(
        c,
        OrderingAnswer(['down', 'down', 'down', 'right', 'right', 'right']),
        ctx,
      );
      expect(skip.outcome, Outcome.incorrect);
      expect(skip.itemResults, {
        'goal': true,
        'moves': true,
        'visit:parc': false,
      });
      // Into the wall.
      final bump = evaluator.evaluate(
        c,
        OrderingAnswer(['down', 'right']),
        ctx,
      );
      expect(bump.itemResults['goal'], isFalse);
      expect(c.walk(['down', 'right']).bumped, isTrue);
      expect(bump.evaluator, 'path_planner.exact@1');
    });
  });

  group('reduce', () {
    test('a live route refuses a bump; removing a step works', () {
      final c = parsed(grid);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const AddPathMove('down')).state;
      expect(PathPlannerEngine.canAdd(c, s, 'right'), isFalse);
      expect(PathPlannerEngine.canAdd(c, s, 'down'), isTrue);
      s = engine.reduce(s, const AddPathMove('down')).state;
      expect(engine.reduce(s, const AddPathMove('right')).state.program, [
        'down',
        'down',
      ]);
      s = engine.reduce(s, const RemovePathMove(0)).state;
      expect(s.program, ['down']);
      s = engine.reduce(s, const RemovePathMove(-1)).state;
      expect(s.program, isEmpty);
    });

    test('a blind route accepts a bump, and is walked once checked', () {
      final c = parsed({...grid, 'show_path': false});
      var s = engine.initialize(c, const EngineSeed(1));
      expect(PathPlannerEngine.canAdd(c, s, 'up'), isTrue);
      s = engine.reduce(s, const AddPathMove('up')).state;
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      s = engine.applyFeedback(s, r);
      expect(s.revealed, isTrue);
      expect(s.program, ['up']);
      s = engine.reduce(s, const AddPathMove('right')).state;
      expect(s.revealed, isFalse);
    });

    test('snapshot round-trips and refuses a false "solved"', () {
      final c = parsed(grid);
      final s = PathState(
        content: c,
        program: const ['right', 'down'],
        revealed: true,
      );
      expect(engine.restore(c, engine.snapshot(s))!.program, ['right', 'down']);
      expect(
        engine.restore(c, {...engine.snapshot(s), 'solved': true}),
        isNull,
      );
      expect(
        engine.restore(c, {
          'program': ['jump'],
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('arrow keys walk Foxy, a skipped landmark, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(grid);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('path-foxy')), findsOne);

      for (final m in ['down', 'down', 'down', 'right', 'right', 'right']) {
        await tester.tap(find.byKey(ValueKey('path-move-$m')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      // Clear it with Backspace, then go the right way with the keyboard.
      await tester.tap(find.byKey(const ValueKey('path-board')));
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      }
      await settle(tester);
      expect((c.current!.state as PathState).program, isEmpty);
      for (final k in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(k);
      }
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

    testWidgets('a 7×7 cardinal grid fits a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'rows': 7,
        'cols': 7,
        'start': {'row': 6, 'col': 0},
        'goal': {'row': 0, 'col': 6},
        'directions': 'cardinal',
        'landmarks': [
          {'id': 'b', 'row': 3, 'col': 3, 'label': 'Bibliothèque'},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('N'), findsOne);
      expect(find.text('O'), findsOne);
      c.dispose();
    });
  });
}
