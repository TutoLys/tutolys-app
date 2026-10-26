# ADR 0048 — `pattern_machine`: what comes next, what's missing

Date: 2026-10-26
Status: accepted

## Context

Catalogue #5 (`Platforms/ENGINE_CATALOGUE_2026-10-25.md`), Hafid's
"La machine à motifs" (B26) merged with the pattern form of missing_piece
and the frises. It covers about 7 grade-1 math leaves: non-numeric and
numeric regularities, adding terms to a sequence, frises. It needs no art.
The content contract is backend ADR 0056.

## Decision

`PatternMachineEngine` + `PatternMachineEvaluator`
(`packages/engines_core/lib/src/pattern_machine/`), key `pattern_machine`,
explicit submit, `BlanksAnswer` (gap id `g<index>` → choice id).

- **A term is a shape drawn in code, or a short text.** Eight shapes
  (circle, square, triangle, diamond, hexagon, star, heart, arrow), seven
  colours, three sizes, quarter turns. A turning arrow makes a frise; a
  text of up to 4 characters makes a numeric regularity. Every piece has a
  dark edge, so yellow and pink still read on a white card.
- **The content authors the whole sequence and lists the hidden indexes.**
  The right answer for a gap is the choice that is the same piece. There
  is no separate answer key, so a lesson can't name the wrong one.
- **1 to 3 gaps, anywhere.** At least 3 terms stay visible. A "…" follows
  the row unless `continues: false`.
- **A choice is a stamp, not a tile.** It stays in the bank, because a
  pattern repeats (A A B A A _ _ wants A twice).
- **Interaction and grading match `fill_blank`.** A choice goes into the
  highlighted gap (the first empty one unless the child tapped another);
  tapping a filled gap empties it. VALIDER waits for every gap. Partial
  credit: right gaps lock green, wrong ones empty, and that choice goes
  amber and inactive for that gap.
- **Screen reader:** every piece describes itself, with French agreement
  ("grande étoile verte", "flèche violette vers la droite") and in English
  ("blue arrow pointing down"). An empty gap reads "case 2, vide, à
  remplir".

Not built: the catalogue's "predict stage 10" for growing patterns (a
grade-2+ idea), object sprites (optional art, never sent), the placement
"pop" sound.

## Consequences

- Tests: 11 in `test/pattern_machine_engine_test.dart`, covering pieces
  (defaults, rejects, descriptions), parse, a stamp filling two gaps,
  partial credit with lock and no repeat, retarget and empty, snapshot, and
  in the shell (wrong then right; twelve turning arrows on a phone).
  engines_core is now 243.
- Registered in `learning_platform_providers.dart` (two lines).
