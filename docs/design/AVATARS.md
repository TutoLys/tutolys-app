# Avatar brief

Kid avatars for Profil and the header, matching `asset-profil.png` (Léa: a
3D cartoon kid, head and shoulders, blue hoodie). The fox stays the
app's mascot and is never a kid's avatar.

## Specs (every avatar)

- **Square canvas, 512×512, transparent background.** Head and shoulders,
  centred, filling about 85 %.
  - The app crops to a **circle** at 30 px (phone header), 52 px (header)
    and 92 px (Profil). Keep the face inside the middle circle and make
    sure it reads at 30 px.
- **The same 3D style and lighting as `asset-profil.png`.** Blue
  (`#1f3c88`-ish) is the shared accent: a hoodie, collar or trim.
- **WebP or PNG with alpha.** Check the edge pixels for a coloured fringe;
  the brand mark had one.
- **No text in the art.** Names come from the app, in French and English.
- **One version only.** The app draws the locked state itself (dimmed, with
  a lock and what unlocks it).
- **File name:** `avatar-<key>.webp`, using the keys below.

## Starters: free from day one

Six, so every child can pick one that looks like them. A choice of who you
are is never locked behind play.

| # | File | Art idea |
|---|---|---|
| 1 | `avatar-kid-wavy.webp` | **The existing Léa** (`asset-profil.png`), re-exported at 512 with alpha. The default. |
| 2 | `avatar-kid-curly.webp` | Boy, dark skin, short black curly hair, big smile, blue hoodie |
| 3 | `avatar-kid-glasses.webp` | Kid with round glasses, straight black bob, light-tan skin, blue hoodie |
| 4 | `avatar-kid-hijab.webp` | Girl in a blue hijab, warm brown skin, blue hoodie |
| 5 | `avatar-kid-freckles.webp` | Boy, red hair, freckles, gap-toothed grin, blue hoodie |
| 6 | `avatar-kid-braids.webp` | Girl, medium-dark skin, two long braids with blue beads, blue hoodie |

## Unlockables: earned by playing

Each one is the kid in a costume, so it stays a "me" and not a different
character. Unlocks are recorded once and never taken back.

| # | File | Name (FR) | Unlocked by | Art idea |
|---|---|---|---|---|
| 7 | `avatar-tuque.webp` | Tuque d'hiver | Level 2 | Knitted blue-and-white tuque with a pompom, scarf, rosy cheeks |
| 8 | `avatar-camper.webp` | Campeur | 3-day streak | Camping cap, holding a small glowing lantern (the flame theme) |
| 9 | `avatar-astronaut.webp` | Astronaute | Level 3 | Round space helmet, visor up, blue mission patch |
| 10 | `avatar-explorer.webp` | Explorateur | Played all subjects | Explorer hat, binoculars round the neck, a little map |
| 11 | `avatar-captain.webp` | Capitaine | Level 5 | Sailor-captain hat, striped collar, a spyglass |
| 12 | `avatar-knight.webp` | Chevalier | Quest master (every quest in one day) | Shiny helmet with a blue plume, the visor open |
| 13 | `avatar-hero.webp` | Super-héros | 7-day streak | Blue cape and mask, like the fox's cape: "Gardien de la flamme" |
| 14 | `avatar-wizard.webp` | Magicien | Level 10 | Starry blue wizard hat, a small wand |
| 15 | `avatar-scientist.webp` | Scientifique | Every subject 50 % | Lab goggles pushed up, lab coat, a bubbling flask |
| 16 | `avatar-artist.webp` | Artiste | 50 quests | Beret, a paint smudge on the cheek, a brush behind the ear |
| 17 | `avatar-fox-hood.webp` | Capuche de renard | Level 20 | Hood shaped like the TutoLys fox (white and blue ears). The rarest one. |

Levels use the backend's `LevelCurve`, which is 100 XP per level today, so
level 2 comes in the first session and level 20 is about 1,900 XP. The
achievement unlocks reuse the eight achievements in Quêtes
(`quest_board.dart`), so an avatar and its badge always unlock together.

Until the art arrives, the app shows the existing Léa for slot 1 and a
neutral silhouette for the others, so the picker can ship and be tested
first.
