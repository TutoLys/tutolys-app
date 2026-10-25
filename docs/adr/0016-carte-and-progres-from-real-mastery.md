# ADR 0016 — Carte and Progrès: built on mastery and curriculum data the app already has

Date: 2026-10-24
Status: accepted

## Context

The design draws two pages that need finer-grained progress than the app
had shown so far:

- **Carte**: subject pills; a strand title ("Sens des nombres"); nodes that
  are mastered (gold check), active (progress ring and an "En cours · 60 %
  maîtrisé" card with Continuer), available, or locked.
- **Progrès**: three headline stats (skills mastered, streak, level plus
  coins), then one row per strand, each with a bar, a status pill
  (Maîtrisé / En cours / À découvrir) and a percentage.

The handoff before this work said per-node mastery "isn't exposed by the
backend". That was wrong. `GET /api/v1/me/progress` already returns
`masteries[]`, one entry per played skill with `mastery_pct` and
`is_mastered`. The app had been dropping that list everywhere except the
Village's per-subject join.

The local leaf cache (`skill_node_cache`) has no strand or label column.

## Decision

1. **Mastery comes from `/me/progress`'s per-skill list, joined to the
   cached curriculum.** No new endpoint, and it works offline from what is
   already cached. It's the same join `subjectProgressProvider` uses for
   the Village.

2. **Strand titles come from the leaf's `stable_key`.** Every key names its
   strand (TAXONOMY.md §4; both the current grammar and the legacy
   `…/strand/<slug>/…` form are read). The PFEQ's own learning-area maps
   (`tutolys-backend/reference/pfeq/learning_area_maps/`, bilingual) group
   strands into titled areas: Arithmétique, Géométrie, Mesure, and so on.
   They're copied into `lib/features/path/learning_areas.dart` as curriculum
   data, which is why the i18n guard skips that file. One function,
   `groupLeavesByArea`, feeds both pages, so the Carte's section titles and
   Progrès's rows always agree.
   - Rows are per **area**, not per strand: the design's strand-level names
     aren't available in any language-correct form locally.
   - **Français is incomplete.** Its map predates the round-2 rebuild
     (backend ADR 0006), so most français leaves fall into one untitled
     group. The real fix is strand labels on the curriculum endpoint.
     Guessing labels from slugs would show children French without accents.

3. **Node states (Carte).**
   - **Mastered**: the backend's `is_mastered`.
   - **Active**: the first playable, unmastered node in path order. Exactly
     one per subject, so the fox and the Continuer card have a single,
     well-defined place.
   - **Available**: any other playable node.
   - **Locked**: nothing is synced to play on it. Today that is the only
     real reason to lock a node; nothing gates on order.
   - A never-played active node reads "À découvrir", not "0 %": a zero
     reads as a score, not a beginning.

4. **Area status (Progrès) is a fact, not a threshold.**
   - **Maîtrisé** only when every leaf in the area is mastered.
   - **En cours** once any leaf has real mastery.
   - **À découvrir** otherwise.
   - The bar shows mean mastery across all leaves, with unplayed leaves
     counting as zero. The design's mock pairs a 68 % bar with "Maîtrisé";
     this rule never produces that, on purpose.

5. **The level is the server's** (`level` on `/me/progress`, curve in
   backend ADR 0024). It's now parsed. Offline it is null rather than
   recomputed locally, because a second curve would drift from the first.
   **No coins**: no currency exists, so the design's "340 pièces" shows the
   XP the level is built from.

6. **No Culture québécoise pill**: that subject has no curriculum data yet
   (open item #13), and a pill would open an empty page.

## Consequences

- Both pages are honest for a brand-new kid: everything reads À découvrir
  or locked, at 0 %.
- Mastery updates only as often as the backend's `refresh_mastery` job
  runs. The app refreshes `/me/progress` after each game, but the server's
  number can lag behind.
- The Carte's "Maîtrise avancée" milestone node isn't built: no data backs
  it.
- Follow-up for the backend: strand labels (FR/EN) on the curriculum
  endpoint would replace the français gap and allow the design's per-strand
  rows.
