/// How a run ended.
enum ExerciseOutcome { completed, abandoned }

/// Returned to the host when an engine finishes.
///
/// Carries no telemetry: the events were already written through the context,
/// so this exists only to let the host decide what screen comes next.
class ExerciseResult {
  const ExerciseResult({
    required this.outcome,
    required this.attempts,
    required this.correct,
    required this.elapsedMs,
    this.questionResults = const [],
  });

  const ExerciseResult.abandoned()
    : outcome = ExerciseOutcome.abandoned,
      attempts = 0,
      correct = 0,
      elapsedMs = 0,
      questionResults = const [];

  final ExerciseOutcome outcome;
  final int attempts;
  final int correct;
  final int elapsedMs;

  /// Empty for a single-question exercise. For a multi-question one, this
  /// is the real per-question breakdown — `attempts`/`correct`/`elapsedMs`
  /// above are already the sums across these, so a host that only cares
  /// about the totals (recording "played today", say) never needs to look
  /// here at all; one that cares about the per-question detail (XP) does.
  final List<ExerciseResult> questionResults;

  bool get isFirstTryPerfect => attempts == 1 && correct == 1;
}
