import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_shelf.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

/// Invent mode (ADR 0096): the child makes the pattern.
const invent = <String, Object?>{
  'task': 'invent',
  'palette': [
    {'id': 'a', 'shape': 'circle', 'color': 'red'},
    {'id': 'b', 'shape': 'square', 'color': 'blue'},
    {'id': 'c', 'shape': 'triangle', 'color': 'yellow'},
  ],
  'slots': 6,
};

void main() {
  const engine = PatternMachineEngine();
  const evaluator = PatternMachineEvaluator();
  PatternContent parsed(Map<String, Object?> c) => engine.parse(c).valueOrNull!;
  String? reason(Map<String, Object?> c) => switch (engine.parse(c)) {
    ParseInvalid(:final reason) => reason,
    _ => null,
  };
  EvaluationResult grade(Map<String, Object?> config, String strip) {
    final c = parsed(config);
    return evaluator.evaluate(
      c,
      BlanksAnswer({
        for (var i = 0; i < strip.length; i++)
          PatternContent.gapId(i): strip[i],
      }),
      ctx,
    );
  }

  group('parse', () {
    test('an invent strip: every cell a gap, the palette the choices', () {
      final c = parsed(invent);
      expect((c.invent, c.slots, c.length), (true, 6, 6));
      expect(c.gaps, ['g0', 'g1', 'g2', 'g3', 'g4', 'g5']);
      expect(c.choices.map((x) => x.id), ['a', 'b', 'c']);
    });

    test('refuses what an invent strip cannot be', () {
      expect(
        reason({...invent, 'task': 'draw'}),
        contains('continue or invent'),
      );
      expect(
        reason({
          ...invent,
          'hidden': [0],
        }),
        contains('task continue'),
      );
      expect(reason({...invent, 'slots': 3}), contains('4 to 12'));
      expect(reason({...invent, 'core': 4}), contains('fits twice'));
      expect(reason({...invent, 'core': 1}), contains('fits twice'));
      expect(
        reason({
          ...invent,
          'palette': [
            {'id': 'a', 'shape': 'circle', 'color': 'red'},
            {'id': 'b', 'shape': 'square', 'color': 'red'},
          ],
          'vary': ['color'],
        }),
        contains('two colors'),
      );
      expect(reason({...invent, 'palette': <Object>[]}), startsWith('palette'));
    });

    test('the continue task is unchanged by default', () {
      expect(
        engine.parse({
          'sequence': [
            {'shape': 'circle'},
            {'shape': 'square'},
            {'shape': 'circle'},
            {'shape': 'square'},
          ],
          'hidden': [3],
          'choices': [
            {'id': 's', 'shape': 'square'},
            {'id': 't', 'shape': 'triangle'},
          ],
        }),
        isA<ParseOk<PatternContent>>(),
      );
    });
  });

  group('evaluate: any strip that repeats a core of 2+ at least twice', () {
    test('a core of 2 or 3 repeating is a pattern', () {
      expect(grade(invent, 'ababab').outcome, Outcome.correct);
      expect(grade(invent, 'abcabc').outcome, Outcome.correct);
      // A core may repeat a piece inside it.
      expect(grade(invent, 'aabaab').outcome, Outcome.correct);
    });

    test('a core of 1 is not a pattern to see', () {
      final r = grade(invent, 'aaaaaa');
      expect((r.outcome, r.feedbackCode), (Outcome.incorrect, 'no_repeat'));
    });

    test('a partial last repeat is fine', () {
      expect(grade({...invent, 'slots': 5}, 'ababa').outcome, Outcome.correct);
      expect(
        grade({...invent, 'slots': 7}, 'abcabca').outcome,
        Outcome.correct,
      );
    });

    test('too short: the core must fit twice', () {
      final r = grade({...invent, 'slots': 5}, 'abcab');
      expect((r.outcome, r.feedbackCode), (Outcome.incorrect, 'no_repeat'));
      expect(grade(invent, 'abcbca').feedbackCode, 'no_repeat');
    });

    test('rotations: whichever piece the core starts on', () {
      for (final strip in ['abcabc', 'bcabca', 'cabcab']) {
        expect(grade(invent, strip).outcome, Outcome.correct, reason: strip);
      }
      expect(PatternMachineEvaluator.periodOf('bcabca'.split('')), 3);
    });

    test('an asked core size and variety', () {
      final r = grade({...invent, 'core': 3}, 'ababab');
      expect((r.outcome, r.feedbackCode), (Outcome.incorrect, 'core_size'));
      expect(grade({...invent, 'core': 3}, 'abcabc').outcome, Outcome.correct);

      final shapesOnly = {
        ...invent,
        'palette': [
          {'id': 'a', 'shape': 'circle', 'color': 'red'},
          {'id': 'b', 'shape': 'square', 'color': 'red'},
          {'id': 'c', 'shape': 'square', 'color': 'blue'},
        ],
        'vary': ['shape', 'color'],
      };
      // a b: two shapes, one colour.
      expect(grade(shapesOnly, 'ababab').feedbackCode, 'vary');
      // a c: two shapes and two colours.
      expect(grade(shapesOnly, 'acacac').outcome, Outcome.correct);
    });

    test(
      'a miss empties the strip and marks it amber (N11); Recommencer clears',
      () {
        final c = parsed(invent);
        var s = engine.initialize(c, const EngineSeed(1));
        for (final id in 'aaaaaa'.split('')) {
          s = engine.reduce(s, TapPatternChoice(id)).state;
        }
        final miss = engine.applyFeedback(
          s,
          evaluator.evaluate(c, engine.extractAnswer(s)!, ctx),
        );
        // The strip is empty again, so the stamps work; the refused strip
        // shows in amber until the next tap.
        expect(miss.filled, isEmpty);
        expect(miss.missed, hasLength(6));
        expect(miss.locked, isEmpty);
        final next = engine.reduce(miss, const TapPatternChoice('b')).state;
        expect(next.missed, isEmpty);
        expect(next.filled, {'g0': 'b'});
        // Recommencer empties every cell.
        expect(
          engine.reduce(next, const ClearPatternStrip()).state.filled,
          isEmpty,
        );
      },
    );
  });

  testWidgets('N16: empty cells and stamps have a 3:1 edge', (tester) async {
    final c = parsed(invent);
    final s = engine.initialize(c, const EngineSeed(1));
    await tester.pumpWidget(
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: Builder(
            builder: (context) => engine.buildView(
              context,
              EngineView(
                content: c,
                state: s,
                dispatch: (_) {},
                locale: fr,
                enabled: true,
              ),
            ),
          ),
        ),
      ),
    );
    // g0 is the target (highlighted blue); g1 is a plain empty cell.
    for (final key in ['pattern-gap-g1', 'pattern-choice-a']) {
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Material),
            )
            .first,
      );
      final side = (material.shape! as RoundedRectangleBorder).side.color;
      expect(side, VillagePalette.light.inkMuted, reason: key);
    }
  });

  testWidgets('in the shell: a hand on the palette, a miss, then kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shelf = FakeShelf();
    final c = ActivitySessionController(
      envelope: QuestionEnvelope.parse({
        'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
        'version': 1,
        'content_hash': 'h',
        'engine_key': 'pattern_machine',
        'engine_min_version': 1,
        'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
        'subject': 'MATH',
        'grade': 1,
        'rank': 0,
        'prompt': {'text': 'Invente ta suite.'},
        'config': {...invent, 'creation': true},
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
      CreationShelfScope(
        shelf: shelf,
        child: MaterialApp(
          theme: TutolysTheme.village(),
          home: Scaffold(
            body: LearningActivityView(
              controller: c,
              locale: fr,
              onDone: () {},
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.pump();
    }

    expect(find.text('Touche une forme pour remplir la case.'), findsOneWidget);
    await tester.pump(IdleHandHint.wait + const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('idle-hand')), findsOneWidget);

    Future<void> stamp(String ids) async {
      for (final id in ids.split('')) {
        await tester.tap(find.byKey(ValueKey('pattern-choice-$id')));
        await settle();
      }
    }

    await stamp('abcbca');
    await tester.tap(find.text('VALIDER'));
    await settle();
    expect(find.text('Presque !'), findsOneWidget);
    expect(find.text('Ta suite ne se répète pas encore.'), findsOneWidget);
    // N11: the stamps work again straight away (the board is the retry).
    await stamp('abcab');
    expect(find.text('Presque !'), findsNothing);
    // Each filled cell shows it can be emptied, and Recommencer is there.
    expect(find.byKey(const ValueKey('pattern-cell-remove')), findsNWidgets(5));
    expect(find.text('Touche une case pour l’enlever.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pattern-clear')));
    await settle();
    expect((c.current!.state as PatternState).filled, isEmpty);
    await stamp('abcabc');
    await tester.tap(find.text('VALIDER'));
    await settle();
    expect(find.text('Bravo !'), findsOneWidget);
    expect(find.text('Quelle belle création !'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creation-keep')));
    await settle();
    final pieces = shelf.items.single.payload['pieces']! as List;
    expect(pieces, hasLength(6));
    expect((pieces.first as Map)['shape'], 'circle');
    expect(tester.takeException(), isNull);
    c.dispose();
  });
}
