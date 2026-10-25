# ADR 0020 — The outbox flusher follows the active kid

Date: 2026-10-25
Status: accepted

## Context

The Phase 2 live check (ADR 0019) found that **no play event ever reached
telemetry**. A kid was paired and played; after a reload restored them, 40
seconds passed and nothing was posted to `/v1/events/batch`. The events
were on the device, queued under the kid's own outbox scope.

The cause was two decisions that were each right on their own:

- ADR 0007 had `AppShell.initState` read `outboxFlusherProvider` **once**
  and start it, keeping the instance in a field because `ref` is unusable
  in `dispose()`.
- ADR 0014 made the outbox per kid. `eventOutboxProvider`, and therefore
  `outboxFlusherProvider`, rebuild whenever the active kid changes.

`initState` runs before the session restores (restore is a post-frame
callback). So the flusher it captured was always the one for
`unpairedKidId`, an outbox scope no row ever has. That flusher ticked every
30 s for the whole run and found nothing. The kid's flusher was built when
the kid became known, but nothing ever started it. The same happened after
pairing during a run.

So since ADR 0014, **every event on every platform stayed on the device**.
Mastery, streaks, XP and reports have had no new device data since then,
apart from what tests and manual `curl` injected.

The existing wiring test didn't catch it. It overrides both
`eventOutboxProvider` (fixed to one kid) and `outboxFlusherProvider`, so
the active kid never changes underneath `AppShell`. That is the one
situation the bug needs.

## Decision

- **`AppShell` follows the provider instead of capturing it.** It uses
  `ref.listenManual(outboxFlusherProvider, fireImmediately: true)`: stop
  the previous flusher, keep the new one in the field (still needed for
  `dispose` and the lifecycle `flushNow`), and start it. This is the same
  "hold it in a field" reasoning as before, with the field now kept
  current.
- **The provider stops what it replaces** (`ref.onDispose(flusher.stop)`),
  so an old kid's flusher can't keep ticking against a scope nobody writes
  to.
- **New `telemetryApiProvider` seam**, so a test can fake the network
  while the real outbox and flusher providers do the kid scoping. Named
  `OutboxFlusher.defaultInterval` (30 s, unchanged) for tests to step past.

## Verification

- **Two new tests** in `pairing_test.dart` use the real providers and only
  a fake server. One covers a kid restored at launch, the other a kid
  paired during the run. Both failed before the fix with nothing
  delivered, and both pass after it. The full app suite passes (358).
- **Live, against the dev-stack:** the same browser as ADR 0019, rebuilt
  and reloaded with the kid restored. Within one interval it sent
  `POST /v1/events/batch → 200` with `accepted: 5, rejected: 0`. Those
  were the five events from the earlier live play, stuck on the device
  until now.

## Consequences

Events queued on any device since ADR 0014 will upload on its first launch
with this build: the outbox kept them, as designed. A large backlog uploads
50 per 30 s tick. That is slow but correct, and capped by ADR 0009's 10k
eviction rule.
