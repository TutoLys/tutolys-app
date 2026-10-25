# Badge icon brief

Badge art for the app, matching the existing 3D art (`asset-badge`,
`asset-flame`, `asset-chest`, `asset-xpstar`).

## Specs (every icon)

- **Square canvas, 256×256**, transparent background, the art filling about
  85 % of it.
  - The app shows badges from 28 px (Profil grid) to 92 px (weekly card),
    so the shape must read at 28 px.
- **WebP or PNG with alpha.**
  - Check the edge pixels for a coloured fringe; the brand mark had one.
- **No text in the art.** Names come from the app, in French and English.
- **One version only.** The app draws the locked state itself (dimmed, with
  a lock).
- **File name:** `badge-<key>.webp`, using the keys below.

## The set

| # | File | Name (FR) | What the kid did | Art idea |
|---|---|---|---|---|
| 1 | `badge-streak3.webp` | Série de 3 jours | Played 3 days in a row | small flame, bronze ring |
| 2 | `badge-streak7.webp` | Série de 7 jours | Played 7 days in a row | bigger flame, gold ring |
| 3 | `badge-quest-master.webp` | Maître des quêtes | Finished every daily quest in one day | trophy or target with a crown |
| 4 | `badge-quests50.webp` | 50 quêtes | Finished 50 quests in total | stack of scrolls / "50" medal shape (no digits) |
| 5 | `badge-level10.webp` | Niveau 10 | Reached level 10 | XP star, silver |
| 6 | `badge-level20.webp` | Niveau 20 | Reached level 20 | XP star, gold with wings |
| 7 | `badge-all-subjects50.webp` | Toutes matières 50 % | Every subject at least half mastered | five-colour pie / balanced scales |
| 8 | `badge-explorer.webp` | Explorateur | Played in all five subjects | compass or the fox with a map |
| 9 | `badge-weekly.webp` | Badge de la semaine | Finished 15 quests in one week | today's `asset-badge` works; replace it only if you want |

### Streak rewards in the Série modal (optional art)

| File | Name | Today |
|---|---|---|
| `reward-chest.webp` | Coffre de série · 3 jours | uses `asset-chest`; already fine |
| `reward-title.webp` | Titre : Gardien de la flamme | a plain scroll icon, so new art would help |

### Optional extras (not in the design; build only if you say so)

| File | Name | Earned when |
|---|---|---|
| `badge-first-step.webp` | Premier pas | first exercise ever finished |
| `badge-streak30.webp` | Série de 30 jours | 30-day streak |
| `badge-subject-<code>.webp` ×5 | Maître des maths / du français / … | one subject at 80 % mastery |
