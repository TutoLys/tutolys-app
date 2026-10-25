/// The semantic states a character can be in. Renderer-neutral: a
/// placeholder maps them to a tint and a bounce, a Rive renderer to
/// state-machine inputs. No character must support all of them — see
/// `CharacterManifest.resolve`.
enum Reaction {
  idle,
  thinking,
  curious,
  listening,
  speaking,
  explaining,
  encouraging,
  celebrating,
  victory,
  waiting,
  sleeping,
}

/// How much a cue matters, low to high. A higher cue interrupts a lower one
/// on the same actor; an equal one replaces it; a lower one is dropped while
/// something more important plays.
enum CuePriority {
  /// Idle loops.
  ambient,

  /// Flourishes nobody would miss.
  decorative,

  /// Responses to a tap or selection.
  interaction,

  /// Reactions to an evaluated answer — the ones that teach.
  learningFeedback,

  /// Session-level transitions: activity complete, session resumed.
  critical,
}

/// The role an actor plays in an activity. Activities fill roles; engines
/// never name characters.
enum ActorRole { guide, companion }

/// One instruction to one actor.
class ReactionCue {
  const ReactionCue({
    required this.role,
    required this.reaction,
    required this.priority,
    this.hold = const Duration(milliseconds: 900),
    this.returnTo = Reaction.idle,
  });

  final ActorRole role;
  final Reaction reaction;
  final CuePriority priority;

  /// How long the reaction holds before returning. Null = until replaced
  /// (e.g. `listening` while narration plays). Gameplay never waits on
  /// this: the director runs it on its own clock.
  final Duration? hold;
  final Reaction returnTo;
}
