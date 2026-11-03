import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);
const engine = PhraseLabEngine();
const evaluator = PhraseLabEvaluator();

List<Map<String, String>> words(String sentence) => [
  for (final (i, w) in sentence.split(' ').indexed) {'id': 'w$i', 'text': w},
];

// « Le petit chat | dort sur le lit | ce matin . »
final groupCfg = <String, Object?>{
  'task': 'group',
  'tokens': words('Le petit chat dort sur le lit ce matin .'),
  'labels': [
    {'id': 'sujet', 'label': 'Sujet'},
    {'id': 'predicat', 'label': 'Prédicat'},
    {'id': 'cp', 'label': 'Complément de phrase'},
  ],
  'groups': [
    {'id': 'g1', 'from': 'w0', 'to': 'w2', 'label': 'sujet'},
    {'id': 'g2', 'from': 'w3', 'to': 'w6', 'label': 'predicat'},
    {'id': 'g3', 'from': 'w7', 'to': 'w8', 'label': 'cp'},
  ],
  'hint': 'Le sujet, c’est qui fait l’action.',
};

final testCfg = <String, Object?>{
  'task': 'test',
  'tokens': words('Ce matin , le chat dort .'),
  'labels': [
    {'id': 'sujet', 'label': 'Sujet'},
    {'id': 'cp', 'label': 'Complément de phrase'},
  ],
  'group': {'from': 'w0', 'to': 'w1'},
  'tests': [
    {'id': 'del', 'op': 'delete', 'result': 'Le chat dort.', 'ok': true},
    {'id': 'mov', 'op': 'move', 'result': 'Le chat dort ce matin.', 'ok': true},
  ],
  'conclusion': {
    'options': ['sujet', 'cp'],
    'correct': 'cp',
  },
};

PhraseContent parsed(Map<String, Object?> c) => engine.parse(c).valueOrNull!;

PhraseState run(PhraseState s, List<PhraseAction> actions) {
  for (final a in actions) {
    s = engine.reduce(s, a).state;
  }
  return s;
}

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'phrase_lab',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 3,
  'rank': 0,
  'prompt': {'text': 'Encadre les groupes de la phrase.'},
  'config': config,
};

ActivitySessionController controllerFor(Map<String, Object?> config) =>
    ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(config)).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([eraseEngine(engine)]),
      evaluators: EvaluatorRegistry(const [evaluator]),
      store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
      appVersion: '0.2.0',
      seed: 3,
    );

Widget app(ActivitySessionController c) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
  ),
);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

void main() {
  group('parse', () {
    test('both sample shapes parse; groups come out in reading order', () {
      final c = parsed({
        ...groupCfg,
        'groups': [...(groupCfg['groups']! as List)].reversed.toList(),
      });
      expect(c.groups.map((g) => g.id), ['g1', 'g2', 'g3']);
      expect(c.text(c.groups.first.span), 'Le petit chat');
      expect(parsed(testCfg).tests.length, 2);
    });

    for (final (why, bad) in <(String, Map<String, Object?>)>[
      (
        'overlapping groups',
        {
          ...groupCfg,
          'groups': [
            {'id': 'a', 'from': 'w0', 'to': 'w3', 'label': 'sujet'},
            {'id': 'b', 'from': 'w2', 'to': 'w6', 'label': 'predicat'},
          ],
        },
      ),
      (
        'backwards group',
        {
          ...groupCfg,
          'groups': [
            {'id': 'a', 'from': 'w3', 'to': 'w0', 'label': 'sujet'},
          ],
        },
      ),
      (
        'label not in the tray',
        {
          ...groupCfg,
          'groups': [
            {'id': 'a', 'from': 'w0', 'to': 'w2', 'label': 'gn'},
          ],
        },
      ),
      (
        'unknown op',
        {
          ...testCfg,
          'tests': [
            {'id': 'x', 'op': 'shout', 'result': 'x', 'ok': true},
          ],
        },
      ),
      (
        'conclusion not among its options',
        {
          ...testCfg,
          'conclusion': {
            'options': ['sujet', 'cp'],
            'correct': 'cd',
          },
        },
      ),
      ('one token', {...groupCfg, 'tokens': words('Oui')}),
    ]) {
      test('refuses $why', () {
        expect(engine.parse(bad), isA<ParseInvalid<PhraseContent>>());
      });
    }

    test('an unknown task is an app update, not a content bug', () {
      expect(
        engine.parse({...groupCfg, 'task': 'agree'}),
        isA<ParseUnsupported<PhraseContent>>(),
      );
    });
  });

  group('group', () {
    final c = parsed(groupCfg);
    final s0 = engine.initialize(c, const EngineSeed(1));

    test('two taps bracket a group, in either order', () {
      final t = engine.reduce(
        engine.reduce(s0, const TapPhraseToken(2)).state,
        const TapPhraseToken(0),
      );
      expect(t.state.spans.single.key, '0-2');
      expect(t.state.selected, '0-2');
      expect(t.events.single.type, 'item_placed');
    });

    test('a bracket never swallows another one', () {
      var s = run(s0, const [TapPhraseToken(4), TapPhraseToken(5)]);
      // 3 to 6 would hold « sur le »: refused, and the new tap starts over.
      s = run(s, const [TapPhraseToken(3), TapPhraseToken(6)]);
      expect(s.spans.map((x) => x.key), ['4-5']);
      expect(s.anchor, 6);
      // A word inside a bracket isn't a start.
      final inside = engine.reduce(s, const TapPhraseToken(4));
      expect(inside.state, s);
      expect(inside.events, isEmpty);
    });

    test('a label goes on the selected bracket; a second tap undoes it', () {
      var s = run(s0, const [
        TapPhraseToken(0),
        TapPhraseToken(2),
        TapPhraseLabel('sujet'),
      ]);
      expect(s.named, {'0-2': 'sujet'});
      s = run(s, const [TapPhraseSpan('0-2'), TapPhraseSpan('0-2')]);
      expect(s.spans, isEmpty);
      expect(s.named, isEmpty);
    });

    test('VALIDER waits for every group, each named', () {
      var s = run(s0, const [
        TapPhraseToken(0),
        TapPhraseToken(2),
        TapPhraseLabel('sujet'),
        TapPhraseToken(3),
        TapPhraseToken(6),
        TapPhraseLabel('predicat'),
      ]);
      expect(engine.extractAnswer(s), isNull, reason: '2 of 3');
      s = run(s, const [TapPhraseToken(7), TapPhraseToken(8)]);
      expect(engine.extractAnswer(s), isNull, reason: 'unnamed');
      s = run(s, const [TapPhraseLabel('cp')]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
    });

    test('partial credit: the right one locks, a wrong one comes off', () {
      final s = run(s0, const [
        TapPhraseToken(0),
        TapPhraseToken(2),
        TapPhraseLabel('sujet'),
        // The predicate stops short: « dort sur le ».
        TapPhraseToken(3),
        TapPhraseToken(5),
        TapPhraseLabel('predicat'),
        TapPhraseToken(7),
        TapPhraseToken(8),
        TapPhraseLabel('sujet'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.partial);
      expect(r.score, closeTo(1 / 3, 1e-9));
      final after = engine.applyFeedback(s, r);
      expect(after.locked, {'0-2'});
      expect(after.spans.map((x) => x.key), ['0-2']);
      // Same name back on the same words: refused.
      final again = run(after, const [
        TapPhraseToken(7),
        TapPhraseToken(8),
        TapPhraseLabel('sujet'),
      ]);
      expect(again.named['7-8'], isNull);
      expect(engine.reduce(after, const TapPhraseSpan('0-2')).state, after);
    });

    test('with one label in the tray, a bracket names itself', () {
      final one = parsed({
        ...groupCfg,
        'labels': [
          {'id': 'sujet', 'label': 'Sujet'},
        ],
        'groups': [
          {'id': 'g1', 'from': 'w0', 'to': 'w2', 'label': 'sujet'},
        ],
      });
      final s = run(engine.initialize(one, const EngineSeed(1)), const [
        TapPhraseToken(0),
        TapPhraseToken(2),
      ]);
      expect(
        evaluator.evaluate(one, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
    });

    test('a snapshot round-trips, and nonsense is refused', () {
      final s = run(s0, const [
        TapPhraseToken(0),
        TapPhraseToken(2),
        TapPhraseLabel('sujet'),
        TapPhraseToken(4),
      ]);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(engine.snapshot(back), engine.snapshot(s));
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'spans': ['0-2', '1-3'],
        }),
        isNull,
      );
    });
  });

  group('test', () {
    final c = parsed(testCfg);
    final s0 = engine.initialize(c, const EngineSeed(1));

    test('a test must run before it is judged; running it reveals', () {
      expect(
        engine.reduce(s0, const JudgePhraseTest('del', works: true)).state,
        s0,
      );
      final t = engine.reduce(s0, const RunPhraseTest('del'));
      expect(t.events.map((e) => e.type), ['experiment_run', 'reveal']);
    });

    test('every verdict and the conclusion are items', () {
      final s = run(s0, const [
        RunPhraseTest('del'),
        JudgePhraseTest('del', works: true),
        RunPhraseTest('mov'),
        JudgePhraseTest('mov', works: false),
      ]);
      expect(engine.extractAnswer(s), isNull, reason: 'no conclusion yet');
      final done = run(s, const [PickPhraseConclusion('cp')]);
      final r = evaluator.evaluate(c, engine.extractAnswer(done)!, ctx);
      expect(r.itemResults, {'del': true, 'mov': false, 'conclusion': true});
      expect(r.outcome, Outcome.partial);
      final after = engine.applyFeedback(done, r);
      expect(after.lockedItems, {'del', 'conclusion'});
      expect(after.judged.containsKey('mov'), isFalse);
      // The same wrong verdict can't be given twice.
      expect(
        engine.reduce(after, const JudgePhraseTest('mov', works: false)).state,
        after,
      );
      final fixed = run(after, const [JudgePhraseTest('mov', works: true)]);
      expect(
        evaluator.evaluate(c, engine.extractAnswer(fixed)!, ctx).outcome,
        Outcome.correct,
      );
    });
  });

  group('in the shell', () {
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('bracket, name, VALIDER: Bravo', (tester) async {
      tall(tester);
      final c = controllerFor(groupCfg);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> tap(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await settle(tester);
      }

      for (final (a, b, label) in [
        (0, 2, 'sujet'),
        (3, 6, 'predicat'),
        (7, 8, 'cp'),
      ]) {
        await tap('phrase-token-$a');
        await tap('phrase-token-$b');
        await tap('phrase-label-$label');
      }
      expect(find.text('Groupes : 3 / 3'), findsOneWidget);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('run, judge, conclude', (tester) async {
      tall(tester);
      final c = controllerFor(testCfg);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('phrase-focus')), findsOneWidget);
      expect(find.text('Le chat dort.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('phrase-run-del')));
      await settle(tester);
      expect(find.text('Le chat dort.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phrase-judge-del-ok')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('phrase-run-mov')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('phrase-judge-mov-ok')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('phrase-conclude-cp')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('a phone: the sentence wraps, nothing overflows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = controllerFor(groupCfg);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('phrase-token-3')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('phrase-token-8')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
