# ADR 0027 — Pictures in lessons: a content-addressed asset cache

Date: 2026-10-25
Status: accepted (app side); backend half is `Platforms/BACKEND_WORKORDER_IMAGES.md`

## Context

Content can name a picture: `prompt.image_ref`, and `image_ref` on mcq
options and sort_buckets/pair_match items. Nothing in the app downloaded
or drew one. Only audio had a cache, so lessons used emoji in labels
instead (ADR 0025). That blocks the find_it engine entirely, and real
picture items in every other engine.

The contract already existed (backend ADR 0021): a ref resolves against
the exercise's own `assets[]`, `{ref, url, sha256}`. Audio and pictures
share that one array. The app's audio sync downloaded **every** asset into
`audio_cache`, so a picture would have been stored, and offered to the
player, as audio.

## Decision

- **Tell pictures from audio.** `assetKindOf` uses the asset's
  `media_type` when the backend sends one (work order I1). Otherwise it
  uses the URL's extension: webp, png, jpeg and gif are pictures, and
  anything else stays audio, which is all `assets[]` ever held before.
  SVG is not a picture here: Flutter can't decode it from bytes without a
  renderer the app doesn't ship.
- **A content-addressed `asset_cache` table** (schema v6), one row per
  sha256 holding the bytes, media type and size. Lessons that share a
  picture keep one copy and download it once. It's shared across kids,
  like the exercise cache it serves. The exercise's cached envelope maps
  ref → sha256, so the table needs no per-exercise rows.
- **Sync** works like audio: best-effort, verified against the sha256 the
  manifest-verified envelope carries, and a picture that fails is retried
  next sync. A bad picture never fails the exercise sync.
- **Pruning, never silent.** After every sync, any picture no cached
  exercise references is removed. The running total and the time of the
  last removal are kept in device-scoped `app_state`
  (`asset_cache.removed_total`, `asset_cache.last_removed_at`), the same
  rule as the outbox cap's evictions.
- **Engines resolve through `engine_sdk`**, which never touches the app's
  database:
  - `ImageResolver`, the same shape as `AudioResolver`;
  - `InMemoryImageResolver` for tests;
  - `ImageResolverScope`, an InheritedWidget the play screen puts above
    every engine, legacy and new runtime alike. It carries the exercise id
    as well as the resolver: an engine's view never sees the id, and
    assets belong to the whole envelope, so every question in a série
    shares them;
  - `ContentImage`, which draws a ref, or a fallback while it loads or
    when it's missing.

  The app supplies `DriftImageResolver`.
- **A picture never blanks a tile.** Content keeps its `label` alongside
  `image_ref`, both as the screen-reader name and as `ContentImage`'s
  fallback, so an unsynced or undecodable picture shows the label.

## Not done

- **The rolling per-subject offline window** (CLAUDE.md's 20–30 leaves) is
  still unbuilt for exercises, and pictures inherit that. Today the
  pictures cached are exactly those of the exercises cached. When the
  window lands, evicting an exercise frees its pictures through the same
  prune, already counted.
- **Audio stays in its own `audio_cache`**, keyed by (exercise, ref). It
  is not content-addressed and is never pruned when an exercise is
  withdrawn. That predates this ADR. Moving audio into `asset_cache` is
  the natural follow-up.
- **Drawing pictures in tiles and prompts** is the engine session's
  change in `packages/engines_core` (`AnswerTile`), built on
  `ContentImage`.
