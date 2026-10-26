# ADR 0081 — `fraction_slice`: name or colour a fraction

Date: 2026-10-26
Status: accepted

## Context

This is catalogue #8, "La découpe magique" (B10). It covers the grade-1
math leaves on recognising and representing a fraction. The content
contract is backend ADR 0059.

## Decision

`FractionSliceEngine` + `FractionSliceEvaluator`
(`packages/engines_core/lib/src/fraction_slice/`), key `fraction_slice`,
explicit submit. The answer type is `AnswerValue`: `SingleChoiceAnswer`
in identify mode, `MultiSelectAnswer` in shade mode. The evaluator checks
that the answer fits the mode.

- **The whole:** a pizza or a bar cut into 2–8 equal parts, drawn in
  code. No art.
- **`identify`:** the first `shaded` parts are coloured, and the child
  picks a fraction. It reuses `PickOne`. The right option is the one equal
  **in value** to shaded/parts, so 2/4 coloured accepts 1/2. Parse
  rejects two options of equal value.
- **`shade`:** the child taps parts to colour the target. Any parts count;
  only how many matters. A wrong count stays on the board, so the child
  adds or removes rather than starts over. `parts` is a multiple of the
  target's `den`.
- **Options** read as `3/4`, or in words with `display: words` ("trois
  quarts", "un demi", "two thirds"). The screen reader always uses the
  words.
- **Every part is a focusable, spoken toggle,** a 44 px target at its
  centre. A tap anywhere on a part also works.
- **Item results:** shade records only `count`. Error codes come from the
  backend's taxonomy, and this engine invents none.

## Consequences

- Tests: 8 in `test/fraction_slice_engine_test.dart`.
