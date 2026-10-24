import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/play/xp_estimate.dart';

/// `estimateXp` is a deliberate, hardcoded mirror of
/// tutolys-backend's `apps.progress.services._xp_for_run` (ADR 0022) —
/// these tests pin the same formula (10 per question, +5 first-try-perfect
/// bonus), not the real server call.
void main() {
  test('an abandoned run earns nothing', () {
    const result = ExerciseResult.abandoned();
    expect(estimateXp(result), 0);
  });

  test('a single-question exercise taking more than one attempt earns the base amount', () {
    const result = ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: 2,
      correct: 1,
      elapsedMs: 100,
    );
    expect(estimateXp(result), xpPerQuestion);
  });

  test('a single-question exercise solved first try earns the bonus too', () {
    const result = ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: 1,
      correct: 1,
      elapsedMs: 100,
    );
    expect(estimateXp(result), xpPerQuestion + xpFirstTryPerfectBonus);
  });

  test('a multi-question exercise sums each question\'s own score', () {
    const result = ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: 3,
      correct: 2,
      elapsedMs: 400,
      questionResults: [
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: 1,
          correct: 1,
          elapsedMs: 100,
        ), // first-try-perfect: 15
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: 2,
          correct: 1,
          elapsedMs: 300,
        ), // not: 10
      ],
    );

    expect(estimateXp(result), 25);
  });

  test('a three-question exercise earns proportionally more than a one-question one', () {
    ExerciseResult oneQuestionFirstTry() => const ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: 1,
      correct: 1,
      elapsedMs: 100,
    );

    final single = estimateXp(oneQuestionFirstTry());
    final triple = estimateXp(
      ExerciseResult(
        outcome: ExerciseOutcome.completed,
        attempts: 3,
        correct: 3,
        elapsedMs: 300,
        questionResults: List.generate(3, (_) => oneQuestionFirstTry()),
      ),
    );

    expect(triple, single * 3);
  });
}
