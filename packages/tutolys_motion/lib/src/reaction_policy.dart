import 'package:engine_sdk/engine_sdk.dart';

import 'engine_moments.dart';
import 'reaction.dart';

/// Maps runtime events to character cues. Pure.
abstract interface class ReactionPolicy {
  List<ReactionCue> onEvent(RuntimeEvent event);
}

/// The default mapping, before any character-specific personality.
///
/// A wrong answer gets `encouraging`, never anything that reads as
/// disappointment: the design's Decision Log rules out failure states, and a
/// grade-1 child who feels judged stops trying.
class DefaultReactionPolicy implements ReactionPolicy {
  const DefaultReactionPolicy();

  @override
  List<ReactionCue> onEvent(RuntimeEvent event) => switch (event) {
    QuestionPresented() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.curious,
        priority: CuePriority.interaction,
      ),
    ],
    AudioRequested(part: SpeechPart.prompt) => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.speaking,
        priority: CuePriority.interaction,
        hold: null,
      ),
    ],
    AnswerSubmitted() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.thinking,
        priority: CuePriority.interaction,
        hold: null,
      ),
    ],
    AnswerEvaluated(:final result) => switch (result.outcome) {
      Outcome.correct => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.celebrating,
          priority: CuePriority.learningFeedback,
        ),
        ReactionCue(
          role: ActorRole.companion,
          reaction: Reaction.celebrating,
          priority: CuePriority.decorative,
        ),
      ],
      Outcome.partial || Outcome.incorrect => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.encouraging,
          priority: CuePriority.learningFeedback,
        ),
      ],
      // Nothing for the child to react to: the failure was ours.
      Outcome.ungraded => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.idle,
          priority: CuePriority.learningFeedback,
        ),
      ],
    },
    HintRequested() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.explaining,
        priority: CuePriority.interaction,
      ),
    ],
    ActivityCompleted() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.victory,
        priority: CuePriority.critical,
        hold: Duration(milliseconds: 1600),
      ),
      ReactionCue(
        role: ActorRole.companion,
        reaction: Reaction.celebrating,
        priority: CuePriority.critical,
        hold: Duration(milliseconds: 1600),
      ),
    ],
    SessionPaused() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.waiting,
        priority: CuePriority.critical,
        hold: null,
      ),
    ],
    SessionResumed() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.idle,
        priority: CuePriority.critical,
      ),
    ],
    // A combo: the companion joins in, on top of the guide's own
    // celebration of the answer.
    StreakAdvanced() => const [
      ReactionCue(
        role: ActorRole.companion,
        reaction: Reaction.celebrating,
        priority: CuePriority.decorative,
        hold: Duration(milliseconds: 1200),
      ),
    ],
    // Nothing touched for a while: the guide shows the way.
    IdlePrompted() => const [
      ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.explaining,
        priority: CuePriority.interaction,
        hold: Duration(milliseconds: 1500),
      ),
    ],
    InteractionEvent(:final type) => switch (momentOf(type)) {
      EngineMoment.select ||
      EngineMoment.place ||
      EngineMoment.connect => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.curious,
          priority: CuePriority.interaction,
          hold: Duration(milliseconds: 600),
        ),
      ],
      EngineMoment.run => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.thinking,
          priority: CuePriority.interaction,
          hold: Duration(milliseconds: 900),
        ),
      ],
      EngineMoment.reveal => const [
        ReactionCue(
          role: ActorRole.guide,
          reaction: Reaction.curious,
          priority: CuePriority.interaction,
          hold: Duration(milliseconds: 900),
        ),
      ],
      // Taking something back, a timeout, or a name nobody registered:
      // nothing for a character to react to.
      EngineMoment.remove || EngineMoment.timeout || null => const [],
    },
    _ => const [],
  };
}
