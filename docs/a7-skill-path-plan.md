# A7 — the real skill path screen: plan for a fresh session

Status: 2026-10-18. Scoped and researched, **zero code written**. Handed off
for a new session to build, per Hafid's "thin vertical slice" scope
decision below. Read this top to bottom before writing anything — it
front-loads research so the new session doesn't have to re-derive it.

Per `TUTOLYS_HANDOFF_PLAN.md` line 462, A7 was always meant to land in the
same phase as B7 (curriculum import), not as a Phase-3 afterthought — it
needs real taxonomy data, which is exactly what B7 produces. `CLAUDE.md`'s
earlier framing of A7 as "next after A6, blocked on curriculum" undersold
this; trust this file over that framing now.

## The scope decision

Hafid chose **"thin vertical slice"**: a minimal but fully real version of
every piece end-to-end, for one subject/grade, rather than polishing any
one piece first. Explicitly:

- Backend endpoint returns a **flat leaf list** (no nested tree traversal
  UI yet) for one subject/grade.
- App caches it locally.
- `go_router` gets **exactly 2 routes**: path → play.
- `EngineRegistry` / `EngineFeedback` get real (simple is fine)
  implementations — not test doubles.
- Path UI is a **plain scrollable list** of nodes (locked / available —
  see "mastered" note below), not a visual tree with connecting lines.

Extend visually later. The point of this pass is "a kid can pair, see a
real list of their skills, tap one, play it for real, come back" — every
link in that chain real, nothing mocked.

## What's missing — confirmed by direct research, not assumed

This isn't "write a screen." Five things don't exist at all yet:

1. **No backend API for curriculum tree data.** `apps/curriculum/` has
   `models.py` + `pfeq_import.py` + migrations — no `views.py`, `urls.py`,
   or `serializers.py`. `config/urls.py`'s included app urls are `common,
   accounts, orgs, kids, pairing, platform_admin, exercises` — curriculum
   is absent. The existing content manifest/exercise envelope
   (`apps/exercises/views.py`, `Exercise.envelope()` in
   `apps/exercises/models.py:170-190`) carries `skill_node_id` as a bare
   UUID — no label, no level, no parent chain anywhere on the wire.

2. **No local cache for tree structure.** `lib/data/local_db/database.dart`
   has `ExerciseCacheTable` (flat `skillNodeId` column per exercise row,
   no FK, no tree table) and `EventOutboxTable` / `EngineSettingsTable` /
   `AppStateTable` — nothing else. `ContentSync.cachedExercises()` can
   filter/group by the raw UUID string but cannot resolve what it *is*.

3. **Routing inside the paired shell is genuinely greenfield.**
   `lib/core/routing/app_shell.dart` is a plain `ConsumerStatefulWidget`
   switching on `SessionStatus` — no `go_router` anywhere in `lib/`, despite
   being a declared dependency. The file's own doc comment says routing
   here is "A7 onward." No existing pattern to follow; this establishes it.

4. **`EngineRegistry` and `EngineFeedback` have zero production
   implementations.** Only test doubles exist:
   `_RecordingFeedback`/`RecordingFeedback` in
   `packages/engine_sdk/test/exercise_runner_test.dart` and
   `packages/engines_core/test/support/engine_harness.dart`. The three real
   engines (`McqEngine`, `PairMatchEngine`, `ComposeBuildEngine`) exist in
   `packages/engines_core/lib/` and are tested, but nothing in app code
   constructs `EngineRegistry([McqEngine(), PairMatchEngine(),
   ComposeBuildEngine()])`.

5. **No progress/mastery tracking exists.** `apps/progress/` is a
   registered Django app (`config/settings/base.py`'s `INSTALLED_APPS`)
   with only `__init__.py` + `apps.py` — no model, no migration. It is
   **not** on `CLAUDE.md`'s "Still OPEN — do not build" list, so building a
   minimal version is not forbidden — but it's also not started. **This is
   why the thin slice uses locked/available only, not locked/available/
   mastered** — "mastered" needs this model and isn't in scope for the
   first pass. Don't build a fake local-only mastery heuristic to fill the
   gap; leave the third state out and say so in the UI copy/design rather
   than fabricating a signal that doesn't mean anything yet.

## Design system inventory (what exists vs. what's new)

`packages/design_system/lib/design_system.dart` exports exactly four
things: `theme.dart`, `tokens.dart`, `widgets/code_field.dart`,
`widgets/mascot.dart`. Available: `TutolysColors`/`Space`/`Radii`/`Motion`/
`Breakpoints` tokens, theme extensions (`context.colors`, `context.text`,
`context.extras`), `TutolysMascot` (animated, mood-driven, reduce-motion
aware — good fit for `EngineFeedback`'s reactions). **Nothing path-specific
exists**: no node/card widget, no progress indicator, no lock iconography.
Build these new, either inside `features/path/` locally (favor this for a
thin slice — promote to `design_system` later only if a second screen needs
the same widgets) rather than over-engineering a reusable component now.

## Session state available post-pairing

`PairedKid` (`lib/data/local_db/session_store.dart`): `id`, `displayName`,
`gradeLevel` only. No subject enrollment, no org type. Subject selection
for the thin slice: hardcode to one subject for now (suggest `MATH` —
largest, cleanest Phase-4-round-1 dataset, see B7 status below) rather than
building subject-switching UI; that's explicitly out of scope for "thin."

## Concrete pieces to build, in dependency order

### 1. Backend: read-only curriculum endpoint

New `apps/curriculum/views.py` + `serializers.py` + `urls.py`, wired into
`config/urls.py` alongside the existing `exercises` include. Mirror
`ContentManifestView`'s auth (`IsPairedDevice` / `KidPrincipal` — check
`apps/exercises/views.py` for the exact pattern) and query-param shape
(`?subject=MATH&grade=1`, matching `ContentManifestView`'s existing
`subject` param).

Response: flat list of **taggable leaves** (`SkillNode.objects.taggable()`,
already defined in `apps/curriculum/models.py` — derives `is_leaf`, don't
reinvent it) for that subject/grade, each with: `id`, `label_fr`,
`label_en`, `stable_key` (useful for debugging, cheap to include),
`grade_markers` (optional — the kid-facing grade/marker data, or omit for
v1 and add once there's a UI use for it). Do **not** expose `notes`,
`raw_ref`, or internal-only fields.

Grade filtering: a leaf's "grade" isn't a column on `SkillNode` — it's
derived from `SkillGradeMarker` rows (`skill_node.grade_markers`, grade
1-6, marker introduced/mastered/reused). Filter to leaves having *any*
marker at the requested grade. Write a test fixture-based test, not just a
manual check — follow `tests/test_content_cli.py`'s style (flat functions,
`@pytest.mark.django_db` only where DB access is needed).

### 2. App: local cache + sync for the tree

New `SkillNodeTable` in `lib/data/local_db/database.dart` (columns: `id`,
`labelFr`, `labelEn`, `stableKey`, `subject`, `grade` — keep it as flat as
the backend response; no parent/child columns needed for a flat-list UI).
New sync class mirroring `ContentSync`'s shape (`lib/data/sync/
curriculum_sync.dart` or similar) — diff-by-content-hash is overkill for a
first pass (the tree changes rarely, unlike exercises); a simple
replace-on-sync is fine, don't copy `ContentSync`'s checksum machinery
wholesale unless it's actually needed. New API client method (extend
`lib/data/api/content_api.dart` or add a sibling `curriculum_api.dart`)
calling the new backend endpoint.

### 3. App: `go_router` inside the paired shell

Two routes only: path (shows the flat node list) and play (hosts
`ExerciseRunner`). Wire into `AppShell`'s `paired` branch
(`lib/core/routing/app_shell.dart`) — replace the direct `PathScreen()`
instantiation with a router. Tapping a node in the path pushes to play
with the tapped node's synced exercise(s); finishing (`ExerciseRunner`'s
`onFinished`) pops back to path. Keep `test/pairing_test.dart`'s two
existing assertions passing (`PathScreen` still shown once paired) —
check what it actually asserts before assuming a widget-type change breaks
it.

### 4. App: `EngineRegistry` + `EngineFeedback`, for real

`EngineRegistry` — trivial, a Riverpod provider:
`EngineRegistry([McqEngine(), PairMatchEngine(), ComposeBuildEngine()])`.

`EngineFeedback` — needs a real implementation. Simple is fine for a thin
slice: drive `TutolysMascot`'s `MascotMood` (already built, animated,
reduce-motion aware) on `correct`/`incorrect`/`celebrate`/`hint`; sound
effects can be a no-op stub for v1 if audio assets/package aren't already
sorted (don't block the slice on finding sound assets — note it as a
follow-up if skipped, don't silently drop it undocumented).

### 5. App: the path screen itself

Replace the `PathScreen` placeholder. Flat `ListView` of synced skill
nodes for the hardcoded subject + the kid's `gradeLevel`. Each row: label,
a locked/available visual state (no "mastered" — see gap #5 above). Tap →
push the play route with that node's exercise. Where does the exercise
come from? A node may have zero, one, or several exercises tagged to it
(`Exercise.skill_node` FK, no uniqueness constraint) — for a thin slice,
simplest is one exercise per node (pick first by `rank` if several exist);
don't build a sub-list UI for multiple exercises per node yet.

## What's deliberately NOT in this pass

- Visual tree/path rendering (connecting lines, branching) — flat list only.
- Mastery state — no model exists yet; don't fabricate one.
- Subject switching — hardcoded to one subject.
- Settings-override persistence into `ExerciseRunner` (flagged already in
  `docs/adr/0001-exercise-runner.md` as a seam, not built) — use empty
  overrides (`{}`), matching `ExerciseRunner`'s default.
- Sound effects, if audio assets aren't trivially available — stub and
  flag, don't block on it.
- Reward unlock triggers — explicitly on `CLAUDE.md`'s "Still OPEN — do
  not build" list (#3). Don't touch.

## B7 status, for context on what curriculum data actually exists right now

Phase 4 round 1 (ADR 0005, `tutolys-backend/docs/adr/`) landed 958 taggable
leaves in the real dev database, all five subjects, idempotent re-import
confirmed. **Math (178 leaves) is the cleanest, most complete dataset** —
no known structural defects, matches `TAXONOMY.md`'s predicted count
exactly. Round 2 (in progress, paused by choice — see
`tools/curriculum_cli/pfeq_pdf_extraction/README.md` in the backend repo)
is re-deriving français from the real PDF and isn't merged into the
database yet. **This is why MATH is the recommended subject for A7's
hardcoded slice** — it's the one dataset not mid-repair.

## Tests expected

Backend: a `tests/test_curriculum_*.py` file, flat pytest functions
matching house style, covering at minimum: the endpoint returns only
taggable leaves, filters correctly by subject + grade, respects auth (a
request without a valid kid token is rejected the same way
`ContentManifestView` rejects one — check that test for the pattern).

App: at minimum, `ExerciseRunner`-style widget tests for the new path
screen (tap a node → navigates to play) and a sync test for the new
`SkillNodeTable` cache (mirroring `test/content_sync_test.dart`'s shape).
Follow the existing test file conventions in each repo — don't invent a
new style.

## Standing rules still apply

Per `CLAUDE.md`: plan before code (this file **is** that plan — restate it
and confirm before writing, since a fresh session hasn't seen the
back-and-forth that produced it), small conventional commits, no push/
deploy without being asked, an ADR for any non-trivial decision made while
building this (e.g. if the endpoint's exact response shape changes from
what's sketched above, or if the one-exercise-per-node simplification
turns out wrong), tests before calling anything done.
