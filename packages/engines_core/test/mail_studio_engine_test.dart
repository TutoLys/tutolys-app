import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_shelf.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

Map<String, Object?> letter(String character, String audience) => {
  'news': 'Mon chien Max a appris à rouler !',
  'recipient': {'character': character, 'audience': audience},
  'slots': [
    {'id': 'format', 'label': 'Quoi envoyer ?'},
    {'id': 'greeting', 'label': 'Pour commencer'},
    {'id': 'details', 'label': 'Ce qu’il faut dire', 'many': true},
  ],
  'tiles': [
    {
      'id': 'carte',
      'slot': 'format',
      'label': 'Une carte',
      'template': 'card',
      'audiences': ['family', 'friend'],
    },
    {
      'id': 'article',
      'slot': 'format',
      'label': 'Un article',
      'template': 'article',
      'audiences': ['public'],
      'reaction': 'Un article pour moi toute seule ?',
    },
    {
      'id': 'salut',
      'slot': 'greeting',
      'label': 'Salut !',
      'audiences': ['friend', 'family'],
      'reaction': 'Salut ? Un journal n’écrit pas comme ça…',
    },
    {
      'id': 'bonjour',
      'slot': 'greeting',
      'label': 'Bonjour à tous,',
      'audiences': ['public'],
    },
    {
      'id': 'chere',
      'slot': 'greeting',
      'label': 'Chère Grand-maman,',
      'audiences': ['family'],
    },
    {
      'id': 'mon_chien',
      'slot': 'details',
      'label': 'Mon chien Max',
      'audiences': ['family', 'friend', 'public'],
      'needed_by': ['public'],
      'missing_reaction': 'Qui est Max ?',
    },
    {
      'id': 'roule',
      'slot': 'details',
      'label': 'a appris à rouler !',
      'audiences': ['family', 'friend', 'public'],
      'needed_by': ['family', 'friend', 'public'],
    },
    {
      'id': 'bisous',
      'slot': 'details',
      'label': 'Gros bisous !',
      'audiences': ['family'],
      'reaction': 'Des bisous dans le journal ?',
    },
  ],
  'delighted': 'Merci pour la nouvelle !',
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'mail_studio',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Écris ta nouvelle pour le journal du village.'},
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
      engines: LearningEngineRegistry([eraseEngine(const MailStudioEngine())]),
      evaluators: EvaluatorRegistry(const [MailStudioEvaluator()]),
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

MailContent parsed(Map<String, Object?> config) =>
    const MailStudioEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const MailStudioEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = MailStudioEngine();
  const evaluator = MailStudioEvaluator();
  final paper = letter('journal', 'public');
  final grandma = letter('grand_maman', 'family');

  MailState pick(MailState s, List<String> ids) {
    for (final id in ids) {
      s = engine.reduce(s, ToggleMailTile(id)).state;
    }
    return s;
  }

  group('parse', () {
    test('the school wall is a recipient', () {
      final c = parsed(letter('babillard', 'public'));
      expect(c.recipient.name(fr), 'le babillard de l’école');
      expect(c.recipient.name(const Locale('en')), 'the school wall');
    });

    test('reads the recipient, slots and tiles', () {
      final c = parsed(paper);
      expect(c.recipient.key, 'journal');
      expect(c.tile('article').template, MailTemplate.article);
      expect(c.tile('mon_chien').neededBy, {'public'});
    });

    test('rejects letters with no real choice', () {
      expect(
        reason({
          ...paper,
          'recipient': {'character': 'journal', 'audience': 'aliens'},
        }),
        contains('audience is one of'),
      );
      final tiles = (paper['tiles']! as List).cast<Map<String, Object?>>();
      expect(
        reason({
          ...paper,
          'tiles': [
            for (final t in tiles)
              if (t['slot'] != 'format') t,
            {
              'id': 'a1',
              'slot': 'format',
              'label': 'A',
              'audiences': ['family'],
            },
          ],
        }),
        contains('no tile that suits'),
      );
      expect(
        reason({
          ...paper,
          'tiles': [
            for (final t in tiles)
              if (t['id'] != 'carte') t,
          ],
        }),
        contains('nothing to choose'),
      );
      expect(
        reason({
          ...paper,
          'tiles': [
            ...tiles,
            {
              'id': 'x',
              'slot': 'format',
              'label': 'X',
              'audiences': ['family'],
              'needed_by': ['public'],
            },
          ],
        }),
        contains('needed only by audiences it suits'),
      );
      expect(
        reason({
          ...paper,
          'slots': [
            {'id': 'format', 'label': 'F'},
            {'id': 'greeting', 'label': 'G'},
            {'id': 'details', 'label': 'D'},
          ],
        }),
        contains('make it many'),
      );
    });
  });

  group('the same news, two readers', () {
    test('the paper needs "mon chien Max"; Grand-maman doesn\'t', () {
      final forPaper = ['article', 'bonjour', 'roule'];
      var c = parsed(paper);
      var s = pick(engine.initialize(c, const EngineSeed(1)), forPaper);
      var r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {
        'format': true,
        'greeting': true,
        'details': false,
      });
      s = engine.applyFeedback(s, r);
      expect(s.reaction, 'Qui est Max ?');
      expect(s.mood, CharacterMood.confused);
      expect(s.picks['details'], {'roule'});
      s = pick(s, ['mon_chien']);
      r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
      s = engine.applyFeedback(s, r);
      expect(s.reaction, 'Merci pour la nouvelle !');

      c = parsed(grandma);
      s = pick(engine.initialize(c, const EngineSeed(1)), [
        'carte',
        'chere',
        'roule',
        'bisous',
      ]);
      expect(
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
    });

    test('a misfit puts the reader off, goes amber and leaves', () {
      final c = parsed(paper);
      var s = pick(engine.initialize(c, const EngineSeed(1)), [
        'carte',
        'salut',
        'mon_chien',
        'roule',
        'bisous',
      ]);
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.itemResults, {
        'format': false,
        'greeting': false,
        'details': false,
      });
      s = engine.applyFeedback(s, r);
      expect(s.mood, CharacterMood.putOff);
      // The card has no line of its own; the view says a generic one.
      expect(s.reaction, '');
      expect(
        s.tried,
        containsAll(['format|carte', 'greeting|salut', 'details|bisous']),
      );
      expect(s.picks['details'], {'mon_chien', 'roule'});
      expect(
        engine.reduce(s, const ToggleMailTile('salut')).state.picks['greeting'],
        isEmpty,
      );
    });

    test('a single slot swaps its tile; snapshot round-trips', () {
      final c = parsed(paper);
      var s = pick(engine.initialize(c, const EngineSeed(1)), [
        'salut',
        'bonjour',
      ]);
      expect(s.picks['greeting'], {'bonjour'});
      s = pick(s, ['article']);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.picks['greeting'], {'bonjour'});
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'locked': ['details'],
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    for (final (who, header, not) in [
      ('journal', 'LE JOURNAL DU VILLAGE', 'BABILLARD'),
      ('babillard', 'LE BABILLARD DE L’ÉCOLE', 'JOURNAL'),
    ]) {
      testWidgets('an article for $who is headed $header', (tester) async {
        // Grade-1 ELA 122 reports for the school wall, but every article
        // used to say newspaper (2026-11-16 play-test).
        tallView(tester);
        final (c, _) = controllerFor(letter(who, 'public'));
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c));
        await tester.tap(find.byKey(const ValueKey('mail-tile-article')));
        await settle(tester);
        expect(find.text(header), findsOneWidget);
        expect(find.textContaining(not), findsNothing);
        c.dispose();
      });
    }

    testWidgets('a letter for a person has no newspaper header', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(grandma);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.textContaining('JOURNAL'), findsNothing);
      c.dispose();
    });

    testWidgets('write for the paper: confused, then delighted', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(paper);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> tap(String id) async {
        await tester.tap(find.byKey(ValueKey('mail-tile-$id')));
        await settle(tester);
      }

      for (final id in ['article', 'bonjour', 'roule']) {
        await tap(id);
      }
      expect(
        find.bySemanticsLabel(
          RegExp('Aperçu, un article : Bonjour à tous, a appris à rouler'),
        ),
        findsOne,
      );
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(
        find.bySemanticsLabel(RegExp('le journal du village : Qui est Max')),
        findsOne,
      );
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tap('mon_chien');
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

    for (final creation in [true, false]) {
      testWidgets('offers to keep it only with creation: $creation', (
        tester,
      ) async {
        tallView(tester);
        final (c, _) = controllerFor({...paper, 'creation': creation});
        final offered = await offersKeep(
          tester,
          c: c,
          app: app,
          solve: const [
            ToggleMailTile('article'),
            ToggleMailTile('bonjour'),
            ToggleMailTile('mon_chien'),
            ToggleMailTile('roule'),
          ],
        );
        expect(offered, creation);
      });
    }

    testWidgets('fits a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(grandma);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      for (final id in ['carte', 'chere', 'roule', 'bisous']) {
        await tester.tap(find.byKey(ValueKey('mail-tile-$id')));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
