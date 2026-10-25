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

/// The daily challenge, once completed.
const int xpDailyChallenge = 10;

/// XP for [questions] solved questions. A replay of a lesson this kid has
/// already finished earns half, rounded down over the lesson.
int questionXp(int questions, {bool replay = false}) =>
    replay ? (questions * xpPerQuestion) ~/ 2 : questions * xpPerQuestion;

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
