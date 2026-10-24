# ADR 0009 — A capacity ceiling on the local outbox

Date: 2026-10-23
Status: accepted

## Context

`GO_LIVE_CHECKLIST.md` Track E's last item: "No cap on local outbox
storage growth if the backend is unreachable for an extended period."
`OutboxFlusher`'s own class doc states an unconditional contract: **"never
drop an event silently."** Those two things are in direct tension — any
cap that evicts data is, definitionally, dropping it. This is why the
item was left alone in the first pass on this track (see ADR 0008): it
isn't a default an engineering session gets to make unilaterally. Hafid
asked for it explicitly afterward — this ADR is that decision, recorded.

## Decisions

**"Never silently" becomes "never unaccounted."** The resolution isn't a
loophole around the existing principle, it's a deliberate, narrow
amendment to it: data can be evicted past a ceiling, but the fact that it
happened, when, and how many rows — never can be. That distinction is
the entire design. `OutboxFlusher`'s own doc comment, `stuck()`'s doc
comment, and `DriftEventOutbox.enforceCapacityCap`'s doc comment were all
updated to say this explicitly, not left stale.

**Default ceiling: 10,000 undelivered rows** (`OutboxFlusher.maxOutboxRows`).
Provisional, like every other numeric default added this session
(`MASTERY_REFRESH_INTERVAL_MINUTES`, the rate-limit's 60/min) — not a
number from the plan. Chosen to sit well above any realistic multi-week
outage (the backoff schedule's own ceiling is ~8.5 minutes between
retries, not the growth problem) and exist only for the pathological
case: a device sitting unreachable for the better part of a year.

**Eviction is oldest-first, tracked in `AppStateTable`** (the same
key/value store `HomeStats`/`StreakLocal` already use) — a cumulative
`dropped_total` counter and a `last_dropped_at` timestamp, both exposed
through a new `OutboxHealth.droppedForCapacity`/
`lastDroppedForCapacityAt`, which also now flips `isHealthy` to `false`.
A device that has ever hit this ceiling is noteworthy and worth
surfacing — the same reasoning `stuck` already gets for a different
failure mode.

**Checked in `flush()`'s `finally` block, not nested in the
`UploadProcessed` success case `pruneDelivered()` lives in.** This was
the one real bug risk in the whole feature, found by thinking through the
scenario rather than by a failing test: the exact situation this cap
exists for — *sustained* offline, every tick landing on `UploadOffline`
— never reaches the success branch at all. A cap nested there would have
silently never fired during the one scenario it was built for. `finally`
runs on every call to `flush()`, success or not.

**Enforced even while paused.** `_paused` (set on a 401 — device
credential revoked) used to be an early-return guard *before* the `try`
block, which would have also skipped `finally`. Moved the pause check
*inside* `try` instead: a kid can keep playing while a device's
credential sits revoked (`PlayScreen` writes to the outbox regardless of
pairing state), so the cap still has to run even when uploads are
halted.

## Verified

7 new tests (`test/outbox_test.dart`, "capacity cap" group): no eviction
under the ceiling, oldest-first eviction down to exactly the ceiling, an
eviction is counted and timestamped, the counter accumulates correctly
across repeated evictions (not reset), `flush()` enforces the cap on a
real `UploadOffline` outcome — the scenario-correctness test, proving the
`finally`-placement decision rather than just asserting it — `flush()`
enforces the cap while paused, and `isHealthy` turns `false` once an
eviction has happened. Full suite: 139 passed (was 132), `flutter
analyze` clean.

Live-verified with the real production classes — real `OutboxFlusher`,
real `DriftEventOutbox`, real `TelemetryApi`/`Dio` — pointed at an
unreachable address (a real connection failure, not a fake
`UploadOffline`): 50 queued events, `maxOutboxRows: 20`, one
`flushNow()` call. Depth went to exactly 20, `capacityDropStats()`
reported `totalDropped: 30` with a real timestamp, and `health.isHealthy`
was `false` — all from one real flush against a real failing connection,
not mocked.

## Not done

No UI surfaces `droppedForCapacity` yet (it's exposed through
`OutboxHealth`, which nothing in the app currently reads for display —
the "active"/"done" path-node states and a reward system are still the
same open product-decision items they were before this). No byte-size-
based cap, only row-count — simpler to reason about and query, judged
sufficient for a "protect against the pathological case" ceiling rather
than a precise storage budget.
