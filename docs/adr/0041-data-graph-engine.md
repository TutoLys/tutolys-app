# ADR 0041 — `data_graph`: read a chart, or make one

Date: 2026-10-25
Status: accepted

## Context

Third on the Questions Maker's ranked gap list. It covers math statistique
("représenter / interpréter des données") and probabilité tables, about
3–4 grade-1 leaves. The point it made: reading a chart can be faked with
`mcq` and a picture, but **building** one can't, and building is what this
engine adds. The old product had `data_graph`, read only. The content
contract is backend ADR 0050.

The Questions Maker hasn't answered my four shape questions yet (build vs
read, pictograph key, limits, probabilité tables). This ships the defaults
named below. Anything its answers add is additive.

## Decision

`DataGraphEngine` + `DataGraphEvaluator`
(`packages/engines_core/lib/src/data_graph/`), on the old key.

- **Two modes, one engine.** Both draw the same chart from data, so it's
  one widget:
  - **`read`** (the default, the old engine): the chart is drawn from the
    categories' values, and a 2–4 option multiple choice is asked about
    it. A wrong pick turns amber and can't be picked again, like `mcq`.
  - **`build`**: every bar starts at 0, and the child sets each with −/+.
    VALIDER checks each bar with partial credit. Right bars lock green.
    Wrong ones turn amber and **keep their height**, since a bar that's off
    by one is fixed by one tap, not rebuilt from 0. The amber clears as soon
    as that bar is changed.
- **`chart_type`**: `bar`, or `pictograph`, which stacks the category's
  `symbol` once per unit and labels the column "🍎 pommes". 1 symbol = 1
  unit for now. A key ("🍎 = 2") is the obvious additive extension if
  content needs it.
- **`source`** (build, optional): the things to count, drawn above the
  chart as emoji ("build the graph from the list"). Without it, the prompt
  carries the counts.
- **Limits:** 2–6 categories, values 0–20, `max` 1–20. The default max is
  5, 10 or 20, the first that holds the largest value. The value axis is
  labelled at every step up to 10 and every 2 above.
- **The answer can't be empty**: a target of 0 is legal, so VALIDER waits
  until a bar has moved, rather than accepting an untouched chart as an
  answer.
- **Answers:** read is `SingleChoiceAnswer`; build is `BlanksAnswer`
  (category id → count). `itemResults` is keyed by category. A bar move is
  the v2 `tile_moved` event, `{category_id, count}`.
- **Layout:**
  - steppers sit side by side when a column has 100px, and stack (+ on top,
    as a bar grows up) when six categories share a phone;
  - buttons are 48px;
  - each column's screen-reader name is "chien : 8".
- **The usual rules:** `VillagePalette`, never red, no animation, nothing
  read aloud, everything drawn natively with no picture assets.

## Verification

- engines_core 163 → 174 (`test/data_graph_engine_test.dart`):
  - parse and its refusals (correct naming no option, a value above max, a
    pictograph without symbols, options in build mode, read without
    options);
  - build: starts at 0 with nothing to check until a bar moves, never below
    0, partial credit with lock / amber / keep height, snapshot;
  - read: amber retry, then right;
  - in the real shell:
    - building a pictograph from a list: one bar off → "Presque !" → one
      tap → "Bravo !", with attempts `[false, true]`;
    - a locked bar's buttons disabled;
    - a read bar chart drawn to scale (8 : 3);
    - keyboard-only raising;
    - six categories at 375px with no overflow (the first version
      overflowed by 48px; the steppers now stack).
- The first version computed a read-mode wrong answer's score as 0 ÷ 0.
  `EvaluationResult`'s own range assertion caught it.
- App: 476 tests pass with the engine registered.
- **Not done:** live play, and dev-stack activation (the Backend session
  runs `sync-engines --activate`).
