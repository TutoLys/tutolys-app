# ADR 0100 — A QA lesson picker, never in a release build

Date: 2026-10-29
Status: accepted

## Context

A fresh kid can only open the Carte's frontier, so reviewers couldn't
reach pair_match, speed_tap, the creation lessons or pattern invent on
:8080. The Manager asked for a picker, in profile and debug builds only.

## Decision

- `qaToolsEnabled = !kReleaseMode && bool.fromEnvironment('QA_TOOLS')`.
  It's a `const`, so a release build compiles the picker out whatever its
  defines. A profile build turns it on with **`--dart-define=QA_TOOLS=true`**.
- **The way in:** the technical log (long-press in À propos) gets « QA ·
  lessons ». Without QA tools there's no button and no route.
- **The list:** every published lesson at the kid's grade, from the stored
  manifests (ADR 0095), downloaded or not, by subject, then engine, node
  and rank. A subject's manifest is stored once the Carte has opened it,
  or after the first online load's background prefetch of the others.
- **Playing:** downloads the leaf first if it's outside the offline
  window, then plays through `/play` as **practice** (ADR 0098). Nothing
  reaches telemetry, the Carte, XP, quests or the streak, so the paired
  kid's real data stays clean.
- English-only labels: a tool for reviewers, not a screen a child sees.

## Consequences

- Tests: `qaToolsFor` is false for every release build; the log has no
  entry without QA tools; with them, every lesson is listed by subject and
  engine.
- Reviewers can play any engine on :8080 once the preview build adds the
  define.
