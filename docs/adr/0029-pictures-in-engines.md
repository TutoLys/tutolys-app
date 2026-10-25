# ADR 0029 — Pictures in the engines

Date: 2026-10-25
Status: accepted
Builds on ADR 0027 (the app's picture asset cache and `ContentImage`).

## Context

ADR 0027 added the picture pipeline: content-addressed `asset_cache`,
`ImageResolverScope` around every activity, and `ContentImage`. Engines
had parsed `image_ref` since the content schemas allowed it, but drew
nothing (ADRs 0025, 0026, 0028 all said "accepted, not drawn yet").

## Decision

Drawn wherever the content schemas already allow `image_ref`:

| where | how |
|---|---|
| `prompt.image_ref` (shell, every engine) | above the question, at most 360×180 |
| `AnswerTile` (mcq, speed_tap, pair_match, sort items, timeline items, find_it `items`) | a 56px box before the label |
| `AnswerSlot` (timeline positions) | carries the placed item's picture |
| sort_buckets bucket | 72px, above the bucket's label |
| find_it `grid` square | fills the square (10% inset) |

- **The label always stays.** It's the screen-reader name, and it's the
  visible text until the picture has synced. In a grid square the label is
  the fallback, so an unsynced plan still shows its emoji.
- **Nothing is drawn in place of a missing picture.** The fallback in a
  tile is an empty box, so an unsynced tile is just its label, never an
  empty frame. `ContentImage` shows that fallback with no scope (widget
  tests), when nothing is synced, and when bytes don't decode.
- **Not drawn:** `words` and `letters` cells in find_it, because a sentence
  is text by nature; and compose_build tiles, whose schema has no
  `image_ref`.
- **Not done:**
  - a way to hide the label when a picture is shown ("find the picture of
    the cat" when the label says "chat"). If content needs that, it's an
    additive per-item flag.
  - find_it's picture background with tappable regions, still the later
    mode ADR 0028 names.

## Verification

- engines_core 141 → 147 (`test/content_images_test.dart`), with a real 1×1
  PNG through a real `ImageResolverScope`:
  - an option picture shows once synced, and the tile is its label when
    not;
  - the prompt picture is drawn above the question;
  - sort item and bucket pictures;
  - a find_it square's picture, with the emoji label as fallback;
  - a timeline item's picture following it into its slot.
- App: analyze clean, 471 tests pass.
- Not live-verified: no lesson carries a real picture asset yet. That
  needs `BACKEND_WORKORDER_IMAGES.md`.
