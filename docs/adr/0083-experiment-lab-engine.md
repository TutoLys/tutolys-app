# ADR 0083 — `experiment_lab`: try things, then say what you found

Date: 2026-10-26
Status: accepted

## Context

This is catalogue #10, "Petit scientifique" (B18), with ecosystem_sim's
plant (B20). It covers grade-1 science: the needs of a plant, the states
of water and the effect of heat, and mixtures. The catalogue expected
heavy art. None exists, so the three scenes these leaves need are drawn in
code. The content contract is backend ADR 0081.

## Decision

`ExperimentLabEngine` + `ExperimentLabEvaluator`
(`packages/engines_core/lib/src/experiment_lab/`), key `experiment_lab`,
explicit submit, `SingleChoiceAnswer` (the conclusion).

- **Running experiments:** the child sets 1–2 variables (2–4 values each)
  and presses "Essayer". The result appears in a card and is written in a
  notebook ("Mon carnet") of every distinct run.
- **Showing the result:** the result is drawn for a `scene`:
  - plant: dry, small, healthy, drowned;
  - water: ice, liquid, steam;
  - mix: dissolved, settled, floating.

  Without a scene, a lesson uses an `image_ref` (with the usual
  placeholder) or just the outcome's words. Each look differs by more than
  colour.
- **Only the conclusion is graded.** It's a choice of 2–4 sentences, with
  an authored `correct`, because a conclusion about cause can't be
  derived. The experiments themselves are free.
- **The conclusion waits for `min_runs`** different experiments (default
  2), because a conclusion is only science if it comes from trying. Until
  then, a line says how many more to run.
- **After a wrong conclusion,** the child can keep experimenting.
- **Screen reader:** every result is also spoken in words. The drawing is
  never the only way to see what happened.

## Consequences

- Tests: 6 in `test/experiment_lab_engine_test.dart`.
- Not built: animated growth over time, measured quantities (that's
  `measure_tool`), and a "predict before you try" step. That step is a
  natural v2: an ungraded prediction recorded in telemetry.
