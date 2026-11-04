# ADR 0125: experiment_lab machine scenes

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` step 4. The backend side is
backend ADR 0400.

## Decision
Five new scenes, drawn in code in `experiment_lab/machine_scenes.dart`. The
interaction doesn't change: set variables, Essayer, notebook, conclude.

| scene | looks |
|---|---|
| `lever` | `near`/`far` × `lifted`/`stuck`, and `middle` × `lifted`/`stuck`/`level` |
| `ramp` | `low`/`high` × `stays`/`short`/`far` |
| `pulley` | `none`/`one`/`two` × `lifted`/`stuck` |
| `magnet` | `stuck`, `pulled`, `still_near`, `still_far`, `repelled` |
| `circuit` | `lit`, `lit_gap`, `dark_gap`, `open`, `open_gap`, `open_block` |

- A look is a named picture, as the first three scenes already do. The
  picture doesn't read the variables, so a lesson can't draw something its
  outcome text doesn't say.
- Looks differ by position or shape, never colour alone: a lit bulb has rays,
  and a thin arrow is the small effort of two pulleys.
- No red. The magnet is blue and grey, because a machine that doesn't move is
  not a mistake.
- A crate's weight and an object's material are not drawn. The outcome's words
  and the notebook say them.
- The engine version goes to 2.

## What the plan said that is already done or differs
- `reveal` on a run landed in step 0 (ADR 0118). It's unchanged.
- The plan's « mise à jour » for older installs works per engine, not per
  scene: the envelope's `engine_min_version` is `Engine.current_version`, not
  the lesson file's value. Raising it to 2 asks every experiment_lab lesson to
  be played on a v2 app, including the plant, water and mix ones. That is fine
  before launch, with no public installs. After launch, a per-scene change
  should use a lesson-level floor instead.

## Not covered
Electrostatics has no scene. A rubbed balloon is not a magnet, and the plan
named five scenes. Its leaves stay with `image_ref` or words.
