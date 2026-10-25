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
- **One version only.** The app draws the locked state itself (a silhouette, with
  a lock and what unlocks it).
- **File name:** `avatar-<key>.webp`, using the keys below.

## The catalog

`lib/features/profile/avatars.dart` is the source of truth; ADR 0050 has
the reasoning. **Avatars follow the kid's sex** (Hafid, 2026-10-25): an
adult sets it in the portal (`Kid.sex`), a girl is offered girl art, a boy
boy art, an unspecified kid everything. A character drawn as both is one
unlock under two keys (`<character>_girl`, `<character>_boy`); earning it
unlocks both.

File names are the key with `-` for `_`: `scientist_girl` →
`avatar-scientist-girl.webp`.

### Free from day one

| Key | Source art |
|---|---|
| `kid_wavy` (girls' default) | Léa, `asset-profil.png` |
| `kid_curly` (boys' default) | Cheerful 3D Boy in Blue Hoodie |
| `kid_glasses` | Glossy Chibi Girl Avatar with Glasses |
| `kid_braids` | Glossy Braided Girl Avatar |
| `kid_freckles` | Freckled Auburn-Haired Boy Avatar-1 |
| `kid_hijab` | **not drawn yet** |
| `camper_girl` / `camper_boy` | Cheerful Camper Girl Avatar / Camper Adventurer Portrait |
| `explorer_girl` / `explorer_boy` | Young Explorer Adventure Portrait / Cartoon Explorer with Map-1 |

### By subject: completed skills in that subject

| Keys | Subject | Skills | Source art (girl / boy) |
|---|---|---|---|
| `scientist_*` | SCI | 5 | ChatGPT 02_27_53 PM-2 / 02_27_52 PM-1 |
| `chemist_*` | SCI | 15 | Leaping Science Girl… / Jumping Kid Scientist… |
| `knight_*` | CCQ | 5 | Blue Crest Girl Knight-2 / Blue-Crested Knight |
| `fleur_knight_*` | CCQ | 15 | Fleur-de-Lis Knight-1 / Knight with Sword and Shield-1 |
| `mathematician_*` | MATH | 10 | Eureka Math Adventure / Math Adventure with a Cheerful Fox |
| `french_teacher_*` | FR | 10 | French Teacher Adventure / French Teacher Mascot |
| `english_*` | EN | 10 | English Learning Adventure / English Learning Classroom Mascot |
| `historian_*` | SOC | 10 | Adventurous Young Historian Explorer / Explorer of History |

### Milestones

| Keys | Unlocked by | Source art |
|---|---|---|
| `tuque_girl` | Level 2 | ChatGPT 12_42_49 PM-2 (**no boy version**) |
| `hero_*` | 7-day streak | Flying Blue Superhero Girl-2 / Joyful Blue Superhero in Flight-2 |
| `captain_*` | Level 10 | Girl Captain with Spyglass-2 / Young Captain with Spyglass-3 |
| `artist_*` | 50 quests | Jumping Artist Girl / 3D Paintbrush Artist Boy |
| `fox_hood` | Level 20 | **not drawn yet**: a hood shaped like the TutoLys fox |

Levels are the school year's 1–99 (ADR 0033).

### Rare: found on a perfect lesson

About one perfect lesson in 20 reveals one, deterministically per kid and
lesson; shown as "?" until found.

| Keys | Source art |
|---|---|
| `wizard_*` | Joyful Girl Wizard Casting Magic-1 / Joyful Wizard Boy Casting Magic-2 |
| `astronaut_*` | Girl Astronaut Portrait-1 (black backdrop removed) / ChatGPT 12_58_25 PM-2 |
| `coder_*` | Cheerful Cyber Coder Adventure / Young Cyber Coder Adventure |
| `mermaid` (girls) | ChatGPT 02_44_27 PM-2 |
| `pirate` (boys) | Cheerful Pirate Captain Adventure |

### Not used from the 2026-10-25 delivery

Group pictures and character sets (Costume Collage, Mascot Quartet, Science
Squad, Kids' Chemistry, the three Character Sets), duplicates of faces
already in the catalog (the extra Léas, Red-Haired Boy, Freckled Boy-3,
the second girl astronaut and the binoculars explorer, which has a
checkerboard baked in), alternates of the same character (other captains,
wizards, scientists, knights, the map explorer boy), and the adult
"Québec Statesman", who isn't a kid in a costume.

**Still wanted**: `kid_hijab`, `fox_hood`, a boy tuque, and more boy
starters (two against four for girls).

## Adding an avatar

1. Keep the original in `Assets/imgs/avatars/`.
2. Add a line to `tool/export_avatars.py`: the source file and a square
   crop around the head and shoulders (full-body art must be cropped; the
   circle is 30 px in the phone header). Run `python3 -I
   tool/export_avatars.py`: 512 px webp under 120 KB into `assets/images/`.
   Don't ship the 1.2–2.8 MB PNGs: they go in every build, web included.
3. Add or fill one line in `avatarCatalog`
   (`lib/features/profile/avatars.dart`): the key, the unlock rule, the
   sex (`sex: KidSex.girl` / `KidSex.boy`, or none for everyone), and the
   asset. For an unlockable, also add its name to `avatarName` in
   `strings.dart` (FR and EN).
4. The key (`^[a-z0-9][a-z0-9_]{0,63}$`) is what the backend stores in
   `Kid.avatar_key`, so it's **permanent once shipped**. The backend has
   no allowlist, so adding an avatar needs no backend deploy.
