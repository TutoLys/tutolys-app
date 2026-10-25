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

## Decision: progress that shows the moment a lesson ends

**Why it stayed at 0.** Progrès, the Village buildings and the header read
only server mastery (`/me/progress`). The server recomputes mastery on a
schedule from telemetry's continuous aggregates, which never include today
(`materialized_only`, GO_LIVE open question #7). So nothing played today
could show. The design interview's rule, "progression is local-instant,
server-authoritative, monotonic", had never been implemented.

- **The local measure** is defined per skill node: *finished lessons ÷
  lessons*, from this kid's completion record (`nodeProgressProvider`,
  exercise ids per node) against the lessons the Carte would serve. Those
  are every cached exercise at the kid's grade, one per `lesson_group`,
  in the language the subject asks for (`localNodeProgressProvider`). A
  node with nothing cached has no local measure, which is not zero.
- **Shown progress per node = max(server mastery, local measure)**
  (`shownNodeProgress`). A finished lesson shows at once, and the server
  catching up never pulls a bar back.
- **Strands (Progrès) and subjects (Village)** are the mean of shown
  progress over their leaves at the kid's grade, the same rule both
  already used for mastery. A strand is "learning" once any leaf has
  mastery or a finished lesson.
- **Mastery stays the server's.** Gold and "Maîtrisé" still need
  `is_mastered`. Finishing every lesson fills a bar but never turns it
  gold, because mastery is a judgement on answers over time, not a count
  of lessons played.
- **The streak** is max(server, this device's count of consecutive days
  played). The two count days the same way; the server adds
  freeze-bridged gaps and other devices, while the device knows about
  today's play before telemetry uploads. Offline, the device's count
  shows alone. A server that can't read telemetry plus a local 0 stays a
  dash, never a made-up zero.
- **The `~` prefix is gone** (header, Profil, Progrès, Quêtes). It marked a
  local value as provisional. With max() a shown value is never below
  what the kid earned, so there's nothing to hedge, and that supersedes
  ADR 0006's convention.

## Not done

- The local measure isn't recomputed when a sync adds lessons; it refreshes
  on the next completion or app start. Content growth can also lower a
  node's local fraction (1/1 becomes 1/2 when a lesson is added). That's
  honest: there is more to do. It's the one way a bar can move back.
- XP and level stay server-only and still lag until `award_xp` runs.
  Making them local-instant needs a local XP ledger reconciled with the
  server's, a larger change than this bug.
- The old, unused `HomeScreen` still draws `~`; it is not in any
  navigation.
