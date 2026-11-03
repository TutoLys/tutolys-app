# ADR 0117: The personal league and the effort line

- Status: accepted
- Date: 2026-11-03
- Source: Hafid's go (2026-11-03), relayed by the Manager; the contract is
  backend ADR 0207 (`6ee8625`, `59e7921`)

## Decisions

1. **Progrès gets one « Cette semaine » card, above the subject pills**
   (`WeeklyLeagueCard`). It is the page's only cross-subject card, and it
   shows:
   - the division's medal and name, « Ligue Argent »;
   - the week's XP;
   - a bar to the next division's goal and « Encore 28 XP pour Or », or
     « Objectif atteint : tu passes en Or lundi ! » once the goal is met;
   - one effort line;
   - « Nouvelle semaine dans N jours ».

   At Diamant there is no next goal and no bar, just « Tu es au sommet ».
   The goals come from the payload and are never hardcoded.
2. **The effort line is good news or the kid's own progress, never a
   comparison downward.**
   - A served percentile wins: « Plus d'XP que 78 % des élèves de
     1re année qui ont joué cette semaine ». The backend's cohort counts
     only kids who played that week, so the sentence says so.
   - With no percentile, the kid is measured against their own last week.
     « +N XP de plus que la semaine passée » appears only once this week is
     ahead, because last week was a whole week and this one isn't over.
   - Otherwise it reads « N XP cette semaine, continue ! », or « Nouvelle
     semaine, nouveau départ ! » at zero.

   A test scans every league string in both languages for downward words.
3. **The card never shows other kids.** No names, no ranks, no list. The
   percentile is the only number about other children. It is shown only
   when served, which happens only at or above the median, and only from a
   fresh read: a cached one would be a claim about other kids that nobody
   re-checked. The cached league does stand in when a read fails.
4. **Profil is unchanged**, the Manager's call. The percentile appears only
   on Progrès.
5. **A promotion is announced once, in two places:**
   - **The celebration:** the next finished lesson shows
     `LeaguePromotedRow`. `LeagueCelebrations` records the last week
     celebrated per kid, so each promotion shows once. The medal pops in,
     or sits still under reduced motion.
   - **The bell:** a local notification of the backend's own type
     `league_promoted`, keyed `league:<week_start>`, written by the quest
     board.

   A served promotion maps to the same key. The weekly job writes it after
   the judged week ends, so the key's week is the Québec week before its
   `created_at`. The served item carries only a French message, so the
   bell gives it a general line in the reader's language.
6. **Placement, holding and demotion are never announced.** After a drop,
   the card just shows the current league, and at zero XP « Nouvelle
   semaine, nouveau départ ! ».
7. **When the week ends:** `week_end` when served, otherwise `week_start` +
   7 days at Québec midnight, counted in calendar days.

## Consequences

- No live percentile can be checked yet, because no grade has 50 players.
  Tests cover it: the card, the text in both languages, and the
  cache rule.
- The medal is drawn, not illustrated (a coloured disc with a medal icon).
  Bronze is a warm brown, and Diamant uses the design's blue. A test checks
  that no medal is red.
