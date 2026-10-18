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

---

# Tutolys Fox Mascot Animation System

Added 2026-10-18. Planning only — **zero code written, nothing in this
section changes A7's architecture or its thin-slice scope above.** It
plans a *later* replacement for `TutolysMascot`'s current placeholder
rendering, behind the same public API (a mood + size), and a richer
behavior set than the 5 moods A7's thin slice needs. Everything below is
additive to the existing plan; nothing above this line changes.

## Verified facts (don't re-derive these)

- **Current mascot already exists and already works**:
  `packages/design_system/lib/src/widgets/mascot.dart`'s `TutolysMascot` is
  a hand-coded `CustomPainter` fox (ears/head/eyes/snout/cheek-blush drawn
  with `Path`/`Canvas`), driven by one `AnimationController`. Its own doc
  comment says it's a placeholder: "the fox exists only as a reference
  photograph in the design system, while the shipped games carried a
  different mascot entirely." It already has 5 moods —
  `idle, thinking, correct, incorrect, celebrating` — and is **already
  reduce-motion aware**: `didChangeDependencies` reads
  `MediaQuery.maybeOf(context)?.disableAnimations` and, if true, stops the
  controller and pins it at a resting frame (`_controller.value = 0.5`)
  instead of looping. This pattern — not a new one — is what every new
  mood/behavior below needs to keep following.
- **Reference image found, not missing**:
  `Platforms/reference/brand/mascot-arctic-fox-ref.jpg` (784×1168 JPEG). A
  single flat painterly/semi-realistic illustration — a sitting arctic fox
  kit, white/pale-grey fur with darker grey ear-tips and shading, large
  dark expressive eyes, black nose, whiskers, a bushy tail curled to one
  side, front-facing, both front paws visible. It is **not** layered or
  separable as-is (confirms the brief's own framing) — there is no second
  source file (no `.ai`/`.psd`/`.fig`/layered SVG) anywhere in the repo.
- **No Duolingo screenshot was actually received** in this planning pass —
  only its written description. Flagged, not guessed at; re-attach it
  before any visual mockup work starts.
- **Dart SDK across every `pubspec.yaml`** (app root +
  `packages/design_system`, `packages/engine_sdk`, `packages/engines_core`):
  `sdk: ^3.13.3`. No separate Flutter engine version is pinned anywhere in
  the repo — the exact Flutter version needs `flutter --version` run
  directly in the dev environment, not assumed.
- **Actual target platforms, confirmed against the repo, not assumed**:
  `linux/` and `web/` platform directories exist and are fully populated.
  `android/`, `ios/`, `macos/`, `windows/` **do not exist at all** in this
  project. This plan's "Flutter mobile, desktop, and web apps" framing
  doesn't match current reality — **there is no mobile app today**. Every
  phase below is scoped to web + Linux desktop only; if mobile is wanted,
  that's a separate, much larger scope decision (adding whole platform
  targets) outside this document.
- **No animation package dependency exists yet** — no `rive`, `lottie`, or
  `flutter_animate` anywhere in the project. Only `flutter_riverpod`
  (state management, unrelated) is currently declared.
- **No marketing website project exists anywhere in the repo** — `Platforms/`
  contains only `tutolys-app`, `tutolys-backend`, `tutolys-telemetry`,
  `dev-stack`, `reference`, `AUDIT.md`, `TAXONOMY.md`. No `package.json`,
  no Next.js project, nothing. The marketing-site half of this request has
  no codebase to integrate into yet — see "Marketing website" under
  Open Decisions.

## Tool evaluation

| | **Rive** | **Lottie** | **Extend the current `CustomPainter`** |
|---|---|---|---|
| What it is | Interactive state-machine animation (bones, blend states, inputs) | Plays a pre-rendered, one-shot JSON animation (After Effects → Bodymovin export, or authored directly) | What already ships today |
| Flutter package | `rive` (pub.dev, MIT license, **0.14.11** latest stable at verification time) | `lottie` (pub.dev, MIT license, **3.6.1** latest at verification time) | n/a — already in the repo |
| Platform support (verified via pub.dev) | Android/iOS/macOS/Windows/Linux/Web — **covers this project's actual Linux+Web targets** | Android/iOS/macOS/Windows/Linux/Web — **also covers them** | Already proven on Linux+Web (it's running there now) |
| Exact Dart/Flutter SDK constraint for the current `rive`/`lottie` release | **Not confirmed** — pub.dev's own pages don't surface it plainly; needs `flutter pub add rive --dry-run` (and same for `lottie`) run directly against this project before committing | Same caveat | n/a |
| Runtime license | MIT (free, no restriction) | MIT (free, no restriction) | n/a |
| **Authoring tool license — this is the real cost, not the runtime** | Rive **Editor** (where `.riv` state machines are built) is a separate paid product: free tier caps at 3 collaborative files, 10MB asset limit, and **forces a splash screen into every export that only a paid tier removes** — effectively blocking commercial use on free. Cadet tier: **$9/seat/month**, removes the splash screen, raises limits. This is a recurring cost decision for Hafid, not an engineering one. | Authored in After Effects (existing paid tool, or free alternatives) + a free Bodymovin export plugin — no separate per-seat animation-tool subscription | Authored directly in Dart/Flutter code — no external tool or subscription at all |
| Interactivity (blend idle→correct mid-breath, directional pointing, etc.) | Built for exactly this (state machine + inputs) | Cannot blend between animations or react to continuous input — plays one fixed clip start to finish | Fully custom, but increasingly hard to hand-code as behavior count grows |
| Best fit | A state-rich, long-lived mascot with many interruptible moods (what's being asked for here) | Simple, short, non-interactive celebratory clips (e.g. a confetti burst) layered *on top of* something else | Fine for a small, fixed mood count (today's 5) — already shows strain as more states get added |

**Reading the table**: Rive is the right tool for the full 7-state,
interruptible mascot this request describes — but its recurring editor
cost is a real decision, not a formality, and the exact SDK compatibility
is **unverified, not assumed compatible**. Lottie is a reasonable *lower-risk
fallback* for the "lesson complete" burst specifically (layered over Rive
or the current painter), not a full replacement for an interactive mascot.

## Animation states

The current 5-mood enum already covers 3 of the 7 requested states
directly. Mapping:

| Requested state | Existing `MascotMood` | Status |
|---|---|---|
| Idle (breathing, blinking, occasional eye/ear movement) | `idle` | Exists — needs new blink/ear-twitch detail, not a new mood |
| Attention / greeting (wave, look toward learner, point) | *(none)* | **New** — needs a new mood, tentatively `greeting` |
| Thinking | `thinking` | Exists |
| Correct answer (short celebration) | `correct` | Exists |
| Try again (warm, never shaming) | `incorrect` | Exists — current implementation already avoids a sad/frowning face (tilt + a "danger" accent color, no droop) — **preserve that framing explicitly**, don't let a redesign introduce a shaming pose |
| Hint (gesture toward relevant control/content) | *(none)* | **New** — needs a new mood, tentatively `hint`, and a *directional* parameter (which control to gesture toward) — this is more than a mood, it's a mood + target position |
| Lesson complete (bigger celebration) | `celebrating` | Exists — already named for exactly this; `correct` is the small per-answer version, `celebrating` is the big one. Keep this distinction, don't collapse them. |

Net new surface: 2 new mood values (`greeting`, `hint`), and `hint` needs a
directional/target input the other 6 don't — flagged as a design question
below, not resolved here.

## Animation inputs/events (Flutter → mascot contract)

App logic stays in Flutter; the animation asset only ever receives a mood
(+ optional target for `hint`) and returns to `idle` on its own. Proposed
event → mood mapping, built on `EngineFeedback`'s existing (currently
unimplemented — see A7 plan above) hook points:

- `onCorrect()` → `correct`, auto-return to `idle` after a short timer
- `onIncorrect()` → `incorrect`, auto-return to `idle` after a short timer
- `onHint(target)` → `hint` (pointed at `target`), returns to `idle` once
  the learner acts or after a timeout
- `onLessonComplete()` → `celebrating`, held until the learner navigates
  away (not timer-auto-returned — a bigger moment deserves to persist)
- Path-screen arrival / no event in progress → `greeting`, then settles to
  `idle` after a few seconds — this is a **new** integration point,
  `EngineFeedback` is exercise-scoped and the path screen isn't an
  exercise; needs its own small hook, not a reuse of `EngineFeedback`.
- `thinking` stays available for any "waiting on the learner" moment,
  same as today.

## Phases

1. **Spike (small, time-boxed — do this before planning the rest in
   detail, per the brief)**: wire the *existing* fox (current painter, or
   the raw reference JPEG as a static placeholder if faster) into
   `PathScreen`, and test only `idle` → `correct` → `incorrect` on real web
   + Linux builds. Measure, don't guess: does reduce-motion still work,
   does it rebuild cleanly, is there any jank. Output is a go/no-go on
   Rive vs. Lottie vs. extending the current painter, grounded in what the
   spike actually showed — not decided here.
2. **Asset preparation**: a layered vector version of the reference fox
   (separate eyes/ears/head/paws/tail layers), preserving its current
   look. **Needs an artist or a vectorization pass this planning
   document cannot produce** — flagged as a required external input, not
   assumed solvable in-session.
3. **State machine design** (only if the spike picks Rive): the 7 states
   above, their transitions, and the `hint` target-gesture design,
   authored in the Rive editor against the layered art from phase 2.
4. **App integration**: swap `TutolysMascot`'s internals behind its
   existing `{mood, size}` API; add `greeting`/`hint` to the mood enum;
   wire the event mapping above into `EngineFeedback` once that gets a
   real implementation (A7's own open item).
5. **Marketing website**: blocked entirely until that project exists (see
   Verified Facts) — not plannable in further detail now.
6. **Testing**: web + Linux only, matching this project's actual
   platforms — not the phone/tablet/mobile framing the original brief
   assumed.

## Deliverables & acceptance criteria

- Spike report: idle/correct/incorrect working on a real web + Linux
  build, with a documented go/no-go recommendation.
- If Rive is chosen: a `.riv` file with all 7 states wired, importable
  and renderable in this project's actual Flutter/Dart version (verified,
  not assumed).
- `TutolysMascot`'s public API unchanged in shape (still `{mood, size}`),
  so every existing caller (today just `PathScreen`'s placeholder)
  continues to compile without edits beyond the mood enum growing by two
  values.
- Reduce-motion still fully respected for every new state, verified the
  same way the current implementation is (pinned resting frame, not
  looping).
- No animation plays for more than ~1-2 seconds without returning to idle
  or holding deliberately (lesson-complete only).

## Performance & accessibility requirements

- Short and purposeful: no state loops indefinitely except `idle` itself.
- Pause when off-screen where practical — **this needs a visibility
  detection mechanism this project doesn't have yet** (no
  `visibility_detector`-style package currently declared); flagged as a
  new dependency decision, not assumed free.
- Reduce-motion: every new state must degrade to a static resting frame
  the same way `idle` already does — this is a continuation of an
  existing, working pattern, not a new design.
- Static/reduced-motion fallback: same pinned-frame approach already
  proven in the current painter.
- No continuous/ambient movement that competes with lesson content for
  attention — `idle`'s breathing/blinking should read as *subtle*, not as
  a second focal point on the screen.

## Open decisions (flagged, not resolved here)

1. **Rive editor's paid tier** ($9-32+/seat/month) is a real recurring
   cost — Hafid's call, not an engineering one.
2. **Exact `rive`/`lottie` package SDK compatibility** against this
   project's `sdk: ^3.13.3` and actual installed Flutter version —
   unverified by pub.dev's own docs; needs a direct dependency-resolution
   check in the project.
3. **Who produces the layered vector art** (commissioned artist vs.
   AI-assisted vectorization vs. in-house) — not decided, not assumable.
4. **Whether to adopt Rive/Lottie at all**, versus extending the existing,
   already-working, already-accessible `CustomPainter` further — the spike
   in phase 1 should inform this, not a prior assumption.
5. **Marketing website stack** — no project exists yet; `CLAUDE.md` names
   `byltek-frontend-studio` as the skill for building it, but that's a
   wholly separate initiative this mascot plan can only hand off to, not
   schedule.
6. **Mobile platforms don't exist in this Flutter project at all.** If
   the mascot (or anything else) is actually meant to run on phone/tablet,
   that's a prerequisite scope decision (adding `android`/`ios` platform
   targets) far outside this document.

---

# Learner Home and Curriculum Path

Added 2026-10-18. Planning only — **zero code written.** This is explicitly
the *next visual iteration* of the path screen, after A7's thin vertical
slice above ships — it does not change A7's own scope, and it does not
touch the "What's deliberately NOT in this pass" list above (that list
still fully applies to A7's first milestone). Think of this section as
what A7's own closing line, "Extend visually later," is extending *into*
— tentatively "A7.2."

## Hard prerequisites this section inherits, unresolved

These are gaps A7's plan (above) already named as open — this richer
design does not get to assume they're solved:

- **No progress/mastery model.** `apps/progress/` is still an empty
  Django app. A7 explicitly chose locked/available-only for exactly this
  reason, with an explicit rule: *don't fabricate a local mastery
  heuristic to fill the gap.* That rule carries over here — "completed"
  as a visual state on this richer path is **not buildable** until a real
  progress model exists. This is this section's single biggest blocking
  dependency, not a detail to sort out during implementation.
- **No tree-shaped backend API.** A7's own endpoint design (above) returns
  a **flat list** with no parent linkage (`id, label_fr, label_en,
  stable_key`, optional `grade_markers` — no `parent_id` anywhere in that
  shape). A Topic → Domain → Strand → Leaf path with milestones and
  connected nodes needs either a tree-shaped response or parent links
  added to the flat one. This is a real, if small, backend change beyond
  what A7 scoped — not assumed free.
- **No mobile platforms exist in this Flutter project** (confirmed above,
  same fact as the mascot section) — phone/tablet layouts can be designed
  and tested via responsive window-resizing on web/Linux, but **cannot be
  tested on a real phone/tablet or with real touch input** without first
  adding those platform targets, a separate and larger decision.
- **No portal/parent-reporting project exists yet either** — "keep
  parent/tutor reporting in its own separate experience" is trivially true
  today only because that experience doesn't exist to crowd into. Worth
  naming now so it isn't accidentally built inside the kid-facing app
  later by default.

## Desktop layout (three panels)

- **Left**: compact navigation to the learner's main destinations.
- **Center**: the learning path itself — connected activity nodes,
  milestones, the current lesson made obvious, completed activities,
  locked future activities. This is the visual centerpiece; the other two
  panels are secondary.
- **Right**: contextual — today's goal, streak/progress, quests, a
  next-step suggestion. Resist turning every available stat into its own
  card; this panel should stay sparse enough that the center path remains
  the obvious focus.

`packages/design_system`'s existing `Breakpoints` token (confirmed
present, per A7's "Design system inventory" above) is the right mechanism
for the responsive rules below — no new breakpoint system needed.

## Responsive behavior

- Narrow screens: the path stays the main focus; left-nav and right-context
  panels collapse behind a tab, drawer, or compact section rather than
  competing for space.
- Lesson nodes and navigation controls sized for comfortable tapping.
- The same hierarchy (what's current, what's next) must survive at every
  size — not just the same data, the same obvious next action.
- **Caveat repeated from above**: "phone, tablet" here means responsive
  *layout* behavior verified on web/Linux at different window sizes, not
  verified on an actual mobile device — this project has no mobile
  platform target today.

## Fox reactions tied to learner actions

Reuses the mood set from the Mascot section above, plus one new gesture
this richer path specifically needs:

- Greeting/idle on arrival at the home screen — `greeting` → `idle`
  (already planned above).
- **Pointing toward the next lesson** — this is a *directional* gesture,
  the same shape as the mascot section's `hint` state (mood + a target to
  gesture toward), not a new mood on its own. Flagged there as an open
  design question; this is the second place that same question matters,
  which raises its priority.
- Celebrating a completed activity — `correct` (small) or `celebrating`
  (milestone-sized), same distinction as the mascot section.
- Gentle encouragement after a retry — `incorrect`, same "never shaming"
  framing already established.

The path must stay fully usable with the fox absent entirely (reduced
motion, or the fox simply not rendering) — it is a companion on the path,
not the mechanism that makes the path function.

## Functional requirements

- The path's visual state (locked/available/current/completed) must be
  **derived from real curriculum and progress data**, never a
  client-side-only visual flag — this is the same discipline A7 already
  applies to locked/available; "completed" inherits it once the progress
  model (above) exists.
- Completed / available / current / locked must each be distinguishable
  by more than color alone (icon + label + pattern) — an accessibility
  requirement not named in A7's original scope, worth retrofitting into
  A7's own UI work too, not just this richer version.
- Loading, empty, and error states for the path itself — also not named
  in A7's original scope above; same note, worth adding there too rather
  than only here.
- Parent/tutor reporting stays in its own (currently nonexistent)
  experience — don't let it grow inside this screen by default.

## Phases

1. **Design** — low-fidelity mockups of the three-panel desktop layout and
   its responsive collapse, no code. Needs the actual Duolingo reference
   image (not received this pass, see Mascot section) re-attached before
   this phase can start for real, plus the fox's layered art from the
   Mascot section's phase 2.
2. **Component library** — new path-specific widgets (node, progress
   indicator, lock iconography), built locally inside `features/path/`
   first per A7's own existing guidance above, promoted to
   `design_system` only if a second screen needs the same pieces.
3. **Backend tree API** — extend or add alongside A7's flat endpoint to
   carry parent linkage / milestone grouping.
4. **Progress model** — prerequisite for "completed," cross-reference
   against wherever that initiative is actually tracked; not started by
   this document.
5. **Integration** — wire the real endpoint + fox reactions into the new
   layout.
6. **First milestone**: one working learner-home screen, realistic sample
   curriculum data (not live), responsive layouts proven at multiple
   window sizes, and the fox's basic reactions (greeting, point-toward-
   next, celebrate, encourage-after-retry) all working together end to
   end.

## Acceptance criteria (first milestone)

- Renders correctly at desktop, tablet-width, and phone-width window sizes
  on web/Linux (not on a real mobile device — see caveat above).
- Current lesson is unambiguous at every size tested.
- Locked/available/current states are distinguishable without relying on
  color alone.
- Fox reactions play for the four named moments and return to idle/absent
  cleanly; reduced-motion users get the same static-fallback treatment
  established in the Mascot section.
- Nothing in this milestone claims a "completed" state is real — it is
  explicitly out of scope until the progress model exists.

## Open decisions (flagged, not resolved here)

1. Tree-shaped backend API design — new endpoint vs. extending A7's flat
   one with parent links.
2. Progress/mastery model ownership and timeline — this plan only names
   it as a blocker, it doesn't schedule it.
3. Mobile platform support — not present in this project today; a
   prerequisite decision if real phone/tablet support is actually wanted,
   not something this document can plan around.
4. The `hint`/"point toward next lesson" directional-gesture design,
   shared with the Mascot section — one open question, two consumers.
5. Relative priority of this section versus other roadmap items —
   Hafid's call, not implied by this document's existence.
