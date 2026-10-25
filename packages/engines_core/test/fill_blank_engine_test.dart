import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend sample's three questions.
const article = <String, Object?>{
  'text': '{b1} chat dort sur {b2} lit.',
  'tiles': [
    {'id': 'le', 'label': 'Le'},
    {'id': 'la', 'label': 'La'},
    {'id': 'le_min', 'label': 'le'},
    {'id': 'la_min', 'label': 'la'},
  ],
  'blanks': [
    {'id': 'b1', 'answer': 'le'},
    {'id': 'b2', 'answer': 'le_min'},
  ],
  'shuffle': false,
};

const missingTerm = <String, Object?>{
  'text': '4 + {b1} = 7',
  'tiles': [
    {'id': 't3', 'label': '3'},
    {'id': 't11', 'label': '11'},
    {'id': 't4', 'label': '4'},
  ],
  'blanks': [
    {'id': 'b1', 'answer': 't3'},
  ],
};

const either = <String, Object?>{
  'text': '{a} + {b} = 7',
  'tiles': [
    {'id': 't3', 'label': '3'},
    {'id': 't4', 'label': '4'},
    {'id': 't5', 'label': '5'},
  ],
  'blanks': [
    {
      'id': 'a',
      'answer': ['t3', 't4'],
    },
    {
      'id': 'b',
      'answer': ['t3', 't4'],
    },
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'fill_blank',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Complète la phrase.'},
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
      engines: LearningEngineRegistry([eraseEngine(const FillBlankEngine())]),
      evaluators: EvaluatorRegistry(const [FillBlankEvaluator()]),
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

ClozeContent parsed(Map<String, Object?> config) =>
    const FillBlankEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const FillBlankEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = FillBlankEngine();

  group('parse', () {
    test('splits the text at its markers', () {
      final c = parsed(article);
      expect(c.blanks, ['b1', 'b2']);
      expect(c.pieces.first, isA<ClozeGap>());
      expect((c.pieces[1] as ClozeText).text, ' chat dort sur ');
      expect(c.accepted['b2'], {'le_min'});
      expect(parsed(either).accepted['a'], {'t3', 't4'});
    });

    test('rejects what cannot be played', () {
      expect(reason({...article, 'text': 'Pas de trou.'}), contains('1 to 4'));
      expect(
        reason({...article, 'text': '{b1} et {b1}'}),
        contains('appears once'),
      );
      expect(
        reason({
          ...article,
          'blanks': [
            {'id': 'b1', 'answer': 'le'},
          ],
        }),
        contains('every blank a {marker}'),
      );
      expect(
        reason({
          ...article,
          'blanks': [
            {'id': 'b1', 'answer': 'le'},
            {'id': 'b2', 'answer': 'zz'},
          ],
        }),
        contains('must be a tile'),
      );
      expect(
        reason({
          ...article,
          'blanks': [
            {'id': 'b1', 'answer': 'le'},
            {'id': 'b2', 'answer': 'le'},
          ],
        }),
        contains('set reuse: true'),
      );
      expect(
        parsed({
          ...article,
          'reuse': true,
          'blanks': [
            {'id': 'b1', 'answer': 'le'},
            {'id': 'b2', 'answer': 'le'},
          ],
        }).reuse,
        isTrue,
      );
      expect(
        reason({
          'text': '{a} {b}',
          'tiles': [
            {'id': 'x', 'label': 'x'},
            {'id': 'y', 'label': 'y'},
          ],
          'blanks': [
            {'id': 'a', 'answer': 'x'},
            {'id': 'b', 'answer': 'y'},
          ],
        }),
        contains('more tiles than blanks'),
      );
    });
  });

  group('reduce', () {
    test('a tile goes into the first open blank, then the next', () {
      var s = engine.initialize(parsed(article), const EngineSeed(1));
      s = engine.reduce(s, const TapClozeTile('le')).state;
      s = engine.reduce(s, const TapClozeTile('la_min')).state;
      expect(s.filled, {'b1': 'le', 'b2': 'la_min'});
      expect(engine.extractAnswer(s)!.blanks, {'b1': 'le', 'b2': 'la_min'});
    });

    test('tapping a blank targets it; tapping a filled one empties it', () {
      var s = engine.initialize(parsed(article), const EngineSeed(1));
      s = engine.reduce(s, const TapBlank('b2')).state;
      s = engine.reduce(s, const TapClozeTile('le_min')).state;
      expect(s.filled, {'b2': 'le_min'});
      final emptied = engine.reduce(s, const TapBlank('b2'));
      expect(emptied.state.filled, isEmpty);
      expect(emptied.state.active, 'b2');
      expect(engine.extractAnswer(emptied.state), isNull);
    });

    test('without reuse, taking a used tile moves it', () {
      var s = engine.initialize(parsed(article), const EngineSeed(1));
      s = engine.reduce(s, const TapClozeTile('le')).state;
      s = engine.reduce(s, const TapBlank('b2')).state;
      s = engine.reduce(s, const TapClozeTile('le')).state;
      expect(s.filled, {'b2': 'le'});
    });
  });

  group('FillBlankEvaluator and feedback', () {
    const evaluator = FillBlankEvaluator();

    test('partial credit; right blanks lock, a wrong one empties', () {
      final c = parsed(article);
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapClozeTile('le')).state;
      s = engine.reduce(s, const TapClozeTile('la_min')).state;
      final result = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(result.outcome, Outcome.partial);
      expect(result.score, 0.5);
      expect(result.evaluator, 'fill_blank.exact@1');
      s = engine.applyFeedback(s, result);
      expect(s.locked, {'b1'});
      expect(s.filled, {'b1': 'le'});
      // The same wrong tile can't go back into that blank.
      expect(engine.reduce(s, const TapClozeTile('la_min')).state.filled, {
        'b1': 'le',
      });
    });

    test('either accepted tile is right', () {
      final c = parsed(either);
      expect(
        evaluator
            .evaluate(c, BlanksAnswer({'a': 't4', 'b': 't3'}), ctx)
            .outcome,
        Outcome.correct,
      );
      expect(
        evaluator.evaluate(c, BlanksAnswer({'a': 't5', 'b': 't3'}), ctx).score,
        0.5,
      );
    });
  });

  group('snapshot', () {
    test('round-trips, and rejects a locked wrong tile', () {
      final c = parsed(article);
      final s = engine
          .initialize(c, const EngineSeed(1))
          .copyWith(filled: {'b1': 'le'}, locked: {'b1'}, active: 'b2');
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.filled, {'b1': 'le'});
      expect(back.active, 'b2');
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'filled': {'b1': 'la'},
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('missing term: wrong, then right', (tester) async {
      tallView(tester);
      final (c, outbox) = controllerFor(missingTerm);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('='), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cloze-tile-t11')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect((c.current!.state as ClozeState).tried, {'t11|b1'});

      await tester.tap(find.byKey(const ValueKey('cloze-tile-t3')));
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

    testWidgets('a placed tile leaves the bank and shows in its blank', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(article);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(
        find.bySemanticsLabel(RegExp('trou 1, vide, à remplir')),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('cloze-tile-le')));
      await settle(tester);
      expect(find.byKey(const ValueKey('cloze-tile-le')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('blank-b1')),
          matching: find.text('Le'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('trou 2, vide, à remplir')),
        findsOne,
      );
      c.dispose();
    });

    testWidgets('a long sentence wraps on a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'text':
            'Le matin, avant de partir pour {b1} école, Léa met son '
            'manteau, sa tuque et ses {b2} parce qu’il fait froid.',
        'tiles': [
          for (final w in ['l’', 'la', 'mitaines', 'lunettes', 'le'])
            {'id': w.replaceAll('’', ''), 'label': w},
        ],
        'blanks': [
          {'id': 'b1', 'answer': 'l'},
          {'id': 'b2', 'answer': 'mitaines'},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
