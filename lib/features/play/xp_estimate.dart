import 'package:engine_sdk/engine_sdk.dart';

/// Must track `settings.XP_PER_QUESTION`/`XP_FIRST_TRY_PERFECT_BONUS` in
/// tutolys-backend (ADR 0022) — a deliberate, hardcoded mirror, same
/// pattern `StreakLocal`'s own offline estimate already uses for
/// telemetry's streak algorithm. The *authoritative* total is always
/// `ProgressState.totalXp`, read from the backend's real ledger; this is
/// only for the immediate "+N XP" moment right after an exercise finishes
/// — `manage.py award_xp` hasn't run yet at that instant, so there's no
/// real number to show without waiting for the next scheduled refresh.
const int xpPerQuestion = 10;
const int xpFirstTryPerfectBonus = 5;

int _xpForOneQuestion(ExerciseResult result) =>
    xpPerQuestion + (result.isFirstTryPerfect ? xpFirstTryPerfectBonus : 0);

/// The XP a completed exercise is expected to earn, once `award_xp` next
/// runs. A multi-question exercise sums its real per-question results
/// (`questionResults`); a single-question one has none to sum, so it's
/// just the one question's own score — exactly mirroring how the backend
/// ledger awards one row per question either way.
int estimateXp(ExerciseResult result) {
  if (result.outcome != ExerciseOutcome.completed) return 0;
  if (result.questionResults.isEmpty) return _xpForOneQuestion(result);
  return result.questionResults.fold(0, (sum, q) => sum + _xpForOneQuestion(q));
}
