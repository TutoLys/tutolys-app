# ADR 0080 — `path_planner`: Foxy's route on a grid

Date: 2026-10-26
Status: accepted

## Context

This is catalogue #7, "Le chemin de Foxy". It merges path_planner (B15),
code_robot (B25) and map_navigator (B13), and covers about 7 grade-1
leaves:
- math spatial relations, and finding a spot on a plan;
- univers-social orientation, cardinal points and landmarks.

The content contract is backend ADR 0058.

## Decision

`PathPlannerEngine` + `PathPlannerEvaluator`
(`packages/engines_core/lib/src/path_planner/`), key `path_planner`,
explicit submit, `OrderingAnswer` (the moves, in order).

- **The board:** a grid of 2–7 by 2–7 cells with a start, a goal (a gold
  flag), walls (trees) and up to 6 named landmarks.
- **Building the route:** the child uses four direction buttons, either
  arrows or N E S O with north up. The arrow keys work too, and Backspace
  removes the last move. Tapping a step in the route removes it.
- **Foxy walks the route as it grows.** In that live mode, a move into a
  wall or past `max_moves` is refused: the child can see where Foxy is,
  so a bump is a slip, not a plan.
- **`show_path: false` makes it a planning task.** The route is built
  blind and walked only when checked. A wrong route is then drawn in
  amber, and it stays on screen so the child can fix it rather than start
  over.
- **Graded by rules, not by a stored answer.** A route is right when it
  reaches the goal without bumping, passes every `must_visit` landmark
  (in any order), and fits in `max_moves`. Each rule is a separate item
  (`goal`, `visit:<id>`, `moves`), so telemetry can say which one failed.
- **Parse checks the board can be solved:** a BFS through the
  must_visit landmarks in the best order. The shortest route must fit in
  `max_moves`.
- **The reducer enforces the limits.** The state carries its content, so
  keys pressed faster than a rebuild still can't bump a wall or remove the
  wrong step.
- **The evaluator's policy is `exact`.** The shell looks evaluators up by
  the envelope's policy, which defaults to `exact`.
- **Screen reader:** every cell is spoken (row, column, and what's on it),
  and so is where Foxy is and the route so far.

Foxy is `TutolysMascot`, the design system's placeholder fox, until the
real character renderer can be reached from engines_core.

## Consequences

- Tests: 9 in `test/path_planner_engine_test.dart`.
- New `test/backend_samples_test.dart` parses every question of each new
  engine's backend sample with the app's own parser, so the Dart and
  Python rules can't drift unnoticed. It's skipped when the backend
  checkout isn't beside the app. It covers pattern_machine, measure_tool
  and path_planner.
- engines_core is now 269 tests.
