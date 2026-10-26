# ADR 0038: Startup diagnostics, and a stuck screen instead of an endless loader

Date: 2026-10-26. Status: accepted. Observability work order P1, A1–A3
(`Platforms/OBSERVABILITY_WORKORDER_P1.md`), folded into the splash-hang fix.

## Context

Hafid's :8080 preview sat on the loader forever. `POST /pairing/refresh`
answered 200, and then nothing: no progress read, no sync, and no error
anywhere. The loader waits on two things: the session restore, and then
the paired kid's settings, which are **the app's first database query**.
Nothing after the refresh ran, so the settings read never answered: the
local database never responded.

What was tried, in a clean headless Chrome against the live dev-stack. All
of it booted fine:
- a fresh database;
- the schema v7 → v8 upgrade (a v7 build, then the current one, in one
  profile);
- two tabs on mixed versions sharing drift's SharedWorker (which turned
  up a separate hazard: the newer tab connects to the already-open v7
  database and **never runs its own migration**);
- a paired kid with every subject synced: ~2,100 audio clips (~265 MB)
  stored as blobs in SQLite, which drift's IndexedDB storage holds in the
  worker's memory.

So the hang sits in state only Hafid's browser has, most likely a wedged
shared drift worker. It lives as long as *any* tab of that origin is open,
which is why a "fresh tab" in the same browser didn't help. The app cannot
fix a browser's worker, but it can stop waiting forever and say where it
is stuck.

Two real defects were found on the way:
1. **"A failed read counts as ready" was false.** `settingsReadyProvider`
   was `!isLoading`. Under Riverpod 3 a failed `FutureProvider` retries
   automatically, and while it retries its state is `AsyncLoading`
   *carrying* the error. So a failed read also held the loader, retry
   after retry.
2. **Nothing had a timeout.** A read that never answers is neither a
   success nor a failure.

## Decision

**Boot steps with timeouts (A1).** `BootLog` (`lib/core/diagnostics/`)
records each step: start, end, outcome (`ok`, `error`, `timeout`) and the
error, scrubbed. Local steps time out at 10 s, network ones at 20 s.
- The steps are `config_guard`, `db_open`, `first_frame`,
  `splash_release`, `session_restore`, `pairing_refresh` and
  `settings_read`.
- `content_sync` is not a boot step in this app: nothing on the boot path
  waits on it. It runs when the Carte opens.
- `db_open` is a `SELECT 1` fired at boot. It opens the database and runs
  any migration, so a database that never opens is named as such.
- A `settings_read` that times out fails, and readiness now counts any
  error as ready, so the app opens on default settings. Its automatic
  retry is off: one timeout means defaults, and "Réessayer" reads again.
- A `pairing_refresh` timeout is treated as offline: stay paired, play
  from the cache, retry later.
- Each step prints `[boot +1.234s] session_restore ok (312 ms)` in debug
  and profile builds, and in release behind `?bootdebug=1`.

**A stuck screen (A2).** If the loader is still up after 15 s,
`LaunchFlow` shows `BootStuckView`: a calm line in FR or EN, "Réessayer"
(clears the boot log, re-reads settings, restores the session again) and
"Détails" for the adult. Détails shows the step boot is waiting on, every
step, and the error log. No red, and no stack trace unless Détails is
opened. If boot finishes while the screen is up, it carries on. The
release-config red page is unchanged.

**Global error hooks and a ring buffer (A3).**
- `runZonedGuarded` wraps all of `main`. `FlutterError.onError` (chained
  to the previous handler) and `PlatformDispatcher.onError` feed
  `DiagLog`.
- `DiagLog` keeps the last 200 entries in memory: time, kind, type,
  message and the top 5 frames, and prints each one.
- Everything is scrubbed first: JWTs, `Bearer` values, emails, and
  pairing-code-shaped tokens (the backend's alphabet, 6–8 characters, at
  least one digit). Widget text is never recorded.
- The log is saved, debounced, to `app_state` under device scope
  (`diag.last_run`). The next boot shows it as "Session précédente". Each
  run starts by writing an empty log, so a clean run doesn't keep the
  last one's errors. A database that never answers just means nothing is
  saved.
- The five bare `catch (_)` sites now record through `recordCaught` and
  otherwise behave as before.
- À propos: a long-press on the version row opens "Journal technique",
  the same view.

Nothing leaves the device.

## What Hafid's browser needs today

Close **every** :8080 tab (or end the shared worker in
`chrome://inspect/#workers`), then reopen. With this build, if it is still
stuck after 15 s, the screen will name the step.

## Consequences

- Tests in `test/boot_diagnostics_test.dart`:
  - a hung step becomes `timeout`;
  - the loader becomes the stuck screen after 15 s and names the step;
  - "Réessayer" re-runs boot;
  - an error thrown in a frame callback lands in the buffer, scrubbed;
  - the scrubber removes a JWT, an email, a bearer token and a pairing
    code, and keeps ordinary words;
  - a settings read that never answers stops holding boot.
- Open: the mixed-version SharedWorker case (a new tab skips its
  migration while an old tab holds the database). A guard belongs in the
  open path, e.g. check `PRAGMA user_version` against `schemaVersion` and
  ask the user to close the other tabs. Not done here.
