# tutolys-app

Kid-facing TutoLys app. One Flutter codebase for desktop, mobile and web.

> The app knows nothing about organizations, billing or tutors. A kid is a kid.

## Running

```bash
flutter pub get
flutter run -d chrome                      # web
flutter run -d linux                       # desktop (see prerequisites)
flutter test
```

The backend address defaults to `http://127.0.0.1:8000` (the dev-stack).
Override it at build time:

```bash
flutter build web --dart-define=TUTOLYS_API_BASE=https://api.tutolys.ca
```

### Linux desktop prerequisites

```bash
sudo apt install clang ninja-build libgtk-3-dev libsecret-1-dev
```

`libsecret-1-dev` is easy to miss: the Flutter toolchain check passes without
it, and the build only fails at CMake time. It is needed because the device
token is stored in the real system keyring via `flutter_secure_storage`, and
libsecret *is* the Linux keyring. That is the point — a long-lived credential
on a child's device does not belong in shared preferences.

Web builds need nothing extra.

## Layout

```
lib/
  core/      theme wiring, i18n, routing shell, responsive helpers
  features/  pairing, path, play, settings
  data/      api clients, local storage, sync
packages/
  design_system/  brand tokens, themes, shared widgets — Flutter only
  engine_sdk/     the engine contract: registry, context, telemetry client
  engines_core/   the launch engines
```

**The dependency rule that pays for itself:** engines depend on `engine_sdk`
and `design_system` only — never on the app, the API client or the database.
The Godot games had that property (they held no credentials and never talked to
Django) and it is worth keeping.

## Local data and sync

The outbox is **not a cache — it is the write path**. An event counts as logged
only once it is on disk, because buffering in memory and flushing on a timer
loses the last minute of play on every kill, and the end of a session is
exactly where the interesting signal is.

```
engine  ->  TelemetryClient  ->  EventOutbox (drift, on disk)
                                      |
                              OutboxFlusher  ->  telemetry service
```

- **Exactly once, not at least once.** Events carry a client-generated
  `event_id`; the server dedupes on it and reports `duplicate` rather than an
  error, so a retry after a lost acknowledgement is safe and clears the local
  row instead of looping forever.
- **50 events or 30 seconds**, one batch per flush. Draining everything in a
  loop would mean a device returning from a week offline blocks startup.
- **Backoff differs by cause.** Losing Wi-Fi is not the events' fault and fixes
  itself, so it retries on a flat short window; a server error escalates
  exponentially. Both are jittered, so a classroom that lost Wi-Fi together
  does not retry in lockstep.
- **Per-event backoff**, so one permanently-rejected event cannot hold up
  everything queued behind it.
- **Nothing is ever dropped silently.** An event the server will never accept
  is surfaced through `stuck()`, not deleted. The product is the data.
- **A revoked credential pauses the flusher** rather than spinning against a
  token that cannot work.

## Content sync

```
backend manifest  ->  diff by content_hash  ->  fetch only what changed
                                                      |
                                           verify checksum  ->  atomic swap
                                                                     |
                                                            exercise_cache
```

- **Diff by checksum.** Only exercises whose `content_hash` moved are
  downloaded. The predecessor seeded its ETag from a *global* aggregate, so one
  leaf edit anywhere re-downloaded the whole tree for every child on mobile
  data.
- **Verify before accepting.** Every envelope is re-hashed and compared with
  the manifest. Content that does not match is refused, never cached — a kid
  must never be shown content we cannot vouch for. The old backend had no
  integrity guarantee on content at all.
- **Atomic swap.** The cache moves forward in one transaction, so a sync that
  dies halfway leaves the previous content intact and playable instead of a
  half-written mixture.
- **Offline is not an error.** An offline sync leaves the cache untouched and
  cached content stays playable — that is the whole point of caching it. Only a
  server rejection is treated as a problem.

`content_hash` is a **cross-language contract**: Python computes it, Dart
re-computes it to verify. The rules (sorted map keys, preserved list order, no
whitespace, literal non-ASCII) are documented in `content_hash.dart` and pinned
by a test against a hash produced by the real backend. If the two ever diverge
every download looks corrupted and sync never converges.

Timestamps are stored as ISO-8601 text (`build.yaml`), not drift's default unix
seconds: second granularity would make the order of events logged in the same
second undefined, and that order is what lets a report reconstruct the attempt
sequence.

Run `dart run build_runner build` after changing the schema. Generated files
are committed, so a clean checkout builds without codegen.

## Things that are deliberate

- **French first.** `fr-CA` is the default locale, not a fallback. A missing
  French string is a bug.
- **One widget tree per screen**, with breakpoints. Presentation adapts;
  logic is never forked per platform.
- **Pairing errors are specific.** "No internet" and "wrong code" get different
  words — a child told the code is wrong when the Wi-Fi is off will retype a
  code that was never the problem.
- **Offline never un-pairs the device.** Only a server rejection does. Dropping
  the credential on a Wi-Fi blip would force a parent to generate a new code
  every time and would break offline play.
- **Reduce-motion is honoured.** The mascot stops breathing when the platform
  asks for less motion — an accessibility requirement, and the reason widget
  tests can settle at all.
- **Only the code alphabet is accepted** in the pairing field. A mistyped `O`
  or `1` visibly does not appear rather than being silently remapped.
