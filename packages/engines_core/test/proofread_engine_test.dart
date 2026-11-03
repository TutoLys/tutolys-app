import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);
const engine = ProofreadEngine();
const evaluator = ProofreadEvaluator();
const keep = ProofreadEngine.keep;

// « Les chat dorment. Ils mange une pomme. »
final draft = <String, Object?>{
  'character': 'lea',
  'sentences': [
    {
      'tokens': [
        {'id': 'les', 'text': 'Les'},
        {
          'id': 'chat',
          'text': 'chat',
          'fix': 'chats',
          'options': ['chats', 'chates'],
        },
        {'id': 'dorment', 'text': 'dorment'},
        {'id': 'p1', 'text': '.'},
      ],
    },
    {
      'tokens': [
        {'id': 'ils', 'text': 'Ils'},
        {
          'id': 'mange',
          'text': 'mange',
          'fix': 'mangent',
          'options': ['mangent', 'manges'],
        },
        {'id': 'une', 'text': 'une'},
        {'id': 'pomme', 'text': 'pomme'},
        {'id': 'p2', 'text': '.'},
      ],
    },
  ],
  'passes': [
    {
      'id': 'gn',
      'say': 'Je vérifie les accords dans le GN.',
      'targets': ['les', 'chat'],
    },
    {
      'id': 'verbes',
      'say': 'Je vérifie la finale des verbes.',
      'targets': ['dorment', 'mange'],
    },
  ],
  'hint': 'Les verbes s’accordent avec leur sujet.',
};

ProofContent parsed(Map<String, Object?> c) => engine.parse(c).valueOrNull!;

ProofState run(ProofState s, List<ProofAction> actions) {
  for (final a in actions) {
    s = engine.reduce(s, a).state;
  }
  return s;
}

List<ProofAction> decide(String token, String choice) => [
  OpenProofToken(token),
  ChooseProof(token, choice),
];

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'proofread',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 3,
  'rank': 0,
  'prompt': {'text': 'Aide Léa à corriger son texte.'},
  'config': config,
};

void main() {
  final c = parsed(draft);
  final s0 = engine.initialize(c, const EngineSeed(1));

  group('parse', () {
    test('the sample shape parses', () {
      expect(c.character.key, 'lea');
      expect(c.targets, ['les', 'chat', 'dorment', 'mange']);
      expect(c.right('chat'), 'chats');
      expect(c.right('les'), keep);
    });

    Map<String, Object?> without(String token) => {
      ...draft,
      'passes': [
        {
          'id': 'gn',
          'say': 'x',
          'targets': [token],
        },
      ],
    };

    for (final (why, bad) in <(String, Map<String, Object?>)>[
      ('a mistake no pass reaches', without('les')),
      ('an unknown character', {...draft, 'character': 'zorro'}),
      (
        'a word in two passes',
        {
          ...draft,
          'passes': [
            {
              'id': 'a',
              'say': 'x',
              'targets': ['chat', 'mange'],
            },
            {
              'id': 'b',
              'say': 'y',
              'targets': ['chat'],
            },
          ],
        },
      ),
      (
        'a fix that is not among the options',
        {
          ...draft,
          'sentences': [
            {
              'tokens': [
                {
                  'id': 'chat',
                  'text': 'chat',
                  'fix': 'chats',
                  'options': ['chates'],
                },
              ],
            },
          ],
          'passes': [
            {
              'id': 'a',
              'say': 'x',
              'targets': ['chat'],
            },
          ],
        },
      ),
      (
        'a draft with no mistake',
        {
          ...draft,
          'sentences': [
            {
              'tokens': [
                {'id': 'ok', 'text': 'Bonjour'},
              ],
            },
          ],
          'passes': [
            {
              'id': 'a',
              'say': 'x',
              'targets': ['ok'],
            },
          ],
        },
      ),
    ]) {
      test('refuses $why', () {
        expect(engine.parse(bad), isA<ParseInvalid<ProofContent>>());
      });
    }
  });

  group('reduce', () {
    test('only this step\'s words open', () {
      expect(engine.reduce(s0, const OpenProofToken('mange')).state, s0);
      expect(
        engine.reduce(s0, const OpenProofToken('chat')).state.open,
        'chat',
      );
    });

    test('the next step waits for every word of this one, and reveals', () {
      final half = run(s0, decide('chat', 'chats'));
      expect(engine.reduce(half, const NextProofPass()).state.pass, 0);
      final done = run(half, decide('les', keep));
      final t = engine.reduce(done, const NextProofPass());
      expect(t.state.pass, 1);
      expect(t.events.single, isA<RevealEvent>());
      expect(engine.extractAnswer(done), isNull, reason: 'not the last step');
    });

    test('every word right: correct', () {
      final s = run(s0, [
        ...decide('les', keep),
        ...decide('chat', 'chats'),
        const NextProofPass(),
        ...decide('dorment', keep),
        ...decide('mange', 'mangent'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
    });

    test('a missed mistake and a false alarm are items; back to step 1', () {
      final s = run(s0, [
        ...decide('les', keep),
        // Missed: « chat » kept.
        ...decide('chat', keep),
        const NextProofPass(),
        // False alarm on a right verb.
        ...decide('dorment', 'dorment'),
      ]);
      // « dorment » has no options, so that choice doesn't exist.
      expect(s.choice.containsKey('dorment'), isFalse);
      final s2 = run(s, [
        ...decide('dorment', keep),
        ...decide('mange', 'manges'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s2)!, ctx);
      expect(r.itemResults, {
        'les': true,
        'chat': false,
        'dorment': true,
        'mange': false,
      });
      final after = engine.applyFeedback(s2, r);
      expect(after.pass, 0, reason: '« chat » is still wrong');
      expect(after.locked, {'les', 'dorment'});
      expect(
        run(after, decide('chat', keep)).choice.containsKey('chat'),
        isFalse,
        reason: 'the same wrong choice twice',
      );
    });

    test('a snapshot round-trips', () {
      final s = run(s0, [
        ...decide('chat', 'chates'),
        const OpenProofToken('les'),
      ]);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(engine.snapshot(back), engine.snapshot(s));
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'choice': {'chat': 'chiens'},
        }),
        isNull,
      );
    });
  });

  testWidgets('in the shell: two steps, then Bravo', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(draft)).valueOrNull!,
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
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.pump();
    }

    expect(find.text('Le brouillon de Léa'), findsOneWidget);
    expect(find.textContaining('Étape 1 sur 2'), findsOneWidget);
    await tap('proof-token-les');
    await tap('proof-choice-les-keep');
    await tap('proof-token-chat');
    await tap('proof-choice-chat-chats');
    await tap('proof-next');
    expect(find.textContaining('Étape 2 sur 2'), findsOneWidget);
    await tap('proof-token-dorment');
    await tap('proof-choice-dorment-keep');
    await tap('proof-token-mange');
    await tap('proof-choice-mange-mangent');
    await tester.tap(find.text('VALIDER'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(find.text('Bravo !'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
