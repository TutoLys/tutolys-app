# 0126 — The 3D village inside the app (Option A)

Date: 2026-11-10 · Status: accepted (Hafid, via the Manager: "implement the
new village in the app and make sure everything is connected, tested and
working")

## Context

The 3D village prototype (`Platforms/codex/village-3d/`, Three.js r170,
vendored) is a standalone web page. `INTEGRATION.md` there sets out four ways
to bring it in; Hafid chose **Option A**: embed the web scene, web first,
Linux desktop next through a WebView, the 2D village as the fallback.

## Decisions

1. **Flutter owns data, navigation, words and theme.** The scene draws and
   reports taps. Everything it shows comes over the bridge: buildings with
   the real `subjectProgressProvider` figures, the sign, the fox's line,
   reduced motion, and a `strings` map in the app's language.
   `village_bridge.dart` is the contract; `BRIDGE.md` in village-3d is its
   other half. Every message carries `v: 1`; another version is ignored.

2. **The scene is never trusted to navigate.** `open` only reaches
   `onOpenSubject` for a code the app sent, on a live building. Any other
   message type is ignored. On web, messages are taken only from the
   iframe's own window and this origin, and replies go to this origin, never
   `*`.

3. **The 2D village is the floor, and it is what loads.** It stays on top of
   the scene until the scene says `ready`, so a device that can't run 3D
   never sees an empty box. It takes over for good, for the rest of the run,
   when the scene says `unavailable` (no WebGL), when its settled frame rate
   is under 40 fps, or when it hasn't answered within 20 s. Below
   `_sceneMinWidth` (900 px) nothing changes: the phone layout has no scene,
   2D or 3D.

4. **A Réglages toggle, « Village en 3D »**, off by default (see the
   ruling below), under
   Expérience next to « Réduire les animations ». Per kid, like every other
   setting (ADR 0014). Turning it off drops a running scene at once.

5. **Pause.** The scene gets `pause` when the Village tab is hidden
   (`Visibility.of`, the `IndexedStack` rule) or the app leaves the
   foreground (`AppLifecycleListener`), and `resume` when both are back. A
   frame rate measured while paused is ignored.

6. **Reduced motion** is `MediaQuery.disableAnimations`, which already ORs
   the app setting with the OS. The scene ORs it again with the browser's
   `prefers-reduced-motion`: either side can add a reason, neither removes
   one.

7. **Offline.** The bundle is copied into `assets/village3d/` by
   `tool/sync_village3d.sh`, which refuses any file that loads from another
   origin. No CDN, nothing fetched at runtime.

8. **Linux is 2D only.** It has no 3D path at all: the io channel factory
   returns null, so the host always shows the 2D village there, whatever
   the toggle says. The only WebKitGTK embedder on pub.dev
   (`webview_all_linux`) was not taken. Its uploader is unverified and
   its user base is small. It needs `libwebkit2gtk-4.1-dev` and
   `libsoup-3.0-dev` installed on the build machine with sudo. It also
   draws as a GTK overlay above the Flutter view, so a Flutter dialog or
   sheet opened over the Village would sit underneath the scene.

## Ruling (Hafid, 2026-11-10)

"Everything keeps the 2d for now, but get ready to swap and improve in the
app when the 3D is ready!!"

- **The 2D village is the default on every platform, web included.**
- **The swap is one line:** `village3dDefaultOn` in
  `lib/data/local_db/app_settings.dart`, false today. It is the toggle's
  default. Set it to true when Hafid says the 3D is ready. Only a setting a
  kid changed is stored (`writeChanges`, ADR 0125), so the new default
  reaches every kid who never touched the toggle. A kid who turned it on
  already sees 3D on web today.
- `village3dBundled` (in `village_channel.dart`) only says the bundle is in
  the assets. It is not the swap.

## Consequences

- `village_channel.dart` picks the platform with a conditional import; tests
  override `villageSceneChannelFactoryProvider` with a fake, so the whole
  host is tested on the VM (`test/village3d_test.dart`).
- `village3dBundled` stays false until a bundle that speaks the bridge is in
  the assets.

## Bundle and size (2026-11-10)

- `village3d-2026.11.10` from village-3d's `dist/`: 47 files, 7.45 MB, every
  file checked against `MANIFEST.json`'s sha256. The sync script skips
  comment lines in its CDN check, because three.js documents CDN usage in
  comments.
- **Web build: +7.8 MB on disk** (`build/web-preview` 66.6 → 74.5 MB). The
  first load is unchanged. Flutter web fetches assets on demand, and the
  iframe only loads them when the toggle is on, so a kid on the 2D default
  downloads none of it.
- **Linux: +0.** The assets are declared `platforms: [web]`. The profile
  bundle has no `assets/village3d/`.

## Live verification (2026-11-10)

All of this ran against the dev-stack on :8080 (profile build of 5de3c8c),
with a QA kid seeded with 12 real mastery rows in MATH and FR. Screenshots
are in `Platforms/qa/out/village3d-2026-11-10/` (git-ignored).

- **The 3D path** ran in headless Chromium on the machine's real GPU (ANGLE
  Vulkan, AMD Radeon), with the toggle on.
  - The scene sent `loading`, `ready`, then `perf`, at 60 fps.
  - Its pills carried the real figures: Mathématiques 12/100, Français 2/100,
    the rest « À découvrir ».
  - Tapping the Science pill sent `open`, and the app opened the Carte on
    Science et techno.
  - Switching to Quêtes paused the scene: its frame counter stayed at 663 and
    `running` was false. Coming back resumed it.
  - In English, `<html lang>` was `en`, and the stage, every pill and every
    camera button read in English.
- **The fallback** ran in the same Chromium with `--disable-3d-apis`, toggle
  on. The scene sent `loading` then `unavailable:webgl`, the iframe was
  removed, and the 2D village showed. The built-in pane (WebGL off) loads the
  app, but its input stopped responding after the SharedWorker workaround, so
  this run stands in for it.
- **The default**: a freshly paired kid in the WebGL Chromium got the 2D
  village, with no iframe.
- **Linux**: the profile build runs; its boot log reaches `session_restore
  ok`. No screenshot could be taken: GNOME Wayland blocks XWayland grabs, and
  Flutter's screenshot under Impeller isn't supported. Its 2D-only behaviour
  holds by construction: the io channel factory returns null, and the host
  test covers a null channel.

## Known gaps on the scene side (sent to village-3d)

- At the app's scene size (about 845 × 505), the pills show names only, not
  the progress figure, and they crowd.
- The fox's bubble covers the pills in the middle.
- Three signposts are painted in French (BRIDGE.md).
- `hasLessons: false` (ESL/FLS with no lessons yet) has no scene state. Those
  buildings show as live with their progress, where the 2D village says
  « Bientôt ».

## Ruling, second (Hafid, 2026-11-10): 3D everywhere

"Whenever the app is ready, implement the 3d village everywhere." This
supersedes "2D for now".

- **`village3dDefaultOn` is true** (6975361). A kid who never touched the
  toggle gets the 3D village wherever the device can run it. The toggle
  stays, and so do the fallbacks: no WebGL, no answer in 20 s, or a frame
  rate under 40 fps confirmed twice (below).
- **Phones** (below 900 px) get the scene too:
  - order: « Continuer » first (A6), then the scene, then the quests;
  - the scene is portrait (1.45 × its width, at most two thirds of the
    screen), as the scene's phone camera is framed;
  - the fox's bubble carries the greeting, the pills carry the progress;
  - a still placeholder holds the place while it loads, with no spinner
    under reduced motion;
  - if the scene fails, today's 2D phone layout returns.
- **Signposts** (bundle `village3d-2026.11.10.3`) are strings. The FR and
  ESL buildings keep their own language, like their lessons (ADR 0023).
  CCQ's sign follows the app.

## Bugs found live and fixed

- **A tap into the scene paused it** (11e8e7c). On web, focus moving into
  the iframe blurs the page, which Flutter reports as `inactive`. Only
  `hidden`, `paused` and `detached` count as background now.
- **Dialogs over the scene couldn't be clicked, and didn't pause it**
  (c1e0247). The iframe took every click over its box, including the
  parent-NIP dialog's. That dialog sits on the root navigator, out of
  `ModalRoute.of`'s sight from the nested router. Fixed two ways:
  - `RootCoverObserver` on the root navigator;
  - the iframe takes pointer input only when the scene is ready and
    nothing covers it. While the scene loads, taps reach the 2D village
    drawn over it.
- **One false frame rate dropped the scene** (5f94fbf). A scene that loaded
  under a dialog reported `perf` with `fps: 0`. A low `perf` now only raises
  doubt: after 3 s of unbroken running the host sends `getStats`, and only
  that reply can fall back. This was reported to village-3d.
- **Phone pills piled up** in a near-square box (4c6327a): the scene is now
  portrait.

## Linux: option (a), staged

`packages/village_webview_linux` (147d747) wraps `webview_all_linux` 1.5.0.

**Review of the plugin's 1.5.0 source:**
- MIT licence. About 10.5 k lines of Dart and C++ against WebKitGTK 4.1.
- No `system`, `popen`, `g_spawn`, `exec` or `Process` anywhere.
- No hard-coded outside hosts and no telemetry.
- Its own resource server binds `InternetAddress.loopbackIPv4:0`.
- Developer tools open only on an explicit `openDevTools` call.
- `loadFlutterAsset` normalises the path and refuses one that leaves
  `flutter_assets`.
- The uploader is still unverified, so the version is pinned exactly
  (`1.5.0`, not `^`).

**How the package works:**
- The bundle is served by its own `VillageAssetServer`, because WebKit
  won't load ES modules from `file://`. It binds 127.0.0.1 on a random port
  and puts every path under a 128-bit token. It answers GET and HEAD only,
  and no path or symlink can escape the bundle. Five VM tests cover this.
- Messages go out through the `VillageHost` JavaScript channel and come in
  through `window.villageReceive`, with the payload double-JSON-encoded.
- Navigation is locked to the loopback origin.
- The GTK view draws above Flutter (`drawsAboveFlutter`). While a dialog,
  sheet or page covers the Village, the host takes it off screen and shows
  the 2D village in its place.

**Why it isn't wired in yet:** the plugin's CMake has
`pkg_check_modules(WEBKIT REQUIRED webkit2gtk-4.1)`. Adding it to the app
before the headers exist would break `flutter build linux`. Until then,
Linux builds and runs with the 2D village; at 147d747 it reaches
`session_restore ok`.

**Switch steps, once Hafid has run**
`sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev`:
1. In the app's `pubspec.yaml`, add `village_webview_linux: path:
   packages/village_webview_linux`, and add `linux` to the `village3d`
   asset entries' `platforms` (this adds 7.45 MB to the Linux bundle).
2. Make `village_channel_io.dart` return an adapter: on
   `Platform.isLinux`, `villageScenePlatform` is true, `messages`, `send`
   and `dispose` forward to `LinuxVillageView`, `buildView()` is
   `view.build()`, `drawsAboveFlutter` is true, and `setInteractive` does
   nothing (the view is lifted instead).
3. Run `flutter build linux`, and check live that loading, ready, a tap,
   pause and the lift under a dialog all work.

## Live verification, second pass (2026-11-10, :8080 at 5f94fbf / 4c6327a)

Headless Chromium on the real GPU (ANGLE Vulkan), fresh QA kids, real
mastery. Screenshots are in `Platforms/qa/out/village3d-2026-11-10/`.
- **Desktop default** (`web-default-3d-desktop.png`): a freshly paired kid
  gets the 3D village with an untouched toggle.
- **The parent-NIP dialog at first pairing**
  (`web-dialog-over-3d-paused.png`): the scene paused at 7 frames, and the
  iframe's `pointer-events` was `none`. « Plus tard » dismissed the dialog.
  The scene resumed and was interactive again; its `perf: 0` was rechecked
  at 60 fps and it stayed 3D.
- **Phone, 390 × 844, touch** (`web-phone-3d.png`,
  `web-phone-tap-to-carte.png`): portrait scene at 60 fps (quality 1, DPR
  1.5). All seven pills carry real figures. A touch tap on Science opened
  the Carte on Science et techno.
- **Size:** the web build is 74.5 MB, with the bundle at 7.6 MB (+7.8 MB
  over the 2D build). The bundle is fetched only once Village opens with
  3D. Linux is +0 until the switch, then +7.45 MB.

## Known gaps

- **Scene side (sent to village-3d):**
  - on a phone the pills stack in the sky above the island, not by their
    buildings;
  - the pills are 34 px tall in the app's iframe, where the scene says 40
    on touch;
  - `perf` is measured across a pause;
  - `hasLessons: false` has no pill state.
- The built-in pane can't exercise the 3D path (WebGL off), and its input
  stops after the SharedWorker workaround. The no-WebGL fallback was proven
  with `--disable-3d-apis` instead.
- **No Linux screenshot.** GNOME Wayland blocks grabs, and Flutter's own
  screenshot isn't supported under Impeller.

## Real weather, daytime light, « leçons bientôt » (b96a9a5, bundle .6)

- **Weather** (Hafid: "we need to follow the real weather"):
  - The app reads `GET /api/v1/me/weather` with the device token. The
    backend picks a coarse region and never uses the kid's location.
  - It asks when the Village comes on screen, at most once every 10 min,
    then every 30 min while it stays there. It asks only where the 3D scene
    shows, and never while the Village is hidden.
  - The last observation is kept per kid in `app_state`, so it holds
    offline. A 204, 404, offline answer or malformed body changes nothing.
  - The scene gets it as `weather` and judges freshness itself (3 h). A
    missing or stale observation gives a calm sky for the season.
  - On 2026-11-10 the endpoint still 404s on the dev-stack, so the scene
    shows a calm sky. Backend will say when it's live.
- **Daytime only**: live light is held between 7:00 and 20:00 by the scene
  (Hafid's choice).
- **`soon`**: each building says whether it has lessons yet. Its pill says
  « Bientôt », and the building still opens its Carte. 25 strings go over
  in FR and EN.

**Live, final pass** (:8080 at b96a9a5; `final-*.png` in
`Platforms/qa/out/village3d-2026-11-10/`):
- **Desktop**: 3D by default at 62 fps. Pills carry figures and French aria
  labels. The scene pauses on Quêtes and resumes on the Village. Tapping
  Mathématiques opens the Carte on Mathématiques.
- **Phone, 390 px touch**: 60 fps. The pills sit by their buildings,
  40 px tall. A tap on Français sent `open`.
- **Open on the scene side**: the fox's bubble receives the greeting but
  stays `is-hidden`.

## Linux switched on (2026-11-10, after Hafid's apt install)

WebKitGTK 2.52.6 and libsoup 3.6.6 headers are present. The three switch
steps are done:
1. `village_webview_linux` is in the app's pubspec. The `village3d` asset
   entries are `[web, linux]`, so the Linux bundle carries the 7.45 MB.
2. `village_channel_io.dart` hosts the scene on Linux. Its adapter draws
   above Flutter, so the host lifts it under dialogs; `setInteractive` does
   nothing. It stays off under `flutter test`, because the VM runs on Linux
   but has no WebView plugin.
3. `flutter build linux --profile` builds; `libwebview_all_linux_plugin.so`
   and `assets/village3d/` are in the bundle.

**Live** (`integration_test/village3d_linux_test.dart`, `flutter test
integration_test/village3d_linux_test.dart -d linux`): the real WebKitGTK
view, the real loopback server and the bundled scene, driven through
`VillageSceneHost`. It passes.
- The scene sends `loading`, `ready`, then `perf`, at 56.8 fps.
- The pills carry the figures sent (62/100, 2/100, « À découvrir »).
- A click on the Mathématiques pill inside WebKit reaches `onOpen('MATH')`.
- A hidden tab pauses it: frames held at 270, `running` false. It resumes
  when shown again.
- A dialog lifts the native view off screen (the 2D village stands in) and
  pauses it. When the dialog closes, the view returns, running, with no
  `unavailable`.

Flutter's gestures can't reach inside a native WebView, so the click and
the frame counter go through `LinuxVillageView.evaluate`, which is
`@visibleForTesting`. A screenshot of the real app needs Hafid's Print
Screen, because this desktop blocks programmatic grabs.
