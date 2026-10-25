# Learning engine platform — audit and proposed architecture

Status: **accepted 2026-10-25.** Hafid approved the design and took every §10
recommendation (D1–D8). **Phase 1 (contracts) is done**; see ADR 0017.
Phases 2+ not started.

This answers the "Learning Engine Platform, Animation Framework & Educational
Telemetry" brief. The brief asks for an audit before any design, so §1 is a
record of what the code does today, with file references. §2 onwards is the
proposal, built on that audit.

Read the brief and this file together. Where the brief describes something
the code already has, or something that contradicts a decision already on
record in `Platforms/CLAUDE.md`, §10 lists the conflict. Every §10 decision was
accepted as recommended on 2026-10-25.

Paths are relative to `Platforms/`. `app/` = `tutolys-app/`, `be/` =
`tutolys-backend/`, `tm/` = `tutolys-telemetry/`.

---

## 1. Existing architecture (audit)

### 1.1 The overall shape

```
Django backend ── content + curriculum + progress (+ mastery, XP, streaks, reports)
   │  manifest / exercises / audio assets      ▲ service JWT, read-only aggregates
   ▼                                           │
Flutter app ── ExerciseRunner ── engines ── TelemetryClient ── drift outbox ──► FastAPI telemetry
                                                                                (TimescaleDB play_event)
```

Two facts shape everything else. Both differ from the brief's diagram.

1. **Telemetry is a separate service, not Django.** The app uploads play
   events to `tm/` (`POST /v1/events/batch`). Django never receives raw
   events. It reads aggregates from telemetry with a short-lived service
   token and stores the derived results: `SkillMastery`, `XPAward`, streaks
   and reports. Hafid chose this two-service split (CLAUDE.md, "Hafid's
   decisions").
2. **The curriculum is one recursive table, not a model per level.**
   `be/apps/curriculum/models.py:137` `SkillNode` has a self-FK `parent` and
   a `level` enum: subject/strand/block/objective/skill (`:53-69`).
   "Program" is a string on `CurriculumSource`. A *taggable leaf* is any
   live node with no live children; this is computed, never stored
   (`:122-134`). Ids are `uuid5(namespace, stable_key)`, so they are stable
   across re-imports (ADR 0003). Grade applicability comes from
   `SkillGradeMarker` rows (introduced/mastered/reused).

### 1.2 Flutter app

| Concern | What exists | Where |
|---|---|---|
| State / DI | Riverpod 3 (`Provider`/`Notifier`). Engines get no DI; everything reaches them through `EngineContext`. | `app/lib/**` |
| Routing | go_router. `/play` is pushed from Carte with a `PlayRequest(node, envelope)`. | `app/lib/core/routing/paired_router.dart:29-46`, `app/lib/features/path/path_screen.dart:144-156` |
| Engine contract | `TutolysEngine`: `key`, `version`, `category`, `settingsManifest`, `validate(config) → EngineValidation`, `build(EngineContext, config) → Widget`. State is a private `StatefulWidget` per engine, not a reducer. | `app/packages/engine_sdk/lib/src/engine.dart:77-107` |
| Engine context | `telemetry`, `settings`, `feedback`, `onFinished(ExerciseResult)`, `clock`, `random`, `locale`. | `engine.dart:16-54` |
| Registry | `EngineRegistry(List<TutolysEngine>)`. Duplicate keys throw. `resolve()` returns a sealed `ResolvedEngine \| UnknownEngine \| EngineVersionTooOld`. | `engine_sdk/lib/src/registry.dart:10-90` |
| Runner | `ExerciseRunner` (498 lines): resolve, validate, start telemetry, render the prompt (text + speaker), build the engine; complete or abandon exactly once, abandon on dispose. Multi-question runs through `_MultiQuestionSequencer`, one child runner per question. | `engine_sdk/lib/src/exercise_runner.dart` |
| Engines | `mcq` (204 lines), `pair_match` (261, tap-to-connect), `compose_build` (260), `speed_tap` (278). They share **no** code: `_OptionButton` and the hint UI are duplicated, and colours like `Colors.red.shade400` are hard-coded. `design_system` is declared but never imported. | `app/packages/engines_core/lib/src/` |
| Feedback seam | `EngineFeedback { correct(), incorrect(), celebrate(), hint() }` → `MascotEngineFeedback` sets a `ValueNotifier<MascotMood>`, holds it for 900 ms, then returns to idle. There is no generation token, so a race is possible (animation-system-plan §4). | `engine.dart:57-70`, `app/lib/features/play/mascot_feedback.dart` |
| Mascot | `TutolysMascot` is a CustomPainter fox with `MascotMood { idle, thinking, correct, incorrect, celebrating, hint }`, and it honours `disableAnimations`. `BreathingMascot` is an image bob. There is no Rive or Lottie dependency. | `app/packages/design_system/lib/src/widgets/mascot.dart`, `app/lib/core/widgets/breathing_mascot.dart` |
| Audio | `audioplayers ^6.5.1`. `ExercisePromptAudio` is one player per runner: stop-then-play, errors swallowed. `AudioResolver` has `DriftAudioResolver` over the `audio_cache` blobs. Audio autoplays once per prompt. **No TTS, no SFX, no music, no coordination between players.** `audio_cache` is never pruned. | `engine_sdk/lib/src/audio.dart`, `app/lib/data/sync/drift_audio_resolver.dart`, `app/lib/data/local_db/database.dart:98-120` |
| Play screen | AppBar with the node label (hard-coded French), a 96 px mascot, the runner. No VALIDER button, no question counter, no pause. After the run it records HomeStats and the streak, shows a "+N XP" snackbar, then pops. | `app/lib/features/play/play_screen.dart:92-192` |
| Client telemetry | `TelemetryClient` emits 7 types: `session_start, exercise_start, attempt, hint_used, exercise_complete, exercise_abandon, session_end`. Every event carries the full flat field set. `attempt` carries `answer_payload` (ids) + `answer_hash`. `summary` is computed by the client. | `engine_sdk/lib/src/telemetry.dart:9-292` |
| Outbox | drift `event_outbox` (`event_id` PK = idempotency key, `kid_id`, `payload`, `attempts`, `next_retry_at`, `delivered_at`, `last_error`). `OutboxFlusher` sends batches of 50 every 30 s and on pause/detach. Backoff is exponential with full jitter. Accepted and duplicate events both count as delivered. A 401 pauses the flusher. Delivered rows are pruned after 6 h. The cap is 10k rows, evicting the oldest, and evictions are counted. | `app/lib/data/sync/outbox_flusher.dart`, `drift_event_outbox.dart:186-245` |
| Content sync | Manifest diff by `content_hash`, fetched in chunks of 25. Each envelope is re-hashed, and a mismatch is rejected. The commit is atomic and grade-scoped. Audio is synced best-effort. **Correct answers are inside `config` on the device; grading is client-side.** | `app/lib/data/sync/content_sync.dart` |
| Local DB | drift, kid-scoped since ADR 0014. Native via FFI, web via WASM (ADR 0003). | `app/lib/data/local_db/` |
| Tests | 34 app test files, 2 in engine_sdk (the runner test is 792 lines), 4 in engines_core plus a harness, 0 in design_system. | |

What does **not** exist: session pause/resume or crash recovery (a killed
app loses the question index); seeded shuffles in production (`PlayScreen`
passes no `random`, and no seed is logged); `min_app_version` checks; a
shared answer/evaluation type; any reading of `sound_effects`, `music` or
`animation_level` (only `hints` is read).

### 1.3 Backend (Django)

| Concern | What exists | Where |
|---|---|---|
| Engine registry | `Engine { key, category, current_version, content_schema, min_app_version, status }`. `min_app_version` is **never sent to devices**. | `be/apps/engines/models.py:36` |
| Exercise | `Exercise { engine FK, skill_node FK (one leaf only, enforced), subject, grade, rank, locale, prompt{text,audio_ref,image_ref}, config, assets, schema_version, version, status, content_hash }`. `publish()` bumps the version and snapshots it into an immutable `ExerciseVersionHistory`. | `be/apps/exercises/models.py:65-296` |
| Content schemas | JSON Schema 2020-12 files in `be/docs/schemas/exercise/`: an envelope plus one per engine. **All are `additionalProperties: false`**, items included. `content_cli` validator adds referential checks per engine. | `be/tools/content_cli/validator.py` |
| Multi-question | `config.questions[{prompt, config}]` with **one `engine_key` per exercise** (ADR 0023). | validator `:153-258` |
| Audio | Piper, generated once at authoring time, run as a subprocess (GPL boundary). Voices: fr-CA→`fr_FR-siwis` (France-French, an accepted tradeoff), en-CA→`en_US-lessac`. | `be/apps/exercises/audio.py` |
| Device API | `GET content/manifest?subject=` and `GET content/exercises?ids=` (≤200). Both are grade-scoped from the token. | `be/apps/exercises/views.py:112,176` |
| Mastery | `SkillMastery`, one per (kid, node): an EMA `mastery_pct` (0.3/0.7, mastered at ≥80) **plus** a rules `status` (struggling/watch/mastered/learning/not_started) with evidence fields and `rules_version`. `RulesThresholds` is a versioned config row. `refresh_kid_mastery` runs every 15 min from telemetry aggregates. | `be/apps/progress/` |
| XP / levels / streaks | `XPAward`, one per `exercise_run_id` (10 XP + 5 for first try). `LevelCurve` row. Streak computed from telemetry play-days plus freezes. **XP never feeds mastery**, which already satisfies brief principle 3. | same |
| Reports | Immutable `Report` snapshots with tutor-readable evidence text (`_evidence_text`). | `be/apps/reports/` |
| Auth | Kid token: RS256, 15 min, claims kid/org/device. `IsPairedDevice`. Kid authenticator first (load-bearing order). | `be/apps/pairing/` |
| Admin | Unfold. Exercises are editable, but the admin neither validates `config` against the schema nor recomputes the hash on save. | `be/apps/exercises/admin.py` |
| Error classification | **None.** Options allow only `id/label/image_ref/audio_ref`. The one diagnostic signal is "the same wrong `answer_hash` repeated in a run" (`repeated_wrong_rate`). | `be/apps/progress/rules.py:11-14` |

### 1.4 Telemetry service (FastAPI + TimescaleDB)

- Ingest: `POST /v1/events/batch`, at most 200 events. The response is 200
  with a per-event `accepted | duplicate | rejected(reason)`. The schema is
  `tm/docs/schemas/play_event.v1.json` (`additionalProperties: false`). Each
  event is capped at 16 KiB, and `event_ts` must carry a timezone and be at
  most 300 s in the future. kid/org/device ids are **overwritten from the
  token**. A rate limit of 60/min per device applies.
- Dedupe: `ON CONFLICT (event_id, event_ts) DO NOTHING`. This is
  effectively-once ingestion, exactly what brief §17 asks for, and it
  already exists.
- `play_event` hypertable with a CHECK constraint on `event_type`. Two
  continuous aggregates: `kid_skill_daily` and `exercise_baseline_daily`.
  Compression after 30 days, retention 24 months. An erasure endpoint
  exists.
- Read API (`/v1/aggregates/kid/{id}/…`): skill, rules-signals, skills,
  streak, play-days, exercise-runs, daily-challenge, plus an exercise
  baseline.
- `answer_payload` is stored but **no query reads it**.

### 1.5 Reference material

- `reference/specs/TUTOLYS-FLUTTER-FRONTEND-SPEC.md` §3.8 covers the old
  Godot `tutolys_core` game shell: `LaunchContext`, `GameSession`, one
  scoring formula, a resume store keyed `(child, leaf, leaf_session)`,
  `TelemetrySink` (**`answer_submit` carries ids only, never stem or option
  text: preserve that**), and shared HUD/feedback/settings widgets. Its
  claim: *get the shell right and each engine is 150–250 lines.*
- `reference/engine-schemas/GAME-ARCHETYPES.md`: the 16 archetypes and
  their maturity tiers.
- `app/docs/animation-system-plan.md`: proposed, not built. M0–M6, a
  `tutolys_motion` package, a `MascotDirector` with priorities and a
  generation token. Rive goes behind an M0 spike gate (it downloads native
  binaries at build time).

---

## 2. What can be reused

Keep these. Each already meets a requirement of the brief, or most of one.

1. **The telemetry pipeline end to end.** Stable `event_id`, durable drift
   outbox, kid scoping, batching, backoff, capacity cap with counted
   evictions, per-event server outcomes, `ON CONFLICT` dedupe, token-derived
   identity, erasure, retention. This covers brief §17 almost entirely. The
   gaps are an event *taxonomy* (§6) and session recovery (§5.4), not
   transport.
2. **Content sync and the content-hash discipline.** Canonical-JSON sha256,
   verified on device, atomic commit, grade scoping, content-addressed
   audio.
3. **`EngineRegistry`'s sealed resolution.** It already fails gracefully on
   unknown or too-old engines. It needs a schema-version axis and an
   app-version floor, not a rewrite.
4. **The runner's lifecycle guarantees** (complete or abandon exactly once,
   abandon on dispose) and multi-question by composition (one run per
   question). Mastery, XP and streaks all key off `exercise_run_id`, so
   this must not change.
5. **The `EngineFeedback` seam.** It is already the "engines emit semantic
   outcomes, something else animates" boundary that brief §10 asks for. It
   needs widening into an event stream, not a replacement.
6. **The mastery and rules engine.** It is evidence-based, versioned
   thresholds, pure `classify()`, and never fed by XP. Brief §13 level 4 is
   largely this, plus assistance signals.
7. **Piper audio plus `AudioResolver`.** This is the pre-recorded path of
   brief §9, already offline and verified.
8. **The JSON Schema files plus the `content_cli` validator.** These are
   the reusable validators that brief §19 asks for. An authoring UI should
   call the same validator.

---

## 3. Gaps

| # | Gap | Brief § |
|---|---|---|
| G1 | Engine state is widget-internal, so there is no deterministic reducer, no snapshot or restore, and no session recovery. | 5, 18 |
| G2 | Engines decide correctness themselves. There is no separate evaluator, no partial credit, no evaluation version or authority. | 12 |
| G3 | There is no activity shell. The prompt and speaker sit in the runner, the hint inside each engine, and there is no submit, no feedback panel, no question counter, no pause. | 8 |
| G4 | No shared mechanics or presentation components. The 4 engines duplicate buttons and hints and bypass `design_system`. | 7 |
| G5 | Audio is one player per runner. There is no coordinator (narration, SFX and character speech would collide), no per-part speech policy, no visible-text vs speech-text split, no TTS adapter seam. | 9 |
| G6 | There is no animation director: no characters, no priorities, no cancellation, no renderer abstraction. | 10 |
| G7 | The telemetry taxonomy has only 7 coarse types: no interaction-level events, no session/run split, no sequence, no active (pause-excluded) time, no evaluation detail. | 13, 14 |
| G8 | No error classification: options can't carry diagnostic meaning, and the schemas forbid extra keys. | 15 |
| G9 | Shuffles are unseeded and no seed is stored. | 11, 18 |
| G10 | `min_app_version` is never sent. Strict schemas mean any new content key breaks older installs. | 5, 11 |
| G11 | One skill per exercise, and one engine per exercise. | 2 |
| G12 | Audio cache never pruned; stuck outbox rows never cleared. | 17 |

---

## 4. Proposed architecture

### 4.1 Package layout (fits the existing repo; one new package)

```
app/packages/
  engine_sdk/        CONTRACTS + RUNTIME (no UI chrome, no characters)
    contracts/       LearningEngine, Evaluator, QuestionEnvelope, AnswerValue,
                     EvaluationResult, RuntimeEvent (sealed), EngineDescriptor
    runtime/         ActivitySessionMachine (pure), ActivitySessionController,
                     SessionStore (interface), ActiveClock, SeededRandom
    audio/           AudioCoordinator, SpeechPlan, AudioResolver (exists),
                     TtsEngine (interface only), VoiceCaptureService (interface only)
    telemetry/       TelemetryClient (exists, extended to v2 envelope)
    legacy/          TutolysEngine adapter, so the 4 existing engines keep running
  engines_core/      ENGINES + SHARED MECHANICS + PRESENTATION
    mechanics/       Selectable, Sortable, Connectable, Droppable, TextEditable...
    widgets/         AnswerTile, WordTile, NumberTile, DropZone, ... (on design_system)
    shell/           ActivityShell (header, prompt, speaker, hint, submit, feedback,
                     character slot) — depends on design_system
    engines/         mcq (reference), pair_match, compose_build, speed_tap, ...
  tutolys_motion/    NEW — animation director, characters, renderers
                     depends on engine_sdk (event types) + design_system. Never imported
                     by an engine.
  design_system/     unchanged role; gains its first tests
app/lib/features/play/   composition root: wires shell + controller + director +
                         audio + drift SessionStore + outbox. The /play route is unchanged.
```

Dependency rule, enforceable by a test that reads each package's
`pubspec.yaml` and imports: **`engines_core/engines/**` may import only
`engine_sdk/contracts`, `engines_core/mechanics` and `engines_core/widgets`.**
It may not import `tutolys_motion`, `audioplayers`, drift, dio or `lib/`.

This is the animation-system-plan's `tutolys_motion` package, not a second
one. Its M1/M2 phases become Phase 2 here.

### 4.2 Data flow for one question

```
QuestionEnvelope ─parse/validate─► engine.initialize(content, seed) ─► state
      learner gesture ─► Action ─► engine.reduce(state, action) ─► (state', [InteractionEvent])
      shell "VALIDER" / auto-submit ─► engine.extractAnswer(state) ─► AnswerValue
      Evaluator.evaluate(content, answer, ctx) ─► EvaluationResult
      ActivitySessionMachine.on(AnswerEvaluated) ─► next state (feedback / retry / next / done)
                     │
                     └── RuntimeEvent stream ──┬─► TelemetryRecorder ─► drift outbox (durable)
                                               ├─► AnimationDirector ─► CharacterRenderer
                                               ├─► AudioCoordinator  ─► players
                                               └─► SessionStore (snapshot after each durable step)
```

Ordering rule: **the telemetry write and the session snapshot happen before
the event is published to the director and audio.** A renderer that throws
is isolated in its own `runZonedGuarded` subscriber. It is logged as a local
`animation_diagnostic` and can never block or lose a learning event (brief
§16).

---

## 5. Contracts

All names are provisional. Signatures are illustrative Dart, close to what
Phase 1 will write.

### 5.1 Engine SDK

```dart
final class EngineDescriptor {
  final String key;                      // stable: 'mcq' — matches be Engine.key
  final int version;                     // implementation version
  final Set<int> contentSchemaVersions;  // which config shapes it parses
  final SubmitMode submitMode;           // explicit (VALIDER) | onComplete | immediate
  final EngineCapabilities capabilities; // keyboard, screenReader, dragFree, speakableParts
}

abstract interface class LearningEngine<C, S, A, Ans extends AnswerValue> {
  EngineDescriptor get descriptor;
  ParseResult<C> parse(Map<String, Object?> config, int schemaVersion); // validation lives here
  S initialize(C content, EngineSeed seed);                             // pure, deterministic
  Transition<S> reduce(S state, A action);                              // pure: state' + interaction events
  Ans? extractAnswer(S state);                                          // null = not submittable yet
  S applyFeedback(S state, EvaluationResult result);                    // e.g. lock a wrong option
  Map<String, Object?> snapshot(S state);                               // for SessionStore
  S restore(C content, Map<String, Object?> snapshot);
  Widget buildView(EngineView<C, S, A> view);                           // view.dispatch(action)
}

final class Transition<S> { final S state; final List<InteractionEvent> events; }
```

Why this shape, and not the brief's verbatim: `parse` replaces
`validate(TContent)`, because validating an already-typed `TContent` is too
late. The raw map is the runtime boundary (brief rule 11). `applyFeedback`
exists because retry-until-correct engines must react to a wrong answer,
greying out the tried option for example, without knowing *why* it was
wrong. `snapshot`/`restore` are what make G1 closable.

The registry gains an **app-version floor only**:
`resolve(engineKey, minimumVersion, minAppVersion?, appVersion?)` returns
`Resolved | Unknown | VersionTooOld | AppVersionTooOld`. Phase 1 found that
`engine_min_version` already *is* the content-schema axis: it carries the
backend's `Engine.current_version`, the content-contract version. So a
separate schema number would have duplicated it (ADR 0017 §7). The
envelope's own `schema_version` is checked by `QuestionEnvelope.parse`,
which reports a newer one as *unsupported*. The shell renders every miss as
"this activity needs an update", and each one is logged.

**Legacy adapter.** `TutolysEngine` implementations keep working through
`LegacyEngineHost`, which runs them inside the new shell with
`submitMode: immediate`. They are migrated one at a time. No content
changes are needed, because the engine keys and config shapes stay the
same.

### 5.2 Question envelope

The backend envelope already exists. Extend it **additively**, so every new
field is optional with a default (G10).

```jsonc
{
  "schema_version": 2,                     // envelope schema; 1 still accepted
  "exercise_id": "…", "version": 3, "content_hash": "…",
  "engine_key": "mcq", "engine_min_version": 1, "min_app_version": "1.4.0",   // NEW: from Engine
  "skill_node_id": "…",                    // primary skill — unchanged
  "secondary_skill_node_ids": [],          // NEW, only if §10 D5 approves
  "locale": "fr-CA",
  "prompt": {
    "text": "Combien font 7 + 5 ?",
    "audio_ref": "audio",                  // existing: pre-recorded (Piper today)
    "speech": { "text": "Combien font sept plus cinq ?", "locale": "fr-CA",
                "mode": "prerecorded" }    // NEW: authoring-time pronunciation source
  },
  "speech_policy": {                       // NEW: what may be read aloud, and when
    "prompt": "auto",                      // auto | on_request | never
    "options": "on_request",               // never for reading/listening assessments
    "feedback": "on_request"
  },
  "config": { /* engine content, per engine schema */ },
  "evaluation": { "policy": "exact", "version": 1, "max_attempts": null }, // NEW; null = retry-until-correct (today)
  "assets": [ { "ref": "audio", "url": "…", "sha256": "…" } ]
}
```

- Each question in `config.questions[]` keeps its own `prompt`. It may gain
  `engine_key` only if §10 D4 approves mixed engines.
- `speech.text` is what Piper renders at authoring time. The visible
  `text` stays as written. This gives the brief's text/pronunciation split
  without live TTS (§10 D2).
- Options gain an optional `diagnosis` (§5.5) and optional `speech`/
  `audio_ref`. Option `audio_ref` is already allowed by the schema.

**Question instance identity.**
`question_instance_id = uuid5(activity_session_id, question_index)`. The
shuffle seed is drawn once per activity session, stored in the session
snapshot, and logged in `exercise_start`.

### 5.3 Answers and evaluation

```dart
sealed class AnswerValue { Map<String, Object?> toJson(); }  // ids only — never stems or labels
  SingleChoiceAnswer(selectedOptionId) · MultiSelectAnswer(ids) · PairsAnswer(pairs)
  OrderingAnswer(orderedIds) · PlacementsAnswer(itemId→targetId) · TextAnswer(value)
  BlanksAnswer(blankId→value) · HotspotAnswer(regionIds)

abstract interface class Evaluator<C, Ans> {
  String get policy; int get version;
  EvaluationResult evaluate(C content, Ans answer, EvaluationContext ctx);  // pure
}

final class EvaluationResult {
  final Outcome outcome;            // correct | partial | incorrect | ungraded
  final double score;               // 0..1, partial credit
  final int attemptNumber;
  final String evaluator;           // 'mcq.exact@1'
  final EvaluationAuthority authority;  // local | server
  final String? feedbackCode;
  final List<ErrorClassification> errors;   // §5.5; may be empty or 'unclassified'
  final List<String> skillNodeIds;
  final bool needsReview;           // e.g. speaking, low-confidence ASR
}
```

Evaluators live in `engine_sdk` (pure Dart, shared by engines). They are
selected by `engine_key` + `evaluation.policy`, so subject-specific
diagnostics never live inside engines (brief §15).

**Authority.** Today all grading is client-side, with answers on the
device. That is the only way offline practice works, and offline practice
is a hard requirement. So every result says `authority: local`. Server
re-evaluation becomes possible later without any client change: telemetry
already stores `answer_payload` and the exact `exercise_version`. Hiding
answers from the payload only matters for an *assessment* mode, which does
not exist; it is deferred (§10 D6).

### 5.4 Session lifecycle

`ActivitySessionMachine` is a pure reducer:
`(SessionState, SessionInput) → (SessionState, List<RuntimeEvent>)`.

```
created → loading → ready → presenting(q) → awaitingInteraction(q)
  → submitted(q, attempt) → evaluating → feedback(q, result)
      → [retry allowed & not correct] awaitingInteraction(q)
      → [more questions] presenting(q+1)
      → completed
any active state → paused → (resumed) previous
any → interrupted (app killed — detected at next launch from a non-terminal snapshot)
     → resumed | abandoned (user declines, or snapshot older than threshold)
any → failed(reason) (content invalid, engine unresolvable, evaluator threw)
```

- **Logical session vs run.** `activity_session_id` is created once per
  exercise and survives resume. `session_run_id` is new per process/screen
  mount. The existing `exercise_run_id` stays, one per question, because
  XP and mastery key off it.
- **SessionStore.** A new drift table, kid-scoped like the rest of ADR
  0014:
  `activity_session(id, kid_id, exercise_id, exercise_version, content_hash, seed, question_index, engine_snapshot json, attempt_numbers json, status, active_ms, updated_at)`.
  It is written after every durable step. A snapshot whose `content_hash`
  no longer matches the cache is abandoned, never replayed against new
  content.
- **No duplicate submissions.** The `attempt` event id is deterministic:
  `uuid5(question_instance_id, attempt_number)`. If a crash happens between
  the outbox write and the snapshot write, the resume path re-derives the
  same id and the outbox PK rejects the duplicate locally. Telemetry's
  `ON CONFLICT` covers the network side.
- **Active time.** `ActiveClock` is built on `Stopwatch`, which is
  monotonic. It pauses on `AppLifecycleState.inactive/hidden/paused` and on
  shell pause. Wall clock is used only for `event_ts`.

### 5.5 Error classification

- Backend: a new `ErrorCode` model
  `(taxonomy, code, version, subject, label_fr, label_en, teacher_description)`,
  edited in the admin.
- Content: an option may carry
  `"diagnosis": {"code": "math.add.no_regroup", "taxonomy_version": 1}`.
  The validator checks the code exists. This is how "distractors carry
  declared diagnostic meaning" from the 2026-10-24 interview becomes real.
- Runtime: the evaluator copies the chosen option's diagnosis into
  `EvaluationResult.errors`. With no diagnosis it records `unclassified`.
  One result is **an observation, never a diagnosis**. Only the rules
  engine aggregates observations into a status, with thresholds, exactly as
  `repeated_wrong_rate` works today.

### 5.6 Runtime events

Each event is a sealed Dart class with a category:

| Category | Examples | Persisted? |
|---|---|---|
| `learning` | question_presented, answer_submitted→`attempt`, question_completed→`exercise_complete`, activity_completed, question_skipped | **durable outbox → telemetry** |
| `interaction` | option_selected/deselected, tile_moved, pair_connected/disconnected, text_revised (debounced), hint_requested→`hint_used`, audio_requested, audio_replayed | durable outbox → telemetry (state changes only: no pointer paths, no keystrokes) |
| `accessibility` | read_aloud_toggled, keyboard_used, text_scale_bucket | durable, aggregated per session |
| `runtime_diagnostic` / `sync_diagnostic` | engine_unresolved, content_invalid, snapshot_discarded, outbox_eviction | local ring buffer; counted summary only |
| `animation_diagnostic` | reaction_missing, renderer_error | **local only, sampled; never in the outbox** |

### 5.7 Animation (`tutolys_motion`)

```dart
final class CharacterManifest { id, version, rendererType /* placeholder|rive */,
  Set<Reaction> supported, Map<Reaction, Reaction> fallbacks, Reaction idle, assets }
enum Reaction { idle, thinking, curious, listening, speaking, explaining,
                encouraging, celebrating, victory, waiting, sleeping }
abstract interface class ReactionPolicy {        // per character role, data-driven
  List<ReactionCue> onEvent(RuntimeEvent e, DirectorContext ctx); }
final class ReactionCue { actorRole, reaction, Priority priority, Duration? hold, bool returnToIdle }
enum Priority { ambient, decorative, interaction, learningFeedback, critical }
abstract interface class CharacterRenderer {    // Widget + controller; no engine knows it exists
  Widget build(BuildContext, CharacterActorState); Future<void> perform(ReactionCue, CancelToken); }
class AnimationDirector { // subscribes to RuntimeEvent stream; per-actor generation token;
  // higher priority cancels lower; reduced motion → renderer gets ReducedMotion and
  // must rest on a still pose; missing reaction → manifest fallback → idle; never awaited by gameplay
}
```

- The `ActivityShell` exposes `characterSlots` (guide, companion). The
  activity or subject config names which characters fill them, via
  `CharacterRegistry`. No character name appears in an engine or in the
  shell.
- `PlaceholderCharacterRenderer` wraps the existing `TutolysMascot`, mapping
  `Reaction` to the closest `MascotMood` plus a Flutter transition, and
  `BreathingMascot` PNGs. That is the Phase 2 proof. `RiveCharacterRenderer`
  is Phase 7, behind the existing M0 spike.
- `EngineFeedback` becomes a thin adapter that emits `RuntimeEvent`s, so
  the legacy engines feed the director too.
- **Gameplay never awaits an animation.** The ~400–600 ms "beat" before the
  next question is a shell timer (animation-system-plan §5), independent of
  how long a reaction plays.

### 5.8 Audio

```dart
abstract interface class AudioCoordinator {
  Future<PlaybackHandle> play(AudioRequest r);   // channel: narration | character | sfx | music
  void stopChannel(AudioChannel c); void stopAll();
  Stream<PlaybackStatus> get status;             // loading | playing | completed | error
}
// Rules: narration and character speech share a "voice" lane (one at a time; newer
// request with higher priority cancels); sfx ducks nothing and is capped at 1 concurrent;
// music (none exists yet) ducks under voice. One AudioPlayer per channel, app-scoped.
sealed class AudioSource { PrerecordedAsset(ref) | TtsUtterance(text, locale) }
abstract interface class TtsEngine { … }          // interface only; no implementation (§10 D2)
abstract interface class VoiceCaptureService { … } // interface only; Phase 6
```

`SpeechPlan` takes the envelope plus `speech_policy` and the assessment
type, and works out what may be spoken: prompt auto-read, options on
request, and nothing for a reading assessment. The shell's speaker button
and each option's speaker call it; engines never touch audio. Captions are
the visible text, which is always present. The `sound_effects`/`music`
settings finally get read here. **Audio failure never blocks the
question:** the speaker shows an unavailable state, logs
`audio_unavailable`, and the question stays answerable.

### 5.9 Shared mechanics

Mechanics are **interaction controllers, not widgets**: `SelectableGroup`
(single or multi, keyboard arrows, Space/Enter), `SortableList` (drag *and*
move-up/move-down buttons, so drag is never the only path), `Connector`
(tap-tap, the pair_match model, plus drag), `DropTargets`, `TextEntry`
(numeric/text, IME-safe) and `HotspotMap` (regions with semantics labels).
Presentation is separate: `AnswerTile`, `WordTile`, `NumberTile`,
`ImageTile`, `DropZone`, `CategoryContainer`, `ConnectionLine`,
`FeedbackPanel`, `HintPanel` and `QuestionProgress`, all on
`VillagePalette` and design-system tokens. Correctness is never shown by
colour alone: each state also gets an icon and text. A wrong answer uses
amber `retry`, never red, per the design's Decision Log, and the current
`Colors.red.shade400` gets fixed.

Engine composition (brief §6): *Listening* is not an engine. It is any
engine plus `speech_policy.prompt = auto` and an options policy of `never`.
*Categorization* = Droppable + CategoryContainer. *True/False* =
SelectableGroup with two options, so it is a config preset of the
single-choice engine, not new code.

---

## 6. Telemetry changes

The smallest safe path: **keep `play_event.v1` working and add v2
alongside it.** Aggregates, mastery and XP read `attempt` and
`exercise_complete`, so v2 keeps those two types with the same meaning.

- New columns, all nullable, so v1 rows stay valid: `event_category`,
  `activity_session_id`, `session_run_id`, `question_instance_id`,
  `sequence` (per run, monotonic), `active_elapsed_ms`, `content_hash`,
  `evaluation` (jsonb: outcome, score, evaluator, authority, error codes),
  `assistance` (jsonb: hints, audio replays, read-aloud on).
- New `event_type` values for the interaction category. The CHECK
  constraint needs a migration. The schema becomes
  `play_event.v2.json` with a typed `payload` per event type, and
  `schema_version ∈ {1,2}`.
- Privacy rules, enforced in a contract test on both sides: payloads hold
  **ids only** (the old shell's property). Text answers are length-capped
  (≤64 chars) and never logged on interaction events, only on the
  submitted attempt. There is no pointer data, no keystrokes and no audio.
  Identity still comes from the token only.
- `attempt` keeps `is_correct` (true only for `outcome == correct`), so
  every existing aggregate is unchanged. Partial credit lives in
  `evaluation.score`.
- Level 4 (skill evidence) gets **no new event store.** A new read,
  `/v1/aggregates/kid/{id}/skill/{node}/evidence`, adds assistance-
  weighted first-try rates. Hints and replays mark evidence as *assisted*,
  not *wrong* (brief §20: never penalize accessibility). `refresh_mastery`
  consumes it under a new `RulesThresholds` version. Secondary skills (if
  D5 is approved) produce evidence flagged `secondary`, weighted lower.
- Client: the outbox is unchanged. Stuck rows (≥10 attempts) are surfaced
  in a count and kept, never deleted unsynced. `audio_cache` is pruned when
  an exercise leaves the cache (G12).

---

## 7. Backend changes (a work order, not edits from this session)

Per the repo-ownership rule, these go to the backend agent through Hafid as
`Platforms/BACKEND_WORKORDER_LE1.md`. Telemetry changes go to whoever owns
`tm/`.

| ID | Change | Migration? |
|---|---|---|
| LE-B1 | Envelope schema v2: optional `prompt.speech`, `speech_policy`, `evaluation`, option `diagnosis`/`speech`. Validator and Piper generate from `speech.text` when present. | No: JSONField |
| LE-B2 | Ship `Engine.min_app_version` in the manifest and envelope. | No |
| LE-B3 | `ErrorCode` model, admin, and validator check. | Yes, additive |
| LE-B4 | (D5) `ExerciseSkill` M2M `(exercise, skill_node, role=primary\|secondary)`. The `skill_node` FK stays as the primary. | Yes, additive |
| LE-B5 | (D4) per-question `engine_key`. Manifest `engine_min_version` = max over questions. | No |
| LE-B6 | Admin: validate `config` and recompute `content_hash` on save, with a preview link. This is the seed of brief §19 authoring. | No |
| LE-B7 | Expose `SkillMastery.status` and evidence in `/me/progress` for Progrès. | No |
| LE-T1 | `play_event.v2` schema, columns, CHECK migration, ingest accepting both versions. | Yes, additive |
| LE-T2 | `/skill/{node}/evidence` read. | No |

**The plan also depends on two already-open items.** The entitlement bug in
`BACKEND_WORKORDER_A0.md` is unrelated but live. And no device-facing
play-days read exists.

---

## 8. Roadmap (brief §22, mapped to files)

| Phase | Deliverable | Main files | Done when |
|---|---|---|---|
| **1 Contracts** | This doc + ADR 0017. `engine_sdk/contracts/*`, `runtime/activity_session_machine.dart` (pure), `SessionStore` interface, `RuntimeEvent` sealed set, `AudioCoordinator`/`TtsEngine`/`VoiceCaptureService` interfaces, `tutolys_motion` skeleton with its interfaces, registry schema axis, the import-boundary test. No UI change. | `app/packages/engine_sdk/lib/src/{contracts,runtime,audio}/`, `app/packages/tutolys_motion/` | Machine tests cover every transition, pause/resume, interrupted, duplicate submit and failed. App tests are still green. |
| **2 Runtime** | `ActivitySessionController`, `ActivityShell` (prompt, speaker, hint, VALIDER, feedback, counter, pause, exit, character slot), `AudioCoordinator` on audioplayers, `AnimationDirector` + `CharacterRegistry` + `PlaceholderCharacterRenderer`, drift `activity_session` table (schema v4→v5, tested with the existing drift schema harness), telemetry v2 recorder, `LegacyEngineHost`. `PlayScreen` switches to the shell; the route is unchanged. | `engines_core/lib/src/shell/`, `tutolys_motion/lib/`, `app/lib/data/local_db/`, `app/lib/features/play/` | The 4 existing engines play inside the new shell with no content change. |
| **3 Reference** | `mcq` rebuilt on `LearningEngine` with `exact` evaluator, seeded shuffle, snapshot/restore and full interaction events. Works end to end against dev-stack: the brief §25 scenario steps 1–24, with step 22's "sync to Django" meaning sync to telemetry, then mastery refresh. **Blocked on LE-T1** for the v2 fields; v1 still works without them. | `engines_core/lib/src/engines/mcq/` | Kill-and-resume test, duplicate-submit test and a live dev-stack run recorded in the ADR. |
| **4 Mechanics** | Mechanics + widgets, with `design_system` tests. Port `pair_match`, `compose_build` and `speed_tap` onto them. | `engines_core/lib/src/{mechanics,widgets}/` | No duplicated tile/button code. Keyboard-only play test for each. |
| **5 Engines** | Only the ones that need new mechanics: multi-select, ordering, categorization, fill-blank, text input, hotspot. Listening and true/false are presets. **The list needs D1.** | `engines_core/lib/src/engines/` | Each engine ≤ ~250 lines plus tests. |
| 6 Speaking | `VoiceCaptureService`, consent gating, no raw retention. **Needs counsel input (Law 25/COPPA) first.** | | |
| 7 Rive | animation-system-plan M0 spike, then `RiveCharacterRenderer`. | `tutolys_motion/` | Swapped in by manifest; no engine diff. |
| 8 Analytics | Evidence read, thresholds v2, Progrès/teacher surfaces. | `tm/`, `be/apps/progress` | |

---

## 9. Risks

1. **Migrating the engine contract under live content.** Mitigated by the
   legacy adapter and by keeping engine keys and config shapes unchanged.
   One engine moves at a time.
2. **Strict schemas vs older installs.** Every new field must be optional
   *on the client* too. Test: an old-version parser fed a v2 envelope still
   plays it, or shows "update needed", and never crashes.
3. **Telemetry v1/v2 coexistence.** Aggregates must keep reading v1
   semantics. A contract test pins `attempt`/`exercise_complete` meaning
   across both.
4. **Web.** Autoplay policies block audio before the first gesture, so
   auto-read degrades to "tap to listen". drift WASM is already proven
   (ADR 0003). Live web-UI verification has failed in this sandbox before
   (CLAUDE.md), so widget tests carry the proof.
5. **Client-side grading integrity.** It is acceptable for practice. It
   would be wrong to present client-graded data as authoritative
   assessment, and reports must label authority once a server path exists.
6. **Over-abstraction.** The brief lists 9 mechanics and 17 widgets. Build
   each one only when an engine in Phases 3–5 needs it.
7. **Rive native binaries** (same failure class as ADR 0002). It stays
   behind M0.
8. **Speaking and child voice data.** It is legally the riskiest feature
   here, and `Platforms/legal/` doesn't cover it.

---

## 10. Decisions (all accepted as recommended, 2026-10-25)

| # | Question | Conflict | Recommendation |
|---|---|---|---|
| **D1** | Which engine list? | The brief's 12 (single choice … hotspot) differ from your earlier "12 of the 16 archetypes" call and from ADR 0005's unconfirmed 9. | Treat the brief's list as **interaction mechanics** and keep archetype keys for content. `mcq` *is* Single Choice and is not renamed: renaming breaks content, telemetry and mastery history. |
| **D2** | Live TTS? | The brief wants fr-CA TTS. You chose Piper pre-generation (fr-FR voice only) because `flutter_tts` has no Linux build and offline is required. | Keep Piper. Add `speech.text` so pronunciation ≠ visible text. Ship a `TtsEngine` **interface only**, with an adapter later per platform or for a paid fr-CA cloud voice at authoring time. |
| **D3** | Submit model | The design has VALIDER. Today's engines resolve on tap. | The shell owns VALIDER. Engines declare `submitMode`. Single choice uses explicit submit; the legacy engines run as `immediate` until ported. |
| **D4** | Mixed engines in one activity? | The brief says yes. ADR 0023 says one engine per exercise. | Allow a per-question `engine_key` (LE-B5). It is cheap, because each question is already its own run. |
| **D5** | Multiple skills per exercise? | The brief says many-to-many. Today it is one FK. | Keep the primary FK and add secondary skills. Mastery counts secondary evidence at a lower weight, or not at all at first. |
| **D6** | Hide answers from the device? | The brief wants answers not exposed. Offline requires them on the device. | Don't hide them yet, since there is no assessment mode. Label every result `authority: local`. |
| **D7** | Where the doc and ADRs live | The brief names `docs/architecture/`. | This file lives in `tutolys-app`; backend and telemetry parts go to them as a work order. |
| D8 | Speaking (Phase 6) | | Do not start before counsel reviews voice capture for children. |

The brief also says the app already has "quests and achievements".
Achievements and badges don't exist (open item #3) and are not in scope
here. The brief's "no shop" principle matches the Boutique staying
deferred.

---

## 11. Testing strategy

- **Pure-logic unit tests (most of the suite):** session machine
  transitions, including illegal ones; engine `initialize` determinism
  (same seed gives the same order); `reduce` and `extractAnswer`;
  `snapshot`/`restore` round-trip; evaluators, including partial credit and
  diagnosis passthrough; `SpeechPlan` policy; director priority,
  interruption, fallback and reduced motion with a fake clock. None of
  these need widgets.
- **Contract tests:** envelope v1 and v2 parse on the client;
  `play_event.v2` JSON Schema shared with `tm/`, as `telemetry_contract_test`
  already does for v1; a privacy test asserting no label or stem text
  appears in any interaction payload; the import-boundary test (§4.1).
- **Widget tests:** shell plus legacy and new engines; keyboard-only
  completion; semantics labels; renderer swap (fake renderer) with no
  engine change; a renderer that throws doesn't stop progression.
- **Persistence tests:** drift v4→v5 migration on the real schema harness;
  kill mid-question then resume restores the index, seed and state;
  replaying the same attempt id is rejected; outbox flush retry and
  partial-batch outcomes (these mostly exist already).
- **Live:** brief §25 against dev-stack, recorded step by step in the
  Phase 3 ADR, the same way earlier ADRs recorded live runs.
