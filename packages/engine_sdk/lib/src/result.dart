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
  });

  const ExerciseResult.abandoned()
      : outcome = ExerciseOutcome.abandoned,
        attempts = 0,
        correct = 0,
        elapsedMs = 0;

  final ExerciseOutcome outcome;
  final int attempts;
  final int correct;
  final int elapsedMs;

  bool get isFirstTryPerfect => attempts == 1 && correct == 1;
}
