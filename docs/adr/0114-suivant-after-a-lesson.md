# ADR 0114: « Suivant » after a lesson plays the Carte's next one (G12)

- Status: accepted
- Date: 2026-11-01
- Source: `Platforms/ux-review/games.md` G12; Hafid's « YES apply »; Engines'
  ADR 0113 (`bf2eafe`), which gave `ActivityCompleteView` an `onNext`

## Decisions

1. **The celebration offers « Suivant »** when the Carte has an open lesson
   in the subject just played (`carteNextProvider`, the same frontier as
   Village's Continuer). « Retour à la carte » stays beside it. Practice
   (the gallery, the QA picker) and a finished subject get the single
   Continuer.
2. **The game doesn't play the next lesson itself.** It pops with
   `PlayExit.next`, and `playNode`, called from a page that stays mounted
   (Carte, Village, Révision), reads the frontier then and plays it. That
   way a lesson outside the offline window still downloads first, and the
   map's state is read after the finished lesson has moved it.
3. **The stop sheet is Engines' now.** Back and ✕ both open engines_core's
   exported `showActivityStopSheet`. The app's copy from ADR 0107
   (`lib/features/play/stop_sheet.dart`) is deleted.

## Consequences

- « Suivant » can go to the same skill when it has lessons left, which is
  the frontier's own rule.
- AM21's landscape layout needed no app change (Engines' `landscape-columns`).
