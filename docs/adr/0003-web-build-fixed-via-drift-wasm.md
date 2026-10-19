# ADR 0003 — Web build fixed via drift_flutter's WASM backend

Date: 2026-10-19
Status: accepted
Supersedes: ADR 0002

## Context

ADR 0002 scoped A7 to Linux desktop only because `database.dart` imported
`package:drift/native.dart` (`dart:ffi`/`sqlite3`) unconditionally, which
cannot compile for web. The fix it described — `drift_flutter` plus a
platform-conditional backend plus bundled WASM assets — was real, separate
scope, not started at the time.

## Decision

Wired `drift_flutter`'s `driftDatabase()` as the cross-platform entry point:

- `lib/data/local_db/database.dart`'s `openLocalDatabase()` now calls
  `driftDatabase(name: 'tutolys', web: DriftWebOptions(sqlite3Wasm: ...,
  driftWorker: ...))` instead of constructing `NativeDatabase` directly.
  `drift_flutter` picks `NativeDatabase` on desktop and a `WasmDatabase` on
  web itself — no platform conditional needed here.
- `LocalDatabase.memory()` (test-only) still needs a raw `dart:ffi`
  executor, which still can't compile for web. Split into
  `lib/data/local_db/memory_connection.dart`, a conditional-export barrel
  (`dart.library.ffi` → the real `NativeDatabase.memory()`; else → a stub
  that throws). `database.dart` only imports the barrel, never
  `drift/native.dart` directly, so the web target never sees the `dart:ffi`
  import at all.
- `sqlite3.wasm` and `drift_worker.js` (drift 2.35.2, matching
  `pubspec.yaml`'s pinned `drift`/`sqlite3_flutter_libs` versions) downloaded
  from drift's GitHub releases into `web/`, gitignored-binary-free (the repo
  tracks them directly, not a fetch script) since they're small, pinned, and
  reproducible from the same URL if ever lost.
- Dependency versions bumped to the matching set:
  `drift: ^2.35.2`, `drift_dev: ^2.35.1`, `drift_flutter: ^0.3.1`,
  `sqlite3_flutter_libs: ^0.6.0+eol` (up from 2.31.0/0.2.8/0.5.42 — `flutter
  pub add drift_flutter` initially resolved a much older `drift_flutter`
  that silently downgraded `sqlite3`, which would have mismatched the
  pinned WASM assets' version).
- Did **not** add COOP/COEP headers to `web/index.html`. Verified live
  (see below): without them, `drift_flutter` logs `Using
  WasmStorageImplementation.sharedIndexedDb due to missing browser
  features: {MissingBrowserFeature.dedicatedWorkersInSharedWorkers,
  MissingBrowserFeature.sharedArrayBuffers}` and works anyway — OPFS is an
  optimization, not a requirement. Revisit only if a later perf issue
  traces to storage, not preemptively.

## Verification

- `flutter analyze`: 0 issues.
- Full suite: 97 app tests, 33 `engine_sdk`, 27 `engines_core` — all pass,
  no regressions from the drift 2.31.0 → 2.35.2 jump.
- `flutter build linux --debug`: still compiles clean (no desktop
  regression from the dependency bump).
- `flutter build web`: compiles clean, `sqlite3.wasm`/`drift_worker.js`
  present in `build/web/`.
- Live boot check: served `build/web` statically (not `flutter run
  -d web-server` — see pitfall below) and loaded it in a real browser tab.
  Confirmed via console log and DOM inspection, not a screenshot (the
  sandbox's compositor wasn't available this session): `flt-glass-pane`
  mounted, tab title changed to "TutoLys" (set by the running app, proof
  `main()` executed), zero console errors, and the
  `WasmStorageImplementation.sharedIndexedDb` log line above confirms the
  database opened successfully. Did not go further — no backend was
  running, so the pairing → path → play flow wasn't exercised live this
  round.

### Pitfall: `flutter run -d web-server` hangs with no visible error

`flutter run -d web-server`'s debug build never calls the app's `main()`
until a DWDS debugger handshake completes — normally driven by the Dart
Debug Chrome Extension. Without that extension (true of any plain
automated browser), the page loads every script successfully, zero console
errors, `window.$dartRunMain` is defined but never invoked — and it just
sits there forever looking like a silent hang. `flutter build web` +
serving the static output has no such gate; `main()` runs immediately.
Use the static build for any automated/headless boot check; reserve
`flutter run -d web-server` for interactive debugging with the extension
installed.

## Consequences

- `CLAUDE.md`'s "Flutter: web + Linux desktop" line is accurate again.
- `LocalDatabase.memory()` (tests) still can't run on a web test target —
  unaffected in practice, since all existing tests run on the VM.
- Next real gap: the live pairing → path → play flow on web has only been
  exercised through the automated widget tests, not a real backend. Worth
  doing before calling A7-on-web load-bearing for anything beyond "it
  boots."
