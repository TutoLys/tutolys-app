import 'package:engine_sdk/engine_sdk.dart';

// XP option A (Hafid, 2026-10-25), a deliberate mirror of the backend's
// ledger rules, same pattern as `StreakLocal` mirroring telemetry's streak.
// The *authoritative* total is always `ProgressState.totalXp`; this only
// fills the moment between a right answer and the next server read.

/// Each question solved: 1 XP.
const int xpPerQuestion = 1;

/// A lesson finished (every question of the série): +2.
const int xpLessonComplete = 2;

/// Every question right on the first try: +1 more.
const int xpPerfectLesson = 1;

/// XP for [questions] solved questions. A replay of a lesson this kid has
/// already finished earns half, rounded down over the lesson, but never 0
/// when there was something to halve: a credited replay pays at least 1
/// (Hafid's "+1 floor", 2026-11-01; backend `xp_rules.py`, ADR 0047
/// addendum). A one-question replay showed "+0" and looked broken.
int questionXp(int questions, {bool replay = false}) {
  final full = questions * xpPerQuestion;
  if (!replay) return full;
  final half = full ~/ 2;
  return half == 0 && full > 0 ? 1 : half;
}

/// The XP a completed lesson is expected to earn: its questions, plus the
/// lesson bonuses unless it's a replay. Nothing for an abandoned run.
int estimateXp(ExerciseResult result, {bool replay = false}) {
  if (result.outcome != ExerciseOutcome.completed) return 0;
  final questions = result.questionResults.isEmpty
      ? [result]
      : result.questionResults;
  final solved = questions.where((q) => q.correct > 0).length;
  var xp = questionXp(solved, replay: replay);
  if (!replay) {
    xp += xpLessonComplete;
    if (questions.every((q) => q.isFirstTryPerfect)) xp += xpPerfectLesson;
  }
  return xp;
}

/// The running total after [results], out of a lesson of [questions]:
/// 1 per question; the question that finishes the lesson adds the lesson
/// bonus (+2, +1 if all first try). On a replay each question pays 0 and
/// the finishing one pays half the lesson. Ends equal to [estimateXp].
int xpSoFar(
  List<ExerciseResult> results, {
  required int questions,
  bool replay = false,
}) {
  final finished = results.length >= questions;
  if (!finished) return replay ? 0 : results.length * xpPerQuestion;
  return estimateXp(
    ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: results.fold(0, (s, r) => s + r.attempts),
      correct: results.length,
      elapsedMs: 0,
      questionResults: results.length > 1 ? results : const [],
    ),
    replay: replay,
  );
}
