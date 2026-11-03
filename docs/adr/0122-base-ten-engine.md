# ADR 0122: base_ten, Le tableau de numération (instead of a counters_board mode)

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` step 3, "column_calc +
counters_board place_value". The backend side is backend ADR 0214.

## Context
The plan proposed `place_value` as a new mode of counters_board. Building
it showed three conflicts with that board:
- **Caps.** counters_board allows 40 counters and 20 per plate. An exchange
  multiplies counters: one hundred becomes ten tens.
- **Grading.** Its targets count counters (`total`, `per_plate`). Place
  value grades what the board is *worth*.
- **Risk.** That board carries 116 authored near-miss uses. Its parse,
  reducer, metrics and 400-line view would all branch on a mode none of
  them share.

## Decision
A small engine of its own, `base_ten`. A new engine key reaches older
installs the same way a new mode would: through the capability handshake
and « mise à jour ». The plan's reason to widen rather than add (never
break an older install) holds either way.
- **The board:** 2–4 consecutive places, highest first (um, c, d, u, di,
  ci), with base-ten blocks drawn per place. A column holds 19, so 13 tens
  can sit there before the child groups them.
- **Moves:**
  - add or take blocks, unless `supply: false`, where only exchanges change
    the board;
  - **break** one block into ten of the next place down;
  - **group** ten into one of the next place up.

  An exchange emits `reveal` (`exchange`).
- **Grading:** `target.value` is the worth, in any arrangement.
  `target.exact` adds one item per column. Right value in the wrong
  arrangement is named `math.place_value.not_exchanged`, which must be
  registered, like column_calc's codes.
- **Its partner:** it's column_calc's concrete twin. The groupement and
  échange leaves get their second engine, and column_calc gets the picture
  behind its carries.

## Tests
`test/base_ten_engine_test.dart` (12):
- 5 refusals;
- decimals counted in hundredths;
- any arrangement of the value is right;
- an exchange keeps the value and reveals;
- caps and edges;
- the named slip, with no supply;
- snapshot round trip;
- 234 built through the shell to « Bravo ! » at 900 px and at 360 px.
