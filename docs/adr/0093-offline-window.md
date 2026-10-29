# ADR 0093 — The offline window: 25 leaves per subject, not the whole grade

Date: 2026-10-29
Status: accepted

## Context

Hafid: "build the 20-30 lessons offline window". The interview decision
(CLAUDE.md, "Offline") was a rolling window of 20–30 leaves **per
subject**, about 15–18 MB each, one policy on every platform. Prefetch
follows the frontier. Evictions are counted, never silent. Assets are
content-addressed by sha256.

What existed:

- `ContentSync` downloaded **every** published exercise for the kid's
  `(subject, grade)` into `exercise_cache`, with its audio
  (`audio_cache`, keyed by exercise) and pictures (`asset_cache`, keyed
  by sha256). There was no window, no prefetch and no eviction. Audio
  rows of a withdrawn exercise were never deleted.
- The Carte decided "playable" by "has a cached lesson". It drew a node
  without one as *soon*, the "no lesson yet" state.
- Caches are shared by `(subject, grade)` across same-grade siblings
  (ADR 0014).

## Decision

### The window

- `offlineWindowLeaves = 25` (in `offline_window.dart`): the frontier
  leaf plus the next 24 **playable** leaves along the Carte, in the
  Carte's own order (`groupLeavesByArea`). Skills with no published
  lesson don't count, since they hold nothing to download.
- `offlineWindowBehind = 3` more just behind the frontier, so the last
  few finished leaves can be replayed offline.
- The frontier is the Carte's `active` node: the first playable leaf
  neither mastered nor completed. Once everything is done, it's the last
  playable leaf. The computation is one pure function,
  `computeOfflineWindow`, so the Carte and the window can't disagree on
  where the kid is.
- A `review` set is part of the function's input. The evidence-bounded
  review channel (prior-grade leaves the kid's own data says they need)
  **does not exist yet** in the app, and the manifest is grade-from-token,
  so there is nothing to put in it today. The hook exists so the channel
  needs no change to the window when it lands (work order item 3).

### Knowing what exists without downloading it

A new **`manifest_entry`** table (schema v9) holds the last manifest per
`(subject, grade, asked locale)`, replaced wholesale on each fetch. It
lets the app:

- tell "published, not downloaded" apart from "no lesson yet";
- compute a frontier over lessons that aren't on the device;
- download one node on demand.

### Siblings: the union window

- Each kid's window is computed from the manifest, the curriculum cache
  and **that kid's own local completion record**. Every kid's completion
  is already on the device (`node_progress.*`, per kid in `app_state`),
  so a sibling's window needs neither their token nor the network.
- The playing kid's window also uses server mastery when it has it. The
  result is stored per kid (`offline_window.<subject>.<grade>`). A
  sibling's stored window is used when present, and the local
  computation when not.
- What stays on the device is the **union** of every paired kid's
  window. A leaf any sibling is inside is never evicted.

### Prefetch

- `ContentSync.sync` now downloads only the union window's lessons.
  Verified chunks are **committed as they arrive**, so an interrupted
  prefetch resumes where it stopped: the checksum diff skips what's
  already there. Writing a newer verified version never breaks the old
  one, so "a failed sync leaves the old content playable" still holds.
- **Eviction runs only after a complete, successful pass.** An offline,
  failed or partial sync never removes anything.
- Triggers:
  - the Carte loading a subject (as before);
  - a lesson finishing, which moves the frontier: a background re-sync of
    that subject;
  - the app starting online: a background pass over every subject, one
    at a time.

  None of these is awaited by play. The Carte shows its cache first and
  refreshes when the sync lands.

### Eviction

- An exercise leaves when its node falls out of the union window, unless:
  - it has an open `activity_session` (any kid), or
  - it is on screen (`ContentInUse`, registered by the play screen for
    the life of the game).
- Audio goes with the last exercise that references it (`audio_cache` is
  keyed by exercise). A clip whose sha256 is already cached under another
  exercise is copied locally instead of downloaded again. Pictures go only
  when no cached exercise references their sha256 (`pruneImages`, as
  before).
- Every eviction is counted and timestamped in device-scoped `app_state`
  (`offline_window.evicted_total`, `offline_window.last_evicted_at`),
  like the outbox cap. `ContentSync.offlineStats()` returns those counts
  with the cache size per subject. The technical log (À propos) shows
  them, and tests read them.

### Offline on the Carte

- A node that's published but has **no lesson on the device** keeps its
  real state (active, completed, mastered or locked). Past the frontier
  it is still locked, which is true whether or not it's downloaded. It is
  never shown as *soon*.
- **Offline**, an open node that isn't downloaded wears a cloud tag, and
  a tap says so in kid words: "Cette leçon n'est pas encore sur ton
  appareil. Reviens quand tu auras Internet !". It doesn't crash, and the
  node isn't shown as locked.
- **Online**, a tap downloads that node first (a short wait on the orb),
  then plays it.

### Migration

- Schema v8 → v9 only adds `manifest_entry` (tested with the drift
  schema harness).
- A device that holds the whole grade **shrinks to the window on its first
  complete sync**. What a kid is in the middle of is protected: open
  sessions and on-screen content are never evicted, and every paired
  kid's window is kept.

### Backend

The manifest carries no sizes, so the app can't budget in megabytes or
say how big a download will be. The window is counted in leaves, which is
what the interview decided. The work order
`Platforms/BACKEND_WORKORDER_OFFLINE_WINDOW.md` asks for:

- asset sizes in the manifest;
- a per-leaf order, so the app can stop depending on the curriculum
  cache to rank lessons;
- prior-grade review entries.

## Consequences

- A grade-1 math device keeps about 28 leaves instead of every published
  one. Measured sizes are in the commit that adds the measurement.
- A kid who replays a leaf far behind the frontier needs the network the
  first time. That's the cost of a bounded cache, and the Carte says so.
- The window is per kid, so a family tablet holds up to (kids × 28) leaves
  per subject when the siblings are far apart. That's still bounded.
