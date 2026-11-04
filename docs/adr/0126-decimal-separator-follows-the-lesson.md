# ADR 0126 — The decimal separator follows the lesson, not the app

Date: 2026-11-04
Status: accepted

## Context

The Manager's request: 6 English grade-3 math copies (95, 98, 100, 137, 138,
208) wait on decimals. `column_calc` always drew a comma between its columns,
so an English lesson's prompt said 2.4 while its board said 2,4.

`EngineView.locale` is the app's language. That's the wrong input here: an
English app serves the French lesson until an English one exists (ADR 0023),
and that lesson's prompt uses a comma.

## Decision

- `EngineView` gains `contentLocale`, the lesson's language, read from the
  envelope. It defaults to `locale`, so hosts and tests that don't pass it are
  unchanged.
- `column_calc` draws a comma for a French lesson and a point otherwise.
- **Config keeps the comma in every language.** `operands` and `target.value`
  are data, and content_cli and both parsers read one form. An English copy
  writes `"2,4"` in config and `2.4` in its prompt.
- `base_ten` needs no change. It draws block counts and never prints its
  target, so the number a child sees is only in the prompt.
- The board's own words (column names, keypad) still follow `locale`.

## Consequences

- Tests in `column_calc_engine_test.dart` run through the shell: English lesson,
  French lesson in an English app, English lesson in a French app.
- An app older than this draws a comma on an English lesson. That is cosmetic
  and predates launch, so there is no version floor.
