# ADR 0096 — `pattern_machine` invent mode: the child makes the pattern

Date: 2026-10-29
Status: accepted (Hafid: "yes, build the pattern invent mode")

## Context

Leaf 112c8676, « Observer et produire des régularités à l'aide de figures
géométriques », asks the child to *produce* a pattern. Every
pattern_machine item until now hid terms with one right answer each, so
content_cli refuses `creation` on it (backend ADR 0090) and nothing let a
child make a regularity of their own.

## Decision

- **`task: "invent"`, optional, default `continue`.** Invent content is a
  `palette` (2–6 pieces, the stamps), `slots` (a strip of 4–12 cells,
  default 6), an optional exact `core` size, and an optional `vary`
  (`shape`, `color`). `sequence` and `hidden` belong to `continue` only.
- **The same engine, the same taps.** The strip is modelled as a row
  whose every cell is a gap with no expected piece, so the existing gap
  and stamp actions, VALIDER, the idle hand (on the first stamp, G3) and
  the keep button all work unchanged.
- **The evaluator accepts any strip whose smallest core is 2 or more
  pieces and fits at least twice.** It takes the strip's period (the
  smallest p with every cell equal to the cell p before it), so:
  - a core of 1 (AAAAAA) is refused, since there is no pattern to see;
  - a partial last repeat (ABABA, ABCABCA) is accepted, since the pattern
    goes on;
  - too short (ABCAB: the core of 3 fits once and a bit) is refused;
  - rotations all pass (ABCABC, BCABCA, CABCAB), whichever piece the
    core starts on;
  - a core may repeat a piece (AABAAB).
  With `core`, the period must equal it. With `vary`, the core must hold
  two shapes and/or two colours.
- **A miss is amber and keeps the strip.** The result carries a
  `feedbackCode`: `no_repeat` (« Ta suite ne se répète pas encore. »),
  `core_size` or `vary`, which the shell shows instead of the generic
  message (`ShellStrings.missFor`). No cell is locked or marked tried:
  the strip is the child's to change. A pattern locks whole.
- `creation: true` is honest here, and content_cli allows it for invent
  items only.

## Consequences

- The keep button saves the invented strip's pieces, which `creationView`
  already draws.
- An app older than this commit can't parse an invent item and shows it
  as unavailable. No app has shipped.
- Tests: `test/pattern_invent_test.dart` covers parsing, every edge case
  above, and a play in the shell (hand, miss, fix, keep).

## Revision (2026-10-29, UX review N11)

Keeping the strip after a miss left a full strip: a stamp had nowhere to
go, VALIDER failed again, and only tapping a cell emptied it, which
nothing said. A grade-1 child was stuck. Now a miss empties the strip and
shows the refused one in amber until the next tap (as G7/N5 do for the
other boards). Filled cells show a small ✕ with « Touche une case pour
l'enlever. », and a « Recommencer » button empties the strip at any time
(`ClearPatternStrip`).
