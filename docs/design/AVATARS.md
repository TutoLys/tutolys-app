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

**Avatars follow the kid's sex** (Hafid, 2026-10-25). An adult sets it in
the portal (`Kid.sex`: girl, boy, or unspecified); a girl is offered girl
avatars, a boy boy avatars, and an unspecified kid all of them. The
default follows it too: Léa for girls, `kid_curly` for boys.

| # | File | Sex | Art idea |
|---|---|---|---|
| 1 | `avatar-kid-wavy.webp` | girl | **The existing Léa** (`asset-profil.png`), re-exported at 512 with alpha. The girls' default. |
| 2 | `avatar-kid-curly.webp` | boy | Boy, dark skin, short black curly hair, big smile, blue hoodie. The boys' default. |
| 3 | `avatar-kid-glasses.webp` | girl | Girl with round glasses, straight black bob, light-tan skin, blue hoodie |
| 4 | `avatar-kid-hijab.webp` | girl | Girl in a blue hijab, warm brown skin, blue hoodie |
| 5 | `avatar-kid-freckles.webp` | boy | Boy, red hair, freckles, gap-toothed grin, blue hoodie |
| 6 | `avatar-kid-braids.webp` | girl | Girl, medium-dark skin, two long braids with blue beads, blue hoodie |

**Boys are short of starters**: one drawn (`kid_curly`), one planned
(`kid_freckles`), against four for girls. More boy starters are needed;
each is a new key with `sex: KidSex.boy`.

## Unlockables: earned by playing

Each one is the kid in a costume, so it stays a "me" and not a different
character. Unlocks are recorded once and never taken back.

They have **no sex in the catalog yet**, so every kid is offered them. When
the art comes, either draw one neutral version, or draw a girl and a boy
version as two keys (`astronaut_girl`, `astronaut_boy`) with the same
unlock rule and tag each.

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

## Status

Delivered 2026-10-25 (source art in `Lab/Tutolys/Assets/imgs/avatars/`,
never edited in place): **#1 `kid_wavy`, #2 `kid_curly`, #3
`kid_glasses`.** The other 14 show a neutral face until drawn.

The same delivery had four more images, which are **not in the catalog**
because they repeat a face that's already there: "ChatGPT Image … AM-1"
is the curly-haired boy again, and "… AM-2", "Cheerful Girl in Blue
Hoodie" and "Léa's Cheerful Blue Hoodie Avatar" are all Léa. Still
missing from the starters: #4 hijab, #5 freckles, #6 braids.

## Adding an avatar

1. Keep the original in `Assets/imgs/avatars/`.
2. Export a square 512×512 webp with alpha (quality about 86, which is
   about 40–50 KB) to `tutolys-app/assets/images/avatar-<key>.webp`.
   Don't ship the 1.2–1.5 MB PNGs: they go in every build, web included.
3. Add or fill one line in `avatarCatalog`
   (`lib/features/profile/avatars.dart`): the key, the unlock rule, the
   sex (`sex: KidSex.girl` / `KidSex.boy`, or none for everyone), and the
   asset. For an unlockable, also add its name to `avatarName` in
   `strings.dart` (FR and EN).
4. The key (`^[a-z0-9][a-z0-9_]{0,63}$`) is what the backend stores in
   `Kid.avatar_key`, so it's **permanent once shipped**. The backend has
   no allowlist, so adding an avatar needs no backend deploy.
