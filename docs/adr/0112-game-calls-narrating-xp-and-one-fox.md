# ADR 0112: Game calls on the app side: narrating, header XP, practice XP, one fox

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/ux-review/games.md` G12, G17, N6, N7, N14; Hafid's
  « YES apply », relayed by the Manager; Engines' ADR 0108 (`e4a911f`)

## Decisions

1. **G17, `narrating`.** Every read-aloud clip the play screen starts (the
   question's speaker, a passage sentence's speaker, the auto-read) goes
   through `_narrate`. A `ValueNotifier<bool>` is true from `play` until that
   clip's handle is done, and only the latest clip clears it. It's passed to
   `LearningActivityView.narrating`, so speed_tap's clock pauses while the
   question is read.
2. **N7, header XP right after a série.** `LocalXp` keeps a per-kid floor in
   `app_state`, which is the total shown plus the celebration's XP. The
   header shows the larger of the floor and the server's total
   (local-instant, server-authoritative). The floor goes once the server
   reaches it, once the server lowers its total on purpose (a recompute,
   backend ADR 0047), or after a day, so a wrong estimate can't stick.
   Practice credits nothing.
3. **N14, no XP in practice.** A practice game passes no `xpEarned`, so the
   game header shows no "+1".
4. **N6, one fox.** Hafid's joyful, victory and surprised renders (from
   2026-10-25) are a different model: a blue body and a scarf, where the
   Village fox is white with a cape. So the celebration showed another
   character.
   - The app's registry (`villageFox`) now leaves those three pose slots
     empty. The Village fox's pose plays every reaction, and the motion
     recipes tell the reactions apart.
   - The renders stay in `tutolys_motion`. A render of the Village fox brings
     a reaction back with one line in that set.
   - This reverses a pick Hafid made himself, so it's flagged to him: he may
     prefer to confirm the other model as intended, the review's other
     option.
5. **G12, « Suivant » on the celebration: not done here.** The celebration
   view (`ActivityCompleteView`) has a single Continuer, and it lives in
   engines_core. That's Engines' package. The app wires the next node once
   the view takes a primary `onNext` and a secondary "Retour à la carte".
   Asked of Engines.

## Consequences

- On a fast server the floor clears at the next read, so it's invisible.
- If the ledger already counted the série when the floor was set, the header
  runs ahead by that série for at most a day. That's unlikely, because
  `award_xp` runs after the upload that follows the celebration.
