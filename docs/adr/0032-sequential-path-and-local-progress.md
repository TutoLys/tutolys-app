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
- ~~A node completed before this rule existed stays completed and
  replayable.~~ Reversed the same day; see the revision below.
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

## Revision 2026-10-25: nothing past the frontier opens, and the Carte opens on it

Hafid still could skip ahead on :8080, and asked twice. The cause was this
ADR's own exception: a node already finished (an older build's record) or
mastered on the server kept its state, and with it a tap handler, even past
the frontier.

- **Past the frontier every node is locked**, whatever it was before:
  completed, mastered, or both. It has no tap handler. Once the frontier
  reaches it, it shows done again and the frontier moves on past it, so no
  record is lost. `soon` nodes stay `soon`.
- Done still means "mastered on the server, or every lesson finished here",
  so a "2/4" node is the frontier until all four are done.
- The frontier spans the whole subject, not one strand: a later learning
  area waits for the earlier ones. That's stricter than "the same strand"
  and keeps exactly one fox and one Continuer card per subject.
- **Every way into a game checks it.** The orb and the Continuer card get a
  handler only when the node is open (`isOpenState`), and the Carte's
  `_play` refuses a node that isn't, as a last word. The Village never
  opens a game: its CTA, quest rows and buildings only switch to the Carte.
- **The Carte opens on the frontier.** On showing the tab, switching
  subject, finishing loading, a lesson completing, or coming back from a
  game, it scrolls the active node to the middle of the screen
  (`Scrollable.ensureVisible`, alignment 0.5, `Motion.normal` eased, or a
  jump under reduced motion). With every node done it goes to the last
  one. A hidden tab doesn't scroll until it is shown.

## Revision 2026-10-25: the pills and strand title are pinned

Hafid, from :8080: once the map scrolled to the frontier, the subject pills
and the strand title were off the top, and switching subject meant
scrolling all the way back up. "Like a freeze row in Excel."

- The Carte is now a fixed header (pills, then the subject eyebrow and the
  current strand's title) above the path's own scroll view. Only the path
  scrolls, at every breakpoint; on mobile the pills keep scrolling
  sideways inside the header.
- The header is transparent over the shell's sky gradient. The path is
  clipped at the header's bottom edge rather than sliding under an opaque
  band, so there's no seam in the gradient.
- The title follows the scroll: it names the last area whose top has
  reached the header. The first area's title is the header's own, and
  later areas keep an in-path title that marks where they start.
- The frontier scroll is unchanged: `ensureVisible` centres in the path's
  own viewport, which now starts under the header, so the fox is never
  hidden behind it.
