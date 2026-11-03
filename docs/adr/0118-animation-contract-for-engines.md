# ADR 0118: Engines report moments; the shell and the director draw them

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` §3, step 0 of §2.3. Hafid's
go on 2026-11-03, relayed by the Manager.

## Context
An animation system (Rive or other, `docs/animation-system-plan.md`) is
coming. It can only plug in without touching engines if every moment an
engine has (select, correct, retry, combo, reveal, complete, idle) reaches
it as a `RuntimeEvent`. The plan's audit found three gaps:
- no event carried a combo, a reveal or an idle prompt;
- five engines ran the idle hand's timer and animation themselves;
- path_planner drew and moved Foxy inside its own widget.

## Decisions
1. **A `presentation` event category**, which is never durable. Combo,
   idle and reveal are derived from learning or interaction facts already
   recorded, so persisting them would only count those facts twice. The v1
   and v2 recorders drop them without adding to `unrecordedCount`.
2. **The combo comes from the session machine.** `StreakAdvanced {count}`
   follows the `attempt` event when the question was right on the first
   try, from the second one in a row. A miss or a retry resets the count,
   and an ungraded verdict leaves it alone. `SessionState.firstTryStreak`
   rides the snapshot, and older snapshots read it as 0.
3. **Reveal is `RevealEvent(what, itemId)`.** It is an `InteractionEvent`,
   so a reducer can return it, but its category is presentation.
   - In a reducer: experiment_lab's `outcome` and the discussion's `clue`.
   - After a verdict: a new optional interface, `RevealsAfterFeedback<S>`.
     The runtime calls it right after `applyFeedback` and emits what it
     returns, so no other engine had to change. It covers balance_scale's
     `tip` (to the truth once solved, and for a wrong value in balance
     mode), stage_presenter's `reaction`, and path_planner's `walk` (`goal`
     or `stopped`).
4. **The shell owns the idle prompt.**
   - `IdleHandHint` is now only the engine's marker: which tile, and
     whether the board is still waiting. It takes a `targetId`.
   - It arms the shell's `IdleCueController`. After 2.4 s with nothing
     touched, the shell sends `IdlePrompted` through the new
     `ActivitySessionController.signal`, which publishes the event without
     committing it.
   - When the event comes back on the stream, the shell cues the hand.
     `IdleHand`, a shell widget, draws it.
   - An engine on its own, with no shell, keeps a controller of its own.
   - Under reduced motion the hand is there at once, still, as before.
   - The behaviour children see is unchanged: the G3 and N4 tests pass
     unedited.
5. **Characters on a board are the host's.**
   - path_planner draws a `BoardActor(role: 'walker')`; the engine keeps
     only the cell and the tween to it.
   - `LearningActivityView.boardActor` lets the host pass its cast
     (eventually the director's stage).
   - Without one, the view supplies a fox that turns happy on a correct
     verdict, from the events. That is what the engine used to decide for
     itself.
6. **One table of moments** in `tutolys_motion` (`interactionMoments`,
   `momentOf`). It maps every interaction wire name to select, place,
   remove, connect, run, reveal or timeout.
   - Wire names aren't renamed. They're durable, so renaming would split
     the telemetry aggregates.
   - `DefaultReactionPolicy` now reacts to select, place, connect, run and
     reveal, and to `StreakAdvanced` and `IdlePrompted`.
   - New engines use only the canonical names: `option_selected`,
     `item_placed`, `item_removed`, `pair_connected`, `experiment_run`,
     `reveal`.
7. **Two guard tests:**
   - `tutolys_motion/test/engine_moments_coverage_test.dart` reads every
     `InteractionEvent(` name in engines_core and fails on one without a
     moment.
   - `engines_core/test/engine_animation_boundary_test.dart` fails on
     `AnimationController`, `TweenAnimationBuilder` or `Animated*` inside
     an engine folder, except a reviewed allow-list of board-geometry
     tweens. The list has two entries: balance_scale's beam and
     path_planner's position.

## Corrections to the plan's audit
counters_board already emitted `item_removed` when a counter went back to
the reserve (a ternary the audit's grep missed), so fix 5 needed no change.

## Not done here (the app session's)
`lib/features/play/play_screen.dart` should pass `boardActor:` from its
director's stage, so the walker reacts with the same cast as the guide.
Until it does, the default fox behaves as before.

## Tests
- engine_sdk 185: combo counts, resets and round-trips; presentation
  events are never durable; `signal` publishes without writing.
- tutolys_motion: policy cues for the new events, and the coverage test.
- engines_core: `test/animation_contract_test.dart` (9) covers:
  - each reveal;
  - the compare scale staying level;
  - the idle event preceding the hand, with the engine's target;
  - the standalone hint;
  - the host's board actor, and the default fox's mood.

  Plus the boundary test.
