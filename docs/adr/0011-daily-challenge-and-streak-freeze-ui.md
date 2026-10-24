# ADR 0011 — Daily challenge and streak-freeze UI

Date: 2026-10-24
Status: accepted

## Context

The app side of the two new gamification mechanics the backend/telemetry
now compute (`tutolys-backend` ADR 0019, `tutolys-telemetry` ADR 0007):
a daily "N correct in a row" challenge, and a limited, earnable streak
freeze. Both read through the same `GET /api/v1/me/progress` call the
app already makes — no new network surface needed on this side.

## Decisions

**Both are purely additive to `ProgressSnapshot`/`ProgressState`** —
`freezesAvailable`/`dailyQuest`, both nullable, both following the same
"null means unknown, never a fabricated number" convention
`currentStreakDays` already established. Neither field exists on the
offline path (`ProgressOffline`'s local `StreakLocal` estimate has no
opinion on either), which falls out naturally from leaving them at their
`null` default rather than inventing an offline estimate for either.

**Daily challenge gets its own card on Home, gated on `dailyQuest !=
null`** — same "no card at all for nothing real to show" pattern
`ProfileScreen`'s own `_ProgressSummary` already uses, not a fabricated
"0/3" for a kid who hasn't been read yet. The target is never hardcoded
in the widget — it's whatever `DailyQuestDto.target` says, which traces
back to the backend's own `settings.DAILY_QUEST_TARGET`.

**Freeze balance is a small line inside the existing `ProfileScreen`
progress card, not a new card of its own** — it's a supporting fact
about the streak directly above it, not an independent achievement
worth its own visual weight. Shown only when `freezesAvailable != null`,
same unknown-vs-zero distinction as every other number on this screen.

## Verified

9 new widget tests: `test/progress_controller_test.dart` (freeze
balance and daily quest pass through from a real fetch; offline has no
opinion on either), `test/home_screen_test.dart` (no card when nothing
to report, in-progress wording vs. the completed message), `test/profile_screen_test.dart`
(freeze balance line shown with a real value, absent when unknown).
`flutter analyze`: 0 issues. Full suite: 151 passed (was 144).

Attempted a live browser check (`flutter build web` + static serve,
same recipe as every prior UI change this session). Same
sandbox-compositor limitation already documented in ADR 0003/0008/0010
— assets load clean, zero console errors, `flt-glass-pane` never
composites a frame in this specific sandbox. Not claimed as visually
verified; the widget tests above are the real verification.

## Not done

No settings/customization surface for either — the daily-challenge
target and freeze grant/cap are entirely backend-owned config, the app
just displays whatever it's told. No animation or celebratory moment
when the challenge completes or a freeze gets spent — both render as a
plain state change, consistent with this app's "visual layer only, no
unearned flourish" scope elsewhere (ADR 0004).
