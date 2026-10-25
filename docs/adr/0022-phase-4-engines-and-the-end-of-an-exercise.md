# ADR 0022 — Phase 4: the other three engines, and how an exercise ends

Date: 2026-10-25
Status: accepted

## Context

Phase 3 (ADR 0021) put `mcq` on the `LearningEngine` contract. Phase 4
ports the other three launch engines. While it was in progress, Hafid
played the result and asked for three things before any more engines:

1. a finished exercise should show as done on the map;
2. the "+N XP" ending was "ugly asf" and should be fun;
3. everything should follow the app's language (his English menu sat over
   a French game).

His screenshots also showed a progress bar that never filled.

## Decision

### The three ports

All four launch engines now run on the new runtime. The legacy path
(`LegacyEngineHost`, `ExerciseRunner`, the old engine classes) serves
nothing that is published. It stays only as a fallback for now; deleting
it is a later step, once the new path has been in use for a while. Content
contracts are unchanged, apart from one parse rule (see `compose_build`).

- **`speed_tap` → `TimedChoiceEngine`.**
  - It reuses `mcq`'s content parsing and adds `time_limit_ms`.
  - A tap is the answer (`SubmitMode.immediate`).
  - Time running out is a new `NoResponseAnswer('timeout')`, graded
    incorrect with `feedbackCode: timeout` and **no** error
    classification, because running out of time says nothing about a
    misconception. The banner then says "Temps écoulé !".
  - The countdown lives in a widget (`CountdownBar`) that sends
    `TimeUp(round)`, so the engine stays pure. A `TimeUp` from an earlier
    round is ignored.
  - The countdown stops while an answer is checked, while feedback shows
    and while the session is paused.
  - It uses `AnimationBehavior.preserve`, so the platform's
    reduce-animations setting doesn't make it run 20 times faster.
- **`pair_match` → `PairMatchBoardEngine`.**
  - Tap a left item, then a right one. Tap a paired left item again to
    undo. A right item belongs to one pair at a time.
  - VALIDER checks the **whole board, with partial credit**: right pairs
    lock, wrong ones come apart. Tiles show which pair they're in with a
    number badge.
  - This changes what one attempt means for this engine. The legacy
    engine logged one attempt per pair; this one logs **one per checked
    board**. `first_try_success_rate` for `pair_match` now means "the
    whole board right first time".
- **`compose_build` → `ComposeSlotsEngine`.**
  - Tapping a tile fills the next empty slot; tapping a filled slot sends
    its tile back. VALIDER checks each slot, ordered or not, with partial
    credit, and right slots lock.
  - A target that uses one tile twice is now refused at parse, because
    each tile places once and such content can't be built. No published
    content does this.
- **Contract additions (engine_sdk), all additive:**
  - `NoResponseAnswer`;
  - `EvaluationResult.itemResults`, a verdict per part, so an engine can
    lock the right parts without grading anything;
  - `ActivitySessionController.lastResult`, so the banner can say *why*:
    timeout, or partly right.
- **Shared widgets, only the ones these engines needed:**
  - `AnswerTile` gains a pair badge;
  - `AnswerSlot`, an empty slot that is deliberately blank. A position
    number looked like a tile's value in a math exercise; the position is
    in the semantics label.
  - `CountdownBar`.

### The three asks

1. **Done on the map: the local half.** The map's `mastered` state comes
   from server mastery. That needs telemetry upload, the 15-minute
   `refresh_mastery` job and an 80% mastery score, so a node the child
   just finished doesn't change. New: `NodeProgressLocal` and
   `nodeProgressProvider`.
   - On every completed exercise the play screen records
     `node_progress.<skillNodeId>` (plays, last completed, ever perfect)
     in the kid-scoped `app_state`, and invalidates the provider.
   - It claims completion, never mastery.
   - **Carte doesn't read it yet.** That's the Carte owner's change; the
     prompt for it is in the session's handoff.
2. **The ending.** The SnackBar is gone. `ActivityCompleteView` is the
   design's end-of-series panel ("Mise à jour des quêtes !") made into a
   celebration:
   - a sky background, and a burst of stars behind the **real 3D fox art**
     (`BreathingMascot`, not the painted placeholder);
   - "Parfait !" for a perfect run, otherwise "Bravo, {name} !";
   - the XP counting up into a gold "+15 XP" pill;
   - cards for right answers and first-try answers;
   - a gold Continuer, which Enter also triggers.

   It also takes `extraRows` (`CelebrationRow`, the design's
   `.quest-update-row`) for quest progress, which the quest owners feed.
   With reduced motion there's no burst and no count-up. Continuer never
   waits on an animation. In the game, the XP pill now updates **on the
   right answer**, with a little pop, instead of after Continuer.
3. **Language.** Already true, and now tested: all game chrome follows the
   app's language, because `MaterialApp.locale` comes from Réglages and
   the shell reads `Localizations.localeOf`. That covers VALIDER/CHECK,
   the banners, the hint, the speaker's label, the celebration, and the
   engines' own semantics. **What stays French is the content**: the
   question text and options (only French content exists) and Carte's
   node labels where `labelEn` is empty. Neither is engine work. Prompts
   for both are in the handoff.

### Bug fixed: the progress bar never filled

The gold fill was a `FractionallySizedBox` around a childless box inside
a `Stack`, so it had zero height. The countdown had the same bug. Both now
use `heightFactor: 1`, and tests check the drawn size (half done is half
drawn).

## Verification

- **Tests:** engines_core 66 → 90, app 380, engine_sdk 124, motion 24;
  analyze is clean.
  - Each new engine is played through the real controller and shell,
    including keyboard-only play: timeout → "Temps écoulé !" → a fresh
    countdown → right; a partial board → "Certaines sont justes" → fix →
    Bravo; a partial build → the right slot stays → Bravo.
  - App: the celebration replaces the SnackBar; the node progress is
    recorded; the XP shows on the right answer; an English app shows
    CHECK / Almost! / TRY AGAIN around French content; and the legacy
    fallback is still covered by emptying the new registry.
- **Live, on web against the dev-stack:** the real `compose_build`
  exercise, with the full gold progress bar, "+15" in the pill on Bravo,
  then the celebration with the real fox. A session left mid-question
  resumed after a reload, with the same tray order.

## Not done

- Carte reading `nodeProgressProvider`; quest rows in the celebration;
  English content. All three are handed to their owners.
- The legacy path hasn't been deleted.
- `Strings.playXpEarned` is now unused. It lives in a file another
  session is editing, so I left it for them to remove.
