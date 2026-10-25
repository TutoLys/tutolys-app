import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/play/xp_estimate.dart';

/// XP option A (Hafid, 2026-10-25), mirrored from the backend's ledger:
/// 1 per question, +2 per lesson finished, +1 if every question was right
/// first try, a replay at half question XP with no lesson bonus.
ExerciseResult q({int attempts = 1}) => ExerciseResult(
  outcome: ExerciseOutcome.completed,
  attempts: attempts,
  correct: 1,
  elapsedMs: 100,
);

ExerciseResult lesson(List<ExerciseResult> questions) => ExerciseResult(
  outcome: ExerciseOutcome.completed,
  attempts: questions.fold(0, (s, x) => s + x.attempts),
  correct: questions.length,
  elapsedMs: 100,
  questionResults: questions,
);

void main() {
  test('an abandoned run earns nothing', () {
    expect(estimateXp(const ExerciseResult.abandoned()), 0);
  });

  test('a perfect 5-question lesson: 5 + 2 + 1 = 8', () {
    expect(estimateXp(lesson([q(), q(), q(), q(), q()])), 8);
  });

  test('one retry costs only the perfect bonus: 5 + 2 = 7', () {
    expect(estimateXp(lesson([q(), q(attempts: 2), q(), q(), q()])), 7);
  });

  test('a one-question lesson counts as a lesson too: 1 + 2 + 1', () {
    expect(estimateXp(q()), 4);
  });

  test('a replay earns half its question XP and no lesson bonus', () {
    expect(estimateXp(lesson([q(), q(), q(), q(), q()]), replay: true), 2);
    expect(estimateXp(lesson([q(), q(), q(), q()]), replay: true), 2);
  });

  test('question XP alone, as the game shows it before the celebration', () {
    expect(questionXp(3), 3);
    expect(questionXp(3, replay: true), 1);
  });

  test('the daily challenge is worth 10', () {
    expect(xpDailyChallenge, 10);
  });
}
