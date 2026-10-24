# TutoLys — Interactive Animation & Mascot System

**Status: PROPOSAL, awaiting Hafid's review. Nothing implemented, nothing in
`CLAUDE.md` / `GO_LIVE_CHECKLIST.md` modified yet** (per standing rule 1 and
the brief's own "do not modify or implement anything until reviewed"). §11
below contains the *exact proposed edits* to those two files, ready to apply
on "go".

Date: 2026-10-23. Produced from a read of the real `tutolys-app` source
(`lib/`, `packages/engine_sdk`, `packages/engines_core`,
`packages/design_system`), `pubspec.yaml`, the Flutter SDK itself, plus
runtime/licensing verification against pub.dev and rive.app.

---

## 0. Executive summary — the five findings that change the plan

**1. The "reusable event/trigger interface" the brief asks for already
exists and is already wired into every engine.** `EngineFeedback`
(`packages/engine_sdk/lib/src/engine.dart:60`) is exactly the abstraction
the brief sketches as `mascot.play(MascotAnimation.correct)`. All four
engines already call `context.feedback.correct()` /
`.incorrect()` / `.celebrate()` / `.hint()`, and `MascotEngineFeedback`
already drives `TutolysMascot`'s mood from those calls. The brief's §5
requirement — *"must integrate with our existing learning engines rather
than requiring each engine to implement its own animation logic"* — is
**already satisfied architecturally**. This is the single biggest
cost saving available: we widen and harden one existing seam instead of
designing a new system. It also means **no engine code has to change** for
the mascot to get dramatically richer.

**2. Recommend against adding Lottie.** The brief proposes Rive *and*
Lottie, then says "avoid … creating multiple overlapping animation
systems." Those two instructions conflict. Everything §4 lists for Lottie
(confetti, stars, XP, sparkles) is a particle system that Flutter draws
natively for near-zero cost and near-zero bytes, and anything else Lottie
could do, Rive already does from the same editor and the same runtime.
Adding Lottie buys a second runtime *and* a second authoring toolchain
(After Effects — proprietary, subscription, and the real licensing cost in
that option). **One asset runtime (Rive) + native Flutter for effects.**

**3. Rive is the right call for the fox, and one requirement decides it
outright.** §2 asks for *"eyes following the user's cursor."* Lottie is a
baked timeline with no runtime inputs — cursor-follow is effectively
impossible. Rive's state machine takes live numeric inputs, so it is a
first-class feature. Every other mascot requirement (mood blending,
interruption, randomized idles) also wants runtime inputs. Hafid's
instinct is correct. **But it must pass a build gate first** (§8 risk R1):
`rive` depends on `rive_native`, which **downloads native binaries at build
time**, and this project has a documented history of exactly that class of
problem (ADR 0002/0003, the drift-FFI/wasm saga).

**4. Three existing, unused hooks mean less new surface than expected —
and one of them is in the wrong architectural place.**
- `animation_level` (`full|reduced|none`) already exists in `commonSettings`
  (`settings.dart:133`) and **nothing reads it**.
- `sound_effects` / `music` already exist there too and **nothing reads
  them**.
- `MediaQuery.disableAnimations` is honored in exactly **one** place
  (`mascot.dart:68`).

  The problem: `animation_level` lives in *per-engine* settings resolved
  inside `ExerciseRunner`, but animation is app-wide (home, path, profile,
  onboarding), and `design_system` cannot see `EngineContext`. Worse,
  `PlayScreen` never passes `settingsOverrides` at all, so it is always the
  default today. **This must be promoted to an app-level motion policy** or
  it will be duplicated and drift — which is exactly the failure the
  design-system package exists to prevent.

**5. Three of the brief's wishlist items have no data or product model to
attach to, and one is explicitly OPEN.** Honest scoping, not scope-cutting:
- **XP does not exist** anywhere — no model in `tutolys-backend`, no field,
  no endpoint. Mastery and streak are real (B9); XP is not.
- **Achievements / reward reveals / unlockable levels** are open item **#3**
  (reward unlock trigger), which `CLAUDE.md` marks *"Still OPEN — do not
  build."*
- **"Lesson complete" has no lesson.** `PlayScreen` hosts exactly *one*
  exercise and pops (`play_screen.dart:66`). There is no N-exercises-in-a-row
  session concept, so "animated progress indicator" and "lesson completed
  celebration" have nothing to hang on yet.

  Buildable gamification animation **today**: streak celebration only
  (real data via B9 + the offline estimate). The rest needs product
  decisions first — see §12 Q3.

---

## 1. How this fits the current architecture

### What exists

| Layer | State | Evidence |
|---|---|---|
| Motion tokens | 4 durations + 3 curves, defined | `tokens.dart:86` |
| `Motion.bounce` (`elasticOut`) | **defined, never used anywhere** | grep: 0 hits |
| Animation outside the mascot | **none** — zero `AnimationController`, zero `Animated*` in `path_screen`, `home_screen`, `profile_screen`, `exercise_runner`, any engine | grep |
| Mascot | `CustomPainter` fox, 1 breath controller, 6 static mood poses | `mascot.dart` |
| Reaction seam | `EngineFeedback` → `MascotEngineFeedback` → `ValueNotifier<MascotMood>` | `engine.dart:60`, `mascot_feedback.dart` |
| `design_system` widgets | **2 only** (`code_field`, `mascot`) | file tree |
| `assets/` | **does not exist**; `pubspec.yaml`'s `flutter:` section is `uses-material-design: true` and nothing else | `pubspec.yaml:47` |
| Platform folders | **`linux/` and `web/` only** — no `android/`, `ios/`, `macos/`, `windows/` | `ls` |
| Animation dependencies | **none** | `pubspec.yaml` |

### Where the new system has to live (and why not in `design_system`)

Plan §6.3 locks the layering: *engines depend on `engine_sdk` and
`design_system` only.* So putting `rive` into `design_system` would make
**every engine transitively depend on `rive_native`** — dragging a
build-time binary download into `engines_core`'s unit tests and inflating
every engine build. That is unacceptable.

Proposed layering — one new package:

```
packages/design_system/      + MotionPolicy, extended Motion tokens,
                               MascotMood (stays — pure enum, no churn
                               for existing call sites), dependency-free
                               animated primitives
packages/engine_sdk/         + widened EngineFeedback (pure interface,
                               still zero dependencies)
packages/tutolys_motion/     NEW. depends on: design_system + rive.
                               MascotDirector, the Rive renderer,
                               asset loading/caching, particle effects.
packages/engines_core/       UNCHANGED. never sees rive.
lib/ (app)                   wires MascotDirector into the EngineFeedback
                               adapter + Riverpod providers.
```

`MascotMood` deliberately stays in `design_system` and keeps its current
export, so `play_screen.dart` and `path_screen.dart` compile untouched. The
*renderer* moves to `tutolys_motion`; the *vocabulary* does not move.

This also makes the Rive go/no-go reversible: the director writes to a
renderer interface, so if the §8/R1 spike fails, a hand-rigged
`CustomPainter` fox satisfies the same interface and **nothing else in the
system changes**.

---

## 2. Technology recommendation

### Verified facts (not recalled — checked 2026-10-23)

| | `rive` | `lottie` | `flutter_animate` |
|---|---|---|---|
| Version | 0.14.11 | 3.6.1 | 4.5.2 |
| Runtime license | MIT | MIT | BSD-3 |
| Native deps | **yes** — `rive_native` 0.1.11, binaries downloaded at build | none, pure Dart | none |
| Platforms | iOS, Android, macOS, Win, **Linux**, **Web** | same | same |
| Last published | ~2 months | ~35 days | **~23 months** |
| Authoring tool | Rive editor (paid SaaS) | Adobe After Effects | n/a (code) |
| Runtime inputs | **yes** — state machine inputs | **no** — baked timeline | n/a |

**Rive licensing, corrected at the source.** Aggregator sites claim the
free tier cannot export `.riv` for production. [rive.app/pricing](https://rive.app/pricing)
says otherwise: the free plan **does** allow production export, but
requires shipping **a Rive splash screen in the app**. For a branded kids'
product that is a non-starter, so realistically: **Cadet, $9/seat/month**
(≤3 seats, unlimited files, no splash). That is the true cost of this
direction — cheap, but it must be a conscious purchase, and only animator
seats need it, not developers.

### The recommended stack

**Layer 1 — Flutter native animation. No new dependency.**
All UI micro-interaction: button press/release, card bounce, page
transitions, loading states, counter roll-ups, progress fills,
correct/incorrect flashes, navigation. This is roughly **70% of perceived
polish** and carries zero bytes, zero platform risk, and works on every
target today. `Motion.bounce` has been sitting unused since A7.2 — this
layer is mostly *applying tokens that already exist*.

**Layer 2 — Rive, for the Arctic Fox only.** Single `.riv`, single
artboard, one state machine, driven by named inputs. Gated on the §8/R1
spike.

**Layer 3 — particles in native Flutter, not Lottie.** Frost, sparkle,
aurora sweep, streak burst: a `CustomPainter` over one `AnimationController`.
Smaller, faster, fully themeable from `TutolysColors` (a Lottie JSON bakes
its colors — it cannot follow the learner/adult theme split), and it
avoids a second runtime and an After Effects dependency.

### Explicitly recommended against

- **Lottie / dotLottie** — see §0.2. Reconsider only if TutoLys hires an
  After Effects animator rather than a Rive one; that is a hiring decision,
  not a technical one.
- **`flutter_animate`** — the obvious pick, and I'd skip it. Last published
  **~23 months ago**. It is a convenience wrapper over `AnimationController`
  and implicit animations, both of which are stable framework code. A ~150-line
  internal equivalent in `design_system` gives the same ergonomics with no
  stale dependency on the critical path of the product's visual identity.
- **Spine** (proprietary, paid, game-oriented, no first-class Flutter
  runtime), **SVGA** (unmaintained), **Flare** (superseded by Rive).
  Nothing credible competes with Rive here.
- **`visibility_detector`** — not needed. Verified in the Flutter SDK:
  `IndexedStack` wraps children in `_VisibilityScope`, and
  **`Visibility.of(context)` is public API** that registers a rebuild
  dependency (`indexed_stack.dart:434`). Offscreen self-pausing is free.
  See §8/R7 — this is a real bug in the current shell, not just a future
  concern.

### Sound

`commonSettings` already declares `sound_effects` and `music`; nothing
reads them and there is no audio dependency. Recommendation: **design the
hook in Phase M2, defer the implementation.** `MascotDirector` emits a
`cue` alongside every visual reaction; the audio backend (`just_audio` or
`soloud`) lands in its own phase. Retrofitting sound into an animation
system that never anticipated it is the expensive path — reserving the
seam costs nothing now.

---

## 3. Architecture: the reaction pipeline

```
engine (engines_core)
  └─ await context.feedback.correct()        ← UNCHANGED call site
       │
       ▼
  EngineFeedback  (engine_sdk — widened interface, still zero deps)
       │
       ▼
  MascotDirector  (tutolys_motion)
       ├─ MotionPolicy       → full | reduced | none  (OS flag + app setting + offscreen)
       ├─ priority + interruption resolver
       ├─ generation token   → fixes the stale-reset defect (§4)
       ├─ IdleScheduler      → randomized idles, then sleep (injected clock)
       └─ cue stream         → audio backend (seam only in M2)
       │
       ▼
  MascotRenderer  (interface)
       ├─ RiveMascotRenderer       ← Phase M3, after the spike + artwork
       └─ PainterMascotRenderer    ← today's CustomPainter fox, the M2 stand-in
                                     and the permanent fallback
```

Two properties this buys:

**Renderer-agnostic.** The whole system is built and tested in M2 against
the *existing* painter fox. The `.riv` becomes a drop-in swap. This fully
de-risks the artwork dependency — no plumbing waits on an artist.

**`rive` never reaches the engines.** It lives behind `tutolys_motion`,
which engines do not depend on.

---

## 4. The interruption model, and a defect it fixes

`MascotEngineFeedback._show()` (`mascot_feedback.dart:45`) is:

```dart
Future<void> _show(MascotMood next) async {
  mood.value = next;
  await Future<void>.delayed(hold);   // fixed 900ms
  mood.value = MascotMood.idle;
}
```

**This is a latent bug.** Two overlapping calls race: if `correct()` starts
at t=0 and anything triggers at t=100ms, the *first* call's timer still
fires at t=900ms and slams the mood back to `idle` — truncating the newer
reaction 100ms into its life. It is invisible today only because every
engine happens to `await` each call strictly sequentially
(`mcq_engine.dart:124`: `await …correct(); await …celebrate();`). The first
non-awaited call, or the first ambient idle variation landing mid-reaction,
exposes it.

The fix is a **generation token**: each request increments a counter, and
the auto-return-to-ambient only applies if its generation is still current.

### Priority tiers

| Tier | States | Duration | Interruptible by |
|---|---|---|---|
| **Ambient** (0) | `idle`, `thinking`, `sleeping` | persistent | anything |
| **Reaction** (1) | `correct`, `incorrect`, `hint` | bounded | tier ≥ 1 |
| **Celebration** (2) | `celebrating`, `streak`, `levelUp` | bounded | tier 2 only |

A reaction always returns to the *current ambient* state, not hardcoded
`idle` — so a reaction fired while the fox is `thinking` returns to
`thinking`, which the current code gets wrong.

### Blocking beat vs visual duration — the key decoupling

Engines `await` feedback calls, so **today, a richer animation literally
makes gameplay slower.** As celebrations get more expressive, the app gets
more sluggish. That tension has to be designed out, not discovered later.

Split them: the awaited `Future` resolves after a short **gameplay beat**
(~400–600ms — enough for a child to register the outcome), while the
*visual* keeps playing non-blockingly. A 2.5s celebration and a 500ms
gameplay pause become independent numbers.

```dart
abstract interface class EngineFeedback {
  // Existing four — signatures unchanged, so no engine edits.
  Future<void> correct();
  Future<void> incorrect();
  Future<void> celebrate();
  Future<void> hint();

  // New. Ambient; never awaited for flow control.
  void thinking();
  void idle();
}
```

The four existing signatures are preserved deliberately: `engines_core`
compiles and its 36 tests pass unchanged.

---

## 5. Mascot state machine specification

### States

| State | Trigger | Tier | Visual | Exit |
|---|---|---|---|---|
| `idle` | default | 0 | breathing, periodic blink, occasional ear flick, slow tail | — |
| `idle` variations | `IdleScheduler`, randomized 8–20s | 0 | look around / scratch / tail sweep / stretch | → `idle` |
| `thinking` | engine awaiting input | 0 | head tilt +, look up, slower blink | → `idle` |
| `sleeping` | no user input for 90s | 0 | eyes close, slump, slow breath, occasional ear twitch | any input → `idle` |
| `hint` | `feedback.hint()` | 1 | head tilt −, glance toward hint, gold accent | → ambient |
| `correct` | `feedback.correct()` | 1 | small hop, closed-eye smile, tail wag, paw raise | → ambient |
| `incorrect` | `feedback.incorrect()` | 1 | curious tilt, ears half-down, soft shrug — **never sad, never scolding** | → ambient |
| `celebrating` | `feedback.celebrate()` | 2 | full jump, spin, both paws, frost burst | → ambient |
| `streak` | streak milestone | 2 | `celebrating` + aurora sweep | → ambient |

`incorrect`'s tone is a hard product rule, already encoded in
`EngineFeedback`'s own doc comment (*"a harsh buzzer teaches avoidance
rather than the skill"*). The artwork brief must inherit it.

### Rive contract (the artist/developer interface)

One artboard `Fox`, one state machine `FoxMood`:

| Input | Type | Written by | Meaning |
|---|---|---|---|
| `trig_correct` | Trigger | director | one-shot |
| `trig_incorrect` | Trigger | director | one-shot |
| `trig_celebrate` | Trigger | director | one-shot |
| `trig_hint` | Trigger | director | one-shot |
| `ambient` | Number | director | 0=idle 1=thinking 2=sleeping |
| `idle_variant` | Number | `IdleScheduler` | 0..n, randomized |
| `look_x` / `look_y` | Number | pointer tracker | −1..1, cursor follow |
| `energy` | Number | director | 0..1, global motion scale for `reduced` |

**These input names are a versioned contract.** Rename one in the editor
and the app silently stops animating — binary `.riv`, no compile error.
Mitigation: a contract test asserting every input the director writes
exists in the shipped `.riv`, following the precedent already set by
`packages/engine_sdk/test/telemetry_contract_test.dart`.

`energy` is how `animation_level: reduced` degrades gracefully instead of
switching off: same states, damped amplitude.

### Cursor follow

Desktop/web only, via `MouseRegion`. Must **not** engage on touch (there is
no cursor, and a stale `look_x` would leave the fox staring off-screen).
Writes go straight to the Rive input — never through `setState`, which
would rebuild the subtree on every mouse move.

---

## 6. Animation design language — "Snowdrift"

The brief's hardest requirement: Duolingo-level polish, zero Duolingo
resemblance. Generic "playful" motion (3-oscillation elastic bounce,
rainbow confetti) is precisely what reads as a Duolingo clone. The
differentiator should come from what TutoLys already owns: an **arctic
fox**, **Quebec blue + gold**, and the **navy cloud shadow**.

1. **Settle, don't bounce.** One small overshoot (1.0 → 1.06 → 1.0), never
   a springy multi-oscillation. The current `Motion.bounce = elasticOut` is
   too cartoonish for this register — add `Motion.settle` (a tuned
   `Cubic` overshoot) and reserve `elasticOut` for celebrations only.
2. **Drift in from below.** Entrances rise and settle like snow coming to
   rest. Never slide in from the side.
3. **Gold is the reward channel, exclusively.** Nothing gold animates
   unless the child earned something. This makes gold *mean* something and
   directly extends the locked token rule (*"gold … never for large
   areas"*).
4. **Cold-to-warm on success.** The success flash runs blue → gold →
   settle, rather than the universal green checkmark.
5. **Frost, not confetti.** Celebrations emit frost crystals / snow
   sparkle. Confetti is the single most generic choice available; frost is
   free, equally joyful, and unmistakably this product.
6. **Aurora sweep** for milestones — a slow gradient sweep in brand blues
   and greens. Cheap (one shader/gradient), and nothing else in the
   category looks like it.
7. **Two motion registers, reusing `TutolysRegister`.** The learner theme
   gets full expressive motion; the adult/portal theme gets calm, no
   character, no overshoot. That light/dark, playful/calm split is
   *already* in `theme.dart` — motion must honor it rather than inventing a
   parallel switch.

Timing: keep the four existing durations. Add `celebration: 1600ms`;
ambient loops ≥ 3000ms.

---

## 7. Asset pipeline

### Production workflow

1. **Design** — layered vector fox. Figma or Illustrator → SVG → import to
   Rive, or draw directly in Rive. Deliverable: separated parts (ears L/R,
   eyes, pupils, snout, body, 4 paws, tail segments) on named layers.
2. **Rig** — bones for tail and ears; nested artboards for eyes so blink
   and `look_x`/`look_y` compose independently of body state.
3. **Animate** — one timeline per state in §5.
4. **State machine** — wire the §5 input table *exactly*. This is the
   contract.
5. **Export** — `.riv` → `assets/mascot/fox.riv`, declared in `pubspec.yaml`
   (the `flutter:` section currently declares no assets at all).
6. **Integrate** — `RiveMascotRenderer`; contract test guards input names.

### Versioning

`.riv` is binary: no meaningful git diffs. Rive cloud is the source of
truth for the editor file; the exported `.riv` is committed with a
changelog line per export. Git LFS if it grows.

### What AI/Claude Code can and cannot do — honestly

**Can do, end to end:** every line of Dart (director, policy, primitives,
renderers, adapters, providers, tests); the particle and shader effects
(Layer 3 is *entirely* code — no asset, no artist); the state-machine
contract document; the runtime contract test; all of Layer 1; a static SVG
placeholder fox.

**Cannot do:** operate the Rive editor. It is a GUI with no authoring API —
there is no programmatic path to a `.riv` file. Rigging a character and
producing expressive keyframe animation is skilled human work. Same for
Lottie/After Effects.

**The practical consequence:** the fox's *actual animation* is the one hard
external dependency in this entire plan. Everything else is code we write.
And §3's renderer indirection means that dependency **blocks nothing** —
M1, M2, M4, M5, M6 all ship against the existing painter fox. The artist
can be hired in parallel, or later.

---

## 8. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| **R1** | `rive_native` downloads native binaries at build time. This repo has a documented history of exactly this failure class (ADR 0002/0003, drift FFI→wasm). Breaks offline/reproducible builds and future CI. | **High** | **Phase M0 spike is a hard gate.** `dart run rive_native:setup` can pre-download; must be proven on Linux *and* web in the real sandbox before committing. |
| **R2** | Web: Rive renderer + drift wasm on one page, with **no COOP/COEP headers** (ADR 0003 declined them deliberately). Interaction unverified. | **High** | Part of M0. Note: threaded-wasm needs COOP/COEP; single-threaded does not. Must be measured, not assumed. |
| **R3** | **Live-browser verification is a known-broken capability here** (CLAUDE.md, 2026-10-20: `flt-glass-pane` stayed empty, narrowed to drift's worker handshake in this sandbox). We may be unable to verify the web path at all. | **High** | Do not claim web verification without evidence. If M0 can't verify in-sandbox, say so and gate on a real browser elsewhere. |
| **R4** | **No `android/` or `ios/` folders exist.** Rive is being chosen for platforms that have no scaffolding, and `rive_native` ships per-platform binaries. | Medium | Ties to GO_LIVE open question #1. Either answer it first, or scope M0 to linux+web and accept a re-spike on mobile. |
| **R5** | Infinite animations hang `pumpAndSettle` → the whole test suite. `mascot.dart:68`'s comment already documents this trap. 21 test files today. | **High** | One shared `MotionPolicy` primitive, never copy-pasted; test harness defaults to `animation_level: none`; a guard test that fails on a non-compliant looping animation. |
| **R6** | Reduce-motion must be honored in **three** independent places (OS flag, app setting, offscreen). Today: one. | Medium | Single `MotionPolicy` resolves all three into one value. Required by M1. |
| **R7** | **Confirmed defect:** `home_shell.dart`'s `IndexedStack` keeps all three tabs alive, and `IndexedStack` does **not** mute tickers (verified in SDK: it wraps children in `_VisibilityScope` + `ExcludeFocus` only). Three mascots would tick at once — battery and frame cost. | Medium | `Visibility.of(context)` is public API and registers a rebuild dependency (`indexed_stack.dart:434`). Self-pause, no new package. |
| **R8** | Rive free tier forces **a Rive splash screen** in a shipped kids' app. | Low | Budget **$9/seat/mo** (Cadet). Animator seats only. §12 Q2. |
| **R9** | Asset size / offline-first. ADR 0004 already rejected CDN fonts for this reason. | Low | Everything bundled; `.riv` is vector and small; measure the delta in M0 and record it in the ADR. |
| **R10** | Mobile battery from continuous idle loops. | Medium | Sleep-after-inactivity (already wanted, §2) + R7's offscreen pause + `energy` damping. |
| **R11** | Building gamification UI for data that doesn't exist (XP) or is explicitly OPEN (#3). | Medium | M5 is gated. Streak only until §12 Q3 is answered. |
| **R12** | **Opportunity cost.** `GO_LIVE_CHECKLIST.md`'s #1 item is that `OutboxFlusher` is never called — telemetry has never received real data. Animation is polish on a pipeline that isn't connected. | **High** | Not a technical risk; a sequencing call for Hafid. §12 Q1. |

---

## 9. Phased roadmap

Reworked from the brief's six phases. The main change: the brief's Phase 3
("learning engine integration") is **mostly already done** — see §0.1 — so
it collapses into M2, and a hard technology gate is added in front.

### M0 — Spike & gate
Not a feature phase. Prove `rive_native` builds and renders on **Linux
desktop and web** in this actual environment, with a trivial `.riv`.
Measure: bundle-size delta, frame cost, and whether the drift-wasm web boot
still works.
**Exit: an explicit go/no-go on Rive.** No-go → `PainterMascotRenderer`
stays permanent and the rest of the plan is unaffected (§3).

### M1 — Motion foundation · no new dependencies
`MotionPolicy` (unifies OS reduce-motion + `animation_level` + offscreen);
extended `Motion` tokens (`settle`, `celebration`); the dependency-free
animated primitives (`PressableScale`, `AnimatedCounter`, `DriftIn`,
`BouncyCard`); fix R7. Ships visible polish immediately, zero asset
dependency, zero platform risk.

### M2 — Director + widened feedback
`MascotDirector` with the §4 priority/interruption model and the
generation-token fix; blocking-beat/visual-duration split; `IdleScheduler`
(injected clock, following the `EngineContext.clock` precedent); `sleeping`
state; cue seam for audio. Renderer: the **existing painter fox**. All four
engines gain richer reactions with **zero engine code changes**.

### M3 — Rive fox
Swap in `RiveMascotRenderer` + contract test. **Depends on artwork and M0
passing.** Parallelizable with everything after it.

### M4 — Learning-experience animation
Answer-selection, correct/incorrect feedback, animated hints, drag-drop
feedback, `pair_match` transitions. Touches `engines_core`. Also fixes
`mcq_engine.dart:272`'s raw `Colors.red.shade400` (a token violation found
while reading).

### M5 — Gamification · partially gated
**Now:** streak celebration (real data). **Blocked:** XP, achievements,
reward reveals, unlockable levels, path node `active`/`done` states — all
need §12 Q3 answered first.

### M6 — UI system, onboarding, polish, perf
Page transitions (`go_router` `CustomTransitionPage`), loading states,
onboarding, perf passes, final accessibility audit.

**Suggested first slice if Hafid wants value fast: M1 + M2.** No new
dependencies, no artwork, no platform risk, and it makes the app feel
dramatically more alive — while M0 and hiring run in parallel.

---

## 10. Acceptance criteria & testing

**Global, every phase:**
- `flutter test` stays green and **never hangs**. A guard test fails if any
  animation loops without consulting `MotionPolicy`.
- Every animated widget renders correctly at `animation_level: none` **and**
  with `MediaQuery.disableAnimations: true` — asserted, not assumed.
- `flutter analyze` → 0 issues.
- No `engines_core` test changes in M1–M3 (proves the seam held).

**Per phase:**
- **M0** — builds and renders on linux + web; bundle delta and frame cost
  recorded in the ADR; verification evidence stated honestly, including
  "could not verify" where true (R3).
- **M1** — unit tests for `MotionPolicy` across all three inputs; golden
  tests for each primitive at `full`/`reduced`/`none`.
- **M2** — director unit tests: priority ordering, interruption, **the
  generation-token case** (new reaction mid-flight is not truncated),
  return-to-current-ambient (not hardcoded idle), `IdleScheduler` with an
  injected clock, sleep/wake.
- **M3** — contract test asserting every director-written input exists in
  the shipped `.riv`; mascot goldens per mood with the controller pinned.
- **M4** — widget tests per engine asserting the feedback visual appears;
  engine logic tests unchanged.
- **M6** — frame-time budget on Linux desktop + web; 60fps target with the
  measurement method documented.

**Two new ADRs:** `0007-animation-stack.md` (the Rive/Lottie/native
decision + M0 evidence), `0008-mascot-director-and-state-machine.md` (the
priority model and the Rive input contract).

---

## 11. Proposed plan updates — NOT YET APPLIED

Exact text, ready to apply on "go".

**`CLAUDE.md` → "Where things are"**, add to the tree:
```
  tutolys-app/packages/tutolys_motion/   animation + mascot director (M0-M6)
```

**`CLAUDE.md` → "Still OPEN — do not build"**, append:
```
#12 XP model (no backend model exists; blocks M5's XP animations) ·
#13 lesson/session concept (PlayScreen hosts one exercise and pops;
    blocks "lesson complete" celebrations)
```

**`CLAUDE.md` → "Gotchas that cost real time"**, append:
```
- **`rive_native` downloads native binaries at build time.** Not a pub
  dependency — a build step with a network call. `dart run
  rive_native:setup --platform linux` pre-seeds it. Same failure class as
  ADR 0002's drift FFI problem; expect it to bite CI first.
- **`IndexedStack` does not mute tickers.** It wraps children in
  `_VisibilityScope` + `ExcludeFocus` only, so every tab in `home_shell`
  keeps animating while hidden. `Visibility.of(context)` (public, and it
  registers a rebuild dependency) is the fix — no extra package.
```

**`GO_LIVE_CHECKLIST.md` → new track:**
```
## Track G — Animation & mascot system

Proposal: `tutolys-app/docs/animation-system-plan.md`. Six phases (M0-M6),
M0 is a hard go/no-go gate on Rive. M1+M2 need no new dependencies and no
artwork. Not started.

- [ ] M0 spike: rive_native on linux + web in the real sandbox
- [ ] M1 motion foundation (no new deps)
- [ ] M2 mascot director + widened EngineFeedback
- [ ] M3 Rive fox (needs artwork + M0 pass)
- [ ] M4 learning-experience animation
- [ ] M5 gamification (gated on open items #3/#12/#13)
- [ ] M6 UI system, onboarding, polish
```

**`GO_LIVE_CHECKLIST.md` → open questions**, append items 7–9 (= §12 below).

---

## 12. Decisions needed from Hafid

**~~Q1 — Sequencing.~~ Answered 2026-10-24 — nothing blocks M1.** This
asked whether to wire the telemetry pipeline before starting animation
work. It was already done: `OutboxFlusher` was wired into `AppShell` on
2026-10-23 (`tutolys-app` ADR 0007), hours after the checklist that
flagged it was written, and live-verified into TimescaleDB. A follow-on
streak defect found while checking this is also fixed (`tutolys-telemetry`
ADR 0006). **Consequence for this plan: M5's streak celebration now has
correct real-time data behind it** — before ADR 0006 the backend's streak
never counted the current day, so an increment could not have been
celebrated at the moment it happened.

**Q2 — Rive seat budget.** $9/seat/month (Cadet) to avoid shipping a Rive
splash screen in a children's app. Approve, or do we stay on
`PainterMascotRenderer` and hand-code the fox?

**Q3 — Gamification scope.** XP has **no backend model**, and achievements
/ reward unlocks are open item **#3** ("do not build"). M5 can ship streak
celebrations now. Does XP become a real backend feature (its own phase), or
does gamification stay streak+mastery for launch?

**Q4 — Mobile, again** (GO_LIVE open question #1, still unanswered). It now
also gates the M0 spike's scope: `rive_native` ships per-platform binaries,
and there is no `android/` or `ios/` folder to test against. Spike linux+web
only, or stand up mobile targets first?

**Q5 — The artist.** The `.riv` is the one thing no amount of code
substitutes for. Hire a Rive animator, commission a one-off, or stay on the
hand-coded fox indefinitely? M1/M2/M4/M5/M6 don't block on this either way.

**Q6 — Design language.** Does "Snowdrift" (§6) land — frost instead of
confetti, gold reserved exclusively for earned rewards, aurora sweeps for
milestones, settle-not-bounce? This is the ownable, not-Duolingo decision,
and it's a taste call, not an engineering one.
