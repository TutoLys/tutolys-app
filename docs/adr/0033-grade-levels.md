# ADR 0033 — Levels 1–99 per school year, from skills completed

Date: 2026-10-25
Status: accepted (app side); the server side is the backend session's

## Context

Hafid's decision, 2026-10-25:

> Levels 1–99 per school year, level = 1 + floor(98 × completed skills /
> all skills of the kid's grade), 99 only when every skill is done, restart
> at 1 for a new grade, XP stays as points only.

Before this, the level was the server's XP curve (backend ADR 0024, flat
100 XP per level). It measured how much the kid had played, not what they
had learned, and it lagged until `award_xp` ran.

## Decision

- **The formula** is `gradeLevelFor(completed, total)` = 1 + ⌊98 ×
  completed ÷ total⌋. 99 needs every skill; one short is 98. Grade 1 has
  ~526 skills, so six completed skills reach level 2. Progress toward the
  next level is the fractional part of 98 × completed ÷ total.
- **A skill counts as completed** when every lesson on it is finished. This
  is the backend's rule, applied on the device to the per-exercise
  completion record against the lessons the Carte serves (one per
  `lesson_group`, in the subject's language). It's the same local measure
  as ADR 0032, at value 1. Mastery plays no part.
- **Local-instant, server-authoritative, monotonic** (`mergeGradeLevel`):
  - *Denominator*: the server's `skills_total` when known. The device
    caches only the subjects it has synced, so its own count can be short,
    and a short denominator inflates the level. Otherwise it uses the
    larger of the device's count and the last server total it saw, kept
    per kid and grade.
  - *Completed*: whichever of device and server counts more.
  - *Level*: the largest of the formula, the server's level, and the
    highest level already shown in this grade. That high-water mark is
    stored per kid **and per grade** in `app_state`
    (`grade_level.<grade>.high`), so a new grade starts again at 1 without
    any reset step. A level held up by the mark shows no progress toward
    the next one, rather than an invented bar.
  - It recomputes the moment a lesson ends (it listens to the local
    measure) and on every server read.
- **An older backend's level is ignored.** It sent an XP level under the
  same `level` key. The payload's `skills_total` marks the new meaning, so
  without it the server level isn't trusted and the device's own level
  shows.
- **Display**: the header pill and Progrès show "Niv. N", with a track
  toward the next level. The pill's tooltip names the skills ("33 notions
  réussies sur 526 en 1re année"), no longer XP. Profil and Progrès keep
  XP as points under the level. XP still shows on the celebration and in
  quests, but no longer drives anything.
- **Everything reading `ProgressState.level` follows**: the avatar unlocks
  at levels 2/3/5/10/20, and the level achievements. Unlocks are recorded
  once and never revoked (ADR 0024), so a new grade restarting at 1 takes
  nothing away.

## Not done

- **The exact server payload** isn't final; the app parses `level`,
  `skills_completed` and `skills_total` from `/api/v1/me/progress`, as the
  backend announced. Until it lands, the level is the device's own.
- **Denominator check**: the device counts `skill_node_cache` at the kid's
  grade, which the curriculum endpoint fills with the grade's leaves. The
  backend counts every live leaf with a marker for that grade. These
  should agree; when they don't, the server's total wins as soon as it is
  read.
