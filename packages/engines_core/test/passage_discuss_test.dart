import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// Pompon hides under the bed. Léa thinks he's scared (s2), Omar that
// he's cold (s3). The clue settles it: the storm.
const discuss = <String, Object?>{
  'task': 'discuss',
  'sentences': [
    {'id': 's1', 'text': 'Pompon se cache sous le lit.'},
    {'id': 's2', 'text': 'Le tonnerre gronde dehors.'},
    {'id': 's3', 'text': 'La fenêtre est restée ouverte.'},
    {'id': 's4', 'text': 'Pompon tremble un peu.'},
  ],
  'question': 'Pourquoi Pompon se cache-t-il ?',
  'options': [
    {'id': 'peur', 'label': 'Il a peur.'},
    {'id': 'froid', 'label': 'Il a froid.'},
    {'id': 'jeu', 'label': 'Il joue à cache-cache.'},
  ],
  'takes': [
    {
      'id': 'lea',
      'character': 'lea',
      'text': 'Je pense qu’il a peur.',
      'cites': 's2',
    },
    {
      'id': 'omar',
      'character': 'omar',
      'text': 'Moi, je pense qu’il a froid.',
      'cites': 's3',
    },
  ],
  'clue': {
    'id': 'c1',
    'text': 'Quand l’orage s’arrête, Pompon sort tout de suite.',
    'accepts': ['peur'],
  },
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'passage_reader',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Lis l’histoire, puis discute avec tes amis.'},
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
        eraseEngine(const PassageReaderEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [PassageReaderEvaluator()]),
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
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

PassageContent parsed(Map<String, Object?> config) =>
    const PassageReaderEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const PassageReaderEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = PassageReaderEngine();
  const evaluator = PassageReaderEvaluator();

  PassageState run(PassageState s, List<PassageAction> actions) {
    for (final a in actions) {
      s = engine.reduce(s, a).state;
    }
    return s;
  }

  group('parse', () {
    test('reads the takes and the clue', () {
      final c = parsed(discuss);
      expect(c.task, PassageTask.discuss);
      expect(c.discuss!.takes.map((t) => t.character.key), ['lea', 'omar']);
      expect(c.discuss!.clue.accepts, {'peur'});
    });

    test('rejects what cannot be discussed', () {
      final takes = (discuss['takes']! as List).cast<Map<String, Object?>>();
      expect(
        reason({...discuss, 'takes': takes.take(1).toList()}),
        contains('exactly 2'),
      );
      expect(
        reason({
          ...discuss,
          'takes': [
            takes[0],
            {...takes[1], 'character': 'lea'},
          ],
        }),
        contains('own ids and characters'),
      );
      expect(
        reason({
          ...discuss,
          'takes': [
            takes[0],
            {...takes[1], 'cites': 's2'},
          ],
        }),
        contains('different sentences'),
      );
      expect(
        reason({
          ...discuss,
          'takes': [
            takes[0],
            {...takes[1], 'character': 'pirate'},
          ],
        }),
        contains('character is one of'),
      );
      expect(
        reason({
          ...discuss,
          'clue': {'id': 's1', 'text': 'x'},
        }),
        contains('new sentence'),
      );
      expect(
        reason({
          ...discuss,
          'clue': {
            'id': 'c1',
            'text': 'x',
            'accepts': ['peur', 'froid', 'jeu'],
          },
        }),
        contains('leave accepts out'),
      );
      expect(reason({...discuss, 'correct': 'peur'}), contains('no correct'));
      expect(
        reason({
          'task': 'choose',
          'sentences': discuss['sentences'],
          'options': discuss['options'],
          'correct': 'peur',
          'takes': takes,
        }),
        contains('belongs to task discuss'),
      );
    });
  });

  group('the steps', () {
    test('takes need a first answer; the clue needs both matches', () {
      final c = parsed(discuss);
      var s = engine.initialize(c, const EngineSeed(1));
      expect(
        engine.reduce(s, const DiscussCite('lea', 's2')).state.discuss!.cites,
        isEmpty,
      );
      s = run(s, [
        const DiscussPickFirst('froid'),
        const DiscussCite('lea', 's2'),
      ]);
      expect(s.discuss!.clueShown, isFalse);
      expect(
        engine
            .reduce(s, const DiscussPickFinal('peur'))
            .state
            .discuss!
            .finalPick,
        isNull,
      );
      s = run(s, [const DiscussCite('omar', 's3')]);
      expect(s.discuss!.clueShown, isTrue);
      // The first answer is fixed once the clue is out.
      expect(
        engine.reduce(s, const DiscussPickFirst('jeu')).state.discuss!.first,
        'froid',
      );
      expect(engine.extractAnswer(s), isNull);
      s = run(s, [const DiscussPickFinal('peur')]);
      final answer = engine.extractAnswer(s)! as BlanksAnswer;
      expect(answer.blanks, {
        'first': 'froid',
        'take_lea': 's2',
        'take_omar': 's3',
        'final': 'peur',
      });
    });

    test('the clue decides: takes and revision are items (proxy)', () {
      final c = parsed(discuss);
      var s = run(engine.initialize(c, const EngineSeed(1)), [
        const DiscussPickFirst('peur'),
        const DiscussCite('lea', 's4'),
        const DiscussCite('omar', 's3'),
        const DiscussPickFinal('froid'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {
        'take_lea': false,
        'take_omar': true,
        'final': false,
      });
      expect(r.outcome, Outcome.partial);
      s = engine.applyFeedback(s, r);
      expect(s.discuss!.lockedTakes, {'omar'});
      expect(s.discuss!.cites, {'omar': 's3'});
      expect(s.discuss!.finalPick, isNull);
      expect(s.discuss!.finalTried, {'froid'});
      // The tried cite is refused; the right one fixes it.
      expect(
        engine.reduce(s, const DiscussCite('lea', 's4')).state.discuss!.cites,
        {'omar': 's3'},
      );
      s = run(s, [
        const DiscussCite('lea', 's2'),
        const DiscussPickFinal('peur'),
      ]);
      expect(
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
    });

    test('both takes valid: the revision is practice, not an item', () {
      final c = parsed({
        ...discuss,
        'clue': {'id': 'c1', 'text': 'Pompon aime aussi les coins chauds.'},
      });
      final s = run(engine.initialize(c, const EngineSeed(1)), [
        const DiscussPickFirst('peur'),
        const DiscussCite('lea', 's2'),
        const DiscussCite('omar', 's3'),
        const DiscussPickFinal('jeu'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {'take_lea': true, 'take_omar': true});
      expect(r.outcome, Outcome.correct);
    });

    test('snapshot round-trips and refuses a falsely locked take', () {
      final c = parsed(discuss);
      final s = run(engine.initialize(c, const EngineSeed(1)), [
        const DiscussPickFirst('peur'),
        const DiscussCite('lea', 's2'),
      ]);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.discuss!.cites, {'lea': 's2'});
      final snap = engine.snapshot(s);
      final bad = {
        ...snap,
        'discuss': {
          ...(snap['discuss']! as Map<String, Object?>),
          'locked_takes': ['omar'],
        },
      };
      expect(engine.restore(c, bad), isNull);
    });
  });

  group('in the shell', () {
    testWidgets('answer, match, read the clue, revise: wrong, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(discuss);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('discuss-takes')), findsNothing);
      Future<void> tap(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await settle(tester);
      }

      await tap('discuss-first-froid');
      expect(find.byKey(const ValueKey('discuss-takes')), findsOne);
      expect(find.bySemanticsLabel(RegExp('Léa : Je pense')), findsOne);
      await tap('discuss-cite-lea-s2');
      await tap('discuss-cite-omar-s1');
      expect(find.byKey(const ValueKey('discuss-clue')), findsOne);
      await tap('discuss-final-froid');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tap('discuss-cite-omar-s3');
      await tap('discuss-final-peur');
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

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> tapShown(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await settle(tester);
      await tester.pumpAndSettle();
    }

    bool onScreen(WidgetTester tester, String key) {
      final y = tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      return y > 0 && y < 600;
    }

    testWidgets('AM30: each sentence carries the number its cite button uses', (
      tester,
    ) async {
      phone(tester);
      final (c, _) = controllerFor(discuss);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      for (var i = 1; i <= 4; i++) {
        expect(find.byKey(ValueKey('passage-number-$i')), findsOne);
      }
      c.dispose();
    });

    testWidgets('AM28: a part a tap reveals scrolls into view', (tester) async {
      phone(tester);
      final (c, _) = controllerFor(discuss);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tapShown(tester, 'discuss-first-peur');
      expect(onScreen(tester, 'discuss-takes'), isTrue);
      await tapShown(tester, 'discuss-cite-lea-s2');
      await tapShown(tester, 'discuss-cite-omar-s3');
      expect(onScreen(tester, 'discuss-clue'), isTrue);
      c.dispose();
    });

    testWidgets('AM29: the next question opens at the top; no cue over Bravo', (
      tester,
    ) async {
      phone(tester);
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse({
          ...envelope(discuss),
          'config': {
            'questions': [
              for (final q in ['Pourquoi ?', 'Et encore ?'])
                {
                  'prompt': {'text': q},
                  'config': discuss,
                },
            ],
          },
        }).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([
          eraseEngine(const PassageReaderEngine()),
        ]),
        evaluators: EvaluatorRegistry(const [PassageReaderEvaluator()]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tapShown(tester, 'discuss-first-peur');
      await tapShown(tester, 'discuss-cite-lea-s2');
      await tapShown(tester, 'discuss-cite-omar-s3');
      await tapShown(tester, 'discuss-final-peur');
      ScrollPosition body() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(body().pixels, greaterThan(0));
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(find.byKey(const ValueKey('scroll-more')), findsNothing);
      await tester.tap(find.text('CONTINUER'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Et encore ?'), findsOneWidget);
      expect(body().pixels, 0);
      c.dispose();
    });

    testWidgets('fits a phone once every step is open', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(discuss);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('discuss-first-peur')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discuss-cite-lea-s2')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discuss-cite-omar-s3')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
