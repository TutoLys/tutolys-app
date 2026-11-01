# ADR 0113: « Suivant » on the celebration, an exported stop sheet, two columns sideways

Date: 2026-11-01 · Status: accepted
Asked by the app session (ADR 0107, ADR 0112) through the Manager. These
are UX items already decided: G12, AM20 and AM21.

## Decisions
1. **G12: `ActivityCompleteView.onNext`.** When the host passes it, the
   gold primary button reads « SUIVANT », Enter triggers it, and a
   secondary « Retour à la carte » (with a map icon) runs `onContinue`.
   Without it, nothing changes: one « CONTINUER ». The view doesn't know
   what the next lesson is; the host does, so it decides whether to offer
   one.
2. **The stop sheet is public:**
   `showActivityStopSheet(BuildContext, ShellStrings)` in
   `src/shell/stop_sheet.dart`, exported from `engines_core.dart`. It is the
   same sheet the ✕ opens (Continuer false, Arrêter true, dismissed null).
   It's named apart from the app's copy (`showStopSheet`) so the two don't
   clash on import; the app deletes its copy when it switches.
3. **AM21: two columns on a phone held sideways.** When the screen is
   under 500 px tall (`landscapeMaxHeight`) and wider than tall, the
   activity shell puts the question (picture, prompt row, instruction) in a
   left column (flex 2) and the board in a right one (flex 3). Each column
   scrolls on its own, and the right one keeps the ↓ cue and the
   per-question scroll reset. Insets drop to 16 px. Phones are otherwise
   locked to portrait (ADR 0107); this covers a browser tab, which can't be
   locked.

## Tests
`test/celebration_stop_landscape_test.dart` (6):
- Continuer alone without `onNext`.
- With `onNext`: Suivant is primary and Enter's action, and Retour goes
  back.
- The exported sheet's two answers.
- At 812 × 375 the question sits left of the answers, with no overflow,
  and the question is still answerable through to « Bravo ! ».
- 375 × 812 and 1280 × 800 keep one column.
