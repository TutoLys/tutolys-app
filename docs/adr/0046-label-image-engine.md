# ADR 0046 — `label_image`: put the right name on each part of a picture

Date: 2026-10-25
Status: accepted

## Context

This is catalogue #3 (`Platforms/ENGINE_CATALOGUE_2026-10-25.md`). It merges
drag_drop (A1), label_image (A2), map labels and missing_piece's picture
form. It's the broadest engine on the list: it reaches all six subjects,
about 35 grade-1 leaves. It had to wait for art.

Hafid's first batch arrived on 2026-10-25: L7 classroom, L8 neighbourhood
and L9 fox emotions (backend `content/images/`, commit 85c295f). The Manager
moved this engine ahead of `fill_blank`. The Questions Maker wants it right
away for strand-1 univers social: se repérer sur un plan, points cardinaux,
lieux du quartier. The content contract is backend ADR 0054.

## Decision

`LabelImageEngine` + `LabelImageEvaluator`
(`packages/engines_core/lib/src/label_image/`), key `label_image`, explicit
submit, `PlacementsAnswer` (label id → point id).

- **The picture carries no text.** The app draws numbered points at
  fractional `x, y` positions. A label placed on a point replaces the
  number, as a chip centred on the point and clamped inside the picture.
  One picture therefore serves FR and EN.
- **`aspect_ratio` is in the content** (width over height). The picture,
  and so its points, are laid out before it has synced; an asset entry
  doesn't carry dimensions. Until the picture arrives, the points sit on
  a blank card.
- **Interaction:** the same tap-to-place as `sort_buckets`. Tap a label to
  hold it, then tap a point to drop it. Tapping a placed label takes it
  back into the hand. Dropping onto a filled point sends the old label to
  the tray.
- **VALIDER waits until every point has a label.** Like `sort_buckets`, a
  half-labelled board isn't an answer.
- **Grading:** partial credit, scored as right labels over points. Right
  labels lock green. Wrong ones go back to the tray, and that exact
  label-on-point pair can't be placed again. That's the "a tried answer
  turns amber" rule, without stopping the label going elsewhere.
- **Distractors:** up to 2 labels that belong nowhere. A distractor placed
  anywhere is wrong.
- **Screen reader:** each point reads "repère 3, en haut à droite". Where
  it sits is derived from `x, y`, so the reader can tell points apart
  without being told the answer. Once a label is placed it reads
  "…, en haut à droite : Nord".
- Markers are 40 px circles. Chips are 40 px tall and at most 150 px wide,
  with ellipsis.

## Not done

- **Drag and drop.** Tap-to-place works with a keyboard and switch access;
  drag can be added on the same reducer later.
- **Zoom.** A 12-point plan on a phone is tight, so content_cli warns when
  two points sit closer than 0.06 of the picture.
- **Leader lines** from a point to a label placed off the picture. Labels
  sit on their points for now.

## Consequences

- The L7/L8/L9 lessons can be written today. A sample uses L9 with the
  proposed points, which still await Hafid's confirmation (including
  "the compass's top arm is Nord").
- Tests: 11 in `test/label_image_engine_test.dart`, covering parse, reduce
  (place, take back, swap, wait for a full board), the evaluator and
  feedback (lock, return, no repeat of a known-wrong pair, distractors),
  snapshot, and in the shell (the L9 board with a swap, the point named by
  place, chips inside the picture on a phone). engines_core is now 220.
