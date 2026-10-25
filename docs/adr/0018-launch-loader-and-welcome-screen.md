# ADR 0018 — Launch loader and welcome screen

Date: 2026-10-25 · Status: accepted (Hafid: "Go — build it with the defaults as planned")

## Context

Launch was a still image: `flutter_native_splash` drew the emblem on navy,
`main()` preserved it until `AppShell` had restored the session and read
the kid's settings, and the first thing after it was pairing or the
Village. Hafid asked for a launch that feels like opening a children's
adventure game — an animated emblem, a wordmark, a glossy progress bar,
rotating French lines — and a title screen to go with it. Neither screen
exists in the 2026-10-24 design, so this is new design inside that
design's system (navy and Quebec blue, gold pill CTAs, Baloo 2, the real
fox art).

Two facts shaped it:

- **On web, launch has two stages.** Until `main.dart.js` has downloaded,
  only HTML can draw anything. After Flutter's first frame, Flutter can.
- **Flutter's web loader reports no download progress.** A bar that
  fills on a timer would be invented.

## Decision

**One continuous launch, loader → welcome → app, once per cold start.**

1. **Progress is real, and only ever forward.** The bar follows
   milestones, not a clock:
   - HTML stage (`web/flutter_bootstrap.js`): bootstrap running → code
     loaded → engine initialised → app running, up to 60 %.
   - Flutter stage (`LaunchFlow`): session restored → settings read →
     done. These are the same two facts `AppShell` already waited on.
   - Inside a stage the fill creeps toward that stage's end and stops 2 %
     short, so a slow wait still moves and only a real stage change can
     cross the line. `TutolysProgressBar` ignores any lower value than it
     has shown.
2. **No minimum display time.** A fast start is a short loader. The only
   fixed wait is a 0.9 s beat (0.5 s under reduced motion) on
   "Bienvenue dans TutoLys !" once the bar is full, so the line can be read.
3. **The lines are mood; the bar is fact.** The five story lines rotate on
   a timer below 80 %. "Tiens bon, on y est presque…" appears only past
   80 %, "Presque prêt…" only past 92 %, "Bienvenue dans TutoLys !" only
   when startup is done. A timer never shows "almost".
4. **The HTML stage draws the Flutter loader's first frame.** Same layout
   maths, emblem, wordmark, bar and copy. `globalThis.tutolysBoot` hands
   the bar position and the current line to Flutter
   (`boot_handoff_web.dart`), so the hand-over shows no visible change
   except the bar continuing. `AppShell` now removes the native splash on
   Flutter's first frame. The loader, not a still image, does the waiting.
5. **The HTML stage speaks the kid's language.** It runs before Flutter
   and cannot read Réglages, so the app stores the chosen language in
   `localStorage` (`rememberBootLocale`). With nothing stored, the HTML
   stage uses French, the app's default, never the browser's guess.
6. **The welcome screen is a title screen on every cold start.**
   - Paired: "Salut Yelhan !" and **Jouer**, into the Village.
   - Unpaired: an invitation and **Commencer l'aventure**, into pairing.
   - This is the one screen every session passes, so it is where
     "Qui joue ?" belongs once B-A0.4/B-A0.5 land.
   - Signing out or re-pairing later in the same run skips it.
7. **Baloo 2 is bundled** in `design_system/fonts/`. These are static 600,
   700 and 800 instances cut from the exact woff2 the design embeds, under
   the OFL. `VillageType.display` now resolves to that bundled font, so
   every screen that already asked for Baloo 2 gets it. This closes the
   "how delivered" question ADR 0004 left open.
8. **The progress bar is blue → cyan with a gold glint and a gold tip.**
   The brief asked for blue/cyan, and Hafid had asked for gold an hour
   earlier, so the bar uses both.
9. **"Foxy" appears in exactly one string** (`launchMessages[3]`, both
   locales). The mascot has no name in the design, so the name stays a
   one-line change.

### Widgets

Under `lib/features/launch/`, named `Tutolys…` to match `TutolysTheme`
and `TutolysMascot`:

- `TutolysAnimatedLogo`: float, breathe, glow pulse, a shine sweep
  (`ShaderMask` with `srcATop`, so it lights only the emblem) and
  orbiting sparkles.
- `TutolysProgressBar`: the bar described above.
- `TutolysLoadingMessageRotator`: rotates a list of lines. A new list
  starts from its first line.
- `TutolysLoaderScreen` and `TutolysWelcomeScreen`: presentation only.
- `LaunchFlow`: owns the stage → progress mapping, the creep and the
  closing beat.
- `LaunchBackdrop` and `TutolysWordmark`: shared by both screens.

Every loop extends `AmbientLoopState`, which owns one controller and
applies `BreathingMascot`'s two guards. Under reduced motion a loop rests
on a defined frame. When hidden (`Visibility.of`) it stops ticking. Tests
check both with `hasScheduledFrame`.

## Consequences

- Every app-shell test now passes the welcome screen; `pairing_test`'s
  `passLaunch` helper presses its button the way a child would.
- One extra tap per cold start for a paired kid. This was accepted for the
  title-screen feel; the plan named "first run only" as the alternative.
- The HTML stage duplicates the five French and English mood lines from
  `Strings`. Both copies are commented as mirrors; change them together.
- The HTML stage draws no star field, while the Flutter loader does. Stars
  appearing at the hand-over is the one visible seam left.
- The build console shows an opaque `Uncaught Error`. It does not come
  from page JavaScript: a window `error` listener caught nothing. It looks
  like the drift worker's, and pre-existing, but this ADR does not prove
  that.
- Not done: the native desktop splash (Linux has none, and starts fast
  enough), and a Lottie/Rive-quality fox animation. That belongs to the
  animation-system plan (M0–M6); the welcome fox uses `BreathingMascot`.
