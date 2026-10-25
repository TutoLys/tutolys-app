# ADR 0019 — Learning engine platform, Phase 2: the shared runtime

Date: 2026-10-25
Status: accepted

## Context

Phase 1 (ADR 0017) added the contracts and the pure parts. Phase 2 makes
them run. That means a controller that drives a session, the shared shell
every exercise appears in, an audio coordinator, an animation director with
a placeholder character, durable session storage, and a bridge so today's
four engines play inside the new shell unchanged
(`docs/architecture/learning-engine-platform.md` §8).

No engine is on the new `LearningEngine` contract yet; porting `mcq` is
Phase 3. So in the running app every exercise takes the **legacy path**
through the new shell. The new **runtime path** is complete and tested, but
until Phase 3 only test engines exercise it.

## Decision

1. **A step's events and the session snapshot commit in one transaction**
   (`ActivitySessionStore.commit`, `DriftActivitySessionStore`). Phase 1
   leaned on deterministic event ids for duplicate safety. Building the
   store showed why that isn't enough on its own: telemetry deduplicates
   on `(event_id, event_ts)`, so a step replayed after a crash, with a new
   timestamp, would be a new row at the server once the original had been
   delivered and pruned locally. With one transaction there is no crash
   window to replay from. The deterministic ids stay as a second line of
   defence.

2. **`ActivitySessionController` follows one order for every operation.**
   First it computes the next machine state, engine state and events, all
   pure. Then it commits. Only after that does it adopt the new state and
   publish to subscribers. So the director and the audio never react to
   an event that isn't durable, and a failed commit leaves the session
   exactly where it was. The failure shows as a "couldn't save" notice,
   and tapping again retries. Operations are serialised, so a double tap
   of VALIDER produces one attempt.

3. **The recorder writes `play_event.v1`.** Telemetry doesn't take v2 yet
   (LE-T1), so `V1EventRecorder` maps only the events with a v1 type:
   session start and end, exercise start and complete, attempt, hint and
   abandon. These keep their v1 meaning, so aggregates, mastery and XP
   read them unchanged. Selections, audio requests and pauses are
   published in-process but **not stored yet**; `unrecordedEventCount`
   keeps that gap visible. Durations come from `ActiveClock`, so a paused
   or backgrounded app doesn't count as answer time. The recorder's
   tallies and the open run's identity ride in the snapshot, so a summary
   written after a resume covers the whole question. An ungraded attempt
   (the evaluator threw) is not written as `attempt` at all: v1 needs
   `is_correct`, and our bug must not lower a child's mastery. The v1
   event map now lives in one builder, `buildV1Event`, shared with
   `TelemetryClient`, so the two paths can't drift apart.

4. **`ActivityShell` is presentation only and follows the design**
   (`03-exercise-engines.html` `.exo-*`):
   - a top bar with close, a gold progress track, the XP pill and
     "N en série";
   - the prompt with its speaker button;
   - a character slot;
   - the INDICE button and a hint panel;
   - VALIDER, gold when active;
   - the feedback banner: "Bravo !" with a check on green, "Presque !"
     with a target on amber, never red.

   Every state carries words and an icon, not colour alone. Enter is
   VALIDER, or the banner's action when one is showing. The bottom bar
   tightens below 600 px. A test at 360 px caught a real overflow.
   `VillagePalette` gained `successPale` and `retryPale`, copied from the
   design's `:root` blocks like the rest.

5. **`LegacyEngineHost` and `LegacyFeedbackBridge`.** Today's engines run
   in the shell with **no content, telemetry or scoring change**: the
   `ExerciseRunner` still owns its prompt, engine and events. The shell
   drops what a legacy run can't honestly show: progress (the runner
   doesn't expose its question index), VALIDER (these engines resolve on
   tap), the shell's hint (each engine draws its own) and pause
   (`speed_tap`'s timer can't be paused from outside). The bridge turns
   `EngineFeedback` calls into runtime events **for characters only**.
   It keeps the 900 ms beat the engines already await, so their pacing is
   unchanged. `MascotEngineFeedback` is deleted; the bridge plus the
   director replace it.

6. **`AnimationDirector`** keeps one `ActorScheduler` per cast role and
   runs reactions on its own timers. Gameplay never awaits it. A missing
   character, or a policy that throws, becomes a local
   `AnimationDiagnostic`, never a crash. A renderer that throws while
   building draws nothing (`CharacterStage`). Its `dispose()` is
   synchronous. An awaited version hung every widget test that awaited
   it, and a screen's `dispose` can't await anyway.

7. **`PlaceholderCharacterRenderer`** draws the existing painted fox.
   *Encouraging* borrows the gold `hint` pose, because
   `MascotMood.incorrect` paints the danger red. A test asserts no
   reaction ever maps to it. A Rive renderer arrives later as another
   `CharacterRenderer` selected by manifest. The swap is tested with a
   fake renderer, and no engine changes.

8. **`ChannelAudioCoordinator`** is the app's one coordinator
   (`audioCoordinatorProvider`): one player per channel, arbitrated by
   Phase 1's `AudioLanePolicy`. It never throws. A missing asset is
   *unavailable*, a platform failure is *error*, and the question stays
   answerable either way. The Réglages sound-effects and music toggles
   are read on every request. No effects are bundled, because the old
   SFX were never licensed.

9. **Answer choices are never read aloud by default.** The envelope's v1
   default for `speech_policy.options` changed from *on request* to
   *never*. The audit had missed Hafid's recorded correction, kept in the
   design's Decision Log and on `AppSettings.readAloud`: read the question
   aloud, never the choices. Content can still opt choices in. The
   speaker button only appears when the prompt has something that may
   actually play.

10. **Session storage**: drift `activity_session` table, schema v4 → v5.
    The migration is tested against a real v4 database with the drift
    schema harness, and existing outbox and streak rows survive. A
    session left mid-question resumes on the next visit to that exercise.
    A session played against different content is closed in telemetry
    (`exercise_abandon` and `session_end`, under its own ids and its run's
    original identity) and a fresh one starts.

11. **Smaller changes:**
    - `ExerciseRunner` no longer creates a platform audio player just to
      dispose it.
    - `ActivitySessionStore` is the Phase 1 `SessionStore`, renamed: the
      app already has a `SessionStore` (the pairing secure store).
    - The fake engine moved to `package:engine_sdk/testing.dart`, and a
      boundary test keeps production code from importing it.
    - The play screen lost its AppBar title. The design's exercise chrome
      has none, and `paired_router_test` now checks that the node arrives
      rather than that it is drawn.

## Verification

- **Tests:**
  - engine_sdk: 94 → 124;
  - engines_core: 36 → 45;
  - tutolys_motion: 16 → 24;
  - app: 325 → 349, including the v4 → v5 migration, the drift store,
    and three `PlayScreen` tests. One plays a real `mcq` through the
    legacy path into the real drift outbox. One leaves a runtime session
    mid-question and resumes it with no second `session_start`. One
    closes it and confirms nothing is left to resume.
  - `flutter analyze` is clean in the app and in every package.
- **Live, against the real dev-stack:**
  - A fresh test kid was paired on localhost through the real API, and
    the web build was served under a same-origin proxy.
  - The real `compose_build` exercise "Construis le nombre 7 avec deux
    blocs" played inside the new shell: close button, the placeholder fox
    on stage, the runner's prompt and speaker.
  - On the correct answer the fox turned to its celebrating pose through
    the bridge and director, and the screen returned to Carte when the
    run finished.
  - This is the first time the Flutter web app has been seen running in
    this sandbox; earlier sessions recorded an empty `flt-glass-pane`.

## Found, not fixed here

- **Telemetry never uploads.** After pairing, and after a reload that
  restores the kid, no request reached `/v1/events/batch` within 40 s.
  `AppShell.initState` captures `outboxFlusherProvider` once, before the
  session restores, so the running flusher is bound to the
  `__unpaired__` outbox scope and finds nothing to send. When the kid is
  known, the provider builds a new flusher for that kid, but nothing ever
  starts it. This predates Phase 2 (ADR 0014's kid scoping plus ADR 0007's
  one-time wiring). It means every play since kid scoping has stayed on
  the device. It needs its own fix and its own test.

## Not done

- No engine on `LearningEngine` (Phase 3: `mcq`).
- Interaction events aren't stored until telemetry v2 (LE-T1).
- There is no "Continue where you left off?" prompt: a session resumes
  silently on the next visit to the same exercise. Sessions left on other
  exercises stay until visited.
- Audio volume (Réglages' 0–100) isn't applied to the coordinator yet.
