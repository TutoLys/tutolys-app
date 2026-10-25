# ADR 0042 — speed_tap is untimed by default; a countdown is for diagnostics

Date: 2026-10-25
Status: accepted
Amends ADRs 0005 and 0022 (speed_tap's countdown).

## Context

Hafid played a speed_tap lesson (3 + 3) and got "Temps écoulé ! … a fresh
countdown starts". His call: "Can we remove the timing in the exos? It
does not make any sense… leave it but only when the question is for a
test (diagnostic). Regular lessons do not need this."

A grade-1 child who can't add 3 + 3 in eight seconds isn't helped by a
clock. The countdown measured speed in lessons that are meant to teach.

## Decision

- **`time_limit_ms` is optional.** Absent, `null` or `0` all mean
  **untimed**: no `CountdownBar`, no timeout, no "Temps écoulé !", and no
  `time_expired` event. The question plays as a single choice answered by
  tapping. A tap is still the answer (`SubmitMode.immediate`), because the
  descriptor's submit mode can't vary by content. A lesson that wants
  select-then-VALIDER uses `mcq`.
- **Timed play stays, unchanged**, when the field is set (1000–60000 ms),
  but **only for diagnostic tests**. No diagnostic lesson type exists yet,
  and per Hafid none is invented here: every regular lesson omits the
  field. The backend validator warns when it's set (backend ADR 0051), so
  a timed regular lesson can't slip in unnoticed.
- `TimedChoiceState.timed` comes from the content, at initialize and at
  restore, never from the snapshot. The reducer can't see the content,
  and a stray `TimeUp` on an untimed question must do nothing; the test
  caught that the first version still honoured one.
- **No other engine has a countdown.** `CountdownBar` is used only by
  `speed_tap`. The legacy `SpeedTapEngine` (the old `TutolysEngine` path)
  still requires a limit, but serves nothing: the new registry always
  handles `speed_tap`.

### Older apps: the floor must rise

Today's app, and every earlier build, **refuses** speed_tap content
without `time_limit_ms` as invalid. So once lessons drop the field, an
older app can't play them. That is exactly what `min_app_version` is for
(backend ADR 0037). It has to happen in order:

1. **App session:** bump the app's version (`appVersion` in
   `lib/features/pairing/pairing_controller.dart`, now `0.1.0`, plus
   `pubspec.yaml`) to `0.2.0` in a build that contains this change. Today
   every build reports 0.1.0, so a floor can't tell old from new.
2. **Backend session:** set `Engine(speed_tap).min_app_version` to
   `0.2.0`.
3. **Questions Maker:** strip `time_limit_ms` from every regular lesson
   and re-import.

Raising the floor before step 1 would make every current build,
including the new one, refuse speed_tap entirely. Requested from the
app and backend sessions via the manager.

## Verification

- engines_core 174 → 176:
  - parse: absent, 0 and null are untimed; a set limit is still bounded;
  - in the real shell: no `CountdownBar`, 30 s pass with nothing timing
    out, wrong → retry → right → "Bravo !", no `time_expired` in the
    outbox;
  - a stray `TimeUp` does nothing.

  The existing timed tests ("Temps écoulé !" → a fresh countdown) still
  pass, unchanged.
- Analyze is clean.
