# ADR 0032 — A sequential path, and progress that shows the moment a lesson ends

Date: 2026-10-25
Status: accepted

## Context

Two bugs Hafid hit playing Science on the :8080 preview:

1. **The path let him skip ahead.** Node 1 done, node 2 "Classer des
   matériaux" locked, node 3 done, node 4 up next. Nothing gated on order:
   every playable node was open, and "locked" only meant "no lesson
   synced". Node 2 had no lesson, so it sat locked in the middle of the
   path, looking like the reason he was stuck, while node 3 was open.
   Hafid: "if the game is not done, we should not go to the next."
2. **Progress stayed at 0** after two Science games (see the second
   decision below).

Leaving an exercise early was checked and is **not** a cause. Completion
is recorded only when the session reaches `completed`, which means every
question of the série. Quitting after one of two questions records
nothing, and `play_screen_test` now pins that.

## Decision: the path

- **Unlocking is strictly sequential over playable nodes.** In path order
  (the Carte's sections, then each section's nodes), the first playable
  node that is neither mastered nor completed is **active**. Every
  playable node after it is **locked** until the nodes before it are done.
  Server mastery counts as done.
- **A node with no published lesson is `soon`**, not locked: it gets an
  hourglass instead of a lock and a "BIENTÔT" tag, and it can't be tapped.
  It is **skipped** by the sequence, so a missing lesson never blocks the
  path or looks like what's blocking it. It stays on the path rather than
  disappearing, because the kid should see that the skill exists and is
  coming.
- A node completed before this rule existed (out of order, like Hafid's
  node 3) stays completed and replayable. Nothing is taken back.
- `PathNodeState.available` is no longer produced by the Carte. The widget
  still draws it.
