# ADR 0026 — `timeline_calendar`, the ordering engine

Date: 2026-10-25
Status: accepted

## Context

Ordering is the next gap after sorting: days of the week, a morning
routine, a life cycle, a story's events, smallest to largest. Univers
social's "localisation dans le temps" strand depends on it entirely.
`compose_build` with `ordered: true` could fake it, but only as a stopgap:
its tiles allow distractors, and it says nothing about what the two ends of
the sequence mean. The content contract is backend ADR 0032.

## Decision

### One engine, the old product's key

`timeline_calendar` (`TimelineOrderEngine` + `TimelineOrderEvaluator`,
`packages/engines_core/lib/src/timeline/`). It is the old product's key
and its item shape (`{id, label, order}`), so its dev packs port as they
are, one round per question.

A dedicated `order_sequence` key was considered. The old engine of this
name *is* plain 1-D ordering, so a second key would mean two names for one
mechanic. Placing events on a real calendar grid or a dated axis is a
different interaction. If the content needs it, it gets its own key then.

### Build the order, then check it once

The old engine revealed one position at a time through a multiple choice:
"what comes next?". This one works like `compose_build`'s slots:

- tap an item to put it in the next empty position;
- tap a placed item to send it back;
- VALIDER checks **position by position, with partial credit**. Right
  positions lock and wrong ones empty for the retry.

It gives the same evidence without making a child commit to step one
before seeing the rest, and it fits the shell's VALIDER contract (D3). One
attempt is one checked order.

### Smaller choices

- **No distractors.** Every item belongs in the sequence, because "which
  comes next?" is the whole question.
- **The tray never starts in the right order.** A seeded shuffle is
  retried until it differs, since a solved tray would let the child just
  copy it. The answer comes from `order`, never from authoring order.
- **`start_label` / `end_label` are optional.** They say what the ends
  mean ("Le matin", "Le plus grand"). They're drawn before the first
  position and after the last.
- **Layout:**
  - one row, left to right, when every position fits 120px (a number line
    or a week reads that way);
  - top to bottom otherwise (8 items on a phone), so "first" is never
    ambiguous across a line break.
- **Answer:** the existing `OrderingAnswer`. `itemResults` is keyed by
  position, as for `compose_build`. A wrong order is
  `ErrorClassification.unclassified()`, because diagnostic notes live in
  the reviewer-only `.authoring.yaml` sidecar.
- **The usual rules:**
  - `VillagePalette` and the shared `AnswerTile` / `AnswerSlot`; nothing
    is ever red;
  - no animation;
  - nothing read aloud by the engine;
  - semantics labels inline in the view's locale, like the other engines;
  - `image_ref` accepted but not drawn until the image pipeline exists
    (ADR 0025).
- **Registration:** two lines in `lib/features/play/learning_platform_providers.dart`.

## Verification

- engines_core: 105 → 117 (`test/timeline_order_engine_test.dart`):
  - parse and its refusals (fewer than 3 items, a shared order, a gap, not
    starting at 0, duplicate ids);
  - the reducer, including that a cleared gap refills first;
  - the tray never starting solved, over 50 seeds;
  - partial credit and locking;
  - snapshot round-trip and refusal;
  - in the real shell: a swapped pair → "Presque !" → fix → "Bravo !";
    keyboard-only placement; one row on a tablet, a column at 375px with no
    overflow.

  Analyze is clean.
- **Not done:** live play on web, and activation on the dev-stack. Docker
  isn't usable from this session.
