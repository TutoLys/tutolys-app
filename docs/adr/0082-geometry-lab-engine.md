# ADR 0082 — `geometry_lab`: a geoboard to build and copy figures

Date: 2026-10-26
Status: accepted

## Context

This is catalogue #9, "Atelier des formes" (B9), the geoboard half of
"geometry_lab, then shape_puzzle". It covers grade-1 math: constructing
plane figures and figures that are the same shape. The **tangram
(shape_puzzle, B12) is not built**: it needs rotate, flip and snap, plus
silhouettes, and the catalogue marks it high-cost. The content contract
is backend ADR 0080.

## Decision

`GeometryLabEngine` + `GeometryLabEvaluator`
(`packages/engines_core/lib/src/geometry_lab/`), key `geometry_lab`,
explicit submit, `OrderingAnswer` (peg ids `row,col`, in band order).

- **The band:** a board of 3×3 to 7×7 pegs. Tapping pegs stretches an
  elastic band from peg to peg:
  - tapping the last peg takes it back;
  - tapping the first peg closes the band (with 3 or more pegs);
  - tapping the last peg of a closed band opens it again;
  - "Recommencer" clears it.

  VALIDER waits for a closed band.
- **`build`:** make a triangle, square, rectangle, rhombus, or a figure
  with N sides (`target: polygon`).
  - Grading uses exact geometry on integer pegs, never a stored answer.
  - Any correct figure anywhere is right, a tilted square included.
  - A square is also a rectangle and a rhombus, as in mathematics. So a
    lesson must not ask for "a rectangle that is not a square".
- **`copy`:** reproduce a model figure, shown on its own board, anywhere
  on the child's board. It may be moved, but not turned or mirrored.
- **What counts as a figure:**
  - A band that crosses itself is never a figure (item `simple`).
  - A peg the band runs straight through is not a corner.
  - Item `shape` says whether it's the asked-for figure.
- **Colours:** the model is drawn in purple, because gold disappears on
  the wood. The two boards are captioned "Modèle" and "Ta planche".
- **Accessibility:** every peg is a focusable, spoken button ("clou ligne
  2, colonne 3"). The board says how many pegs the band goes round and
  whether it's closed.

## Consequences

- Tests: 10 in `test/geometry_lab_engine_test.dart`:
  - the geometry (corners, crossing, naming, moved copies);
  - parse;
  - the band's reducer;
  - grading;
  - snapshot;
  - in the shell, and the copy layout on a phone.
