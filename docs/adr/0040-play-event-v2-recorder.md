# ADR 0040 — The runtime records `play_event.v2`

Date: 2026-10-25
Status: accepted
Implements LE-T1 on the app side (`Platforms/BACKEND_WORKORDER_LEARNING_ENGINE.md`),
against telemetry ADR 0013 (`tutolys-telemetry` `8cdcbab`).

## Context

Until now the new runtime wrote `play_event.v1`. That meant every
interaction was dropped on the device: picks, placements, audio requests,
pause and resume. `V1EventRecorder` counted them in `unrecordedCount` and
kept nothing. Partial credit was lost too, because v1's `attempt` is only
`is_correct`, so a board 3-of-4 right was stored like 0-of-4.

Telemetry now accepts v2 alongside v1, live on the dev-stack. Its schema
was agreed with this session field by field.

## Decision

**`V2EventRecorder`** (`engine_sdk/lib/src/runtime/v2_event_recorder.dart`),
behind the existing `RuntimeEventRecorder` interface, is now the
controller's default (`ActivitySessionController.recorderFactory`).

- **Built on `V1EventRecorder`, not beside it.** Every event v1 writes is
  written with the **same `event_id`** and the same v1 fields, then gains
  v2's. So `attempt` and `exercise_complete` mean what they meant, every
  aggregate, mastery, XP and streak reads v2 rows unchanged, and an app
  upgraded mid-session can't write one attempt twice under two ids. A test
  plays the same activity through both recorders and compares the ids.
- **On every event:**
  - `event_category`, taken from the runtime event; pause, resume and
    `question_presented` are `learning`;
  - `activity_session_id` and `session_run_id`;
  - `sequence`, counted per activity session;
  - `active_elapsed_ms` and `content_hash`;
  - `question_instance_id` while a question is open.
- **On an `attempt`:** `evaluation`, holding the outcome, the
  partial-credit score, the evaluator, `authority: local`, `errors` as
  `{code, taxonomy_version}` (≤16), and per-part `items` (≤64).
- **On `attempt` and `exercise_complete`:** `assistance`
  `{hints, audio_replays}` so far in the question. A first
  `audio_requested` isn't assistance; a replay is. That's telemetry's
  evidence rule, and it never penalises accessibility.
- **Events v1 dropped:** `question_presented`, `session_paused` and
  `session_resumed`, and every interaction type with an **ids-only**
  `payload`. The recorder drops display-text keys, nested values and
  anything past 8 keys before sending, rather than sending an event that
  comes back `rejected` and sits stuck in the outbox. An unknown
  interaction type is not sent; it's counted in `unrecordedCount`, so a new
  engine vocabulary gets noticed.
- **`sequence` rides in the recorder state**, which the controller commits
  in the same transaction as the events (ADR 0019). A resume continues the
  count with no gap or repeat. `session_run_id` is new per recorder, so per
  mount, and a resume gets a fresh one. A v1 snapshot resumes on v2 with
  its tallies.
- `RecorderFrame` gained `contentHash`, which v1 ignores. A stale-resume
  abandon doesn't know the engine version (0); v2 sends `null` rather than
  an invalid 0.
- The legacy `TelemetryClient` path still writes v1. Telemetry accepts
  both, and it serves nothing published.

## Verification

- `engine_sdk/test/v2_event_recorder_test.dart` (10 tests) validates every
  event against **telemetry's own `play_event.v2.json`**, copied verbatim
  into `test/fixtures/` along with its shared batch fixture. It covers:
  - the fixture itself;
  - a whole two-question activity: event types, sequence 0…n,
    `unrecordedCount` 0;
  - an attempt's evaluation and assistance, with per-question tallies;
  - interaction payload, ids and content hash;
  - v1-identical learning ids;
  - resume: sequence continues, new run id, no duplicate ids;
  - pause and exit;
  - unknown types counted, never sent;
  - payload sanitising;
  - a v1 snapshot resuming.

  If telemetry changes its schema, re-copy both files and this test says
  what broke.
- `activity_session_controller_test.dart` now pins `V1EventRecorder`
  explicitly. It's the v1 record's test.
- `test/play_screen_test.dart` (the app session's file), one assertion: a
  real play through the drift outbox now records the listen and the picks,
  and every row is `schema_version: 2`.
- engine_sdk 139, engines_core 163, app 476, all passing; analyze clean.
- **Not done:** a live POST of a device's v2 batch to the dev-stack ingest.
  Telemetry accepted its own copy of the same fixture live, 15/15.
