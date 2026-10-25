# ADR 0028 — `find_it` v1, over text and emoji

Date: 2026-10-25
Status: accepted

## Context

The Questions Maker ranked `find_it` first among the mechanics it can't
write today. It blocks:

- reading a plan or map in univers social (legend, cardinal points,
  landmarks): about 6 leaves;
- géométrie repérage in math (space, plan, axis, first-quadrant grid):
  4 leaves;
- finding a word, letter or mark in a sentence (FR/EN): several leaves.

Its suggestion: don't wait for images. A plan drawn as a grid of emoji
with a legend, a Cartesian grid, and a sentence as tappable words cover
most of it. Images don't render yet (ADR 0025). The content contract is
backend ADR 0033.

## Decision

`FindItEngine` + `FindItEvaluator` (`packages/engines_core/lib/src/find_it/`),
on the old product's key `find_it`, and its field names `scene_items` /
`correct_ids` so its dev packs port.

### Three layouts, one interaction

- **`items`** (the default): separate things in a wrapping row, shuffled
  with a seed. This is the old engine: "Touche tous les nombres pairs".
- **`words`**: a sentence in reading order, words and marks as compact
  chips, never shuffled: "Touche le point".
- **`grid`**: rows × columns, row-major, never shuffled.
  - Optional `row_labels` sit left of each row and `column_labels` under
    the grid, the way a graph's x axis sits.
  - An optional `legend` is drawn below.
  - Only a grid cell may be blank, because an empty square on a plan is
    still a place you can point at.

In every layout you tap to pick and tap again to unpick. With **one** right
answer, a new tap replaces the pick, as when choosing. With **several**,
each tap toggles, and "Trouvés : 1 sur 3" shows above the scene.

### VALIDER, with partial credit

- Right picks lock green with a check. Wrong picks turn amber with the
  target icon and **can't be picked again**. That is the old engine's "a
  wrong guess costs nothing", without letting a child tap every cell to
  win.
- `itemResults` has one entry per pick, true or false. Right cells not yet
  picked aren't listed; they're simply still to find.
- Score is right picks ÷ (right cells + wrong picks), so picking everything
  scores 0.6 on a 3-of-5 board, never 1.
- Outcome is `correct` only when every right cell and no wrong one is
  picked.
- Answer: the existing `MultiSelectAnswer` (found ∪ picked). Events: the
  standard `option_selected` / `option_deselected` vocabulary.

### Accessibility and layout

- A grid cell's screen-reader name is its content plus where it is: "🏫,
  colonne C, rangée 1", or just "colonne B, rangée 1" for a blank square.
  It uses the content's own axis labels when it has them.
- Every state reads without colour: a picked cell has a thicker border and
  is announced as selected; a found one carries a check, a tried one the
  target icon.
- Grid squares are as large as fit, capped at 76px. An 8×8 plan fits a
  375px phone at ~34px squares, below the 48px target. That's why the
  validator warns above 6 columns, and why it's content's call, not the
  engine's.
- The rest is the same as the other engines: `VillagePalette`, never red,
  no animation, nothing read aloud by the engine, and semantics in the
  view's locale.

### Not in v1

- **A picture background with tappable regions** comes once images render.
  It will be an additive mode (a new optional `background` plus region
  shapes), never a change to these three layouts.
- Directional questions ("la case au nord de 🏠") need no engine support:
  the content names the right cell, and the question is the prompt.

## Verification

- engines_core: 123 → 136 (`test/find_it_engine_test.dart`):
  - each layout's parse;
  - plans and sentences never reordering;
  - single-answer replace vs multi-answer toggle;
  - partial credit, locking and amber;
  - the pick-everything score;
  - snapshot round-trip, and refusal of a reordered plan;
  - in the real shell: a wrong square → retry → right → "Bravo !" with
    attempts `[false, true]`; the blank-square semantics name; the
    found-count; keyboard-only picking; an 8×8 grid at 375px with no
    overflow.

  The first version clamped squares to ≥40px and overflowed that phone
  case by 53px. The test caught it.
- App: analyze clean, 464 tests pass with the engine registered.
- **Not done:** live play on web, and dev-stack activation (no Docker
  here).
