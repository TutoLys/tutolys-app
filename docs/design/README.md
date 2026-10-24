# Village UI design exploration — 2026-10-24

Read this first if you're picking this up in a new session. This is the
output of one long design session done **outside the Flutter app**, in
plain HTML/CSS/JS mockups built against real asset files Hafid supplied
and real PFEQ/product content (not placeholder text). It was never wired
into `lib/`, never touched `pubspec.yaml`, and introduced no Flutter code.
Treat everything here as **reference to build from**, not as something
already implemented.

## Read this before you build anything from here

Two things this session explored as "still open" turned out to already be
**real, shipped, app-side work** done in parallel, under a different
mechanism than this session assumed:

- **Read-aloud audio** — this session's exercise mockups (`03-exercise-engines.html`)
  use the browser's `speechSynthesis` API to read questions aloud, purely
  because that's what's available inside a static HTML artifact. **The
  real app does not use this.** See `../adr/0013-read-aloud-audio-multi-question-xp.md`:
  the real implementation plays **Piper-generated audio files from the
  backend**, cached locally via a new `AudioCacheTable`, through an
  injected `AudioResolver` interface. If you're building the real
  exercise-runner UI, reuse this session's *visual* decisions (button
  placement — before the question, not after; sized small, not a big
  CTA; only the question is read, never the answer choices — Hafid's own
  explicit correction, see the Decision Log in `01-design-system-gallery.html`)
  but wire it to the real `AudioResolver`/`ExercisePromptAudio`, not
  browser TTS.
- **`speed_tap` as a 4th engine** — at the end of this session the running
  assumption was "3 of 4 real engines built, `speed_tap` still open."
  That's wrong as of the real codebase: see `../adr/0005-phase-5-engine-list-and-speed-tap.md`
  and `CLAUDE.md`'s Phase 5 status — `speed_tap` was built back on
  2026-10-20, before this session started. This session never designed
  it and has nothing to offer there.

Beyond those two, **this session's screens have not been individually
cross-checked against current app state.** Some (Village's XP/streak
tiles, the Profil progress card) already have real data plumbing per
`CLAUDE.md`'s A7.2/B9 entries — this session's versions are almost
certainly re-designs of something that already exists and should be
reconciled, not built fresh. Others (a full dedicated **Progrès** page
with subject tabs and a per-strand mastery breakdown, a **Réglages**
page, **Aide & support**, the **Carte** path screen's exact visual
treatment, the exercise-engine content area for `mcq`/`pair_match`/
`compose_build`) do not appear to have a matching screen in `lib/` as of
this writing, as best as a design-only session could tell — but verify
against the actual current `lib/` tree before assuming anything here is
still green-field.

## What's in this folder

Three standalone HTML files, each a live, open-in-a-browser artifact —
no build step, no server required beyond `python3 -m http.server`. Open
any of them directly in a browser to look around.

### `01-design-system-gallery.html` — the full design system
Every screen as static, labeled frames (desktop + mobile side by side),
plus a running **Decision Log** at the bottom of the document (locked vs.
draft status per stage) and inline `.note` blocks documenting *why*
things look the way they do, bugs found and fixed along the way, and
open questions. This is the most complete single reference — when in
doubt, start here.

Screens covered: cadre extérieur, navigation (web/tablet/mobile), header,
Village (home dashboard), Carte (skill path), Quêtes (+ streak-detail
modal), Profil, Réglages, Progrès, Aide & support, and the shared
exercise-shell chrome (close/progress/XP/hint/validate) in 4 states
(idle, QCM, Compose, end-of-series recap) across both breakpoints.

**Known gaps, left as-is, not built:** tablet breakpoint for every screen
except the nav frame; the 3 mascot poses received were never fully
reconciled into one consistent style; Boutique (confirmed future, XP-based
per Hafid, no page built); "Entre amis" social tab (marked "bientôt").

### `02-clickable-prototype.html` — the full app, actually clickable
Same visual system, restructured into one real navigable app shell per
breakpoint (desktop sidebar+header, mobile tabbar+header) with a single
content viewport that swaps screens on nav click — not static frames.
Real interactions: Carte → tap an available node → play a real 3-question
exercise (MCQ + compose, real pick/check logic, retry-until-correct, no
lives); Réglages toggles actually toggle; the streak modal opens/closes;
XP/coins earned in an exercise update live across every screen that shows
them.

Only Mathématique has a real Carte path; other subject tabs show an
honest "not mocked up yet" placeholder rather than fake content. Dark
theme and the FR/EN toggle switch visually but don't change anything yet.

### `03-exercise-engines.html` — exercise engine content, in depth
The shared chrome (`fermer` / progress / XP / indice / valider) with real
playable content for 3 of the then-current engines:
- **QCM** (`mcq`) — shown as 4 separate rows so every state is visible at
  a glance without needing to play through: sentence-cloze with chip
  picker, equation-cloze with row picker + a working 4-function
  **calculator popup** ("Outils"), free-text typed answer, and the
  **end-of-series "mise à jour des quêtes" panel** (XP/exercises-done/
  no-retry-streak, tracked and capped against real goals, persisting
  across repeated series within the page session).
- **Association** (`pair_match`) — tap-to-match grid, wrong pairs flash
  and clear, right pairs lock in dimmed.
- **Compose** (`compose_build`) — tap number/operator tiles into blank
  slots to build an equation; tap a filled slot to pull the tile back out.
- **Estimation** — a slider "get as close as you can" pattern, explicitly
  tagged **provisional** in its own UI (orange badge) because it is *not*
  one of Hafid's chosen 4 engines — shown only because reference
  screenshots for it were supplied, never proposed as a real addition.

No `speed_tap` content here — see the warning above, it didn't need
designing, it already shipped.

## Visual language (for anything you build fresh)

Pull these from `01-design-system-gallery.html`'s `<style>` block
(`:root` custom properties) rather than re-deriving by eye — they're the
source of truth this whole session used.

- **Type**: `Baloo 2` (600–800 weight) for display/headings, system font
  stack for body text.
- **Color** (CSS custom property → hex): `--quebec-blue #1F3C88` /
  `--quebec-blue-bright #2F6FED` (primary), `--gold #D4AF37` /
  `--gold-light #FBBF24` / `--gold-pale #FDE68A` (achievement/CTA — the
  gold-pale value matches the real `tokens.dart` exactly, confirmed this
  session), `--success #2FB170` / `--success-pale #DFF5E8`, `--retry
  #F2994A` / `--retry-pale #FFF1E0` (used for "almost!", deliberately not
  red — see "no hearts/lives" below), `--ink #223047` (text),
  `--ink-muted #7C8AA3`, `--line #E4ECF7` (borders), `--track #E1E9F7`
  (progress-bar channels).
- **No hearts/lives, anywhere.** Explicit, repeated decision this
  session (see the Decision Log) — every engine retries-until-correct,
  never ends a lesson early, so a Duolingo-style heart counter would
  contradict the actual mechanic. The "almost" state uses amber + a
  target icon instead of red + an X.
- **Real brand asset**: the Arctic Fox mascot (`asset-mascot-welcome`,
  extracted to `assets/raw/asset-mascot-welcome.webp` below) is the one
  mascot pose embedded across all three files. The real `assets/icon/`
  in this Flutter project is the authoritative processed version for app
  icons specifically — this one is the illustration pose used inline in
  UI (greetings, exercise feedback, support screen).

## `assets/raw/` — real extracted image files

22 files, decoded straight out of the HTML (no re-compression, no
re-export) — these are the actual bytes Hafid supplied / this session
processed, not placeholders. Safe to copy into `assets/images/` and wire
into `pubspec.yaml` directly if/when a screen here gets built for real.

| File | What it is |
|---|---|
| `asset-mascot-welcome.webp` | Arctic Fox mascot, waving pose (the only pose used this session) |
| `asset-bldg-math.webp`, `-francais`, `-anglais`, `-science`, `-univers-social`, `-ccq` | The 6 subject-building illustrations for the Village scene |
| `asset-village.png`, `asset-carte.png`, `asset-quetes.png`, `asset-progres.png`, `asset-profil.png`, `asset-reglages.png` | Nav icons for the locked sidebar/tabbar (Village/Carte/Quêtes/Progrès/Profil/Réglages) |
| `asset-logo.webp` | App logo mark |
| `asset-coin.webp`, `asset-xpstar.webp`, `asset-flame.webp`, `asset-target.webp`, `asset-bell.webp` | Currency/XP/streak/quest/notification icons used throughout headers and stat pills |
| `asset-badge.webp`, `asset-chest.webp` | Achievement badge and reward-chest illustrations (Profil, streak-detail modal) |
| `asset-edit.webp` | Small pencil/edit affordance (Profil avatar) |

Everything else visual (UI icons like close/check/lock/chevrons/sparkle)
is inline SVG `<symbol>` definitions in each file's `<defs>` block,
already small/simple vector shapes — just copy the `<path>` data straight
into a Flutter `CustomPainter` or regenerate as a proper icon font/SVG
asset if needed; there was no reason to extract those as separate files.

## If you're starting a build session from this

1. Check current `lib/` state first — don't assume any screen here is
   still unbuilt.
2. For anything involving audio, XP, or multi-question exercises, read
   ADR 0013 before touching this session's mockups — the real mechanism
   already exists and is different from what's shown here.
3. This was never performance-tested, accessibility-audited beyond the
   read-aloud affordance itself, or reviewed for RTL/i18n beyond the
   FR/EN toggle existing cosmetically.
