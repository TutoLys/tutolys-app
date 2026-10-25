# ADR 0047 — `fill_blank`: complete the sentence or the equation

Date: 2026-10-25
Status: accepted

## Context

This is catalogue #2 (`Platforms/ENGINE_CATALOGUE_2026-10-25.md`), built
after `balance_scale` and `label_image`: both had lessons or art waiting,
and most of this engine's français targets are in strands Hafid is
holding. It covers about 35 grade-1 leaves:
- FR accords (un/une, singulier/pluriel), syntax and punctuation;
- EN conventions;
- math missing term and number facts.

It merges catalogue A3 (fill_blank) and part of A8 (sentence_builder). The
content contract is backend ADR 0055.

## Decision

`FillBlankEngine` + `FillBlankEvaluator`
(`packages/engines_core/lib/src/fill_blank/`), key `fill_blank`, explicit
submit, `BlanksAnswer` (blank id → tile id).

- **The text carries `{id}` markers**, 1–4 per sentence, e.g. `"{b1} chat
  dort sur {b2} lit."` or `"4 + {b1} = 7"`. It's drawn word by word in a
  wrap, so a line breaks like text around the blanks.
- **Blanks are filled from tiles, never typed.** A grade-1 child and a
  keyboard don't mix, and an authored tile is what makes a wrong answer
  diagnostic. That's the same reasoning the Questions Maker gave for
  `balance_scale`'s options.
- **Interaction:**
  - A tile goes into the highlighted blank: the first empty one, unless the
    child tapped another.
  - Tapping a filled blank empties it and makes it the target.
  - Without `reuse`, a tile sits in one blank at a time, and taking it again
    moves it. With `reuse: true` (the same article twice) the bank keeps
    every tile.
- **A blank may accept several tiles** (`answer` as a list), for
  `{a} + {b} = 7` with 3 and 4 in either order. Parse checks the blanks can
  be solved with distinct tiles when `reuse` is off, and that there are
  more tiles than blanks.
- **VALIDER waits for every blank.** Grading is partial credit, scored as
  right blanks over blanks. Right blanks lock green; wrong ones empty, and
  that tile can't go back into that blank (it shows amber and is
  inactive while that blank is the target).
- **Layout:** every blank and every tile is as wide as the longest tile
  label, so filling a blank never reflows the sentence under the child's
  finger.
- **Screen reader:** blanks read "trou 2, vide, à remplir"; a filled one
  reads its word plus "touche pour vider".

## Consequences

- Tests: 11 in `test/fill_blank_engine_test.dart`, covering parse (markers,
  answers, reuse, a real choice), reduce (first-open order, retarget, empty,
  move), the evaluator and feedback (partial, lock, no repeat, accepted
  alternatives), snapshot, and in the shell (a missing term wrong then
  right, a placed tile leaving the bank, a long sentence on a phone).
  engines_core is now 231.
