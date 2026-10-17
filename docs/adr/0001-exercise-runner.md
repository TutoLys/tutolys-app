# ADR 0001 — ExerciseRunner: the host between a content envelope and an engine

Date: 2026-10-17
Status: accepted

## Context

A6 needed `ExerciseRunner` plus the first three engines (`mcq`, `pair_match`,
`compose_build`). The commercially-locked decision behind `engine_sdk`
(`registry.dart`) is that the backend's `engine_key` picks what renders, so
retagging an exercise is a content change, not an app release. Something has
to sit between a cached content envelope and `TutolysEngine.build`, and what
it does and does not do shapes every engine written after it.

## Decisions

### The runner owns the telemetry lifecycle; no engine ever does

`TelemetryClient.startExercise` is called once, by the runner, before the
resolved engine is built. `logComplete` / `logAbandon` are called exactly
once, from the runner's wrapped `onFinished`, never by the engine. An engine
only calls `logAttempt` / `logHint` and reports its outcome through
`context.onFinished(ExerciseResult(...))`.

Rejected: letting each engine manage its own `startExercise`/`logComplete`.
Three engines all getting that lifecycle right, forever, is the kind of thing
that drifts — one engine logging abandon on dispose and another forgetting to,
one forgetting to start the run before its first attempt. Centralizing it in
one place is what lets `telemetry_contract_test.dart`-style guarantees hold
for every engine without re-testing the lifecycle per engine.

A consequence: disposing the runner mid-run (the host navigated away, e.g. a
back button) logs `exercise_abandon` as a best-effort side effect of
`dispose()`, but does **not** call the host's `onFinished` — the host already
knows it is leaving. `onFinished` is reserved for the engine itself reporting
a result while still mounted.

### The prompt is rendered by the runner, not by any engine

`TutolysEngine.build` receives `config` only, never the envelope's `prompt`
(text / audio_ref / image_ref). The runner renders the prompt above whatever
the engine builds. Every engine reduces to "a prompt, an answer space, a
correct-answer spec, and attempts" (`engine.dart`'s own description) — prompt
is the one part that is identical across all of them, so it is drawn once,
in one place, rather than three engines independently reinventing "how do we
show the question text."

### Settings are merged by the runner, overrides passed in as plain data

`ResolvedSettings` for a run = `commonSettings` + the resolved engine's own
`settingsManifest.definitions`, with `overrides` supplied to `ExerciseRunner`
as a flat `Map<String, Object?>`. The runner computes the merge; it does not
load overrides itself.

This keeps the architectural boundary in `engine_sdk`'s doc comment intact:
"an engine depends on engine_sdk and design_system only — never on the app,
the API client or the database." If the runner reached into drift's
`EngineSettingsTable` directly, that boundary would quietly move from
"engines" to "engines plus the thing that hosts them," and the runner would
stop being unit-testable without a database. Loading overrides from storage
and re-rendering on change is therefore the host screen's job (not yet built —
there is no real screen to host exercises until Phase 4's curriculum lands),
not the runner's.

### `pair_match` is tap-to-select-then-connect, not drag-and-drop

The schema's own description calls `pair_match` "drag/connect rather than
tap," chosen specifically to prove the engine abstraction holds across a
different interaction shape than `mcq`. The shape that matters is
*select-and-connect* versus *pick-one*; literal dragging is one way to express
that, not the only one.

Implemented as tap a left item, then tap a right item to attempt a match,
rather than a draggable gesture. Reasons:

- **Testability.** A tap sequence is exact and deterministic in a widget
  test; a drag gesture's hit-testing against a moving target is brittle, and
  this engine has the same contract obligations (answers reported by id,
  attempt telemetry) as the other two — it needs the same quality of test.
- **Input parity.** The app ships on web, desktop and tablets alike (plan
  §6.3, one widget tree per screen). Tap-to-connect works identically with a
  mouse, a trackpad and a finger; a drag gesture tuned for touch is often
  awkward with a mouse, and vice versa.
- **Accessibility.** A sequential tap-tap is unambiguous for a six-year-old
  who overshoots a drag target or lifts a finger mid-drag.

Rejected: literal drag-and-drop. Revisit if playtesting shows kids expect to
drag — the schema and telemetry shape (`{'left': id, 'right': id}` per
attempt) do not need to change either way.

## Consequences

- Adding a fourth engine means implementing `TutolysEngine` and trusting the
  runner for prompt display, telemetry and settings — no new engine needs to
  reimplement any of those.
- `ExerciseRunner` is widget-testable with fake engines and an in-memory
  outbox, with no app, database or network involved
  (`exercise_runner_test.dart`).
- The settings-overrides plumbing from drift to `ExerciseRunner` does not
  exist yet. Whatever screen first hosts a real exercise (Phase 4+) must
  build it; `ExerciseRunner`'s `settingsOverrides` parameter is the seam it
  plugs into.
