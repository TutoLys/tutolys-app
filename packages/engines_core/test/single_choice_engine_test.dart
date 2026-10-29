import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = SingleChoiceEngine();
const evaluator = McqExactEvaluator();

/// A real published grade-1 exercise's config, verbatim from the dev-stack.
const triangle = <String, Object?>{
  'hint': 'Un triangle a trois côtés.',
  'correct': 'b',
  'options': [
    {'id': 'a', 'label': '⬛'},
    {'id': 'b', 'label': '▲'},
    {'id': 'c', 'label': '⚪'},
  ],
  'shuffle': true,
};

SingleChoiceContent content([Map<String, Object?> config = triangle]) =>
    engine.parse(config).valueOrNull!;

void main() {
  group('parse', () {
    test('accepts real published content', () {
      final c = content();
      expect(c.options.map((o) => o.id), ['a', 'b', 'c']);
      expect(c.correct, 'b');
      expect(c.shuffle, isTrue);
    });

    test('rejects what the backend schema rejects', () {
      Map<String, Object?> withOptions(int n) => {
        'options': [
          for (var i = 0; i < n; i++) {'id': 'o$i', 'label': 'L$i'},
        ],
        'correct': 'o0',
      };
      expect(
        engine.parse(withOptions(1)),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
      expect(
        engine.parse(withOptions(7)),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
      expect(
        engine.parse({...triangle, 'correct': 'z'}),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
      expect(
        engine.parse({...triangle, 'shuffle': 'yes'}),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
      expect(
        engine.parse({
          'options': [
            {'id': 'a', 'label': 'x'},
            {'id': 'a', 'label': 'y'},
          ],
          'correct': 'a',
        }),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
      expect(
        engine.parse({
          'options': [
            {'id': 'a', 'label': ''},
            {'id': 'b', 'label': 'y'},
          ],
          'correct': 'a',
        }),
        isA<ParseInvalid<SingleChoiceContent>>(),
      );
    });

    test(
      'reads an optional declared diagnosis, and ignores a malformed one',
      () {
        final c = content({
          'options': [
            {
              'id': 'a',
              'label': '10',
              'diagnosis': {
                'code': 'math.add.no_regroup',
                'taxonomy_version': 1,
              },
            },
            {'id': 'b', 'label': '12'},
            {
              'id': 'c',
              'label': '13',
              'diagnosis': {'code': 7},
            },
          ],
          'correct': 'b',
        });
        expect(c.option('a')!.diagnosis!.code, 'math.add.no_regroup');
        expect(c.option('c')!.diagnosis, isNull);
      },
    );
  });

  group('initialize', () {
    test('the same seed always gives the same order', () {
      final c = content();
      expect(
        engine.initialize(c, const EngineSeed(42)).order,
        engine.initialize(c, const EngineSeed(42)).order,
      );
    });

    test('some seed reorders the options; shuffle:false never does', () {
      final c = content();
      final orders = {
        for (var s = 0; s < 20; s++)
          engine.initialize(c, EngineSeed(s)).order.join(),
      };
      expect(orders.length, greaterThan(1));
      final fixed = content({...triangle, 'shuffle': false});
      for (var s = 0; s < 20; s++) {
        expect(engine.initialize(fixed, EngineSeed(s)).order, ['a', 'b', 'c']);
      }
    });
  });

  group('reduce', () {
    final c = content();
    final start = engine.initialize(c, const EngineSeed(1));

    test(
      'selecting emits an id-only event and makes the answer submittable',
      () {
        final t = engine.reduce(start, const SelectOption('a'));
        expect(t.state.selected, 'a');
        expect(engine.extractAnswer(t.state)!.selectedOptionId, 'a');
        expect(t.events.single.type, 'option_selected');
        expect(
          jsonEncode(t.events.single.payload),
          isNot(contains('⬛')),
          reason: 'ids, never labels',
        );
      },
    );

    test('changing one\'s mind names what was replaced', () {
      final a = engine.reduce(start, const SelectOption('a')).state;
      final t = engine.reduce(a, const SelectOption('c'));
      expect(t.events.single.payload, {
        'option_id': 'c',
        'replaced_option_id': 'a',
      });
    });

    test('meaningless actions change nothing and say nothing', () {
      final a = engine.reduce(start, const SelectOption('a')).state;
      for (final (state, action) in [
        (a, const SelectOption('a')), // already selected
        (start, const SelectOption('zz')), // not an option
      ]) {
        final t = engine.reduce(state, action);
        expect(identical(t.state, state), isTrue);
        expect(t.events, isEmpty);
      }
      expect(
        engine.extractAnswer(start),
        isNull,
        reason: 'nothing to submit yet',
      );
    });
  });

  group('feedback', () {
    final c = content();
    final a = engine
        .reduce(
          engine.initialize(c, const EngineSeed(1)),
          const SelectOption('a'),
        )
        .state;

    EvaluationResult grade(String id, {int attempt = 1}) => evaluator.evaluate(
      c,
      SingleChoiceAnswer(id),
      EvaluationContext(attemptNumber: attempt, skillNodeIds: const ['s']),
    );

    test('a wrong answer is marked tried and can\'t be picked again', () {
      final s = engine.applyFeedback(a, grade('a'));
      expect(s.tried, {'a'});
      expect(s.selected, isNull);
      expect(engine.reduce(s, const SelectOption('a')).events, isEmpty);
    });

    test('a right answer solves the question and stops further answers', () {
      final b = engine.reduce(a, const SelectOption('b')).state;
      final s = engine.applyFeedback(b, grade('b'));
      expect(s.solved, isTrue);
      expect(engine.extractAnswer(s), isNull);
      expect(engine.reduce(s, const SelectOption('c')).events, isEmpty);
    });

    test('an ungraded result never marks the child\'s choice as tried', () {
      final s = engine.applyFeedback(
        a,
        const EvaluationResult.failed(attemptNumber: 1, evaluator: 'x'),
      );
      expect(s.tried, isEmpty);
    });
  });

  group('snapshot', () {
    final c = content();

    test('round-trips', () {
      var s = engine
          .reduce(
            engine.initialize(c, const EngineSeed(5)),
            const SelectOption('a'),
          )
          .state;
      s = engine.applyFeedback(
        s,
        evaluator.evaluate(
          c,
          const SingleChoiceAnswer('a'),
          const EvaluationContext(attemptNumber: 1, skillNodeIds: []),
        ),
      );
      final back = engine.restore(
        c,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.order, s.order);
      expect(back.tried, s.tried);
      expect(back.selected, s.selected);
    });

    test('a snapshot of other content is refused, not guessed at', () {
      expect(
        engine.restore(c, {
          'order': ['x', 'y', 'z'],
        }),
        isNull,
      );
      expect(
        engine.restore(c, {
          'order': ['a', 'b', 'c'],
          'selected': 'q',
        }),
        isNull,
      );
      expect(engine.restore(c, {'nonsense': true}), isNull);
    });
  });

  group('McqExactEvaluator', () {
    final c = content({
      'options': [
        {
          'id': 'a',
          'label': '10',
          'diagnosis': {'code': 'math.add.no_regroup', 'taxonomy_version': 1},
        },
        {'id': 'b', 'label': '12'},
        {'id': 'c', 'label': '13'},
      ],
      'correct': 'b',
    });
    const ctx = EvaluationContext(attemptNumber: 2, skillNodeIds: ['skill-1']);

    test('right is correct, scored 1, with no errors', () {
      final r = evaluator.evaluate(c, const SingleChoiceAnswer('b'), ctx);
      expect(r.outcome, Outcome.correct);
      expect(r.score, 1);
      expect(r.errors, isEmpty);
      expect(r.evaluator, 'mcq.exact@1');
      expect(r.authority, EvaluationAuthority.local);
      expect(r.attemptNumber, 2);
      expect(r.skillNodeIds, ['skill-1']);
    });

    test('a wrong option carries its declared diagnosis, or unclassified', () {
      expect(
        evaluator
            .evaluate(c, const SingleChoiceAnswer('a'), ctx)
            .errors
            .single
            .code,
        'math.add.no_regroup',
      );
      expect(
        evaluator
            .evaluate(c, const SingleChoiceAnswer('c'), ctx)
            .errors
            .single
            .isUnclassified,
        isTrue,
      );
    });

    test('an answer naming no option is a bug, and throws (the runtime records it ungraded)', () {
      expect(
        () => evaluator.evaluate(c, const SingleChoiceAnswer('zz'), ctx),
        throwsArgumentError,
      );
    });
  });

  group('in the shell, through the real controller', () {
    Map<String, Object?> envelope() => {
      'exercise_id': '1c3d6d41-a465-42be-b3a9-c1dc8460e24c',
      'version': 1,
      'content_hash': 'h',
      'engine_key': 'mcq',
      'engine_min_version': 1,
      'skill_node_id': '5a221f09-99f7-597e-bc4a-34e7ccafaa3b',
      'subject': 'MATH',
      'grade': 1,
      'rank': 0,
      'prompt': {'text': 'Quelle figure est un triangle ?'},
      'config': {...triangle, 'shuffle': false},
    };

    late InMemoryEventOutbox outbox;

    ActivitySessionController build() {
      outbox = InMemoryEventOutbox();
      return ActivitySessionController(
        envelope: QuestionEnvelope.parse(envelope()).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(engine)]),
        evaluators: EvaluatorRegistry(const [evaluator]),
        store: InMemoryActivitySessionStore(outbox),
        appVersion: '0.2.0',
        seed: 1,
      );
    }

    Future<void> step(WidgetTester tester) async {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
    }

    Widget app(ActivitySessionController c, VoidCallback onDone) => MaterialApp(
      theme: TutolysTheme.village(),
      home: Scaffold(
        body: LearningActivityView(
          controller: c,
          locale: const Locale('fr'),
          onDone: onDone,
        ),
      ),
    );

    testWidgets(
      'wrong, Presque, the tried tile stays marked, right, Bravo, done',
      (tester) async {
        final c = build();
        var done = false;
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c, () => done = true));

        await tester.tap(find.byKey(const ValueKey('mcq-option-a')));
        await step(tester);
        await tester.tap(find.text('VALIDER'));
        await step(tester);
        expect(find.text('Presque !'), findsOneWidget);
        await tester.tap(find.text('RÉESSAYER'));
        await step(tester);

        final tried = tester.widget<AnswerTile>(
          find.byKey(const ValueKey('mcq-option-a')),
        );
        expect(tried.state, AnswerTileState.retry);
        expect(
          tried.onTap,
          isNull,
          reason: 'a tried option can\'t be picked again',
        );

        await tester.tap(find.byKey(const ValueKey('mcq-option-b')));
        await step(tester);
        await tester.tap(find.text('VALIDER'));
        await step(tester);
        expect(find.text('Bravo !'), findsOneWidget);
        expect(
          tester
              .widget<AnswerTile>(find.byKey(const ValueKey('mcq-option-b')))
              .state,
          AnswerTileState.correct,
        );

        await tester.tap(find.text('CONTINUER'));
        await step(tester);
        await tester.pump();
        expect(done, isTrue);

        final attempts = outbox.all
            .where((e) => e['event_type'] == 'attempt')
            .toList();
        expect(attempts.map((e) => e['is_correct']), [false, true]);
        expect(attempts.first['answer_payload'], {
          'kind': 'single_choice',
          'selected': 'a',
        });
        expect(attempts.first['engine_key'], 'mcq');
        c.dispose();
      },
    );

    testWidgets(
      'keyboard alone can answer: Tab to a tile, Enter to pick, Tab to '
      'VALIDER, Enter to check (UX review G6)',
      (tester) async {
        final c = build();
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c, () {}));

        // Focus walks the shell's controls then the tiles; find tile "b".
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .descendant(
                    of: find.byKey(const ValueKey('mcq-option-b')),
                    matching: find.byWidget(focused.widget),
                  )
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
        }
        // Enter on a focused tile picks it; it doesn't check (G6).
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await step(tester);
        expect(
          (c.current!.answer as SingleChoiceAnswer?)?.selectedOptionId,
          'b',
        );
        expect(c.state.lastOutcome, isNull);

        // Tab on to VALIDER, then Enter checks.
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .descendant(
                    of: find.byKey(const ValueKey('validate')),
                    matching: find.byWidget(focused.widget),
                  )
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await step(tester);
        expect(c.state.lastOutcome, Outcome.correct);
        c.dispose();
      },
    );
  });
}
