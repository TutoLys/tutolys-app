import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const sentences = [
  {'id': 's1', 'text': 'Léa a un petit chat gris.', 'audio_ref': 'audio/s1'},
  {'id': 's2', 'text': 'Il s’appelle Pompon.', 'audio_ref': 'audio/s2'},
  {'id': 's3', 'text': 'Pompon dort sur le lit.', 'audio_ref': 'audio/s3'},
  {'id': 's4', 'text': 'Le matin, il boit du lait.'},
];

// The backend samples, verbatim in shape.
const findConfig = <String, Object?>{
  'title': 'Le chat de Léa',
  'sentences': sentences,
  'correct_ids': ['s3'],
};

const multiConfig = <String, Object?>{
  'sentences': sentences,
  'correct_ids': ['s3', 's4'],
};

const chooseConfig = <String, Object?>{
  'task': 'choose',
  'title': 'Le chat de Léa',
  'sentences': sentences,
  'options': [
    {'id': 'a', 'label': 'Pompon'},
    {'id': 'b', 'label': 'Léa'},
    {'id': 'c', 'label': 'Gris'},
  ],
  'correct': 'a',
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
  'prompt': {'text': 'Où dort Pompon ?'},
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

class FakeSpeaker implements ContentSpeaker {
  final calls = <(String, String)>[];

  @override
  void speak({required String audioRef, required String partId}) =>
      calls.add((audioRef, partId));
}

Widget app(ActivitySessionController c, {ContentSpeaker? speaker}) {
  final view = LearningActivityView(controller: c, locale: fr, onDone: () {});
  return MaterialApp(
    theme: TutolysTheme.village(),
    home: Scaffold(
      body: speaker == null
          ? view
          : ContentSpeakerScope(speaker: speaker, child: view),
    ),
  );
}

void tallView(WidgetTester tester, {double width = 1000}) {
  tester.view.physicalSize = Size(width, 1600);
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

void main() {
  const engine = PassageReaderEngine();

  group('parse', () {
    test('the samples parse', () {
      final find = parsed(findConfig);
      expect(find.task, PassageTask.find);
      expect(find.title, 'Le chat de Léa');
      expect(find.sentences.map((s) => s.id), ['s1', 's2', 's3', 's4']);
      expect(find.sentences[3].audioRef, isNull);
      expect(find.correct, {'s3'});

      final choose = parsed(chooseConfig);
      expect(choose.task, PassageTask.choose);
      expect(choose.options.map((o) => o.id), ['a', 'b', 'c']);
      expect(choose.correct, {'a'});
    });

    test('rejects what cannot be played', () {
      String? reason(Map<String, Object?> config) =>
          switch (engine.parse(config)) {
            ParseInvalid(:final reason) => reason,
            _ => null,
          };
      expect(
        reason({...findConfig, 'task': 'read'}),
        contains('find, choose or discuss'),
      );
      expect(
        reason({
          'sentences': [sentences.first],
          'correct_ids': ['s1'],
        }),
        contains('2 to 10'),
      );
      expect(
        reason({
          'sentences': [
            sentences[0],
            {'id': 's1', 'text': 'Encore.'},
          ],
          'correct_ids': ['s1'],
        }),
        contains('unique'),
      );
      expect(
        reason({
          'sentences': sentences,
          'correct_ids': ['s1', 's2', 's3', 's4'],
        }),
        contains('nothing to find'),
      );
      expect(
        reason({
          'sentences': sentences,
          'correct_ids': ['s9'],
        }),
        contains('correct_ids'),
      );
      expect(
        reason({...findConfig, 'correct': 'a'}),
        contains('belong to task choose'),
      );
      expect(
        reason({...chooseConfig, 'correct': 'z'}),
        contains('correct must name'),
      );
      expect(
        reason({
          ...chooseConfig,
          'correct_ids': ['s1'],
        }),
        contains('belongs to task find'),
      );
      expect(
        reason({
          ...chooseConfig,
          'options': [
            for (final id in ['a', 'b', 'c', 'd', 'e']) {'id': id, 'label': id},
          ],
        }),
        contains('2 to 4'),
      );
      expect(
        reason({
          'sentences': [
            sentences[0],
            {'id': 's2', 'text': '   '},
          ],
          'correct_ids': ['s1'],
        }),
        contains('id and text'),
      );
    });
  });

  group('initialize and reduce', () {
    test('a passage keeps its order; options shuffle, the same per seed', () {
      final find = engine.initialize(parsed(findConfig), const EngineSeed(1));
      expect(find.order, ['s1', 's2', 's3', 's4']);
      expect(find.single, isTrue);

      final orders = {
        for (var seed = 0; seed < 12; seed++)
          engine
              .initialize(parsed(chooseConfig), EngineSeed(seed))
              .order
              .join(),
      };
      expect(orders.length, greaterThan(1), reason: 'options shuffle');
      expect(
        engine.initialize(parsed(chooseConfig), const EngineSeed(5)).order,
        engine.initialize(parsed(chooseConfig), const EngineSeed(5)).order,
      );
    });

    test('one right answer: a new tap replaces the pick', () {
      var s = engine.initialize(parsed(findConfig), const EngineSeed(1));
      s = engine.reduce(s, const TapPassageChoice('s1')).state;
      s = engine.reduce(s, const TapPassageChoice('s3')).state;
      expect(s.selected, {'s3'});
      final t = engine.reduce(s, const TapPassageChoice('s3'));
      expect(t.state.selected, isEmpty);
      expect(t.events.single.type, 'option_deselected');
    });

    test('several right answers: each tap toggles', () {
      var s = engine.initialize(parsed(multiConfig), const EngineSeed(1));
      expect(s.single, isFalse);
      s = engine.reduce(s, const TapPassageChoice('s3')).state;
      s = engine.reduce(s, const TapPassageChoice('s4')).state;
      expect(s.selected, {'s3', 's4'});
      expect(
        (engine.extractAnswer(s)! as MultiSelectAnswer).selectedOptionIds,
        ['s3', 's4'],
      );
    });

    test('an unknown or already tried choice changes nothing', () {
      final s = engine
          .initialize(parsed(findConfig), const EngineSeed(1))
          .copyWith(tried: {'s1'});
      expect(engine.reduce(s, const TapPassageChoice('s1')).events, isEmpty);
      expect(engine.reduce(s, const TapPassageChoice('zz')).events, isEmpty);
      expect(engine.extractAnswer(s), isNull);
    });
  });

  group('PassageReaderEvaluator', () {
    const evaluator = PassageReaderEvaluator();

    test('find: the proving sentence is right, another is wrong', () {
      final content = parsed(findConfig);
      final right = evaluator.evaluate(content, MultiSelectAnswer(['s3']), ctx);
      expect(right.outcome, Outcome.correct);
      expect(right.score, 1);
      expect(right.evaluator, 'passage_reader.exact@1');
      final wrong = evaluator.evaluate(content, MultiSelectAnswer(['s2']), ctx);
      expect(wrong.outcome, Outcome.incorrect);
      expect(wrong.itemResults, {'s2': false});
    });

    test('find several: partial credit, and tapping everything never wins', () {
      final content = parsed(multiConfig);
      final half = evaluator.evaluate(content, MultiSelectAnswer(['s3']), ctx);
      expect(half.outcome, Outcome.partial);
      expect(half.score, 0.5);
      final all = evaluator.evaluate(
        content,
        MultiSelectAnswer(['s1', 's2', 's3', 's4']),
        ctx,
      );
      expect(all.outcome, Outcome.partial);
      expect(all.score, 0.5);
    });

    test('choose: one pick', () {
      final content = parsed(chooseConfig);
      expect(
        evaluator.evaluate(content, MultiSelectAnswer(['a']), ctx).outcome,
        Outcome.correct,
      );
      expect(
        evaluator.evaluate(content, MultiSelectAnswer(['b']), ctx).itemResults,
        {'b': false},
      );
    });

    test('feedback locks right picks and turns wrong ones amber', () {
      final content = parsed(multiConfig);
      var s = engine.initialize(content, const EngineSeed(1));
      s = engine.reduce(s, const TapPassageChoice('s1')).state;
      s = engine.reduce(s, const TapPassageChoice('s3')).state;
      final result = evaluator.evaluate(content, engine.extractAnswer(s)!, ctx);
      s = engine.applyFeedback(s, result);
      expect(s.found, {'s3'});
      expect(s.tried, {'s1'});
      expect(s.selected, isEmpty);
    });
  });

  group('snapshot', () {
    test('round-trips, and rejects a reordered passage', () {
      final content = parsed(findConfig);
      final s = engine
          .initialize(content, const EngineSeed(1))
          .copyWith(selected: {'s3'}, tried: {'s1'});
      final back = engine.restore(content, engine.snapshot(s))!;
      expect(back.selected, {'s3'});
      expect(back.tried, {'s1'});
      expect(
        engine.restore(content, {
          ...engine.snapshot(s),
          'order': ['s2', 's1', 's3', 's4'],
        }),
        isNull,
      );
      expect(
        engine.restore(content, {
          ...engine.snapshot(s),
          'tried': ['s3'],
        }),
        isNull,
        reason: 'the right sentence can never have been tried wrong',
      );
    });

    test('a choose snapshot keeps its shuffled order', () {
      final content = parsed(chooseConfig);
      final s = engine.initialize(content, const EngineSeed(7));
      expect(engine.restore(content, engine.snapshot(s))!.order, s.order);
    });
  });

  group('in the shell', () {
    testWidgets('find: a wrong sentence turns amber, then the right one', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(findConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Le chat de Léa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('passage-sentence-s2')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect((c.current!.state as PassageState).tried, {'s2'});

      await tester.tap(find.byKey(const ValueKey('passage-sentence-s3')));
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

    testWidgets('choose: the passage is only read, the options are picked', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(chooseConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('passage-sentence-s2')));
      await settle(tester);
      expect((c.current!.state as PassageState).selected, isEmpty);

      await tester.tap(find.byKey(const ValueKey('passage-option-a')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });

    testWidgets('AM3: the answers are big and centred', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(chooseConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final tile = tester.widget<AnswerTile>(
        find.byKey(const ValueKey('passage-option-a')),
      );
      expect(tile.prominent, isTrue);
      expect(
        tester.getSize(find.byKey(const ValueKey('passage-option-a'))).height,
        greaterThanOrEqualTo(64),
      );
      c.dispose();
    });

    testWidgets('AM27: on a short screen a ↓ cue shows more below', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (c, _) = controllerFor(chooseConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('scroll-fade')), findsOneWidget);
      final more = find.byKey(const ValueKey('scroll-more'));
      expect(more, findsOneWidget);
      // Tapped until the end: the last answer is reachable, the cue goes.
      for (var i = 0; i < 6 && more.evaluate().isNotEmpty; i++) {
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      expect(more, findsNothing);
      await tester.tap(find.byKey(const ValueKey('passage-option-c')));
      await settle(tester);
      expect((c.current!.state as PassageState).selected, contains('c'));
      c.dispose();
    });

    testWidgets('AM27: a tall screen draws no cue', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(chooseConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('scroll-more')), findsNothing);
      c.dispose();
    });

    testWidgets('several: the count follows what is found', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(multiConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Trouvées : 0 sur 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('passage-sentence-s3')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(find.text('Trouvées : 1 sur 2'), findsOneWidget);
      c.dispose();
    });

    testWidgets('an XP total of 0 draws no chip (a replay pays nothing)', (
      tester,
    ) async {
      tallView(tester);
      for (final (xp, chips) in [(0, 0), (5, 1)]) {
        final (c, _) = controllerFor(findConfig);
        await tester.runAsync(c.start);
        await tester.pumpWidget(
          MaterialApp(
            theme: TutolysTheme.village(),
            home: Scaffold(
              body: LearningActivityView(
                controller: c,
                locale: fr,
                onDone: () {},
                xpEarned: () => xp,
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(chips));
        c.dispose();
      }
    });

    testWidgets('no speaker is drawn when the host offers none', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(findConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      c.dispose();
    });

    testWidgets('a speaker per sentence with audio; tapping it only speaks', (
      tester,
    ) async {
      tallView(tester);
      final speaker = FakeSpeaker();
      final (c, outbox) = controllerFor(findConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, speaker: speaker));
      // s4 has no audio_ref, so 3 speakers for 4 sentences.
      expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(3));
      expect(find.byKey(const ValueKey('passage-speak-4')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('passage-speak-3')));
      await settle(tester);
      expect(speaker.calls, [('audio/s3', 's3')]);
      expect(
        (c.current!.state as PassageState).selected,
        isEmpty,
        reason: 'listening to a sentence never picks it',
      );
      expect(outbox.all.where((e) => e['event_type'] == 'attempt'), isEmpty);
      c.dispose();
    });

    testWidgets('each sentence is named by its place for a screen reader', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(findConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(
        find.bySemanticsLabel('phrase 3 : Pompon dort sur le lit.'),
        findsOneWidget,
      );
      c.dispose();
    });

    testWidgets('keyboard alone can pick a sentence', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(findConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final target = find.byKey(const ValueKey('passage-sentence-s3'));
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null &&
            find
                .descendant(of: target, matching: find.byWidget(focused.widget))
                .evaluate()
                .isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await settle(tester);
          break;
        }
      }
      expect((c.current!.state as PassageState).selected, {'s3'});
      c.dispose();
    });

    testWidgets('a ten-sentence passage fits a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'sentences': [
          for (var i = 1; i <= 10; i++)
            {
              'id': 's$i',
              'text':
                  'Phrase numéro $i, assez longue pour passer à la ligne '
                  'sur un petit écran.',
              'audio_ref': 'audio/s$i',
            },
        ],
        'correct_ids': ['s7'],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, speaker: FakeSpeaker()));
      expect(tester.takeException(), isNull);
      final row = tester.getSize(
        find.byKey(const ValueKey('passage-sentence-s1')),
      );
      expect(row.width, lessThanOrEqualTo(375));
      c.dispose();
    });
  });
}
