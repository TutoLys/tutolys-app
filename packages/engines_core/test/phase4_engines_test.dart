import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// Real published grade-1 configs from the dev-stack, verbatim.
const speedConfig = <String, Object?>{
  'hint': 'Compte 3 de plus après 4.',
  'correct': 'b',
  'options': [
    {'id': 'a', 'label': '6'},
    {'id': 'b', 'label': '7'},
    {'id': 'c', 'label': '8'},
  ],
  'shuffle': true,
  'time_limit_ms': 8000,
};
const pairConfig = <String, Object?>{
  'hint': null,
  'pairs': [
    {
      'left': {'id': 'cinq', 'label': 'cinq'},
      'right': {'id': 'd5', 'label': '5'},
    },
    {
      'left': {'id': 'neuf', 'label': 'neuf'},
      'right': {'id': 'd9', 'label': '9'},
    },
    {
      'left': {'id': 'dix', 'label': 'dix'},
      'right': {'id': 'd10', 'label': '10'},
    },
  ],
  'distractors': [
    {'id': 'd6', 'label': '6'},
  ],
};
const composeConfig = <String, Object?>{
  'hint': 'Cherche deux blocs dont la somme fait 7.',
  'tiles': [
    {'id': 'b1', 'label': '1'},
    {'id': 'b2', 'label': '2'},
    {'id': 'b5', 'label': '5'},
    {'id': 'b3', 'label': '3'},
  ],
  'target': ['b2', 'b5'],
  'ordered': false,
};

Map<String, Object?> envelope(String engineKey, Map<String, Object?> config) =>
    {
      'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
      'version': 1,
      'content_hash': 'h',
      'engine_key': engineKey,
      'engine_min_version': 1,
      'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
      'subject': 'MATH',
      'grade': 1,
      'rank': 0,
      'prompt': {'text': 'Question'},
      'config': config,
    };

final registry = LearningEngineRegistry([
  eraseEngine(const TimedChoiceEngine()),
  eraseEngine(const PairMatchBoardEngine()),
  eraseEngine(const ComposeSlotsEngine()),
]);
const evaluators = EvaluatorRegistry.new;

(ActivitySessionController, InMemoryEventOutbox) controllerFor(
  String key,
  Map<String, Object?> config,
) {
  final outbox = InMemoryEventOutbox();
  return (
    ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(key, config)).valueOrNull!,
      kidId: 'kid',
      engines: registry,
      evaluators: EvaluatorRegistry(const [
        SpeedTapExactEvaluator(),
        PairMatchEvaluator(),
        ComposeBuildEvaluator(),
      ]),
      store: InMemoryActivitySessionStore(outbox),
      appVersion: '0.2.0',
      seed: 3,
    ),
    outbox,
  );
}

Widget app(ActivitySessionController c, {VoidCallback? onDone}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: LearningActivityView(
      controller: c,
      locale: fr,
      onDone: onDone ?? () {},
    ),
  ),
);

/// Let the controller commit (real async), then rebuild. Twice, because
/// work started from a ticker finishes inside the first pump and its
/// rebuild lands on the next.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

/// Move keyboard focus to [target] with Tab alone, as a keyboard-only child
/// would, and fail if it can't be reached.
Future<void> tabTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        find
            .descendant(of: target, matching: find.byWidget(focused.widget))
            .evaluate()
            .isNotEmpty) {
      return;
    }
  }
  fail('Tab never reached $target');
}

Future<void> pressWithKeyboard(WidgetTester tester, Finder target) async {
  await tabTo(tester, target);
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await settle(tester);
}

void main() {
  group('speed_tap — TimedChoiceEngine', () {
    const engine = TimedChoiceEngine();
    final content = engine.parse(speedConfig).valueOrNull!;

    test('parses real content; the time limit is required and bounded', () {
      expect(content.timeLimit, const Duration(seconds: 8));
      expect(
        engine.parse({...speedConfig, 'time_limit_ms': 500}),
        isA<ParseInvalid<TimedChoiceContent>>(),
      );
      expect(
        engine.parse({...speedConfig}..remove('time_limit_ms')),
        isA<ParseInvalid<TimedChoiceContent>>(),
      );
      expect(
        engine.parse({...speedConfig, 'correct': 'z'}),
        isA<ParseInvalid<TimedChoiceContent>>(),
      );
    });

    test('a tap is the answer; a stale TimeUp is ignored; a live one is a no-response answer', () {
      final s0 = engine.initialize(content, const EngineSeed(1));
      expect(
        engine.reduce(s0, const TimeUp(7)).events,
        isEmpty,
        reason: 'another round\'s timer',
      );
      final timed = engine.reduce(s0, const TimeUp(0)).state;
      expect(engine.extractAnswer(timed), isA<NoResponseAnswer>());
      final tapped = engine.reduce(s0, const TapOption('a')).state;
      expect(
        (engine.extractAnswer(tapped)! as SingleChoiceAnswer).selectedOptionId,
        'a',
      );
      expect(
        engine.reduce(tapped, const TapOption('b')).events,
        isEmpty,
        reason: 'one tap per round',
      );
    });

    test(
      'a timeout grades incorrect as a timeout, with no misconception claimed',
      () {
        final r = const SpeedTapExactEvaluator().evaluate(
          content,
          NoResponseAnswer.timeout,
          ctx,
        );
        expect(r.outcome, Outcome.incorrect);
        expect(r.feedbackCode, 'timeout');
        expect(r.errors, isEmpty);
        expect(r.evaluator, 'speed_tap.exact@1');
        expect(
          const SpeedTapExactEvaluator()
              .evaluate(content, const SingleChoiceAnswer('b'), ctx)
              .isCorrect,
          isTrue,
        );
      },
    );

    test('feedback starts a new round and keeps tried options marked; snapshot round-trips', () {
      var s = engine
          .reduce(
            engine.initialize(content, const EngineSeed(1)),
            const TapOption('a'),
          )
          .state;
      s = engine.applyFeedback(
        s,
        const SpeedTapExactEvaluator().evaluate(
          content,
          const SingleChoiceAnswer('a'),
          ctx,
        ),
      );
      expect(s.round, 1);
      expect(s.tried, {'a'});
      expect(engine.reduce(s, const TapOption('a')).events, isEmpty);
      final back = engine.restore(
        content,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.round, 1);
      expect(back.tried, {'a'});
    });

    testWidgets(
      'time runs out → "Temps écoulé !" → a fresh countdown → a tap answers',
      (tester) async {
        final (c, outbox) = controllerFor('speed_tap', {
          ...speedConfig,
          'shuffle': false,
        });
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c));
        expect(
          find.text('VALIDER'),
          findsNothing,
          reason: 'a tap is the answer',
        );

        await tester.pump(const Duration(seconds: 8, milliseconds: 100));
        await settle(tester);
        expect(find.text('Temps écoulé !'), findsOneWidget);

        await tester.tap(find.text('RÉESSAYER'));
        await settle(tester);
        await tester.pump(
          const Duration(seconds: 3),
        ); // well inside the new countdown
        await tester.tap(find.byKey(const ValueKey('speed-option-b')));
        await settle(tester);
        expect(find.text('Bravo !'), findsOneWidget);

        final attempts = outbox.all
            .where((e) => e['event_type'] == 'attempt')
            .toList();
        expect(attempts.first['answer_payload'], {
          'kind': 'no_response',
          'reason': 'timeout',
        });
        expect(attempts.map((e) => e['is_correct']), [false, true]);
        c.dispose();
      },
    );

    testWidgets('the countdown stops while feedback is showing', (
      tester,
    ) async {
      final (c, outbox) = controllerFor('speed_tap', {
        ...speedConfig,
        'shuffle': false,
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('speed-option-a')));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      await settle(tester);
      expect(
        outbox.all.where((e) => e['event_type'] == 'attempt'),
        hasLength(1),
        reason: 'no timeout while waiting',
      );
      c.dispose();
    });

    testWidgets('keyboard alone can answer', (tester) async {
      final (c, _) = controllerFor('speed_tap', {
        ...speedConfig,
        'shuffle': false,
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('speed-option-b')),
      );
      expect(c.state.lastOutcome, Outcome.correct);
      c.dispose();
    });
  });

  group('pair_match — PairMatchBoardEngine', () {
    const engine = PairMatchBoardEngine();
    final content = engine.parse(pairConfig).valueOrNull!;

    test('parses real content, distractors joining the right column', () {
      expect(content.lefts.map((i) => i.id), ['cinq', 'neuf', 'dix']);
      expect(
        content.rights.map((i) => i.id),
        containsAll(['d5', 'd9', 'd10', 'd6']),
      );
      expect(
        engine.parse({'pairs': []}),
        isA<ParseInvalid<PairMatchContent>>(),
      );
    });

    test(
      'pair, move a right item to another pair, undo by tapping the left again',
      () {
        var s = engine.initialize(content, const EngineSeed(1));
        s = engine.reduce(s, const TapLeft('cinq')).state;
        final t = engine.reduce(s, const TapRight('d5'));
        expect(t.events.single.payload, {'left_id': 'cinq', 'right_id': 'd5'});
        s = t.state;
        s = engine.reduce(s, const TapLeft('neuf')).state;
        s = engine.reduce(s, const TapRight('d5')).state; // d5 moves to neuf
        expect(s.links, {'neuf': 'd5'});
        final undo = engine.reduce(s, const TapLeft('neuf'));
        expect(undo.state.links, isEmpty);
        expect(undo.events.single.type, 'pair_disconnected');
        expect(
          engine
              .reduce(
                engine.initialize(content, const EngineSeed(1)),
                const TapRight('d5'),
              )
              .events,
          isEmpty,
          reason: 'a right item needs a left one first',
        );
      },
    );

    test('submittable only once every left item is paired', () {
      var s = engine.initialize(content, const EngineSeed(1));
      for (final (l, r) in [('cinq', 'd5'), ('neuf', 'd9')]) {
        s = engine
            .reduce(engine.reduce(s, TapLeft(l)).state, TapRight(r))
            .state;
      }
      expect(engine.extractAnswer(s), isNull);
      s = engine
          .reduce(
            engine.reduce(s, const TapLeft('dix')).state,
            const TapRight('d6'),
          )
          .state;
      expect(engine.extractAnswer(s)!.pairs, hasLength(3));
    });

    test('partial credit: right pairs lock, wrong ones come apart', () {
      var s = engine.initialize(content, const EngineSeed(1));
      for (final (l, r) in [('cinq', 'd5'), ('neuf', 'd9'), ('dix', 'd6')]) {
        s = engine
            .reduce(engine.reduce(s, TapLeft(l)).state, TapRight(r))
            .state;
      }
      final r = const PairMatchEvaluator().evaluate(
        content,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.score, closeTo(2 / 3, 1e-9));
      expect(r.itemResults, {'cinq': true, 'neuf': true, 'dix': false});
      s = engine.applyFeedback(s, r);
      expect(s.locked, {'cinq', 'neuf'});
      expect(s.links, {'cinq': 'd5', 'neuf': 'd9'});
      expect(
        engine.reduce(s, const TapLeft('cinq')).events,
        isEmpty,
        reason: 'locked',
      );
      final back = engine.restore(
        content,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.locked, s.locked);
    });

    testWidgets('one wrong pair → partial "Presque" → fix it → Bravo', (
      tester,
    ) async {
      final (c, outbox) = controllerFor('pair_match', pairConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      for (final (l, r) in [('cinq', 'd5'), ('neuf', 'd9'), ('dix', 'd6')]) {
        await tester.tap(find.byKey(ValueKey('pair-left-$l')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('pair-right-$r')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      expect(find.textContaining('Certaines sont justes'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(
        tester
            .widget<AnswerTile>(find.byKey(const ValueKey('pair-left-cinq')))
            .state,
        AnswerTileState.correct,
      );

      await tester.tap(find.byKey(const ValueKey('pair-left-dix')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('pair-right-d10')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .toList();
      expect(attempts, hasLength(2), reason: 'one attempt per checked board');
      expect(attempts.map((e) => e['is_correct']), [false, true]);
      c.dispose();
    });

    testWidgets('keyboard alone can pair', (tester) async {
      final (c, _) = controllerFor('pair_match', pairConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('pair-left-cinq')),
      );
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('pair-right-d5')),
      );
      expect((c.current!.state as PairMatchState).links, {'cinq': 'd5'});
      c.dispose();
    });
  });

  group('compose_build — ComposeSlotsEngine', () {
    const engine = ComposeSlotsEngine();
    final content = engine.parse(composeConfig).valueOrNull!;

    test('parses real content; ordered defaults to true; a tile used twice is refused', () {
      expect(content.ordered, isFalse);
      expect(
        engine
            .parse({...composeConfig}..remove('ordered'))
            .valueOrNull!
            .ordered,
        isTrue,
      );
      expect(
        engine.parse({
          ...composeConfig,
          'target': ['b2', 'b2'],
        }),
        isA<ParseInvalid<ComposeContent>>(),
      );
      expect(
        engine.parse({
          ...composeConfig,
          'target': ['zz'],
        }),
        isA<ParseInvalid<ComposeContent>>(),
      );
    });

    test('tiles fill the next slot, a filled slot sends its tile back', () {
      var s = engine.initialize(content, const EngineSeed(1));
      s = engine.reduce(s, const PlaceTile('b5')).state;
      s = engine.reduce(s, const PlaceTile('b1')).state;
      expect(s.slots, ['b5', 'b1']);
      expect(
        engine.reduce(s, const PlaceTile('b2')).events,
        isEmpty,
        reason: 'no empty slot',
      );
      expect(
        engine.reduce(s, const PlaceTile('b5')).events,
        isEmpty,
        reason: 'already placed',
      );
      s = engine.reduce(s, const ClearSlot(1)).state;
      expect(s.slots, ['b5', null]);
    });

    test('unordered and ordered grading, with per-slot verdicts', () {
      final unordered = const ComposeBuildEvaluator().evaluate(
        content,
        OrderingAnswer(['b5', 'b1']),
        ctx,
      );
      expect(unordered.outcome, Outcome.partial);
      expect(unordered.itemResults, {'0': true, '1': false});
      expect(
        const ComposeBuildEvaluator()
            .evaluate(content, OrderingAnswer(['b5', 'b2']), ctx)
            .isCorrect,
        isTrue,
      );

      final ordered = engine.parse({
        ...composeConfig,
        'ordered': true,
      }).valueOrNull!;
      final r = const ComposeBuildEvaluator().evaluate(
        ordered,
        OrderingAnswer(['b5', 'b2']),
        ctx,
      );
      expect(r.outcome, Outcome.incorrect, reason: 'right tiles, wrong order');
    });

    testWidgets('5 and 1 → partial → the 5 stays, swap in the 2 → Bravo', (
      tester,
    ) async {
      final (c, _) = controllerFor('compose_build', composeConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('compose-tile-b5')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('compose-tile-b1')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.textContaining('Certaines sont justes'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect((c.current!.state as ComposeState).slots, ['b5', null]);

      await tester.tap(find.byKey(const ValueKey('compose-tile-b2')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });

    testWidgets('keyboard alone can build', (tester) async {
      final (c, _) = controllerFor('compose_build', composeConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('compose-tile-b2')),
      );
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('compose-tile-b5')),
      );
      expect((c.current!.state as ComposeState).full, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(c.state.lastOutcome, Outcome.correct);
      c.dispose();
    });
  });

  test(
    'all four launch engines resolve on the new contract with their evaluators',
    () {
      final all = LearningEngineRegistry([
        eraseEngine(const SingleChoiceEngine()),
        eraseEngine(const TimedChoiceEngine()),
        eraseEngine(const PairMatchBoardEngine()),
        eraseEngine(const ComposeSlotsEngine()),
      ]);
      for (final key in ['mcq', 'speed_tap', 'pair_match', 'compose_build']) {
        expect(all.contains(key), isTrue, reason: key);
      }
      expect(evaluators, isNotNull);
    },
  );
}
