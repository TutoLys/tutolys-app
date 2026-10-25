# ADR 0025 — `sort_buckets`, the fifth engine

Date: 2026-10-25
Status: accepted

## Context

Hafid needs at least five engines before the whole-app end-to-end test.
Sorting into categories is the mechanic most subjects can use (odd/even,
living/non-living, then/now, word classes), and the old product had it
(`sort_classify`, interaction id `sort_buckets`). The content contract is
backend ADR 0031.

## Decision

`SortBucketsEngine` + `SortBucketsEvaluator` in
`packages/engines_core/lib/src/sort_buckets/`, on the `LearningEngine`
contract, built the way `pair_match` was in ADR 0022.

- **Tap, then tap.** Tap an item in the tray to hold it, then tap a bucket
  to drop it there. Tap the held item again to put it down. Tap an item
  already in a bucket to take it back out (it is then held). No dragging,
  like every other engine.
- **While an item is held, a tap anywhere in a bucket means "here"**, even
  when it lands on an item already sorted into it. Found by the widget
  test: the first version pulled the sorted item out instead, which is what
  a child tapping the middle of a bucket would hit too.
- **VALIDER checks the whole board, with partial credit.** Items sorted
  right lock in their bucket (green, with a check); wrong ones go back to
  the tray, not red, for the retry. The shell's banner says "Presque !" in
  amber. One attempt is one checked board, as for `pair_match`.
- **Answer:** the existing `PlacementsAnswer` (item id → bucket id). No
  engine_sdk change.
- **Evaluator:** `sort_buckets.exact@1`. `itemResults` is keyed by item id.
  A wrong board carries `ErrorClassification.unclassified()`, because the
  item's diagnostic meaning lives in reviewer-only `authoring_meta` and never
  reaches the device.
- **Layout:** the tray is a `Wrap` of `AnswerTile`s, and a sorted item
  leaves a gap so the tray never reflows under a finger. Buckets sit side
  by side when each still fits a 140px tile; otherwise two to a row (four
  buckets on a phone). While an item is held, every bucket turns blue, so
  the child sees where things can go. No colour gives the answer away.
- **Design system:** colours come from `VillagePalette.of(context)` and
  tiles from the shared `AnswerTile`. There is no animation, so reduced
  motion has nothing to turn off. Nothing is read aloud: the shell owns
  speech, and answer choices aren't read by default.
- **Strings:** the engine's semantics labels ("choisi, choisis son groupe",
  "touche pour déposer ici", "bien classé") follow the view's locale inline,
  the same as the other four engines. `Strings` lives in the app's `lib/`,
  which engines_core can't import.
- **Registration:** two lines in `lib/features/play/learning_platform_providers.dart`
  (the engine and the evaluator). There is no legacy `TutolysEngine`
  version, so `engineRegistryProvider` is unchanged.

## Verification

- engines_core: 90 → 105 tests (`test/sort_buckets_engine_test.dart`).
  Covers parse and refusals, the reducer including the held-item drop,
  partial credit, locking, snapshot round-trip and refusal, and, through
  the real controller and shell: a partial board → "Presque !" → fix →
  "Bravo !" with two attempts logged; keyboard-only sorting; a two-question
  série; and four buckets at 375px wrapping with no overflow.
  `flutter analyze` is clean.
- App: analyze clean, 455 tests pass with the engine registered.
- **Not done:** live play on web against the dev-stack. Docker wasn't
  usable from this session, so the engine isn't activated there and no
  `sort_buckets` exercise is published yet.
