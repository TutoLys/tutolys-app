# ADR 0021 — Learning engine platform, Phase 3: `mcq` on the new contract

Date: 2026-10-25
Status: accepted

## Context

Phase 3 is the reference engine. The plan was to port `mcq` onto
`LearningEngine` and prove the whole runtime with it, end to end, against
the real backend (architecture doc §8, the brief's §25 scenario). Phase 2
(ADR 0019) left the runtime path complete but unused in production: no
engine was on the new contract.

## Decision

1. **`SingleChoiceEngine`, key `mcq`** (`engines_core/lib/src/single_choice/`).
   It is the brief's "single choice"; the key doesn't change (D1), so
   every existing exercise, attempt and mastery row stays attached. The
   content contract is exactly the backend's `mcq.content.schema.json`,
   so no content changes. It is a pure reducer:
   - the order is seeded and fixed per question, so a resume shows the
     same order;
   - selecting emits `option_selected` with ids only;
   - a meaningless action is a no-op;
   - snapshot and restore are supported, and a snapshot naming options
     this content lacks is refused.

   Deliberate changes from the legacy engine:
   - **Select, then VALIDER** (D3). An accidental tap is no longer a wrong
     attempt.
   - **A tried option stays marked amber** with a target icon, and can't
     be picked again, instead of being cleared.
   - **No grading, hint, prompt or audio of its own.** The shell and the
     evaluator own those.

2. **`McqExactEvaluator` (`mcq.exact@1`)** grades. A wrong option carries
   its declared `diagnosis` (`{code, taxonomy_version}`) when the content
   has one, and `unclassified` otherwise. An answer naming no option
   throws, and the runtime records that as ungraded, never wrong. The
   engine parses an optional `diagnosis` now, but the backend schema
   doesn't allow one yet (LE-B1), so today every wrong answer is
   `unclassified`.

3. **`AnswerTile`** (`engines_core/lib/src/widgets/`) is the first shared
   presentation component (Phase 4 starts here). It is the design's
   `.cloze-option-row`:
   - states idle, picked (blue), retry (amber plus a target icon) and
     correct (green plus a check), never red;
   - each state is also given in semantics;
   - at least 52 px tall, and focusable with Enter/Space.

4. **Registered in the app** (`learningEngineRegistryProvider`,
   `evaluatorRegistryProvider`). Every exercise whose questions are all
   `mcq` now plays on the new runtime: resumable, with VALIDER, the shell's
   hint and the director. `speed_tap`, `pair_match` and `compose_build`
   stay on the legacy path. The legacy `McqEngine` stays registered as a
   fallback until nothing could need it.

5. **The question is read only when the child taps the speaker, and the
   speaker sits to the left of the question.** This is Hafid's correction,
   made during this phase. It replaces ADR 0013's auto-play and Phase 2's
   auto-read default.
   - `SpeechPolicy`'s default for the prompt is now `on_request`. Content
     may still ask for `"prompt": "auto"` explicitly.
   - The legacy `ExerciseRunner` still resolves the audio up front, so the
     button is ready at once, but it no longer plays it.
   - On both paths the button comes before the text.

6. **Shell fixes found by playing it for real:**
   - **The character is no longer a row of its own.** The design floats
     the mascot (`.mascot-hint`), and the 72 px row starved a fixed-height
     legacy engine (`compose_build` overflowed by 6 px on a 600 px
     window). It now sits beside the prompt, or small in the top bar for
     legacy engines, which draw their own prompt.
   - **VALIDER is back on the right.** The Phase 2 narrow-screen fix had
     centred it. INDICE stays on the left, and a lone VALIDER stays right.
   - **Finishing the last question leaves at once.** The view waited for
     a post-frame callback that nothing scheduled, so the child saw an
     empty shell until the next repaint, about a second, or until the
     mouse moved. It now uses a microtask.
   - **The "+N XP" snackbar shows after the screen pops**, over the page
     the child returns to.
   - The prompt, VALIDER and banner titles use the design's display face
     (Baloo 2, now bundled).

## Verification

- **Tests:**
  - engines_core 45 → 66: 18 for the engine and evaluator, including
    keyboard-only play through the real controller and shell, plus
    layout and timing tests for the shell;
  - engine_sdk 124, still passing, with the speech defaults and the
    runner's left-hand speaker asserted;
  - app 367, including a real-`mcq` `PlayScreen` test with no engine
    overrides: speaker left of the text, nothing played until tapped,
    wrong → Presque → retry → right → Bravo → back, and the exact v1
    event sequence;
  - analyze is clean.
- **Live, on web against the dev-stack, with the paired test kid:**
  - The real published exercise "3 + 5 donne le même résultat que :"
    played on the new runtime: fox beside the question, speaker on the
    left, VALIDER greyed until a choice. "5 − 3" gave "Presque !" in
    amber and stayed marked; "5 + 3" gave "Bravo !", a green tile and the
    fox celebrating; CONTINUER returned to Carte.
  - The runtime's events uploaded: `accepted: 3, rejected: 0`, with
    uuid5 event ids.
  - After the flusher fix (ADR 0020), the header shows XP 15 and a
    1-day streak computed by the real backend, and the daily quests show
    progress.
  - A second run confirmed VALIDER on the right and an immediate return.

## Not done / observed

- **v1 telemetry can't tell the two paths apart by engine.** New-runtime
  attempts carry `answer_payload` `{"kind": "single_choice", "selected": …}`
  where legacy ones carried `{"selected": …}`, so the payloads and their
  hashes differ. Within one run that changes nothing
  (`repeated_wrong_rate` compares hashes inside a run). Across both
  paths, `engine_version` is still 1, so the path is visible only through
  `app_version` until telemetry v2 (LE-T1) carries the evaluator id.
- **Some clicks in the browser pane didn't register on the first try.**
  Two `speed_tap` answers and one CONTINUER needed a second click. The
  same interactions pass in widget tests, including a new `speed_tap`
  inside `LegacyEngineHost`. Not reproduced and not explained; it may be
  the automation's click timing. Worth watching on a real device.
- Interaction events (`option_selected`, audio requests) are still
  published but not stored, pending LE-T1.
