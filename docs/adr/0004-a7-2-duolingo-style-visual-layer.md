# ADR 0004 — A7.2: Duolingo-style visual layer, real data, no progression math

Date: 2026-10-19
Status: accepted

## Context

Hafid asked for the learner experience to look and feel like a modern
gamified learning app — a winding skill path, a home dashboard, a profile
— "just like Duolingo." The old `tutolys-desktop-app` (Tauri + Vue + Rust)
already built exactly this once; Phase 0's audit (`AUDIT.md` §3) ruled
**discard the code, mine the specs**, and that code was believed deleted.
It wasn't — `github.com/iflis7/tutolys-desktop-app` (and
`tutolys-backend`, `tutolys-web`) still exist, last pushed 2026-04-13, the
same snapshot the audit already looked at. Finding the real source intact
didn't change the reuse verdict (confirmed with Hafid: UI reference only,
not a port) — but it gave a far richer reference than the mined spec and
screenshots alone: exact CSS custom properties, exact layout constants,
exact component markup.

A real, separate constraint shapes scope here: the old app's own
progression/mastery/XP/streak engine is explicitly **not** being ported
(spec decision D3 — "the server, entirely" — and this backend's own
B9/analytics-thresholds work is still unbuilt, tracked OPEN in
`CLAUDE.md`). So this round is the **visual layer only**: real layout and
styling, wired to data that's either genuinely real (locked/available,
today's actual play counts) or honestly absent (no XP, no streak, no
mastery bar) — never a fabricated number standing in for math that
doesn't exist yet.

## Decisions

**Screens.** Added `HomeScreen`, kept `PathScreen` (rebuilt), added
`ProfileScreen` — three tabs in a new `HomeShell` (bottom `NavigationBar`,
`IndexedStack` so tab state survives switching), replacing the old
single-screen paired router. `/play` is still a top-level pushed route,
covering the whole shell.

**Skill path.** Rebuilt from a flat `ListView` into a serpentine path —
layout numbers taken directly from the real `GamesView.vue`
(`nodeXForIndex`: strict alternating ±200 from center, not a sine wave;
the connector's cubic-bezier midpoint formula, verbatim) and scaled
proportionally to the available width instead of hardcoding its 760px
desktop canvas. Node styling also follows the real `.quest-orb` CSS: a
neutral card-coloured disc with the state carried by border colour and a
soft glow, never a solid state-coloured fill — matched here for
locked/available only (no "active"/"done" states yet, those need
mastery data this round doesn't have).

**Design tokens.** `Radii.lg` corrected from an invented 22 to the real
app's own `--radius-lg: 2rem` (32), confirmed from its shipped `main.css`.
Added `Shadows.cloud` (the real app's navy-tinted ambient card shadow,
`rgba(31,60,136,0.08)`) and wired it onto `CardThemeData` via
`shadowColor` + non-zero elevation — Flutter's native route to a tinted
shadow, no custom painting needed. Buttons already use the real app's pill
shape (from the token audit earlier this phase); the "play" CTA now also
gets the real app's warm gold treatment (`games-cta-play-*` in its CSS)
via the theme's existing secondary/onSecondary pair, instead of the
generic primary-blue every other button uses.

**Not ported, deliberately**: `--font-display`/`--font-body` (Plus
Jakarta Sans / Inter) — the real app loads these from Google Fonts' CDN
at runtime via a CSS `@import`; the Flutter equivalent (`google_fonts`
package) would mean a new runtime network dependency for every font
glyph, in an app whose native builds are supposed to work fully offline
(spec decision D6). Flagged, not silently skipped — needs an explicit
offline-tradeoff decision, not a judgment call buried in a visual-polish
pass.

**Real home stats.** `HomeStats` (new, `lib/data/local_db/home_stats.dart`)
counts today's completed exercises and play time from a dedicated
`AppStateTable` counter, **not** `EventOutboxTable` — delivered events
there are pruned after as little as 6 hours (`DriftEventOutbox`'s own
crash-safety design, not analytics storage), so a kid reopening the app
later the same day would see "today" already erased. Recorded from
`PlayScreen`'s `ExerciseResult` on `ExerciseOutcome.completed` only — an
abandoned run isn't "played."

## A real bug found and fixed along the way

`HomeScreen`'s stat tiles only ever load once (`IndexedStack` keeps tabs
alive, so `HomeController.build()` never re-runs just by switching back to
the tab) — live-verified: finishing an exercise and returning showed
stale (zero) counts until this was understood. Fixed by having both
`HomeScreen`'s and `PathScreen`'s `/play` launch sites `await` the
`push()` future (which `go_router` resolves exactly when the pushed route
pops) and explicitly refresh `homeControllerProvider` afterward.

## Verification

`flutter analyze`: 0 issues. Full suite: 104 tests (97 prior + updated
assertions for the new shell/path structure, +4 `HomeStats`, +3
`HomeScreen`). Live-verified against a real `dev-stack` backend: paired a
fresh kid, played a real exercise, confirmed the home dashboard's stat
tiles update correctly on return (the bug above, caught live, not by a
test — added `HomeStats`/`HomeScreen` tests afterward to pin the fix,
didn't rely on the live check alone).

## Consequences

- The real `tutolys-desktop-app`/`tutolys-backend`/`tutolys-web` repos are
  a standing, high-value reference for future UI work on this app — worth
  remembering they exist and are clone-able, not just the mined spec.
- Next visual gaps worth closing later, not done this round: the real
  app's "active"/"done" node states (need a progress signal this app
  doesn't have yet), the fonts tradeoff above, and the inline
  tap-to-expand quest-card interaction (this build still navigates
  straight to `/play` on tap — simpler, a deliberate scope cut, not an
  oversight).
