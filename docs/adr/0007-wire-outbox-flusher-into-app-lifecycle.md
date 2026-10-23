# ADR 0007 — Wire OutboxFlusher into the running app

Date: 2026-10-23
Status: accepted

## Context

`Platforms/GO_LIVE_CHECKLIST.md`'s own headline finding: `OutboxFlusher`
(`lib/data/sync/outbox_flusher.dart`) was fully built and exhaustively
unit-tested (`test/outbox_test.dart` — durability, backoff, pause/resume,
batching) but never instantiated anywhere in the running app. No `Timer`,
no background isolate, nothing called `start()`/`flushNow()` outside the
class's own test file. Every feature built on telemetry aggregates
(mastery, streaks, reports, the §5.9 analytics engine) has therefore never
received real data outside one manual test session.

## Decisions

**`AppShell` owns the flusher's lifecycle**, not a lower-level screen. It's
the one widget that already exists for the app's whole lifetime (it's the
root switch on pairing status), so it's the natural place to start a
process-lifetime background task — a single `OutboxFlusher` instance per
app run, not one per screen.

**Started unconditionally on boot, before pairing status is even known.**
`OutboxFlusher.flush()` already no-ops when `accessToken()` returns null,
so starting early just means the timer is already ticking the moment
pairing succeeds rather than missing the first interval.

**`flushNow()` on app background/close** (`AppLifecycleState.paused` /
`.detached`, via `WidgetsBindingObserver`) — the last events of a session
are the most interesting ones (an abandoned exercise, a run of wrong
answers), so they must not wait for a timer tick that may never come.

**`resume()` on every transition into `SessionStatus.paired`**, via
`ref.listen` in `build()`. `_paused` is only ever set by an `UploadUnauthorized`
response — the device token itself was revoked — and the only thing that
ever replaces a device token is a fresh `pair()` call. Listening for the
paired-transition rather than threading a call through
`SessionController.pair()` directly avoids a circular import
(`outbox_flusher_provider.dart` already depends on `pairing_controller.dart`
for `sessionControllerProvider`), and `resume()` is idempotent, so calling
it on every paired-transition (including a plain restore-on-launch) is
harmless.

**The flusher instance is captured once in `initState`, not re-read via
`ref` in `dispose()`.** Riverpod raises `StateError` on `ref.read` during
unmount ("using ref when a widget is about to or has been unmounted is
unsafe") — found by actually running the existing app-shell tests against
this change, not by inspection.

**A new `eventOutboxProvider`/`telemetryDioProvider`/`outboxFlusherProvider`**
in a new `lib/data/sync/outbox_flusher_provider.dart`, same `Provider`
(not `autoDispose`) + dart-define pattern `apiBaseUrl`/`dioProvider` already
use for the backend. Telemetry is a separate deployment (`:8001` in dev),
so it gets its own `TUTOLYS_TELEMETRY_BASE` dart-define rather than reusing
the backend's. `play_screen.dart`'s own `DriftEventOutbox` construction was
switched to the shared `eventOutboxProvider` for consistency — it's stateless
aside from the database handle, so there is no correctness reason to keep
two separate instances.

**A new `outboxFlusherAutoStartProvider`**, same idiom as the existing
`sessionAutoRefreshProvider`: production always starts the flusher, but an
armed periodic timer fails `flutter_test`'s pending-timer check. Existing
`pairing_test.dart` "app shell" tests override it to `false`, same as they
already do for the session auto-refresh timer.

## Verified

A new widget test (`outbox flusher wiring` group, `pairing_test.dart`)
deliberately leaves `outboxFlusherAutoStartProvider` at its real default
and overrides `outboxFlusherProvider` with a short-interval instance
pointed at a recording fake server — proves `AppShell` itself starts the
flusher and that a queued event uploads with zero manual intervention,
which is the exact gap this ADR closes (`outbox_test.dart`'s existing
tests only ever drove `OutboxFlusher` directly, never through the app).

Separately, live-verified against a **real** `dev-stack` — real pairing
exchange, a real `TelemetryClient`-written event, a real `OutboxFlusher`
call against the real telemetry service on `:8001`, no fakes anywhere in
the chain — then confirmed directly in TimescaleDB:

```
SELECT event_id, event_type, kid_id, event_ts FROM play_event WHERE event_id = '...';
 7fe51f3b-... | session_start | d5581262-... (Yelhan) | 2026-10-23 23:55:38...
```

Full suite stays green: 125 app tests (124 + the new wiring test),
`flutter analyze` clean.

## Not done

Retry/backoff behavior itself, pause-on-401, batching — all already
covered by `outbox_test.dart`, untouched here. No change to the outbox's
write side (`TelemetryClient`) or to telemetry's ingest endpoint. The
telemetry retention migration staying `.disabled` (Track B, separate open
item) is now more urgent than before this ADR — `play_event` will actually
start growing for real.
