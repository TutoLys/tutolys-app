import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const redCircle = {'shape': 'circle', 'color': 'red'};
const blueSquare = {'shape': 'square', 'color': 'blue'};

// A B A B A _ : what comes next.
const next = <String, Object?>{
  'sequence': [
    redCircle,
    blueSquare,
    redCircle,
    blueSquare,
    redCircle,
    blueSquare,
  ],
  'hidden': [5],
  'choices': [
    {'id': 'c', ...redCircle},
    {'id': 's', ...blueSquare},
    {'id': 't', 'shape': 'triangle', 'color': 'yellow'},
  ],
  'shuffle': false,
};

// 2 4 _ 8 _ : a numeric regularity with two gaps.
const evens = <String, Object?>{
  'sequence': [
    {'text': '2'},
    {'text': '4'},
    {'text': '6'},
    {'text': '8'},
    {'text': '10'},
  ],
  'hidden': [2, 4],
  'choices': [
    {'id': 'six', 'text': '6'},
    {'id': 'ten', 'text': '10'},
    {'id': 'nine', 'text': '9'},
  ],
  'continues': false,
};

// A A B A A _ _ : the same answer twice — a choice is a stamp.
const twice = <String, Object?>{
  'sequence': [
    redCircle,
    redCircle,
    blueSquare,
    redCircle,
    redCircle,
    blueSquare,
    redCircle,
  ],
  'hidden': [5, 6],
  'choices': [
    {'id': 'c', ...redCircle},
    {'id': 's', ...blueSquare},
    {'id': 'big', 'shape': 'circle', 'color': 'red', 'size': 'l'},
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'pattern_machine',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Qu’est-ce qui suit ?'},
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
        eraseEngine(const PatternMachineEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [PatternMachineEvaluator()]),
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

PatternContent parsed(Map<String, Object?> config) =>
    const PatternMachineEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const PatternMachineEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = PatternMachineEngine();
  const evaluator = PatternMachineEvaluator();

  group('PatternPiece', () {
    test('defaults, keys and equality', () {
      final a = PatternPiece.fromJson({'shape': 'star'})!;
      expect(a.color, PatternColor.blue);
      expect(a.size, PatternSize.medium);
      expect(a.key, 's:star:blue:medium:0');
      expect(
        PatternPiece.fromJson({'shape': 'star', 'color': 'blue', 'size': 'm'})!
            .key,
        a.key,
      );
      expect(PatternPiece.fromJson({'text': '7'})!.key, 't:7');
    });

    test('rejects what it cannot draw', () {
      expect(PatternPiece.fromJson({'shape': 'moon'}), isNull);
      expect(PatternPiece.fromJson({'shape': 'star', 'turn': 45}), isNull);
      expect(PatternPiece.fromJson({'shape': 'star', 'color': 'grey'}), isNull);
      expect(PatternPiece.fromJson({'text': 'trop long'}), isNull);
      expect(PatternPiece.fromJson({'text': '1', 'shape': 'star'}), isNull);
    });

    test('describes itself in French and English', () {
      String fr(Map<String, Object?> j) =>
          PatternPiece.fromJson(j)!.describe(const Locale('fr'));
      String en(Map<String, Object?> j) =>
          PatternPiece.fromJson(j)!.describe(const Locale('en'));
      expect(fr({'shape': 'triangle', 'size': 's'}), 'petit triangle bleu');
      expect(
        fr({'shape': 'star', 'color': 'green', 'size': 'l'}),
        'grande étoile verte',
      );
      expect(
        fr({'shape': 'arrow', 'color': 'purple', 'turn': 90}),
        'flèche violette vers la droite',
      );
      expect(
        fr({'shape': 'triangle', 'turn': 180}),
        'triangle bleu à l’envers',
      );
      expect(en({'shape': 'arrow', 'turn': 180}), 'blue arrow pointing down');
      expect(
        en({'shape': 'heart', 'color': 'pink', 'size': 'l'}),
        'big pink heart',
      );
    });
  });

  group('parse', () {
    test('reads gaps and their expected pieces', () {
      final c = parsed(evens);
      expect(c.gaps, ['g2', 'g4']);
      expect(c.expected('g4')!.key, 't:10');
      expect(c.expected('g1'), isNull);
      expect(c.continues, isFalse);
      expect(parsed(next).continues, isTrue);
    });

    test('rejects what cannot be played', () {
      expect(
        reason({
          ...next,
          'sequence': [redCircle, blueSquare, redCircle],
        }),
        contains('4 to 12'),
      );
      expect(reason({...next, 'hidden': <int>[]}), contains('1 to 3'));
      expect(
        reason({
          ...next,
          'hidden': [6],
        }),
        contains('inside the sequence'),
      );
      expect(
        reason({
          ...next,
          'hidden': [2, 2],
        }),
        contains('distinct'),
      );
      expect(
        reason({
          ...evens,
          'hidden': [1, 2, 4],
        }),
        contains('At least 3 terms'),
      );
      expect(
        reason({
          ...next,
          'choices': [
            {'id': 'c', ...redCircle},
            {'id': 't', 'shape': 'triangle'},
          ],
        }),
        contains('must be one of the choices'),
      );
      expect(
        reason({
          ...next,
          'choices': [
            {'id': 'a', ...redCircle},
            {'id': 'b', ...redCircle},
            {'id': 's', ...blueSquare},
          ],
        }),
        contains('same piece'),
      );
      expect(
        reason({
          ...twice,
          'choices': [
            {'id': 'c', ...redCircle},
          ],
        }),
        contains('2 to 6'),
      );
      expect(
        reason({
          ...evens,
          'choices': [
            {'id': 'six', 'text': '6'},
            {'id': 'ten', 'text': '10'},
          ],
        }),
        contains('a wrong choice'),
      );
    });
  });

  group('reduce and evaluate', () {
    test('a choice is a stamp: the same one fills two gaps', () {
      final c = parsed(twice);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapPatternChoice('c')).state;
      s = engine.reduce(s, const TapPatternChoice('c')).state;
      expect(s.filled, {'g5': 'c', 'g6': 'c'});
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.partial);
      expect(r.itemResults, {'g5': false, 'g6': true});
      expect(r.evaluator, 'pattern_machine.exact@1');
    });

    test(
      'a wrong gap empties, the right one locks, the miss is remembered',
      () {
        final c = parsed(twice);
        var s = engine.initialize(c, const EngineSeed(1));
        s = engine.reduce(s, const TapPatternChoice('big')).state;
        s = engine.reduce(s, const TapPatternChoice('c')).state;
        final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
        expect(r.score, 0.5);
        s = engine.applyFeedback(s, r);
        expect(s.locked, {'g6'});
        expect(s.filled, {'g6': 'c'});
        expect(s.tried, {'big|g5'});
        expect(engine.reduce(s, const TapPatternChoice('big')).state.filled, {
          'g6': 'c',
        });
        s = engine.reduce(s, const TapPatternChoice('s')).state;
        expect(
          evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
          Outcome.correct,
        );
      },
    );

    test('tapping a gap targets it; tapping a filled one empties it', () {
      final c = parsed(evens);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapPatternGap('g4')).state;
      s = engine.reduce(s, const TapPatternChoice('ten')).state;
      expect(s.filled, {'g4': 'ten'});
      final emptied = engine.reduce(s, const TapPatternGap('g4'));
      expect(emptied.state.filled, isEmpty);
      expect(emptied.events.single.type, 'item_removed');
      expect(engine.extractAnswer(emptied.state), isNull);
    });

    test('snapshot round-trips and rejects a locked wrong piece', () {
      final c = parsed(evens);
      final s = engine
          .initialize(c, const EngineSeed(1))
          .copyWith(filled: {'g2': 'six'}, locked: {'g2'}, active: 'g4');
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.filled, {'g2': 'six'});
      expect(back.active, 'g4');
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'filled': {'g2': 'nine'},
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('what comes next: wrong, then right', (tester) async {
      tallView(tester);
      final (c, outbox) = controllerFor(next);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('…'), findsOneWidget);
      expect(find.bySemanticsLabel('cercle rouge'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('pattern-choice-t')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect((c.current!.state as PatternState).tried, {'t|g5'});

      await tester.tap(find.byKey(const ValueKey('pattern-choice-s')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .map((e) => e['is_correct']);
      expect(attempts, [false, true]);
      c.dispose();
    });

    testWidgets('twelve terms fit a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'sequence': [
          for (var i = 0; i < 12; i++)
            {'shape': 'arrow', 'color': 'orange', 'turn': (i % 4) * 90},
        ],
        'hidden': [10, 11],
        'choices': [
          for (final t in [0, 90, 180, 270])
            {'id': 'a$t', 'shape': 'arrow', 'color': 'orange', 'turn': t},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('case 1, vide, à remplir')),
        findsOne,
      );
      c.dispose();
    });
  });
}
