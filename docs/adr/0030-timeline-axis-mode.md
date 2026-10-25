# ADR 0030 — `timeline_calendar` axis mode: items on ticks

Date: 2026-10-25
Status: accepted
Extends ADR 0026.

## Context

The Questions Maker's second-ranked gap is putting items at points on an
axis, not just in order. It covers about 12 grade-1 leaves:

- univers social: "ligne du temps graduée", and the whole "Construire /
  Interpréter une ligne du temps" block;
- math: "Situer des nombres naturels" on a number line.

It asked for this as a mode of `timeline_calendar`, not a new engine, and
said a real calendar grid isn't needed in grade 1. The content contract is
backend ADR 0035.

## Decision

### One key, two engines

`TimelineCalendarEngine` is now what's registered for `timeline_calendar`.
It routes by the content's `mode`:

- `order` (or no mode) goes to the existing `TimelineOrderEngine`,
  unchanged;
- `axis` goes to the new `TimelineAxisEngine`.

Each delegate keeps typed content, state and actions; the router only
switches on the content's type. `TimelineCalendarEvaluator` routes the
same way. Order-mode content, snapshots and attempts are exactly as
before. An axis snapshot carries `mode: axis` and is never restored onto
order content, or the reverse.

One engine rather than two keys, because a série that goes "put these in
order" then "now put them on the line" is one lesson, and LE-B5
(per-question engine keys) doesn't exist yet.

### The axis

- **Ticks** (2–11) are the content's, in order. A label may be empty: a
  0–10 number line labelled only at 0, 5 and 10 still has a tick at 7, and
  counting from a landmark is the skill.
- **Items** (2–8): each has the tick it belongs on, at most one item per
  tick. `given` pre-places one (a life line starting at "Je nais"), fixed
  and not graded, as in order mode.
- **No distractors.** On an axis every tick is a place, so an item that
  belongs nowhere has no "nowhere" to stay in. Parse refuses them.

### Play

- Tap an item, then a tick. Tap a placed item to take it off; it is then
  held.
- Putting an item on a taken tick sends the other one back to the tray.
  While holding an item, a tap on a placed one means "this tick", the same
  rule as `sort_buckets`.
- VALIDER checks each item with partial credit. Right ones lock; wrong
  ones go back to the tray. Answer: `PlacementsAnswer` (item → tick).

### Layout

- **Horizontal** when every tick gets its minimum width: a slot above each
  tick, the line with a mark under each, the label under the mark. The
  minimum is 52px when every item label is ≤ 3 characters (numbers) and
  96px otherwise, so a 0–10 number line stays horizontal on a tablet while
  a life line of phrases turns vertical on a phone.
- **Vertical** otherwise: the label, the line, then the slot, top to
  bottom.
- Narrow slots use a new `AnswerTile.dense`: 6px padding, a 14px state
  icon, the label centred. Every state still reads without colour.
- **A blank tick is named by its distance from the last labelled one**:
  "repère 2 après 5". The first version named it by position ("repère 5"),
  which collided with the tick labelled 5. The widget test caught it.

## Verification

- engines_core 147 → 159 (`test/timeline_axis_engine_test.dart`):
  - mode routing (no mode means order mode; an unknown mode is refused);
  - parse refusals (a shared tick, an unknown tick, distractors, one tick);
  - reducer: place, displace, take off, a given tick that can't be taken;
  - partial credit and locking, given items left out;
  - snapshots that never cross modes;
  - in the real shell: a 0–10 line, one off → "Presque !" → fix →
    "Bravo !"; blank-tick semantics names; a life line vertical at 375px
    with no overflow; keyboard-only placing; order-mode content still
    playing through the registered router.
- App: 471 tests pass with the router registered, and analyze is clean.
- All 76 exercises committed in `tutolys-backend/content/` still validate,
  with 0 warnings.
- **Not done:** live web play and dev-stack activation (no Docker here).

## Amendment, same day: numeric ranges and distractors

The Questions Maker's answers came after the first version and changed two
of its calls.

- **A numeric axis is generated, not listed**:
  `range: {min, max, step = 1, label_every = step}`. It makes one tick per
  step, with id `v<value>`, labelled with its value only every
  `label_every`. Items say `at: 7` instead of `tick`.

  The point is the skill itself: placing 7 on a 0–20 line labelled only at
  0, 5, 10, 15, 20 is estimating; labelling every tick turns it into
  reading. Listed `ticks` stay for non-numeric axes (ages, moments).
- **Up to 21 ticks** (was 11), so 0–20 by 1 fits. Later grades' 0–100 by
  10 is 11.
- **Distractors are allowed** (0–3). The earlier "no distractors on an
  axis" was wrong: they don't need a "nowhere" on the line, they stay in
  the tray.
  - VALIDER becomes available once as many items are on the line as there
    are to place. A counter says how many: "Placés : 2 sur 4".
  - A distractor on a tick is wrong. A real item left off the line is
    wrong. Score is right ÷ (items to place + distractors placed).
- **Narrow ticks for numbers.** A tick needs 36px when every label is ≤ 2
  characters, 52 at 3, and 96 otherwise. 21 × 36 fits the 760px activity
  width, so a 0–20 line stays one row on a desktop.
  `AnswerTile.dense` now stacks the state icon under the label instead of
  beside it, so "17" plus its check fits 34px.

Tests: axis 12 → 16, covering:
- the Questions Maker's two cases: "Situer des nombres" (0–20, labels every
  5, place 3/8/12/17) and Léo's life line (ages 0–6, birth given, a
  distractor);
- generated labels, a value off the grid, the 21-tick cap, `label_every`
  not a multiple of step;
- distractor scoring, and an unplaced item counted wrong;
- a 0–20 line staying one row at desktop width, with a placed 17 not
  overflowing.
