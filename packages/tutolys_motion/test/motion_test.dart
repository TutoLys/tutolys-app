import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

const _ms = Duration(milliseconds: 1);

ReactionCue _cue(
  Reaction r,
  CuePriority p, {
  Duration? hold = const Duration(milliseconds: 900),
  Reaction returnTo = Reaction.idle,
}) => ReactionCue(
  role: ActorRole.guide,
  reaction: r,
  priority: p,
  hold: hold,
  returnTo: returnTo,
);

EvaluationResult _eval(Outcome o) => EvaluationResult(
  outcome: o,
  score: o == Outcome.correct ? 1 : 0,
  attemptNumber: 1,
  evaluator: 'e',
);

void main() {
  group('CharacterManifest.resolve', () {
    final fox = CharacterManifest(
      id: 'fox',
      version: 1,
      rendererType: RendererType.placeholder,
      supported: {
        Reaction.thinking,
        Reaction.celebrating,
        Reaction.encouraging,
      },
      fallbacks: {
        Reaction.victory: Reaction.celebrating,
        Reaction.explaining: Reaction.thinking,
        Reaction.curious:
            Reaction.explaining, // chain: curious → explaining → thinking
        Reaction.sleeping:
            Reaction.waiting, // dead end: waiting unsupported, unmapped
        Reaction.speaking: Reaction.listening,
        Reaction.listening: Reaction.speaking, // cycle
      },
    );

    test('supported reactions resolve to themselves, idle always works', () {
      expect(fox.resolve(Reaction.thinking), Reaction.thinking);
      expect(fox.resolve(Reaction.idle), Reaction.idle);
    });

    test('fallbacks are followed, chains included', () {
      expect(fox.resolve(Reaction.victory), Reaction.celebrating);
      expect(fox.resolve(Reaction.curious), Reaction.thinking);
    });

    test('a dead end or a cycle lands on idle instead of failing', () {
      expect(fox.resolve(Reaction.sleeping), Reaction.idle);
      expect(fox.resolve(Reaction.speaking), Reaction.idle);
    });
  });

  group('CharacterRegistry', () {
    test(
      'a renderer type that is not installed falls back to the placeholder',
      () {
        final placeholder = _FakeRenderer(RendererType.placeholder);
        final rive = CharacterManifest(
          id: 'robot',
          version: 1,
          rendererType: RendererType.rive,
          supported: const {},
        );
        final registry = CharacterRegistry(
          manifests: [rive],
          renderers: [placeholder],
        );
        expect(registry.manifest('robot'), same(rive));
        expect(registry.rendererFor(rive), same(placeholder));
        expect(registry.manifest('nobody'), isNull);
      },
    );

    test('swapping a renderer is a registry change, not a manifest or engine change', () {
      final manifest = CharacterManifest(
        id: 'fox',
        version: 1,
        rendererType: RendererType.rive,
        supported: const {},
      );
      final rive = _FakeRenderer(RendererType.rive);
      final registry = CharacterRegistry(
        manifests: [manifest],
        renderers: [_FakeRenderer(RendererType.placeholder), rive],
      );
      expect(registry.rendererFor(manifest), same(rive));
    });
  });

  group('DefaultReactionPolicy', () {
    const policy = DefaultReactionPolicy();

    test('a correct answer celebrates as learning feedback', () {
      final cues = policy.onEvent(
        AnswerEvaluated(questionIndex: 0, result: _eval(Outcome.correct)),
      );
      final guide = cues.firstWhere((c) => c.role == ActorRole.guide);
      expect(guide.reaction, Reaction.celebrating);
      expect(guide.priority, CuePriority.learningFeedback);
    });

    test('a wrong or partial answer encourages, never anything else', () {
      for (final o in [Outcome.incorrect, Outcome.partial]) {
        final cues = policy.onEvent(
          AnswerEvaluated(questionIndex: 0, result: _eval(o)),
        );
        expect(cues.map((c) => c.reaction), [
          Reaction.encouraging,
        ], reason: '$o');
      }
    });

    test('completing the activity is critical and involves every role', () {
      final cues = policy.onEvent(
        const ActivityCompleted(questionsCompleted: 2, questionsSolved: 2),
      );
      expect(cues.map((c) => c.role).toSet(), ActorRole.values.toSet());
      expect(cues.every((c) => c.priority == CuePriority.critical), isTrue);
    });

    test('diagnostics and unknown interactions produce no reaction', () {
      expect(policy.onEvent(const SessionFailed('x')), isEmpty);
      expect(
        policy.onEvent(const AnimationDiagnostic('renderer_error')),
        isEmpty,
      );
      expect(policy.onEvent(const InteractionEvent('tile_moved')), isEmpty);
    });
  });

  group('ActorScheduler', () {
    test('a cue holds, then returns to idle', () {
      final s = ActorScheduler(idle: Reaction.idle);
      expect(
        s.offer(
          _cue(Reaction.celebrating, CuePriority.learningFeedback),
          Duration.zero,
        ),
        isTrue,
      );
      expect(s.reaction, Reaction.celebrating);
      expect(s.expire(const Duration(milliseconds: 899)), isFalse);
      expect(s.expire(const Duration(milliseconds: 900)), isTrue);
      expect(s.reaction, Reaction.idle);
    });

    test('important feedback interrupts decoration; decoration cannot interrupt feedback', () {
      final s = ActorScheduler(idle: Reaction.idle);
      s.offer(_cue(Reaction.curious, CuePriority.decorative), Duration.zero);
      expect(
        s.offer(
          _cue(Reaction.encouraging, CuePriority.learningFeedback),
          _ms * 10,
        ),
        isTrue,
      );
      expect(
        s.offer(_cue(Reaction.curious, CuePriority.decorative), _ms * 20),
        isFalse,
      );
      expect(s.reaction, Reaction.encouraging);
    });

    test('once a hold expires, a lower cue is accepted again', () {
      final s = ActorScheduler(idle: Reaction.idle);
      s.offer(
        _cue(Reaction.encouraging, CuePriority.learningFeedback),
        Duration.zero,
      );
      expect(
        s.offer(
          _cue(Reaction.curious, CuePriority.decorative),
          const Duration(seconds: 1),
        ),
        isTrue,
      );
    });

    test('returnTo settles at ambient priority so anything can replace it', () {
      final s = ActorScheduler(idle: Reaction.idle);
      s.offer(
        _cue(
          Reaction.celebrating,
          CuePriority.critical,
          returnTo: Reaction.waiting,
        ),
        Duration.zero,
      );
      s.expire(const Duration(seconds: 1));
      expect(s.reaction, Reaction.waiting);
      expect(s.currentPriority, CuePriority.ambient);
      expect(
        s.offer(
          _cue(Reaction.curious, CuePriority.decorative),
          const Duration(seconds: 1),
        ),
        isTrue,
      );
    });

    test('a stale release never cancels a newer cue', () {
      final s = ActorScheduler(idle: Reaction.idle);
      s.offer(
        _cue(Reaction.speaking, CuePriority.interaction, hold: null),
        Duration.zero,
      );
      final speakingGen = s.generation;
      s.offer(
        _cue(Reaction.celebrating, CuePriority.learningFeedback),
        _ms * 5,
      );
      expect(s.release(speakingGen), isFalse);
      expect(s.reaction, Reaction.celebrating);
    });

    test('an open-ended cue stays until released', () {
      final s = ActorScheduler(idle: Reaction.idle);
      s.offer(
        _cue(Reaction.speaking, CuePriority.interaction, hold: null),
        Duration.zero,
      );
      expect(s.expire(const Duration(hours: 1)), isFalse);
      expect(s.release(s.generation), isTrue);
      expect(s.reaction, Reaction.idle);
    });

    test('every accepted change bumps the generation', () {
      final s = ActorScheduler(idle: Reaction.idle);
      final g0 = s.generation;
      s.offer(_cue(Reaction.thinking, CuePriority.interaction), Duration.zero);
      s.reset();
      expect(s.generation, g0 + 2);
      expect(s.reaction, Reaction.idle);
    });
  });
}

class _FakeRenderer implements CharacterRenderer {
  _FakeRenderer(this.type);
  @override
  final RendererType type;
  @override
  Widget build(BuildContext context, CharacterActorState state) =>
      const SizedBox();
}
