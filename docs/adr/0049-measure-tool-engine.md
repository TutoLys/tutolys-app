# ADR 0049 — `measure_tool`: read a ruler, a clock, a thermometer

Date: 2026-10-26
Status: accepted

## Context

This is catalogue #6 (`Platforms/ENGINE_CATALOGUE_2026-10-25.md`). It
merges measure_estimate (A19) with weather_station's instruments, and
covers about 9 grade-1 leaves:
- math lengths, in non-standard units and in cm;
- reading the time;
- temperature;
- science temperature.

It needs no art. The content contract is backend ADR 0057.

## Decision

`MeasureToolEngine` + `MeasureToolEvaluator`
(`packages/engines_core/lib/src/measure_tool/`), key `measure_tool`,
explicit submit, `SingleChoiceAnswer`.

- **Three instruments, all drawn in code:**
  - `ruler`: a pencil from `start` to `start + length` on a cm ruler of up
    to 20, or along a row of cubes (`unit: block`). It can start past 0,
    which tests the classic mistake of reading where the pencil ends.
  - `clock`: an analog clock on a 5-minute mark.
  - `thermometer`: a liquid column on a scale graduated every 1, 2, 5 or
    10 degrees.
- **The child reads, then picks one of 2–4 values.** The right option is
  the one whose value is what the instrument shows. There's no answer key
  for a lesson to get wrong.
- **Labels follow the language:** "7 cm", "18 °C", and "3 h 30" or "3:30".
- **Shared pick logic:** a new `PickOne` (`widgets/pick_one.dart`) holds the
  pick, amber-retry, solve, snapshot and grading rules that `balance_scale`
  wrote inline. `measure_tool` is its first user; `fraction_slice` will be
  the next. `balance_scale` stays as it is (its "tilt on a wrong pick"
  needs `lastWrong`).
- **Screen reader:** the drawing says what instrument it is ("Une règle
  de 0 à 12 cm, avec un crayon posé dessus"), never its value. Reading a
  drawn ruler isn't possible without sight, so the descriptor declares
  `screenReader: false`.
- **On a phone,** a ruler with less than 24 px per unit labels only the
  even numbers.

Not built: modes where the child sets the clock's hands or lays the ruler
(a later mode), estimating, and object pictures (the catalogue lists them
as optional; the pencil is drawn).

## Consequences

- Tests: 14 in `test/measure_tool_engine_test.dart`, covering:
  - the derived answers and labels;
  - parse rejects;
  - pick, retry and solve;
  - snapshot;
  - every instrument at phone and desktop width;
  - the ruler, wrong then right, in the shell.

  engines_core is now 257.
- Registered in `learning_platform_providers.dart` (two lines).
