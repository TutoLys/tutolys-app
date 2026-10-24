# ADR 0014 — A kid-scoped local database

Date: 2026-10-24
Status: accepted

## Context

Hafid's decision (2026-10-24, recorded in `CLAUDE.md`): one device must
hold **several paired kids**. A family has one tablet, and the Family plan
sells three seats — requiring three devices for three children is an
adoption barrier, not a product.

Every local table was written when a device meant exactly one kid:

| table | holds |
|---|---|
| `event_outbox` | play events awaiting upload |
| `played_date` | one row per local date with a completed exercise (streak) |
| `engine_settings` | per-engine local overrides |
| `app_state` | key/value: `home_stats.*` **and** `outbox_capacity.*` |
| `exercise_cache` | exercise envelopes, each tagged `subject` + `grade` |
| `audio_cache` | Piper audio blobs, keyed by `(exercise_id, ref)` |
| `skill_node_cache` | curriculum leaves, each tagged `subject` + `grade` |

None of them has a kid column. Retrofitting one after the seven-page UI
rebuild would be a migration across every table plus a reconciliation
story for data already on disk, which is why this lands first.

## Decisions

**Not every table becomes kid-scoped.** Splitting them by what the data
actually belongs to avoids duplicating content across siblings:

**Per kid — a `kid_id` column.** `event_outbox`, `played_date`,
`engine_settings`. It joins the primary key on `played_date` and
`engine_settings`, whose old keys (`date`, `(engine_key, setting_key)`)
are only unique *within* a kid. It does **not** on `event_outbox`:
`event_id` is a client-generated UUID and the server's own idempotency
key, so it is already globally unique — `kid_id` is an indexed column
there, not part of the key.

- `event_outbox` must carry `kid_id` because the flusher uploads each
  event with *that kid's* device token. Without it, an event queued by one
  child could be uploaded as another — corrupting the per-kid mastery data
  the product exists to produce. This is the single most important column
  in the change.
- `played_date` is a per-kid streak by definition.
- `engine_settings` is a per-kid preference: one child wants hints on, the
  next does not.

**Per kid, but only for some keys — `app_state` gains a `kid_id` whose
empty string means device-level.** The table holds two different kinds of
thing: `home_stats.*` is a per-kid daily counter, while
`outbox_capacity.*` counts evictions for the whole device's outbox. One
table with an owner column keeps both honest; splitting it in two would
duplicate the accessor for no gain.

**A sentinel, deliberately, not NULL.** SQLite permits NULL in any
primary-key column that is not `INTEGER PRIMARY KEY` — a documented
quirk — and NULLs compare distinct, so a nullable `kid_id` in the key
would silently allow unlimited duplicate device-level rows for the same
key. `''` is a real value and makes the uniqueness constraint mean what
it says.

**Shared, NOT kid-scoped — `exercise_cache`, `audio_cache`,
`skill_node_cache`.** Content is identified by `(subject, grade)`, which
these tables already store. Two same-grade siblings are served byte-identical
content, so a `kid_id` column would duplicate 15–18 MB per subject per kid
on disk for nothing. Audio follows its exercise.

`skill_node_cache` already reads and writes scoped to `(subject, grade)`
(`CurriculumSync._replace` / `cachedLeaves`), so it needed no change at
all. `cachedExercises` already *accepts* a `grade` argument — callers
simply never passed one, which was harmless when a device meant one kid.
They pass it now.

**The real hazard this creates, and the fix.** `ContentSync._applyManifest`
computed withdrawn content by reading the **entire** `exercise_cache` table
and deleting everything absent from the syncing kid's manifest. With a
shared cache that means kid A's sync deletes all of kid B's content; B
re-downloads it; they thrash forever, on what may be a metered connection.
Withdrawal is now computed **only over the syncing kid's own
`(subject, grade)` slice** — the one place where "shared cache" could have
been silently expensive.

## Migration

Schema `3 → 4`. Rows already on disk belong to the device's currently
paired kid — there has only ever been one — so the upgrade **backfills
that kid's id** rather than discarding data. A device with no pairing has
nothing worth keeping and is left empty.

The backfill reads the kid id from `SessionStore`, which lives in the
platform secure store, not in this database. The migration therefore takes
the id as a parameter rather than reaching for it: a drift migration that
depends on `flutter_secure_storage` would be untestable and would couple
the schema to the platform.

## Consequences

- The flusher, `HomeStats`, `StreakLocal` and the settings store all take a
  kid id. None of them can be constructed without one, so "which kid?" is
  answered at the type level rather than by convention.
- Content storage stays O(grades in the household), not O(kids).
- Eviction of shared content becomes "no paired kid's `(subject, grade)`
  matches" rather than per-kid — not implemented here, since the rolling
  window itself is not built yet; noted so it is not forgotten.
