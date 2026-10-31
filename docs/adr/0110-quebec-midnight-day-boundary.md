# ADR 0110: The day ends at midnight in Québec (K8)

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/ux-review/kid-app.md` K8; Hafid's ruling relayed by the
  Manager (« YES apply »)

## Context

At 20:05 EDT the review saw « 3 bonnes réponses de suite » go from 3/3 back to
0/3, while « Résous 5 exercices » and « Joue 10 minutes » kept their progress.
The daily challenge comes from the backend, whose day is UTC (GO_LIVE open
question #8), so it rolls over at 20:00 in summer and 19:00 in winter. The two
local quests rolled over at the device's midnight. A child saw a quest they
finished at supper undo itself.

## Decisions

1. **One day, Québec's.** `core/time/quebec_day.dart` gives `quebecNow`,
   `quebecToday` and `quebecIsoDay`. Every local day key uses it: today's
   counters (`HomeStats`), played days and the offline streak
   (`StreakLocal`), the cached progress's daily quest (`ProgressCache`), the
   week strip and weekly badge (from `StreakLocal.today()`), and the inbox's
   `daily_quest:<day>` key. A device set to another zone still counts Québec
   days.
2. **The rule is written out**, not loaded from a tz database: UTC−5, and
   UTC−4 from the second Sunday of March at 2:00 to the first Sunday of
   November at 2:00. One zone doesn't justify the data; a rule change would
   need an app update either way.
3. **A quest finished today stays finished until Québec's midnight**
   (`keepDoneToday`). `QuestLog` already records each completion by day, so
   the board shows a recorded quest as done even when its source has rolled
   over. That fixes what the child sees now, before the server moves.
4. **Reminders keep the device's clock.** A reminder is set for 17:00 where
   the device is, which is what a parent means.

## Server side (asked of Backend and Telemetry, via the Manager)

The daily challenge, streak days, freeze days and the `daily_quest:<day>` and
`streak_freeze:<day>` notification keys are all still UTC days. Until they
move to America/Toronto:
- between 20:00 and midnight the server starts a new challenge for "tomorrow",
  and a challenge finished then also counts for the next Québec day;
- a lesson played after 20:00 counts toward the next day's server streak.

The inbox matches both the Québec and the UTC day key until then.

## Consequences

- `quebecNow` returns Québec's wall clock in a local `DateTime`. It is for
  calendar days only, never for measuring durations.
