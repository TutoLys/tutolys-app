# ADR 0050: Avatar art, subject unlocks and rare drops

Date: 2026-10-25. Status: accepted.

Hafid's brief, routed by the manager session, was to add the new avatar art
and "lock the ones related to our subjects… make some locked and rare drops,
make a few available". This ADR extends ADR 0024.

## Context

Hafid delivered 66 images (`Lab/Tutolys/Assets/imgs/avatars/`). They were
the missing starters plus themed characters, most drawn as a girl and a boy.
Before this, 16 of the 17 avatars in the catalog had no art.

## Decisions

**Which art is used.** There are 37 new avatars, and 40 with art in all.
- Skipped:
  - group collages and character sets, because an avatar is one character;
  - byte-identical duplicates, and near-repeats of a face already in the
    catalog (four Léas, a second red-haired boy);
  - a late-added adult "Québec statesman". He is not a kid in a costume,
    and he looks like a real public figure.
- Full-body and scene art is cropped to the head and shoulders, because the
  app shows avatars as circles as small as 30 px.
- Crops live in `tool/export_avatars.py`, which also re-exports everything:
  512 px webp, under 120 KB each, 3.2 MB in total. The source art is never
  edited.
- Two sources had no alpha channel. The girl astronaut had a black backdrop,
  which was removed from the corners. The boy explorer had a checkerboard
  baked into the pixels, so a different image was used.

**One character, two keys.** A character drawn as a girl and as a boy is
one `group` with two keys (`scientist_girl`, `scientist_boy`) and one
unlock rule. Earning it records both keys, and the picker offers the one
that matches the kid's sex (ADR 0024). Neither unlock nor progress is
attached to sex. A character drawn for only one sex goes only to that
sex: the mermaid and the tuque to girls, the pirate to boys. Unspecified
kids see everything.

**Unlocks**:

| Kind | Avatars | Rule |
|---|---|---|
| Free | 6 starters, camper, explorer | from day one |
| Subject | scientist (SCI 5), chemist (SCI 15), knight (CCQ 5), fleur-de-lis knight (CCQ 15), mathematician (MATH 10), French teacher (FR 10), English teacher (EN 10), historian (SOC 10) | completed skills in that subject |
| Milestone | tuque (level 2), captain (level 10), fox hood (level 20, no art yet), superhero (7-day streak achievement), artist (50 quests achievement) | |
| Rare | wizard, astronaut, coder, mermaid (girls), pirate (boys) | found on a perfect lesson |

- **Subject progress is completed skills**, not XP. A skill is completed when
  every lesson on it is finished, ADR 0033's local measure
  (`localNodeProgressProvider` ≥ 1), counted per subject code
  (`completedSkillsBySubjectProvider`). It updates the moment a lesson ends.
  - Two tiers per subject wherever two distinct characters exist (science,
    CCQ). Elsewhere there is one tier, at 10.
  - The counts are deliberately reachable in grade 1, where a subject has
    tens of skills.
- **The superhero stays on the 7-day streak.** The manager's framework
  listed the superhero as a rare drop. The art has a flame on the chest,
  which is the "Gardien de la flamme" streak reward, so it stays a
  milestone. There are still five rare characters.
- **Camper and explorer became free.** They used to be unlocked by the
  streak-3 and explorer achievements, which keep their badges. This follows
  "make a few available".
- **The old unsexed keys are retired** (`tuque`, `camper`, `astronaut`,
  `explorer`, `captain`, `knight`, `hero`, `wizard`, `scientist`,
  `artist`). No release ever shipped them, and none had art.
  - A stored key the catalog doesn't know (one of these, or one from a newer
    app) is worn as the kid's default for their sex. It never falls back to
    Léa for a boy.
  - Old entries in the unlocked set are harmless.

**Rare drops** (`rareDropFor`):
- A completed lesson with every question right on the first try
  (`ActivitySummary.perfect`) has a 5 % chance to reveal a rare character.
- **The roll is deterministic per kid and lesson**: 32-bit FNV-1a over
  `kid|lesson`. A pinned test vector checks it gives the same result on
  every platform, and the multiply is split so it stays exact on web.
  `String.hashCode` isn't stable, so it isn't used.
  - Replaying a lesson never rerolls.
  - Siblings get different lucky lessons.
- **A lesson drops at most once**, because `avatar.drops` records it.
  Without that record, a lucky lesson could be replayed to collect the
  whole pool, since the pool shrinks as the kid collects.
- Only characters offered to the kid's sex and not yet owned can drop. A
  drop is never a duplicate, and once all are found nothing drops.
- **The moment**: the celebration screen shows a "Avatar rare trouvé !"
  card with the avatar popping in, which stays still under reduced motion
  (`RareAvatarFound`). It's a first version; the animations session can
  replace the entrance.

**The picker** has four sections: free, by subject, milestones and rare.
- A locked avatar is a dark silhouette (`srcATop`, so the outline still
  reads) with a lock, and says what unlocks it: "Termine 5 compétences en
  sciences", "Niveau 10".
- A rare one not yet found is a "?" with "Une leçon parfaite peut le
  révéler", and its name stays hidden until it's found.

## Not done

- **Unlocks are still per device**, including rare drops, which can't be
  re-earned. The server-side copy is
  `Platforms/BACKEND_WORKORDER_AVATAR_UNLOCKS.md` (U1–U4). The app's sync
  call waits for it.
- **Missing art**: `kid_hijab`, `fox_hood`, and a boy tuque.
- **Subject counts are this device's own.** The server reports total
  `skills_completed`, not per subject, so a second device starts its
  subject unlocks from its own play (U1 covers keeping what was earned).
- **The rare reveal is plain**, pending the animations session.
- **Not checked live in a browser.** The picker was rendered in a widget
  test with the real art, and a perfect lesson's drop is covered by
  controller tests.
