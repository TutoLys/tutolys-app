# ADR 0015 — Quêtes: only the parts of the design that have real data

Date: 2026-10-24
Status: accepted

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
