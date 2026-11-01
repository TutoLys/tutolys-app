# ADR 0108: A voiced hint, narrowing after three misses, a clock that pauses

Date: 2026-10-31 · Status: accepted
Source: UX review `Platforms/ux-review/games.md` (G8, G17, N12, N19, N18).
Hafid's go on 2026-10-31: "Game and app calls from the UX reviews: YES apply".

## Context
- **G8:** the hint was text only, so a non-reader couldn't use it. After
  three misses nothing changed: the child saw the same problem again.
- **G17:** a speed_tap countdown kept running while the question was read
  aloud, and while the hint was open. Listening cost time.
- **N12:** Ma galerie opened as a task (« Choisis… et dis pourquoi »), so a
  child who wanted to *see* their work had to do an exercise.
- **N19:** a picture-only answer sat at 34 px in a wide tile.
- **N18:** ESL/FLS word cards can't be heard.

## Decisions
1. **`ActivityAssist`**, an inherited widget the activity view puts over the
   engine, says two things:
   - `paused`: the hint is open, or the host reports the question is being
     read (`LearningActivityView.narrating`, a `ValueListenable<bool>`);
   - `narrow`: this question has had three misses.

   Engines read it from their own `buildView` context. The view now builds
   the engine inside a `Builder` under the scope, since the context it used
   to pass was above it.
2. **The hint's voice is an asset, not a schema field.** The shell looks for
   an asset named `hint` (one question) or `q<i>_hint` (a série), the same
   convention as the prompt's `audio` / `q<i>_audio`. With one, the hint
   panel draws a 48 px speaker left of the text, read on tap only. No engine
   schema changes, so older installs are unaffected. Generating the clips is
   Backend's: `Platforms/BACKEND_WORKORDER_ENGINE_AUDIO.md`.
3. **Narrowing never answers for the child.**
   - Choices (mcq, speed_tap, data_graph, passage_reader `choose`,
     balance_scale, measure_tool, fraction_slice, experiment_lab): one wrong,
     untried answer is set aside: faded to 35 %, not tappable, named
     « écartée » for a screen reader. Never the right one, and never when
     fewer than three answers are left, so a choice stays a choice.
   - Boards (pair_match, compose_build): both tiles of one right pair not yet
     made, or the right tile for the first wrong slot, get a gold edge and a
     sparkle (« essaie celle-ci »). The child still makes the move. Placing
     it for them would record a move they didn't make in the attempt
     telemetry. A creation (compose_build with a `frame`) has no single right
     tile and isn't narrowed.
4. **The countdown pauses** while `ActivityAssist.paused` is true and
   resumes where it stopped. **Open:** the host must pass `narrating`.
   `lib/features/play/play_screen.dart` is the app session's code, so the
   read-aloud half works only once it wires that from its audio
   coordinator's playback status. The hint half works now.
5. **A chosen answer** shows a filled dot ◉ and a 3 px edge (AM32, ADR 0105).
   It's a dot, not ✓, because ✓ means « right ».
6. **N19:** a picture-only answer is 56 px and centred in an answer list, and
   40 px elsewhere, where slots are narrower.
7. **N12:** Ma galerie opens on a wall of creations, 160 px tiles; tapping
   one shows it big. « Accrocher mes préférées » is an optional button that
   leads to the existing hang-and-say-why step. A snapshot with something
   already hung reopens in that step.
8. **N18 needs no app change:** a tile already draws a speaker when its
   option has an `audio_ref`. What's missing is the clips (work order).

## Consequences
- Tests: `test/assist_test.dart` (7): the hint speaker, read on tap only and
  absent with no clip; `answerToDim`; mcq dims after three misses and the
  dimmed answer can't be picked; pair_match points at one right pair; the
  clock pauses for narration and for the hint. Gallery tests walk the wall
  first. Both goldens were refreshed for the 56 px pictures.
- Still open in games.md and not mine: G12 (celebration « Suivant »), N6,
  N7 and N14 (Flutter app).

## Follow-up (2026-11-01): the discussion's friends have a voice
Backend's audio pass is done: 519 hint clips (EA1), 111 ESL/FLS word cards
(EA2) and 5 clues (EA3). A pre-reader still couldn't read Léa's or Omar's
line, so a take may carry an optional `audio_ref` (backend `89d4654`,
schema only, and optional, so every existing lesson still validates).
`CharacterSays.onSpeak` draws a 48 px speaker beside the bubble, read on tap
only. Backend fills the field from `takes[].text` (refs `take_<id>` /
`q<i>_take_<id>`). Tests: a take with a clip gets a speaker that plays on
tap and never by itself; with no clip, none is drawn.
