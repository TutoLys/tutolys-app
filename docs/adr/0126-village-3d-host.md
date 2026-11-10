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
