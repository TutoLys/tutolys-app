# ADR 0121: column_calc, Le calcul en colonnes

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` §2.2 #10. It is step 3 of
§2.3: moved up because one leaf here is most of a year's written math.
Hafid's go on 2026-11-03. The backend side is backend ADR 0213.

## Decisions
1. **The Québec classroom layout:**
   - addition and subtraction, of naturals or of decimals aligned on the
     comma (up to 2 places);
   - multiplication by 1 or 2 digits, one row per digit of the multiplier,
     with the shifted row's 0 written;
   - division with the divisor on the right and the quotient under it.

   Decimal products and quotients (grades 5–6) are a later version.
   `ParseUnsupported` makes an older app show « mise à jour ».
2. **Digits are tapped from a 0–9 keypad, never typed.** They go right to
   left along a row. A cell can be selected, and ⌫ empties it.
3. **No answer key.** The engine computes every expected digit, so a lesson
   can't be wrong about one. Each graded cell is an item, with partial
   credit: right digits lock and wrong ones are cleared.
4. **Scratch boxes** above the columns take carries and borrows. They are
   never graded and survive a retry, because they're the child's working.
5. **The remainder row is as wide as the divisor,** and its leading cells
   may stay empty (they mean 0). Sized to the true remainder, the row would
   give the answer away.
6. **Named slips are computed, not authored:**
   - `math.add.no_regroup`;
   - `math.sub.smaller_from_larger`;
   - `math.mul.partial_not_shifted`;
   - `math.div.remainder_too_big`.

   Each is set as the verdict's `feedbackCode` and as its error code
   (taxonomy v1). The « Presque » banner says a nudge for each, never the
   answer. **The four codes must be registered** in the backend's
   `content/diagnosis_taxonomy.json` (backend ADR 0209). That's Backend's
   file, so it was asked for, not edited.

## Tests
`test/column_calc_engine_test.dart` (19):
- the expected rows for each operation, decimals included;
- 4 refusals, and an unsupported decimal product;
- right-to-left filling;
- ungraded scratch that survives;
- VALIDER waiting, and erase;
- snapshot round trip;
- each named slip;
- the optional leading remainder;
- partial credit;
- a product keyed in through the shell to « Bravo ! ».
