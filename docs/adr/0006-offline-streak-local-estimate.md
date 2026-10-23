# ADR 0006 — Offline streak estimate (plan §5.8)

Date: 2026-10-21
Status: accepted

## Context

Plan §5.8 names `streak_local` as one of the app's local tables and states
the rule plainly: "Streaks work offline and reconcile with the backend on
sync (backend is source of truth)." Nothing in the app ever built this —
the streak tile (A7.2's follow-up, this session's earlier round) was a
live-fetch-only read; a kid with no network saw a dash. Hafid asked for
"streaks" alongside B12 subscriptions; this is the concrete gap that name
pointed at.

## Decisions

**A new table, not a reuse of `EventOutboxTable`.** The outbox prunes
delivered rows after as little as 6 hours (`DriftEventOutbox`'s own
crash-safety design, not analytics storage) — exactly the same reason
`HomeStats` (ADR 0004) already avoided it for "today's" stats. `PlayedDate
Table` is one row per **local calendar date** with at least one completed
exercise (the plan's own rule, verbatim), stored as `TEXT` (`yyyy-MM-dd`),
never pruned — at most one row per day ever played, small enough that
"never prune" is simply correct, not a future cleanup debt.

**The local algorithm matches telemetry's `kid_streak` exactly**:
consecutive days counted back from today, one day's grace (still active if
yesterday — not just today — was played, breaks only on a real 2+ day
gap). Deliberately the same rule as the backend's, not the old desktop
app's different "best run in the last 7 days" metric (already rejected
once, ADR 0009 on the backend) — so an offline estimate and the backend's
own truth read the same way to a kid even before they've reconciled.

**The estimate is clearly marked, never silently indistinguishable from a
live read.** `ProgressState.isStreakEstimated` is `true` only when
`ProgressOffline` was returned и the local history answered instead; the
Home screen renders it with a `~` prefix (`~3`, not `3`) rather than
quietly showing a number that might not match what the backend says once
reachable. The local value is never written back to the backend and never
overrides a successful live read — it exists only to fill the gap while
one hasn't happened yet.

**`recordPlayedToday()` is called from the same one place `HomeStats.
recordExerciseCompleted` already is** (`PlayScreen._handleFinished`, on
`ExerciseOutcome.completed` only — an abandoned run isn't "played", same
rule both counters share).

## Consequences

- `LocalDatabase.schemaVersion` bumped 1 → 2, with a real `onUpgrade` step
  (this app has no production installs yet, but the right pattern is worth
  establishing now rather than wishing it existed the first time it
  matters).
- 9 new tests: `streak_local_test.dart` (7, the algorithm itself — same
  precedence cases ADR 0009's backend-side streak logic was already pinned
  with) plus 2 in `progress_controller_test.dart` proving the offline
  fallback actually reads real local history, not just a hardcoded zero.
  App suite: 124 tests (was 115).
- Not built: writing the local estimate back as a seed/override for the
  backend's own streak (never needed — the backend computes its own from
  telemetry, which the app's outbox already feeds); any UI beyond the `~`
  marker (e.g. an explicit "estimated, not yet synced" tooltip) — flagged
  as a possible polish pass, not done here.
