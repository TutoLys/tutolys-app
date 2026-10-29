# ADR 0098 — "Ma galerie" gets a building in the Village

Date: 2026-10-29
Status: accepted. Extends ADR 0092.

## Context

The `my_gallery` engine (ADR 0092) lets a child hang the creations they
kept and give a reason for each. Nothing in the app led to it: it could
only appear as a lesson. Hafid asked for a permanent home, a building in
the Village, and supplied the art (`Assets/imgs/Royal Blue Memory
Gallery.png`).

## Decision

### The building

- A seventh `VillageBuilding`, `GALLERY` (`galleryBuildingCode`). It's
  **not a subject**: it never reaches the Carte, the backend or telemetry.
  `measured: false`, so its pill shows only « Ma galerie » / « My gallery »
  and never a progress track.
- Placed at (0.67, 0.15), drawn small, in the free sky between Français
  and Univers social. That's clear of the fox, its bubble and the sign.
- On the phone strip (below `Breakpoints.compact`) as its seventh tile.
- Same hover lift, press scale and reduced-motion rest as every building.
  A building doesn't breathe; the fox's breathing already pauses on a
  hidden tab.

### The art

Hafid's PNG was processed like the brand icon (app ADR 0012):
- background noise below alpha 8 removed (it made the trim box the whole
  canvas);
- edge colours pulled in from the nearest opaque pixel, which removes a
  yellow matte fringe;
- alpha softened by 0.6 px;
- trimmed with 4 px of margin, resized to the other buildings' 440 px
  width, and saved as webp at quality 86.

The result is `asset-bldg-gallery.webp`, 440×416, 57 KB. It's clean on the
dark navy and on the scene's sky, so no change to the art is needed and no
art brief was written.

### Opening it

- A tap plays `galleryEnvelope` in the activity shell like any game. The
  envelope is app-authored, in the app's language: four reasons and two
  visitors (Foxy, Léa).
- It reads the playing kid's own shelf (`creationShelfProvider`, per kid),
  so **a sibling's creations never show**.
- `PlayRequest.practice` / `PlayScreen.practice`: no XP estimate, no lesson
  counted toward quests, no streak day, no node progress, and the session
  store **queues no telemetry** (`DriftActivitySessionStore.uploads:
  false`). Leaving returns to the Village.
- **The participation event ADR 0092 mentions isn't sent yet.** A leafless
  practice event would be rejected by telemetry today: the envelope needs a
  skill node, and `evaluation.evidence` waits on LE-T3. Sending nothing is
  the only honest choice until telemetry accepts one.
- **Empty state**: with nothing kept yet, the gallery doesn't open an
  empty game. `GalleryEmptyScreen` shows the gallery building and the fox,
  « Ta galerie t'attend ! », and how to fill it in kid words (« Quand tu
  crées quelque chose dans un jeu, appuie sur « Garder dans mes
  créations ». »), with a gold « Retour au village ». It has no red.
  Nothing is read aloud on its own. A speaker needs a recorded clip, and
  the app has no live speech (D2), so a clip for these lines is a
  follow-up. The engine's own empty state stays as the fallback inside the
  game.

### Tapping a building, fixed

The hit-test gap noted in `f59975f` had one cause. An undecoded image is
0 px tall, and both the building and the strip tile deferred hits to their
children, so a tap aimed at the building's centre reached nothing. The
art now has a fixed box from its aspect (`buildingAspect`), and both
gesture detectors take taps across their whole area. Tap tests now use a
real hit test (`hitTestable`), and the strip's "NOT TESTED" note is
replaced by a test.

## Consequences

- A child's creations have a home they can visit any time, with no lesson
  in the way.
- The phone strip's seventh tile sits past the edge until UX finding A7
  (all subjects visible on phones) lands.
