# ADR 0087 — Answer labels are read on request, never by default

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's request 4. A grade-1 child who can't read yet can't
use a sort or a match whose labels are sentences. The engine schemas
already allow an `audio_ref` on mcq and speed_tap options, sort_buckets
buckets and items, pair_match items, compose_build tiles and timeline
items, but only `passage_reader` sentences and prompts ever played one.
Hafid's standing rule: **answers are never read aloud by default** (app
ADR 0019, recorded again in 0021).

## Decision

- **The tile owns it.** `AnswerTile` takes an optional `audioRef`. When
  the tile has one and the host provides a `ContentSpeakerScope` (the same
  seam `passage_reader` uses, app ADR 0044), the tile shows a small
  speaker before its label:
  - Tapping the speaker plays the clip.
  - A long press anywhere on the tile plays it too.
  - **A plain tap still only chooses**, so play stays silent unless the
    child asks.
  - Without a recording or a host speaker, nothing is drawn. Read-aloud
    turned off in Réglages means no scope, so no speakers.
- **Screen readers** get a long-press action and a custom "Écouter" action
  on the tile.
- **`AnswerSlot`** passes a placed tile's recording through.
  `sort_buckets` draws the same speaker on its bucket cards, which aren't
  AnswerTiles.
- **Engines that now pass labels' `audio_ref` to their tiles:** mcq
  (`SingleChoiceEngine`), speed_tap, sort_buckets (buckets and items),
  pair_match (both sides), compose_build (tray and slots), timeline order
  and axis (items and distractors).
- **Not covered:** engines whose choices are numbers, symbols or
  generated words (balance_scale, measure_tool, fraction_slice, PickOne
  rows). They have no authored label to record. A wrapper that excludes
  semantics around a tile (PickOne) hides the custom action; the visible
  speaker and long press still work.

The clips themselves are made by the backend (Piper, both locales, speech
sanitizer, no emoji read). That's work order **LE-B8** in
`Platforms/BACKEND_WORKORDER_LEARNING_ENGINE.md`. Until it lands, labels
have no `audio_ref` and nothing changes on screen.

## Consequences

- Tests: `test/label_audio_test.dart`:
  - no speaker without a recording or a host;
  - a tap chooses silently, while the speaker and a long press play;
  - the screen-reader action;
  - label models parse `audio_ref`;
  - an mcq under a speaker shows one per option and stays silent when
    chosen.
- This unlocks sentence-length labels in sort_buckets and pair_match, and
  the ELA "listen and sort" lessons, once LE-B8 voices them.
