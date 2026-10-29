# ADR 0099 — The local store after an upgrade: a fresh worker, and say "storage"

Date: 2026-10-29
Status: accepted (UX review K5, raised to P1)

## Context

In a browser profile carried over from older :8080 builds, boot fails
with `[boot:db_open] DriftRemoteException: TypeError: Failed to fetch`.
The Carte then says « Connecte-toi à Internet » while the network is
fine, and refetches the tree. A fresh profile works. A family's browser
would hit the same thing after we ship an update.

### What was checked, in that browser (2026-10-29)

- No service worker is registered and Cache Storage is empty, so a stale
  SW cache isn't the cause.
- `sqlite3.wasm` and `drift_worker.js` both fetch with a 200 from the page.
- The log says `Using WasmStorageImplementation.sharedIndexedDb`: drift
  runs sqlite in a **SharedWorker**.
- Closing the tab and reopening it still fails. Other sessions keep :8080
  tabs open in the same browser.

A SharedWorker is keyed by its script URL and lives as long as any tab of
the origin is connected. Every page load attaches to the existing one. A
worker whose wasm load failed once (a rebuild in progress, a deploy) keeps
that failure, and an updated app keeps attaching to the old build's
worker. A fresh profile gets a fresh worker, which explains the one case
that worked.

## Decision

- **Versioned worker and wasm.** `openLocalDatabase(assetVersion:)` puts
  `?v=<appVersion+gitSha>` on both `drift_worker.js` and `sqlite3.wasm`.
  A new build means a new worker URL, so a new SharedWorker and no stale
  HTTP cache. The two always change together, so they can't mismatch.
- **Retry once, fresh.** `openLocalDatabaseWithRetry` proves the open with
  `SELECT 1`, with an 8 s timeout. If it fails, it closes that database and
  opens again with `-retry<µs>` added to the version, which is a brand-new
  worker even within one build. The retry is recorded on the device.
- **Opened before `runApp`.** The open is awaited at boot, on the
  `db_open` step. It's normally ~150 ms, behind the loader that already
  covers boot. The secure-store read for the 3→4 migration stays lazy, so
  this doesn't bring back the splash hang ADR 0014 avoided.
- **Still failing: a storage screen, never "Internet".**
  `StorageProblemApp`, in the device's language, shows the fox, « L'appareil
  n'ouvre pas tes données », and « Ce n'est pas Internet : c'est l'espace
  de rangement… ». Réessayer reloads on the web, for fresh assets, and
  reopens elsewhere.
- **Réparer** (web) first says what's lost: progress made on this device
  and not yet sent. Pairings live in the secure store and come back, as
  does everything already sent. Then it deletes the browser's copy
  (IndexedDB, plus OPFS if any) and reloads. A store that won't open can't
  be read, so the unsent outbox can't be kept or counted. The reset itself
  is recorded instead.
- `web` is declared as a direct dependency. It was already resolved
  through drift.

## Verification

- Tests: the first open works; a poisoned first open retries on a new
  worker URL; a store still failing returns its error; a probe that never
  answers times out; the screen never says Internet in either language;
  Réparer resets only after a yes.
- In a real browser: the failing profile is the built-in browser on :8080,
  reproduced on 2026-10-29. Closing check after the Manager rebuilds
  :8080: the same profile boots, `db_open ok`, with `drift_worker.js?v=…`
  in the network log.
