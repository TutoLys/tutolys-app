# ADR 0091 — `stage_presenter`: planning a talk for a room

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's ELA request 4, "Le théâtre du village", for the
leaf "Presents to an audience". A real presentation needs a voice and a
room. D8 rules out the microphone before counsel, and nothing here
records anything. So the engine grades the *plan*, and says so: **proxy
evidence**. The content contract is backend ADR 0087.

## Decision

`StagePresenterEngine` + `StagePresenterEvaluator`
(`packages/engines_core/lib/src/stage_presenter/`), key
`stage_presenter`, explicit submit, `BlanksAnswer`.
`EvaluationResult.evidence` is `proxy` (ADR 0088).

- **The scenario** sets the room (carpet, classroom, gym) and who's
  watching (friends, classmates, school, younger). Drawn in code: a stage
  with the presenter holding a picture, and rows of faces. Three friends
  get one row; the whole school four rows of small heads.
- **Up to 6 controls**, each graded as its own item:
  - `order`: the parts of the talk, moved with ↑ and ↓ buttons. Shuffled
    at the start, never already right.
  - `slider`: 3–5 stops with pictures, for voice volume or pace. Right
    inside the scenario's `target` range, so a whisper isn't wrong, only
    wrong for the gym. Never recorded.
  - `choice`: tiles for facing the audience, the text version, or how to
    hold the picture.
- **The audience shows the result.** Each wrong control has a reaction:
  - `cant_hear`: the back row cups its ears;
  - `too_much`: hands over ears;
  - `puzzled`: puzzled faces;
  - `bored`: a yawn.

  Everyone smiles when it's right. The room always says it in words too,
  from the lesson's `reactions` (control id → words, `ok` for the
  applause) or a generic line.
- **Partial credit:** right controls lock; a wrong choice goes amber; a
  slider can simply be moved again.

## Consequences

- Tests: 6 in `test/stage_presenter_engine_test.dart`, covering:
  - parse;
  - each control as an item;
  - the reactions, too quiet and too loud;
  - proxy evidence;
  - snapshot;
  - in the shell: the back row can't hear, then applause;
  - layout on a phone.
- Village art could replace the drawn room. It's optional, and on the
  asset list.
