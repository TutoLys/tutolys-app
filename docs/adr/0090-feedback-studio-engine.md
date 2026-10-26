# ADR 0090 — `feedback_studio`: giving and asking for feedback

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's ELA request 3, "L'atelier des commentaires", for
the Feedback leaf. The content contract is backend ADR 0086.

## Decision

`FeedbackStudioEngine` + `FeedbackStudioEvaluator`
(`packages/engines_core/lib/src/feedback_studio/`), key
`feedback_studio`, explicit submit, `BlanksAnswer`. Direct evidence in
both modes.

- **The piece** is a story of 2–8 numbered sentences, or a drawing
  (`image_ref`) with 2–8 numbered points. The parts a comment points at
  are highlighted in gold.
- **`give`:** a village character shows their piece. The child fills
  three slots from tiles: a kind opener, a specific praise, and one
  helpful suggestion. Correctness is a property of the tile, not a key:
  - opener: right when `kind`;
  - praise: right when kind and `refers_to` a part that's really there;
  - suggestion: right when kind, `actionable`, and `refers_to` a real
    part.

  So the distractors are structural: harsh (`kind: false`), vague (no
  `refers_to`), invented (`refers_to` something not in the piece),
  "fais mieux" (not actionable), "recommence tout" (actionable but about
  nothing). Partial credit per slot; a wrong tile goes amber. A tile's
  declared `diagnosis` is emitted, as mcq's is. The author reacts in the
  tile's words, or with a generic line for the flaw: hurt by harsh,
  confused by vague.
- **`ask_revise`:** the piece is the child's own story. They pick a
  question to ask:
  - a vague one ("C'est bon ?") only gets `vague_reply` ("C'est beau !"),
    so the child sees why a precise question is better;
  - a specific one gets its `comment` pinned to that sentence, which is
    highlighted.

  The child then rewrites the pinned sentence from options, shown in
  place. Two items:
  - `ask`: the first question asked in the attempt was specific;
  - `revise`: the rewrite resolves the comment.

  After a check, the next attempt grades the question asked by then, so
  a child who first asked a vague question isn't stuck forever. The
  first attempt's record keeps the evidence.
- **The config key is `asks`, not `questions`.** `config.questions` is
  how an envelope declares a série, and a lesson using it here was read as
  an incomplete série. That was caught by the shell test.

## Consequences

- Tests: 8 in `test/feedback_studio_engine_test.dart`.
- A drawing piece needs an image. Until art exists it falls back to a
  pale card with the numbered points. The asset list is in the shared
  notes.
