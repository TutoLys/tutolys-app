# ADR 0111: A « Révision » row on the Carte, from evidence only (OW3)

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/BACKEND_WORKORDER_OFFLINE_WINDOW.md` OW3 (Backend's
  design, two questions for Hafid); Hafid's answer relayed by the Manager:
  a « Révision » row, capped at 3 per subject, from evidence only

## Decisions

1. **Its own row, above the path**, never inline. A grade-3 child shown
   grade-1 work inline reads it as being sent back; a separate row titled
   « Révision » reads as an invitation. Gold border, a replay icon, and up
   to three skill pills that play the skill on a tap (`playNode`, the same
   path as the orbs, downloading first if needed).
2. **Evidence only.** A skill qualifies when the backend's §5.9 classifier
   (backend ADR 0010) marks it `struggling` or `watch`, the kid hasn't
   mastered it, it's in this subject, and it has a lesson to play. The app
   never infers that from scores: the thresholds are server config
   (`RulesThresholds`).
3. **Three per subject** (`reviewCapPerSubject`), `struggling` first, then
   the lower mastery.
4. `SkillMasteryDto.status` is optional and kept in the progress cache. With
   no status served, the row doesn't show.
5. Copy is gender-neutral (« Rejoue ces leçons pour les réussir encore
   mieux. »).

## What the backend still has to do (asked via the Manager)

- **Serve `status`** on each `/me/progress` mastery (`SkillMasterySerializer`
  has it on the model but leaves it out). Until it does, the row never shows.
- **OW3 proper**, prior-grade review: manifest entries marked `review: true`
  for the leaves the rule selects, **capped at 3 per subject**, plus those
  leaves' curriculum nodes. The device's curriculum is grade-from-token, so
  a prior-grade leaf has no node here to draw today. The app already keeps a
  `review` set in the offline window (ADR 0095). Once nodes arrive, they
  join this row through the same rule.

## Consequences

- Today the row covers the kid's own grade only, and only once `status`
  is served.
- All published lessons are grade 1, so prior-grade review can't be checked
  against real content yet (Backend's own note in the work order).
