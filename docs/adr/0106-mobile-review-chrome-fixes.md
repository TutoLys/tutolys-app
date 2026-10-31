# ADR 0106: Mobile review fixes to the app chrome (AM6–AM11, AM19, K2)

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/ux-review/mobile-2026-10-31.md`, relayed by the Manager

## Decisions

1. **AM19 (art):** the English building no longer flies a Union Jack beside a
   red phone box. The flag is now Québec's (blue field, white cross, four
   fleurs-de-lys), the phone box is gone under hedges and two topiary trees,
   and the red/white/blue trim on the book and a suitcase sticker is gold.
   This is a retouch of the existing raster, with the same size and position,
   so nothing that places the building moves. The website copies the same file.
2. **AM6:** on a phone, Réglages' four tabs are a 2×2 grid of equal 56px
   cells, icon over label. `PillTabs(grid: true)` keeps the tab-bar semantics
   and keys, so only the layout changes. Pages with many or open-ended tabs
   (the Carte's subjects) keep the scrolling row with its edge fade.
3. **AM7:** « Se déconnecter » is a neutral outline button, ink text with a
   grey icon. Red is gone from the kid app's chrome.
4. **AM8:** on a phone, Réglages, Aide and À propos show a 48px ← in the
   header, and the gear is drawn selected. From Aide and À propos the ← goes
   to Réglages, the only place a phone reaches them. From Réglages it goes to
   the last of the five tabs.
5. **AM10 (dark):** the design's dark `track` (`#243150`) measured 1.3:1 on a
   card, so it is lifted to `#3A4D78` (1.9:1). The fill carries the value, so
   the track only has to be visible. A locked orb in dark drops the light
   theme's half opacity for a `#2A3A5E` fill and a `#5B6E99` ring (3.2:1).
   « Changer de profil » uses the bright blue. The tab bar's and sidebar's
   selected fill come from the palette instead of a hardcoded light tint.
6. **AM11:** the 84px rail labels its icons at 12px. Below 900px of content
   the Village shows the phone layout instead of the scene, which at 768 was
   drawn at 0.62 scale with labels around 7px. Where the scene does show, its
   building pills are counter-scaled (×1.25 at most) so their text stays
   about 12px. « Continuer » comes first at every width.
7. **K2:** the nav's and the bell's count badges are gold with navy figures
   (6.3:1), never red.

## Consequences

- `VillageDarkColors` departs from the design's transcription in one value
  (`track`) and adds two (`lockedFill`, `lockedRing`). The comments say why.
- Between 600 and about 1150px wide (window width), the Village has no scene.
  The phone layout is legible there, and the scene isn't.
- The map's red-and-white target icon stays: it's the design's own symbol,
  not feedback.
