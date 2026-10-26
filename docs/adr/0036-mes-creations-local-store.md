# ADR 0036: "Mes créations", a per-kid local store of what a child made

Date: 2026-10-26. Status: accepted.

## Context

Hafid wants creative ELA engines. A new engine, `my_gallery` ("Ma galerie
au village", built by Engines), lets a child hang 1–3 of their own
creations in a village gallery. Nothing in the app kept a child's output
before this: an answer is graded and goes into the outbox as an event, and
the thing the child built is gone.

## Decision

**A drift table, `creation` (schema v8), behind an SDK interface.**

- `engine_sdk` gains `Creation`, `CreationShelf` and `CreationShelfScope`
  (`src/creations.dart`). This follows the `ContentSpeakerScope` pattern:
  the host puts the shelf above the engine, and the engine never sees a kid
  id, a database or the network. With no scope (a test, an older host),
  `maybeOf` is null. An engine then skips saving, and `my_gallery` shows its
  empty state.
- The app's `CreationStore` implements the shelf for one kid.
  `creationShelfProvider` binds it to the active kid, and the play screen
  puts it above the runtime path.
- **What's stored is the engine's structured result**: engine key, exercise
  id, a JSON payload the engine can draw again, the payload's own version,
  and `created_at`. It's not a screenshot. The store never reads the
  payload, so an engine can change its shape (and bump `payload_version`)
  with no migration.
- **Per kid** (ADR 0014 rules). Every query filters on `kid_id`, so a
  sibling can't list, hang or delete another child's creation even by id.
- **Local only (D6).** Nothing reads this table for the outbox, telemetry
  or any API.
- **Hung**: a persistent flag, with at most 3 hung at once. Hanging a
  fourth throws `StateError` rather than taking one down silently: the
  child chooses.
- **Payload cap: 16 KB of encoded JSON.** A larger or non-JSON payload is
  refused with `ArgumentError`. A sentence, a pattern or a geoboard figure
  is a few hundred bytes.
- **Count cap: 200 per kid, with counted eviction.** Past it, the oldest
  *un-hung* creations go, and `creations.evicted_total` /
  `creations.last_evicted_at` are bumped in that kid's `app_state`. It's
  "never unaccounted", as with the outbox (ADR 0009). A hung creation is
  never evicted. One creation a day takes over six months to reach the cap.
- **Erasure**: `CreationStore.eraseKid` deletes a kid's creations and
  counters. `SessionController` calls it everywhere a kid's credential is
  dropped: a guardian removing the profile (`forget`), and every
  `RefreshRejected` (revoked, archived or erased server-side). A creation
  can never upload, so nothing is lost by deleting it with its owner.

## Not done, and why

- **The other per-kid tables are not cleared when a kid is removed.**
  Before this ADR, removal dropped only the credential. `event_outbox`,
  `played_date`, `engine_settings`, `activity_session` and the kid's
  `app_state` keys all stay. Clearing undelivered outbox rows is a real
  decision: once the token is gone they can never upload, but they are the
  kid's play record. That decision isn't mine to take inside this change.
  It is flagged to the Manager.
- **Export.** The app has no local export of kid data. The portability
  export (backend ADR 0018) is server-side and can't see a local-only
  table. If one is built, creations belong in it.
- **No UI** beyond the scope. `my_gallery` is Engines' engine.

## Consequences

- Schema v7 → v8 only adds a table and an index. It is tested with the
  drift schema harness (`test/migration_v7_to_v8_test.dart`).
- An engine that wants to keep a creation reads
  `CreationShelfScope.maybeOf(context)` and calls `save`. It doesn't need
  to know anything else.
