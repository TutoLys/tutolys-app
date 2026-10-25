import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

EvaluationResult _eval(Outcome o) => EvaluationResult(
  outcome: o,
  score: o == Outcome.correct ? 1 : 0,
  attemptNumber: 1,
  evaluator: 'e',
);

class _ThrowingPolicy implements ReactionPolicy {
  @override
  List<ReactionCue> onEvent(RuntimeEvent event) =>
      throw StateError('policy bug');
}

class _ThrowingRenderer implements CharacterRenderer {
  @override
  RendererType get type => RendererType.rive;
  @override
  Widget build(BuildContext context, CharacterActorState state) =>
      throw StateError('no rive');
}

class _LabelRenderer implements CharacterRenderer {
  @override
  RendererType get type => RendererType.rive;
  @override
  Widget build(BuildContext context, CharacterActorState state) =>
      Text('rive:${state.reaction.name}', textDirection: TextDirection.ltr);
}

void main() {
  final robot = CharacterManifest(
    id: 'robot',
    version: 1,
    rendererType: RendererType.rive,
    supported: {Reaction.celebrating},
  );

  CharacterRegistry registry([List<CharacterRenderer>? renderers]) =>
      CharacterRegistry(
        manifests: [PlaceholderCharacterRenderer.fox, robot],
        renderers: renderers ?? [const PlaceholderCharacterRenderer()],
      );

  test('a correct answer makes the guide celebrate, then rest — on the director\'s clock', () {
    fakeAsync((async) {
      final events = StreamController<RuntimeEvent>.broadcast();
      var now = Duration.zero;
      final d = AnimationDirector(
        events: events.stream,
        cast: const CastAssignment({ActorRole.guide: 'fox'}),
        registry: registry(),
        clock: () => now,
      );
      events.add(
        AnswerEvaluated(questionIndex: 0, result: _eval(Outcome.correct)),
      );
      async.flushMicrotasks();
      expect(d.actor(ActorRole.guide)!.value.reaction, Reaction.celebrating);

      now = const Duration(milliseconds: 900);
      async.elapse(const Duration(milliseconds: 900));
      expect(d.actor(ActorRole.guide)!.value.reaction, Reaction.idle);
      d.dispose();
    });
  });

  test(
    'two actors react independently; an unsupported reaction falls back',
    () {
      fakeAsync((async) {
        final events = StreamController<RuntimeEvent>.broadcast();
        final d = AnimationDirector(
          events: events.stream,
          cast: const CastAssignment({
            ActorRole.guide: 'fox',
            ActorRole.companion: 'robot',
          }),
          registry: registry(),
        );
        events.add(
          const ActivityCompleted(questionsCompleted: 1, questionsSolved: 1),
        );
        async.flushMicrotasks();
        // fox has no `victory` → celebrating; robot supports celebrating.
        expect(d.actor(ActorRole.guide)!.value.reaction, Reaction.celebrating);
        expect(
          d.actor(ActorRole.companion)!.value.reaction,
          Reaction.celebrating,
        );

        events.add(
          AnswerEvaluated(questionIndex: 0, result: _eval(Outcome.incorrect)),
        );
        async.flushMicrotasks();
        // Critical outranks learning feedback until it expires.
        expect(d.actor(ActorRole.guide)!.value.reaction, Reaction.celebrating);
        d.dispose();
      });
    },
  );

  test(
    'a missing character or a throwing policy is a diagnostic, not a crash',
    () async {
      final events = StreamController<RuntimeEvent>.broadcast();
      final diagnostics = <AnimationDiagnostic>[];
      final d = AnimationDirector(
        events: events.stream,
        cast: const CastAssignment({
          ActorRole.guide: 'fox',
          ActorRole.companion: 'nobody',
        }),
        registry: registry(),
        policy: _ThrowingPolicy(),
      );
      d.diagnostics.listen(diagnostics.add);
      events.add(const QuestionPresented(questionIndex: 0, questionCount: 1));
      await pumpEventQueue();
      expect(d.actor(ActorRole.companion), isNull);
      expect(diagnostics.map((e) => e.type), contains('policy_error'));
      expect(diagnostics.every((e) => !e.category.isDurable), isTrue);
      d.dispose();
    },
  );

  test('reduced motion reaches the renderer state', () async {
    final events = StreamController<RuntimeEvent>.broadcast();
    final d = AnimationDirector(
      events: events.stream,
      cast: const CastAssignment({ActorRole.guide: 'fox'}),
      registry: registry(),
    );
    expect(d.actor(ActorRole.guide)!.value.reducedMotion, isFalse);
    d.reducedMotion = true;
    expect(d.actor(ActorRole.guide)!.value.reducedMotion, isTrue);
    d.dispose();
  });

  test(
    'placeholder maps encouragement to the gold pose, never the red one',
    () {
      expect(
        PlaceholderCharacterRenderer.moodFor(Reaction.encouraging),
        MascotMood.hint,
      );
      for (final r in Reaction.values) {
        expect(
          PlaceholderCharacterRenderer.moodFor(r),
          isNot(MascotMood.incorrect),
          reason: '$r',
        );
      }
    },
  );

  testWidgets('swapping in another renderer changes nothing but the drawing', (
    tester,
  ) async {
    final events = StreamController<RuntimeEvent>.broadcast();
    final reg = registry([
      const PlaceholderCharacterRenderer(),
      _LabelRenderer(),
    ]);
    final d = AnimationDirector(
      events: events.stream,
      cast: const CastAssignment({ActorRole.companion: 'robot'}),
      registry: reg,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterStage(
          director: d,
          registry: reg,
          role: ActorRole.companion,
        ),
      ),
    );
    expect(find.text('rive:idle'), findsOneWidget);
    events.add(
      const ActivityCompleted(questionsCompleted: 1, questionsSolved: 1),
    );
    await tester.pump();
    expect(find.text('rive:celebrating'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    d.dispose();
  });

  testWidgets('a renderer that throws draws nothing and breaks nothing', (
    tester,
  ) async {
    final events = StreamController<RuntimeEvent>.broadcast();
    final reg = registry([_ThrowingRenderer()]);
    final d = AnimationDirector(
      events: events.stream,
      cast: const CastAssignment({ActorRole.companion: 'robot'}),
      registry: reg,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            CharacterStage(
              director: d,
              registry: reg,
              role: ActorRole.companion,
            ),
            const Text('the question'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('the question'), findsOneWidget);
    d.dispose();
  });

  testWidgets('the placeholder fox renders from the stage', (tester) async {
    final events = StreamController<RuntimeEvent>.broadcast();
    final reg = registry();
    final d = AnimationDirector(
      events: events.stream,
      cast: const CastAssignment({ActorRole.guide: 'fox'}),
      registry: reg,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TutolysTheme.village(),
        home: CharacterStage(director: d, registry: reg),
      ),
    );
    expect(find.byType(TutolysMascot), findsOneWidget);
    d.dispose();
  });
}
