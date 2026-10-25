# Baloo 2

Copyright 2019 The Baloo 2 Project Authors (https://github.com/EkType/Baloo2).
Licensed under the SIL Open Font License, Version 1.1
(https://openfontlicense.org) — bundling and redistribution inside an app
are permitted; the font may not be sold on its own.

These three files are static instances (wght 600 / 700 / 800) cut from the
variable woff2 the 2026-10-24 design embeds in
`docs/design/01-design-system-gallery.html` — the same font, the same
latin subset (230 glyphs, full French coverage), so the app and the design
render identically. Static rather than variable because Flutter maps
`FontWeight` to separate font assets reliably on every target, while
variable-axis support differs between the web and desktop renderers.

Bundled, never fetched from a CDN: the app is offline-first (ADR 0004).
