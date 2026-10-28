import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const story = {
  'title': 'Le chat de Léa',
  'sentences': [
    {'id': 's1', 'text': 'Léa a un chat.'},
    {'id': 's2', 'text': 'Il est tout noir avec une tache blanche.'},
    {'id': 's3', 'text': 'Il dort.'},
  ],
};

const give = <String, Object?>{
  'mode': 'give',
  'character': 'lea',
  'piece': story,
  'tiles': [
    {
      'id': 'o_merci',
      'slot': 'opener',
      'label': 'Merci de me montrer ton histoire !',
    },
    {
      'id': 'o_bof',
      'slot': 'opener',
      'label': 'Bof.',
      'kind': false,
      'diagnosis': {'code': 'ela.feedback.harsh', 'taxonomy_version': 1},
    },
    {
      'id': 'p_tache',
      'slot': 'praise',
      'label': 'J’aime la tache blanche.',
      'refers_to': 's2',
    },
    {'id': 'p_beau', 'slot': 'praise', 'label': 'C’est beau.'},
    {
      'id': 'p_chien',
      'slot': 'praise',
      'label': 'J’aime le chien qui jappe.',
      'refers_to': 'chien',
      'reaction': 'Un chien ? Il n’y a pas de chien…',
    },
    {
      'id': 's_ou',
      'slot': 'suggestion',
      'label': 'Tu pourrais dire où il dort.',
      'refers_to': 's3',
      'actionable': true,
    },
    {
      'id': 's_mieux',
      'slot': 'suggestion',
      'label': 'Fais mieux.',
      'refers_to': 's3',
    },
    {
      'id': 's_tout',
      'slot': 'suggestion',
      'label': 'Recommence tout.',
      'actionable': true,
    },
  ],
  'delighted': 'Merci, je vais ajouter où il dort !',
};

const askRevise = <String, Object?>{
  'mode': 'ask_revise',
  'character': 'omar',
  'piece': story,
  'asks': [
    {'id': 'q_bon', 'label': 'C’est bon ?'},
    {
      'id': 'q_fin',
      'label': 'Est-ce que ma fin est claire ?',
      'about': 's3',
      'comment': 'Où est-ce qu’il dort ?',
    },
  ],
  'revisions': {
    's3': [
      {'id': 'r_lit', 'label': 'Il dort sur mon lit.', 'resolves': true},
      {'id': 'r_dort', 'label': 'Il dort beaucoup.', 'resolves': false},
    ],
  },
  'vague_reply': 'C’est beau !',
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'feedback_studio',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {
    'text': 'Léa te montre son histoire. Dis-lui ce que tu en penses.',
  },
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
        eraseEngine(const FeedbackStudioEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [FeedbackStudioEvaluator()]),
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
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

FeedbackContent parsed(Map<String, Object?> config) =>
    const FeedbackStudioEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const FeedbackStudioEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = FeedbackStudioEngine();
  const evaluator = FeedbackStudioEvaluator();

  FeedbackState run(FeedbackState s, List<FeedbackAction> actions) {
    for (final a in actions) {
      s = engine.reduce(s, a).state;
    }
    return s;
  }

  group('parse', () {
    test('a right tile is kind, specific, and helpful where it must be', () {
      final c = parsed(give);
      expect(c.tileRight(c.tile('o_merci')), isTrue);
      expect(c.tileRight(c.tile('o_bof')), isFalse);
      expect(c.tileRight(c.tile('p_beau')), isFalse);
      expect(c.tileRight(c.tile('p_chien')), isFalse);
      expect(c.tileRight(c.tile('s_mieux')), isFalse);
      expect(c.tileRight(c.tile('s_tout')), isFalse);
      expect(c.tileRight(c.tile('s_ou')), isTrue);
    });

    test('rejects pieces and slots with no real choice', () {
      final tiles = (give['tiles']! as List).cast<Map<String, Object?>>();
      expect(
        reason({
          ...give,
          'tiles': [
            for (final t in tiles)
              if (t['id'] != 'o_bof') t,
          ],
        }),
        contains('Slot opener'),
      );
      expect(reason({...give, 'character': 'pirate'}), contains('character'));
      expect(
        reason({
          ...give,
          'piece': {
            'sentences': [(story['sentences']! as List)[0]],
          },
        }),
        contains('2 to 8'),
      );
      final asks = (askRevise['asks']! as List).cast<Map<String, Object?>>();
      expect(
        reason({
          ...askRevise,
          'asks': [
            asks[1],
            {...asks[1], 'id': 'q2'},
          ],
        }),
        contains('one vague one'),
      );
      expect(
        reason({
          ...askRevise,
          'revisions': {
            's3': [
              {'id': 'a', 'label': 'A', 'resolves': true},
              {'id': 'b', 'label': 'B', 'resolves': true},
            ],
          },
        }),
        contains('one that doesn'),
      );
      expect(
        reason({
          ...askRevise,
          'piece': {
            'image_ref': 'img',
            'points': [
              {'id': 'a', 'label': 'a', 'x': 0.1, 'y': 0.1},
              {'id': 'b', 'label': 'b', 'x': 0.5, 'y': 0.5},
            ],
          },
        }),
        contains('works on a story'),
      );
    });
  });

  group('give', () {
    test(
      'partial credit per slot; a harsh tile hurts and carries its code',
      () {
        final c = parsed(give);
        var s = run(engine.initialize(c, const EngineSeed(1)), [
          const PickFeedbackTile('o_bof'),
          const PickFeedbackTile('p_tache'),
          const PickFeedbackTile('s_mieux'),
        ]);
        final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
        expect(r.itemResults, {
          'opener': false,
          'praise': true,
          'suggestion': false,
        });
        expect(r.errors.first.code, 'ela.feedback.harsh');
        s = engine.applyFeedback(s, r);
        expect(s.mood, CharacterMood.putOff);
        expect(s.locked, {'praise'});
        expect(s.tried, {'o_bof', 's_mieux'});
        expect(
          engine
              .reduce(s, const PickFeedbackTile('o_bof'))
              .state
              .picks['opener'],
          isNull,
        );
        s = run(s, [
          const PickFeedbackTile('o_merci'),
          const PickFeedbackTile('s_ou'),
        ]);
        expect(
          evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
          Outcome.correct,
        );
      },
    );

    test('praise of something that isn\'t there gets its own reaction', () {
      final c = parsed(give);
      var s = run(engine.initialize(c, const EngineSeed(1)), [
        const PickFeedbackTile('o_merci'),
        const PickFeedbackTile('p_chien'),
        const PickFeedbackTile('s_ou'),
      ]);
      s = engine.applyFeedback(
        s,
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx),
      );
      expect(s.reaction, 'Un chien ? Il n’y a pas de chien…');
      expect(s.mood, CharacterMood.confused);
    });
  });

  group('ask_revise', () {
    test('a vague first question costs the ask item, once', () {
      final c = parsed(askRevise);
      var s = run(engine.initialize(c, const EngineSeed(1)), [
        const AskFeedback('q_bon'),
      ]);
      expect(s.pinned, isNull);
      expect(
        engine.reduce(s, const PickRevision('r_lit')).state.revision,
        isNull,
      );
      s = run(s, [const AskFeedback('q_fin'), const PickRevision('r_lit')]);
      var r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {'ask': false, 'revise': true});
      s = engine.applyFeedback(s, r);
      expect(s.reviseLocked, isTrue);
      expect(s.reaction, 'ask');
      r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
    });

    test('a rewrite that misses the comment goes amber', () {
      final c = parsed(askRevise);
      var s = run(engine.initialize(c, const EngineSeed(1)), [
        const AskFeedback('q_fin'),
        const PickRevision('r_dort'),
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {'ask': true, 'revise': false});
      s = engine.applyFeedback(s, r);
      expect(s.revisionTried, {'r_dort'});
      expect(s.revision, isNull);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.revisionTried, {'r_dort'});
      expect(back.pinned, 's3');
    });
  });

  group('in the shell', () {
    testWidgets('give a kind, specific, helpful comment', (tester) async {
      tallView(tester);
      final (c, outbox) = controllerFor(give);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> tap(String id) async {
        await tester.tap(find.byKey(ValueKey('feedback-tile-$id')));
        await settle(tester);
      }

      await tap('o_merci');
      await tap('p_beau');
      await tap('s_ou');
      expect(find.bySemanticsLabel(RegExp('phrase 3, marquée')), findsOne);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('qu’est-ce qui t’a plu')), findsOne);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tap('p_tache');
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

    testWidgets('ask, read the pinned comment, rewrite — on a phone', (
      tester,
    ) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(askRevise);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('feedback-ask-q_fin')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('feedback-ask-q_fin')));
      await settle(tester);
      expect(
        find.bySemanticsLabel(RegExp('Omar : Où est-ce qu’il dort')),
        findsOne,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('feedback-revision-r_lit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('feedback-revision-r_lit')));
      await settle(tester);
      expect(
        find.bySemanticsLabel(
          RegExp('phrase 3, marquée : Il dort sur mon lit'),
        ),
        findsOne,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });
  });
}
