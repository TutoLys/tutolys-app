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
