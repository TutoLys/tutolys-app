# ADR 0017 — Learning engine platform, Phase 1: the contracts

Date: 2026-10-25
Status: accepted

## Context

Hafid's "Learning Engine Platform" brief asks for a reusable runtime
behind every activity:

- an engine SDK of deterministic state machines;
- a shared activity shell;
- coordinated audio;
- an animation director that engines never touch;
- detailed, durable learning telemetry with resumable sessions.

The audit and the full design are in
`docs/architecture/learning-engine-platform.md`. Hafid approved Phase 1
on 2026-10-25 and took every recommendation in its §10 (D1–D8).

What existed already, and is kept:

- the `TutolysEngine` widget contract and the four engines on it;
- `ExerciseRunner`'s complete/abandon-exactly-once lifecycle;
- multi-question by composition;
- the durable outbox and the server's `ON CONFLICT` dedupe;
- Piper audio;
- the `EngineFeedback` seam.

What didn't exist: engine state anyone outside a widget could see, a
separate evaluator, a session that survives a crash, stored seeds, and any
audio or animation coordination.

## Decision

Phase 1 adds contracts and pure logic only. Nothing in the running app
changes behaviour.

1. **`LearningEngine<C, S, A, Ans>`** (`engine_sdk/lib/src/contracts/`).
   Five members are pure: `parse`, `initialize(content, seed)`,
   `reduce → Transition(state, interaction events)`, `extractAnswer` and
   `applyFeedback`. `snapshot`/`restore` support resume. Only `buildView`
   touches Flutter. The brief's `validate(TContent)` became `parse(raw)`,
   because validating already-typed content is too late: the raw map is
   the boundary. The existing engines keep implementing `TutolysEngine`
   and move one at a time in Phase 3 and 4. **Keys don't change (D1):**
   `mcq` *is* single choice, and renaming it would orphan its content,
   telemetry and mastery history.

2. **Grading leaves engines.** It moves to
   `Evaluator`/`EvaluatorRegistry`, which return an `EvaluationResult`.
   The result carries:
   - an outcome: correct / partial / incorrect / ungraded;
   - a score from 0 to 1, for partial credit;
   - an evaluator id (`mcq.exact@1`);
   - an authority, always `local` today (D6);
   - error classifications.

   An evaluator that throws produces *ungraded + needs review*, never
   *incorrect*. The child did nothing wrong.

3. **One `ActivitySessionMachine`, a pure reducer.** Its phases are:
   created → loading → ready → presenting → awaitingInteraction →
   evaluating → feedback → (retry | next | completed). Pause and resume
   are supported. `interrupted` is how a crashed session is detected at
   launch; `abandoned` and `failed` are terminal.
   - **Input that makes no sense in the current phase is rejected**, with
     no state change and no events. That makes a double tap or a replayed
     input harmless.
   - The answer being evaluated lives in the state, so a crash during
     evaluation resumes by re-evaluating *that* attempt.
   - A broken evaluator moves the child on instead of looping on retry.

4. **Deterministic ids are the duplicate-submission defence**
   (`SessionIds`). Question instance, attempt `event_id` and
   `exercise_run_id` are uuid5 values derived from the activity session id.
   A resumed session re-derives the same ids, so the outbox primary key and
   the server's `ON CONFLICT` both drop a replay. XP's one-award-per-run
   rule therefore can't pay a resumed question twice.

5. **`RuntimeEvent` is a sealed set, with categories.**
   - `learning`, `interaction` and `accessibility` events are durable.
   - `runtime_diagnostic`, `animation_diagnostic` and `sync_diagnostic`
     never reach the outbox.
   - Verdicts keep v1 wire names (`attempt`, `exercise_complete`,
     `hint_used`), so every existing aggregate keeps its meaning when the
     recorder lands in Phase 2.
   - Payloads are ids only.

6. **The envelope parser accepts v1 and v2** (`QuestionEnvelope.parse`).
   It ignores unknown keys, so an older app plays newer content. It is
   strict on the types of keys it knows. A newer `schema_version` is
   *unsupported* (update prompt), not *invalid*. v2's optional fields each
   default to v1 behaviour:
   - `prompt.speech`, so pronunciation text can differ from visible text;
   - `speech_policy`;
   - `evaluation.max_attempts`;
   - `min_app_version`;
   - `secondary_skill_node_ids` (D5);
   - a per-question `engine_key` (D4).

7. **The registry gains an app-version floor**
   (`resolve(minAppVersion:, appVersion:) → AppVersionTooOld`). It does
   not gain a separate schema axis. The audit showed `engine_min_version`
   already *is* the content-schema axis: it carries the backend's
   `Engine.current_version`, the content-contract version. A second
   number would have meant the same thing. An unparseable floor is
   ignored, so a content typo can't lock children out.

8. **Audio is interfaces plus pure policy.** The interfaces are
   `AudioCoordinator` (channels: narration, character, sfx, music),
   `TtsEngine` and `VoiceCaptureService`. `TtsEngine` and
   `VoiceCaptureService` stay interface-only (D2, D8). The pure parts
   are tested:
   - `AudioLanePolicy`: one voice at a time by priority, effects never
     interrupt voices, music ducks under voices.
   - `SpeechPlan`: what may be read aloud, and when. An asset always beats
     TTS. Turning read-aloud off stops auto-play but keeps the speaker
     button.

9. **`packages/tutolys_motion` is new.** It is the animation-system plan's
   package, not a second one.
   - `CharacterManifest.resolve` follows fallback chains and lands on idle
     at a dead end or a cycle.
   - `CharacterRegistry` falls back to the placeholder renderer when a
     character's renderer type isn't installed.
   - `DefaultReactionPolicy`: a wrong answer gets *encouraging*, never
     disappointment.
   - `ActorScheduler` arbitrates priority with a generation token. That
     closes the stale-reset race animation-system-plan §4 found in
     `MascotEngineFeedback`.

   The director and the placeholder renderer are Phase 2.

10. **`test/architecture_boundaries_test.dart` enforces the layering from
    the real import lines.** Engines may import only flutter, engine_sdk
    and design_system. engine_sdk may not import motion, the app, drift,
    dio or riverpod. Motion may not import engines or the app. The pure
    runtime and contracts may not import audio players. The test also
    fails if a scanned directory has no imports, so it can't pass
    vacuously.

## Consequences

- engine_sdk tests: 39 → 94. tutolys_motion: 16 (new). App: 325, all
  passing, including the boundary test. `flutter analyze` is clean in
  the app, engine_sdk and tutolys_motion.
- Phase 2 builds on this without changing it. It adds
  `ActivitySessionController`, `ActivityShell`, `AudioCoordinator` on
  audioplayers, `AnimationDirector` with
  `PlaceholderCharacterRenderer`, and the drift `activity_session` table
  (schema v4 → v5). It also adds the v2 telemetry recorder and
  `LegacyEngineHost`, so today's four engines run in the shell.
- The v2 telemetry fields need the telemetry-side migration (doc §7,
  LE-T1). Until it lands, the recorder emits v1-compatible events.
- Not built here: any UI, any implementation of TTS or voice capture, and
  any backend or telemetry change. Those go to their owners as a work
  order.
