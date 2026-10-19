# ADR 0002 — A7 ships for Linux desktop only: web doesn't compile with the real database wired in

Date: 2026-10-18
Status: accepted

## Context

A7's thin slice (per `docs/a7-skill-path-plan.md`) required actually opening
`LocalDatabase` at app startup and wiring `CurriculumSync`/`ContentSync`/the
telemetry outbox into the running app — before this, nothing in `lib/`
outside test files ever constructed a real `LocalDatabase`; `openLocalDatabase()`
existed but was called from nowhere reachable by `main()`.

Doing that surfaced a real compile-time break on web: `database.dart` uses
`package:drift/native.dart`, which pulls in `dart:ffi` and `package:sqlite3`
— neither of which can compile for a web target at all (confirmed:
`flutter run -d web-server` fails with dozens of "Only JS interop members
may be 'external'" errors across `sqlite3`'s FFI bindings). This is not new
in this round — `database.dart` has imported `dart:io`/`drift/native.dart`
since it was first written — but nothing before A7 ever imported it from a
reachable path in `main.dart`, so the web target had simply never been
asked to compile it.

`flutter build linux --debug` compiles cleanly with the same code.

## Decision

A7 ships for Linux desktop only this round. Web is a known, tracked gap,
not silently broken: this ADR exists specifically so the next session
doesn't have to rediscover it from a confusing compile failure.

Fixing it for real means wiring `package:drift/wasm.dart` with a
platform-conditional `openLocalDatabase()` (`dart.library.io` →
`NativeDatabase`, web → `WasmDatabase`), plus bundling the required
`sqlite3.wasm` and a drift worker script as new `web/` assets — real,
separate scope, not a one-line patch. Not started this round.

## Consequences

- `CLAUDE.md`'s "Flutter: web + Linux desktop" line is now only half
  accurate for anything touching local storage — curriculum sync, exercise
  caching, and telemetry all require the database, so none of them (and
  nothing built on top of them, including A7's path screen) currently
  compiles for web. Pairing-only screens that never imported `database.dart`
  were never affected and still would compile standalone, but the app as a
  whole no longer does from `main.dart` on web.
- Confirmed via `flutter build linux --debug` only — no display server was
  available in this session to visually click through the running Linux
  binary. The automated test suite (97 tests, including a real widget-level
  test driving path → tap → play navigation through the production
  provider graph with only the network/API layer faked) is real coverage of
  the feature logic, but is not a substitute for that visual check.
- Next action on this thread, if web is wanted: wire the WASM backend
  (above), then re-run this exact verification (`flutter build web`, then a
  real click-through) before trusting it.
