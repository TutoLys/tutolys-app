import 'reaction.dart';

/// Per-actor arbitration: which cue wins, and when an actor returns to rest.
///
/// Pure and clock-free — `now` is passed in — so priority, interruption and
/// hold expiry are tested without timers. The animation director (Phase 2)
/// owns one of these per actor, feeds it cues from the reaction policy, and
/// asks it on each tick what the actor should be doing.
class ActorScheduler {
  ActorScheduler({required this.idle});

  final Reaction idle;

  ReactionCue? _current;
  Duration? _expiresAt;
  int _generation = 0;

  Reaction get reaction => _current?.reaction ?? idle;
  int get generation => _generation;
  CuePriority? get currentPriority => _current?.priority;

  /// Offer a cue at time [now]. Returns whether it was accepted.
  bool offer(ReactionCue cue, Duration now) {
    expire(now);
    final current = _current;
    if (current != null && cue.priority.index < current.priority.index) {
      return false;
    }
    _current = cue;
    final hold = cue.hold;
    _expiresAt = hold == null ? null : now + hold;
    _generation++;
    return true;
  }

  /// Drop the current cue if its hold has run out. Returns whether the
  /// actor changed.
  bool expire(Duration now) {
    final at = _expiresAt;
    final current = _current;
    if (current == null || at == null || now < at) return false;
    if (current.returnTo == idle) {
      _current = null;
    } else {
      // Settle into the cue's resting reaction at the lowest priority, so
      // anything that comes next can replace it.
      _current = ReactionCue(
        role: current.role,
        reaction: current.returnTo,
        priority: CuePriority.ambient,
        hold: null,
      );
    }
    _expiresAt = null;
    _generation++;
    return true;
  }

  /// End an open-ended cue (`speaking` when narration stops). Only clears if
  /// [generation] still matches — a newer cue is never cancelled by a stale
  /// completion.
  bool release(int generation) {
    if (generation != _generation || _current == null) return false;
    _current = null;
    _expiresAt = null;
    _generation++;
    return true;
  }

  /// Back to idle unconditionally (session ended, activity exited).
  void reset() {
    _current = null;
    _expiresAt = null;
    _generation++;
  }
}
