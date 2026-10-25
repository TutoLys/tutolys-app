# ADR 0015 — Quêtes: only the parts of the design that have real data

Date: 2026-10-24
Status: accepted — decisions 1, 3 and 6 superseded 2026-10-25 (see Revision)

## Context

The design (`docs/design/01-design-system-gallery.html`, "Quêtes" and
"Quêtes → détail de la série") draws two things.

The page has:

- a streak card with a Monday-first week strip
- three daily quests, each with a "+15 XP" reward
- "Badge de la semaine"
- "Réussites récentes"

The streak modal (a 380px card on desktop, full screen on a phone) has:

- "Personnelle / Entre amis" tabs
- a nudge to play today
- a month calendar
- a streak-goal bar
- three streak rewards: a chest, a "Bouclier de série" and a title

Some of this has real data behind it and some does not. In order:

- **Streak.** Real: `current_streak_days` from `/api/v1/me/progress`
  (backend ADR 0019).
- **Daily quests.** One real type, the daily challenge (N correct in a
  row, today). Teacher-assigned and bonus-review quests need school
  plumbing (open item #11).
- **Quest XP.** None. The daily challenge awards nothing; XP is earned
  per question (ADR 0013).
- **Badges, recent achievements, the chest, titles.** Open item #3.
  Nothing exists.
- **"Entre amis".** Explicitly out (#12).
- **"Bouclier de série".** This is the real streak freeze, under the
  design's name. Its balance is served, but its grant schedule is not.
- **Days played.** No device-facing endpoint serves days played.
  `played_date` holds them locally, per kid (ADR 0014).

## Decisions

1. **Build only what has data.** That means:
   - one quest row, not three
   - no reward chip on it
   - no badge or achievement cards
   - no chest or title rewards
   - no tabs at all, because one tab alone is not a tab bar and the
     other one is out of scope

   Each widget's doc comment names what it leaves out and why, so a later
   session reading the mockup does not "restore" them.
2. **The streak number comes from the backend. The days come from this
   device.** The week strip and the calendar read
   `StreakLocal.playedDays()`. This leaves out:
   - play on another device
   - gaps a freeze bridged on the server

   So the strip can disagree with the number. That is accepted for now.
   The fix is a device-facing play-days read (the backend already reads
   telemetry's `play-days` signal, backend ADR 0019), which would
   need a work order.
3. **The streak-freeze balance moves from Profil to the modal**, as
   "Bouclier de série". Profil's own doc comment promised this move
   once Quêtes existed. "Rechargé dans N jours" is not shown, because the app
   cannot see the backend's grant schedule. When the balance is unknown,
   the section is hidden rather than showing a zero.
4. **The goal bar uses a display-only milestone ladder**:
   3 · 7 · 14 · 30 · 50 · 100, then every hundred. This is the one rule
   this page invents. Nothing is awarded at a milestone, and the backend
   has no goal concept.
5. **The line under the streak depends on today.** The design's
   "Continue demain pour atteindre 5 !" only reads right once today is
   played, so before that it says "Joue aujourd'hui…". A zero streak gets
   a start line. An unknown streak shows a dash, never zero.
6. **The Quêtes nav badge counts open quests.** It shows 1 while the
   daily challenge is unfinished, and nothing once it is done or
   unknown. The design's "3" counted quests that do not exist.
7. **The design's two week starts are kept.** The strip is Monday first
   (L…D) and the calendar is Sunday first (D…S). The design draws both
   that way.

## Consequences

- The page is complete for the data that exists. It grows when quest
  types, badges or a play-days endpoint do, and none of that needs a
  layout change, only more rows and cards.
- The header still leaves out the design's "2/3 quêtes" counter. With
  one quest it would always read 0/1 or 1/1.

## Revision — 2026-10-25: the whole design, on real data

Hafid's correction: build everything the design draws for Quêtes. The
first pass left things out because no system existed behind them. This
pass builds each of those systems on data the app already records,
instead of drawing the element empty.

- **Three daily quests** (`quest_board.dart`):
  - the daily challenge (backend);
  - "Résous 5 exercices" (`HomeStats` count today);
  - "Joue 10 minutes" (`HomeStats` play time today).

  Each completion is written once to `QuestLog` (`app_state`, per kid,
  never pruned).
- **Reward chips**: +15 / +15 / +20 XP, as drawn. The design's third
  reward is coins; that one is XP too, because no currency exists (#3).
  **The XP is not credited yet.** That needs the backend:
  `Platforms/BACKEND_WORKORDER_QUESTS.md` Q1.
- **Badge de la semaine**: 15 quests finished Monday to Sunday, counted
  from `QuestLog` and recorded as `week:<monday>` once reached.
- **Eight achievements**, the design's badge grid in its order:
  - Série de 3 jours and Série de 7 jours (streak);
  - Maître des quêtes (every quest done in one day);
  - Niveau 10 and Niveau 20 (the server level);
  - Toutes matières 50 % (the per-subject join);
  - 50 quêtes (the `QuestLog` total);
  - Explorateur (a skill played in each of the five subjects).

  They are recorded once and **never revoked**. "Réussites récentes"
  shows the newest five, with locked slots after them. Profil's badge
  grid shows all eight.
- **Streak rewards**:
  - the chest opens at 3 days;
  - "Gardien de la flamme" activates at 7 days and shows under the name
    on Profil;
  - the shield is the real freeze balance. "Rechargé dans N jours" needs
    the grant date (work order Q2).
- **Shared by the header, the nav badge and Village**: the "2/3 quêtes"
  pill, the badge counting open quests, and the Village panel and greeting
  all read the same `questBoardProvider`.
- **Still out**: the *Entre amis* tab (open item #12, Hafid's own ruling).

**Known limit**: all of this history is per device, like `played_date`.
Play on a second device does not count toward quests or badges until the
backend owns them.
