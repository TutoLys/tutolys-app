# ADR 0060 — Character renderers, and how to replace the fox

Date: 2026-10-25
Status: accepted
Builds on ADRs 0017 and 0019 (the `AnimationDirector`, the placeholder fox).
Leaves `docs/animation-system-plan.md` §12 open: Rive is **not** approved.

## Context

The game screen showed the line-drawn placeholder fox (`TutolysMascot`)
in its header, and Hafid noticed. His brief: "we will make the animations
system (so we can use these or our mascot for now) but we have to keep in
mind that we will replace them so leave space for them."

The seam already existed (ADR 0019): runtime events → `AnimationDirector`
→ `ReactionPolicy` → `ActorScheduler` per role → `CharacterActorState` →
`CharacterRenderer`, looked up by `CharacterRegistry` from a
`CharacterManifest`. No engine imports `tutolys_motion`
(`test/architecture_boundaries_test.dart`). What was missing was a renderer
for the real art, and a convention for where new art goes.

We have exactly **one** real pose: the design's waving fox
(`asset-mascot-welcome.webp`, 420×409). The design README says three
poses were promised and never fully delivered.

## Decision

### One interface, many renderers

`CharacterRenderer.build(context, CharacterActorState)` is the only thing
a renderer implements. `RendererType` now has three values:

| type | renderer | status |
|---|---|---|
| `bitmap` | `BitmapCharacterRenderer` | **today's fox** |
| `placeholder` | `PlaceholderCharacterRenderer` (painted) | installed as the fallback |
| `rive` | none | reserved, not installed |

A manifest whose renderer isn't installed falls back to `placeholder`, so
a Rive fox shipped to a build without Rive still draws.

### The bitmap renderer

It shows the image for the current reaction's **pose slot** and moves it
with a `MotionRecipe`, which is a pure function of time (`motion_recipes.dart`):

| reaction | motion | particles |
|---|---|---|
| idle | breathing, 3 s | none |
| thinking / curious / listening | slow head tilt | none |
| speaking | quick nod | none |
| explaining (hint) | leans in once | sparkles |
| encouraging (Presque) | gentle damped sway. Never a "no" head-shake, never red | none |
| celebrating (correct) | crouch, hop, squash | stars |
| victory (activity done) | two hops and a wiggle | confetti |
| waiting / sleeping | slower, shallower breath | none |

Every one-shot starts and ends at rest, and a test pins that, so nothing
jumps. Particles are drawn natively (`ParticlePainter`), with no Lottie.
`XpPop` ("+N XP") is available for whoever owns the XP display.

### Reduced motion and hidden tabs

`motionAllowed(context, reducedMotion:)` is false when any of these
holds:

- the director's flag is set;
- `MediaQuery.disableAnimations` is set (the app's setting is already
  OR-ed with the OS setting there, in `main.dart`);
- `Visibility.of(context)` is false, which is how `IndexedStack` hides a
  tab.

When it's false, both controllers stop, the pose rests flat and no
particles are drawn. A cue that arrives in that state is dropped, never
replayed later. The painted fallback is wrapped in `TickerMode`, because
it runs its own loop. Tests assert `hasScheduledFrame` for each case.

### Wiring

The changes in `lib/` are the minimum:

- `learning_platform_providers.dart` registers `BitmapCharacterRenderer.fox`
  plus both renderers.
- `play_screen.dart` puts a `CharacterStage` on the same director into the
  celebration's character slot, at 150 px, in place of the separate
  `BreathingMascot`. The director is cued to `victory` before it mounts,
  and mounting on a cued reaction plays its one-shot.

Engines, `engines_core` and `engine_sdk` are unchanged.

## How to replace the art

### What an artist delivers, for the bitmap renderer

- **One transparent image per pose**, square-ish, with the character's
  feet on the bottom edge. Squash and tilt pivot on the bottom centre.
  WebP with alpha, roughly 512 px on the long side. Clean edges matter:
  the brand icon needed an alpha-matte fix (ADR 0012), so check the edges
  on a dark background.
- **The named slots**: `pose.default` (required), and optionally one image
  per reaction: `pose.celebrating`, `pose.victory`, `pose.encouraging`,
  `pose.thinking`, `pose.curious`, `pose.listening`, `pose.speaking`,
  `pose.explaining`, `pose.waiting`, `pose.sleeping`, `pose.idle`.
  An empty slot follows the manifest's `fallbacks`: `victory` uses
  celebrating's image, `curious` and `listening` use thinking's, `speaking`
  uses explaining's, and `sleeping` uses waiting's. After that it uses
  `pose.default`. So a delivery can be partial, and the order worth paying
  for is celebrating, encouraging, thinking, then explaining.
- The images go in `packages/tutolys_motion/assets/characters/<id>/`.
  That folder is already declared in the package's `pubspec.yaml`. Then
  add one line per pose to the manifest's `assets`, and bump `version`.

Nothing else changes. The motion still plays on top of each pose. Images
that fail to load draw the painted fox, never nothing.

### A new character (a subject companion, say)

1. Add a `CharacterManifest` beside `BitmapCharacterRenderer.fox`, either in
   Dart or loaded with `CharacterManifest.fromJson`. JSON shape:

   ```json
   {
     "id": "owl", "version": 1, "renderer": "bitmap",
     "supported": ["celebrating", "thinking", "encouraging"],
     "fallbacks": {"victory": "celebrating"},
     "assets": {"package": "tutolys_motion",
                "pose.default": "assets/characters/owl/pose-default.webp"}
   }
   ```

   Unknown reaction names are dropped and an unknown renderer reads as
   `placeholder`, so a manifest written for a newer build still loads.
2. List it in `characterRegistryProvider`'s `manifests`.
3. Give it a role in a `CastAssignment`: `guide`, or `companion`. The
   default policy already cues the companion on correct and on completion.
   Casting comes from activity or subject config, never from an engine.

### A new renderer (Rive, if §12 is ever approved)

1. Add the `rive` dependency to **`tutolys_motion` only**. It must first
   pass the M0 build gate in the animation plan (`rive_native` downloads
   binaries at build time).
2. Implement `CharacterRenderer` with `type => RendererType.rive`. Map
   `state.reaction` to state-machine inputs, and use `state.generation` to
   re-fire a one-shot trigger. When `motionAllowed` is false, rest on a
   still frame. Ignore `MotionRecipe`, because the state machine is the
   motion.
3. Register it in `characterRegistryProvider`'s `renderers` and switch the
   fox manifest to `"renderer": "rive"`, with `assets` like
   `{"riv": "assets/characters/fox/fox.riv", "state_machine": "Main"}`.
   Keep `BitmapCharacterRenderer` installed: a build or platform without
   Rive then falls back cleanly to the placeholder. A better fallback would
   point the registry to bitmap, which is a one-line change in `rendererFor`.

No engine, screen or policy changes in any of the three cases.

## First real poses (2026-10-25, later the same day)

Hafid delivered seven fox emotion renders (`Lab/Tutolys/Assets/imgs/engines/`).
Three fill slots, cropped to the art, feet on the bottom edge, 512 px WebP.
Their edges were checked on a dark ground and need no matte fix.

| slot | render |
|---|---|
| `pose.celebrating` | Joyful … Leap |
| `pose.victory` | Joyful … Leaping |
| `pose.explaining`, `pose.curious` (and `speaking`, via its fallback) | Surprised |

Not used, on purpose:

- **Sad, Worried, Fierce.** The obvious home is `pose.encouraging`
  ("Presque"), but the design's Decision Log never lets a wrong answer
  look like disappointment: amber, never red, no hearts lost. A fox that
  looks sad or worried at a six-year-old's mistake is that same signal in
  a face. `pose.encouraging` stays on the default pose plus the sway, and a
  test pins it. Using these needs Hafid's explicit call.
- **Joyful … Leaping (1).** It has a checkerboard baked into its pixels
  and no alpha.

**Known mismatch:** the new renders are a different take on the fox from
the waving `pose-default` (cream fur, rounder face, different ears). The
fox therefore changes look when it hops and changes back when it lands.
A neutral, idle render in the new style for `pose.default` (and
`pose.idle`) would close the gap. That is the next pose worth asking for.

## Not done

- `BreathingMascot` (Village, Carte, Aide, the welcome screen) is still a
  separate widget showing the app's own copy of the same image. Moving
  those screens onto `BitmapCharacterView` is the app session's call. It
  would give them the same swappable art. A screen with no director can
  show a fixed reaction by passing a `CharacterActorState` directly.
- `XpPop` isn't placed anywhere yet. The shell's XP chip is in
  `engines_core`, which the Engines session owns.
- Not checked in a live browser from this session. The manager rebuilds
  the :8080 preview.
