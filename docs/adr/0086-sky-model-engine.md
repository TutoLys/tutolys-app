# ADR 0086 — `sky_model`: the Sun, the Earth and the Moon

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker asked for this engine for strand 2. It covers the
science leaves on the rotation and revolution of the Earth and the Moon,
and the cycle of the seasons (revolution and axial tilt). It also helps
with "the Sun is a star". The content contract is backend ADR 0083.

## Decision

`SkyModelEngine` + `SkyModelEvaluator`
(`packages/engines_core/lib/src/sky_model/`), key `sky_model`, explicit
submit, `BlanksAnswer` (`{angle}`).

- **The model is drawn in code**, with the Sun always on the left.
  Angles are degrees, counter-clockwise, with 0 pointing away from the
  Sun. Every body turns counter-clockwise seen from above the North Pole,
  as the real ones do.
  - `day_night`: the Earth seen from above the pole, a marked town on its
    edge, and the far half in night. Land turns with it, so the turning
    shows. Targets: day, night, noon, midnight, sunrise, sunset. Sunrise
    is at 90°, where a town turning counter-clockwise comes into the
    light.
  - `seasons`: the Earth on a flattened orbit, its axis always leaning
    23° right. Northern summer is with the Earth left of the Sun, when
    the pole leans toward it. Winter, spring, summer and fall are at 0°,
    90°, 180° and 270°. The side facing the Sun is lit. Behind the Sun,
    the Earth is drawn under it.
  - `moon`: the Moon round the Earth, lit from the left, plus a "Vue de
    la Terre" inset showing the phase as seen from Earth. The inset's lit
    fraction and side come from the Moon's elongation; it waxes on the
    right. Targets: new, first_quarter, full, last_quarter.
- **Moving:** drag a body to where the finger is (seasons, moon), or turn
  the Earth by the angle swept (day_night). Or use the ↺ and ↻ buttons, in
  15° steps; ↺ turns the real way. VALIDER waits for a first move.
- **Grading:** right within `tolerance` (10–45°, default 25). Day and
  night are halves and count once 15° inside, so the terminator never
  counts. Parse rejects a start that already meets the target.
- **Near misses:** a wrong angle at another named target (full instead of
  new, sunset instead of sunrise) carries that near miss's diagnosis.
- **Screen reader:** the model speaks where things are after every move
  ("Québec est du côté sombre, la nuit"; "La Lune est à droite de la
  Terre"). Describing the sky in words is how a non-sighted child plays.

## Consequences

- Tests: 9 in `test/sky_model_engine_test.dart`:
  - angle maths;
  - parse;
  - nudges and wrapping;
  - near-miss diagnoses;
  - snapshot;
  - in the shell: buttons wrong then right, and a drag;
  - layout on a phone.
- Drags in a test need a stateful view: the drag's starting angle
  survives rebuilds, and atan2's wrap at ±180° is undone.
- Not built: animated orbits or time-lapse, and the Moon's own rotation.
