# ADR 0044 — `passage_reader`: read a short text, then answer about it

Date: 2026-10-25
Status: accepted

## Context

Hafid sent a catalogue of ~44 candidate engines and asked for them to be
ranked and the best fit built. The ranking is in
`Platforms/ENGINE_CATALOGUE_2026-10-25.md`. Of the 526 grade-1-marked PFEQ
leaves, 322 (61 %) are français or English **reading, listening and
response** skills: "extraire des informations explicites", "identifier ce
dont on parle", "anticiper la suite", "Response Process". Every engine we
had asks one isolated question; none shows a text and asks about it. That
is the biggest gap in the product, ahead of any game on the list. It is
also our thinnest subject: français had 12 lessons, against 69 for math.

This engine merges four catalogue entries: highlight_text (sentence level),
evidence_highlighter (B24), audio_listen (A9) and story_branch's linear
form. The content contract is backend ADR 0052.

## Decision

`PassageReaderEngine` + `PassageReaderEvaluator`
(`packages/engines_core/lib/src/passage_reader/`), key `passage_reader`,
explicit submit (VALIDER).

- **The passage is the stimulus and stays on screen**, 2–10 sentences in
  reading order, never shuffled, on its own white card with an optional
  title. The question is the prompt, read by the shell's speaker as
  always.
- **Two tasks, one engine**, because both draw the same passage:
  - **`find`** (default): tap the sentence that proves the answer. With
    several right sentences it becomes "trouve toutes les phrases…": a
    count is shown, and grading gives partial credit exactly like
    `find_it` (right picks over right sentences plus wrong picks, so
    tapping everything never wins). Right sentences lock green; wrong ones
    turn amber and can't be picked again.
  - **`choose`**: 2–4 options below the passage, shuffled per seed. The
    passage is only read here; tapping it picks nothing.
- **One answer type for both**: `MultiSelectAnswer`. `choose` is a
  one-element set, which kept one state machine, one snapshot and one
  evaluator instead of a router like `timeline_calendar`'s.
- **A speaker per sentence**, on its left (Hafid's rule for the prompt
  speaker, applied to every speaker). This is what makes the engine work
  for a grade-1 child who can't read the passage yet: they tap each
  sentence to hear it, which also serves the "Communiquer oralement"
  listening skills. Rules:
  - Nothing is read aloud unless tapped. That's the existing default for
    answers, and a passage is long.
  - Tapping a speaker never picks the sentence and records no attempt.
  - **The engine never touches audio.** A new `ContentSpeaker` interface
    and `ContentSpeakerScope` in `engine_sdk` (`content_speaker.dart`) let
    the host offer "play this `audio_ref`"; the engine only says which one
    was tapped, with the sentence id as `partId`.
  - With no scope above it, or no `audio_ref` on a sentence, no speaker is
    drawn, rather than one that does nothing. So the engine ships and plays
    today for readers, and the speakers appear once both halves below land.
- **A série asks several questions about the same passage** by repeating
  it in each question's config. A question must stand alone (resume,
  per-question engine keys), and audio is content-addressed (backend ADR
  0041), so the repeat costs nothing on the device.
- **Accessibility:** each sentence is announced "phrase N : …" with its
  state ("choisi", "trouvé", "déjà essayé"). Every state reads without
  colour (border weight, check icon, amber target icon). Keyboard alone
  can pick a sentence. Sentence rows are at least 48 px tall, and a
  ten-sentence passage fits a 375 px phone.

## Not done here (hand-offs)

- **App wiring (app session, `lib/`):** `play_screen.dart` should wrap the
  activity in a `ContentSpeakerScope` whose `speak` plays
  `PrerecordedAudio(exerciseId, audioRef)` on the narration channel, does
  nothing when read-aloud is off, and records the request
  (`recordAudioRequest`, with the sentence id). This is about 10 lines
  beside the existing `speakPrompt`. **Done (2026-10-25):** the request is
  logged as `SpeechPart.prompt` with the sentence id as `part_id`, since
  the passage belongs to the prompt and `SpeechPart` has no part of its
  own for it. With read-aloud off, no scope is provided, so no speakers
  are drawn (`play_screen_test`).
- **Backend audio (backend session):** `fill_missing_audio` voices prompts
  only. It needs to voice each `passage_reader` sentence too. This is item
  LE-B6 in `Platforms/BACKEND_WORKORDER_LEARNING_ENGINE.md`.
- **A picture per passage** uses the existing `prompt.image_ref`, which
  the shell already draws. Nothing is needed in the engine.
- **Branching stories** (story_branch's real form) are content work on
  top of this engine, later.

## Consequences

- Grade-1 français and English get an engine for most of their skills.
  The Questions Maker can write passage lessons now, with no art needed.
- A host-supplied speaker is now a general mechanism. `label_image` (#3)
  or `fill_blank` (#2) can use it for their own parts later.
- Tests: `test/passage_reader_engine_test.dart` covers parse, reduce,
  evaluator, snapshot, and in-shell behaviour (find, choose, the multi
  count, the speaker present and absent, the screen-reader name, keyboard,
  and a phone width). That's 20 tests; engines_core is now 196.
