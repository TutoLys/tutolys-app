# ADR 0127 — Every platform, for the investor demo

- Status: accepted
- Date: 2026-11-10
- Asked by: Hafid, through the Manager: "build everything for all the
  platforms (mobile, linux, windows, macos and web), make sure we're ready
  to show our product to the investors".

## Context

The app had two platform folders, `linux/` and `web/`. The interview of
2026-10-24 already said "all of them eventually, desktop and web first,
mobile a polish pass". The demo moves the rest forward. This machine is
Linux, has no Mac, and has no CI. Hosting (#5) and Windows distribution
(#9) are still open.

## Decision

1. **`flutter create --platforms=android,ios,macos,windows`**, named
   TutoLys everywhere, with the real icon on all of them and the splash
   on Android and iOS (`flutter_launcher_icons` and `flutter_native_splash`
   config in `pubspec.yaml`). Ids follow the Linux build:
   `ca.tutolys.tutolys_app` on Android, `ca.tutolys.tutolysApp` on Apple
   platforms (no underscore allowed there).

2. **The 3D village runs on every native platform**, in a WebView over
   the same hardened loopback server as Linux (ADR 0126):
   - Android, iOS, macOS: the official `webview_flutter`;
   - Windows: WebView2 through `webview_all_windows` 1.5.0, the same
     author and `webview_platform_interface` as the Linux plugin ADR 0126
     reviewed. Pinned exactly. Its CMake fetches `nuget.exe` (hash
     checked) and the WebView2 SDK at build time.

   `VillageAssetServer.startWith` serves from a loader, because on
   Android the scene lives inside the APK, not on disk. A bad path is
   refused before the loader runs. These WebViews are composited inside
   Flutter, unlike Linux's GTK layer, so `drawsAboveFlutter` is false and
   `setInteractive` is an `IgnorePointer`. Anything that fails keeps the
   2D village through the host's ready timeout and fps checks.

3. **Cleartext HTTP is allowed only where the demo needs it.**
   - Android: the default network security config allows cleartext only
     to 127.0.0.1/localhost (the village server). A build with
     `TUTOLYS_DEMO_LAN=1` swaps in `network_security_demo_lan.xml`,
     cleartext to any host, for a laptop's dev-stack over the LAN.
     `tool/build_demo.sh` sets it for the APK. **Never publish that APK.**
   - iOS: `NSAllowsLocalNetworking` plus a local-network usage string.
   - macOS: network client and server entitlements (the loopback server
     binds a socket), and the empty `keychain-access-groups` that
     `flutter_secure_storage` asks for.

4. **Platform fixes found on the way.** Android release lacked
   `INTERNET` (the template grants it in debug and profile only), the
   reminders' permissions and receivers, and the core-library desugaring
   `flutter_local_notifications` requires. On Windows the notification
   plugin threw without `WindowsInitializationSettings`, so reminders
   were silently off there; it now gets an app name, an app user model
   id and a fixed GUID.

5. **Builds.** `tool/build_demo.sh HOST` builds Linux release, web
   release and an APK from a clean worktree of HEAD (other sessions'
   uncommitted edits never reach a demo build), pointed at
   `http://HOST:8000` and `:8001`. The release guard still refuses
   loopback, on purpose.

6. **CI for what Linux can't build**, `workflow_dispatch` only, never on
   push, so nothing is billed until someone presses Run:
   `demo-windows.yml` (windows-latest) and `demo-apple.yml` (macos-latest,
   macOS and iOS as separate opt-in jobs). iOS is a debug simulator app
   plus an unsigned `--no-codesign` device build until there is an Apple
   Developer account. Inputs reach the shell as env variables, never
   pasted into a script. Committed, not pushed.

## Not decided here

- Distribution: no updater, signing purchase or store submission. #9
  stays open. Android signs with the debug key.
- Hosting (#5): the demo points at a laptop's dev-stack.
- The 3D village on Android, iOS, macOS and Windows has not run on a
  real device or VM from this machine. The Android build compiles and
  packages; the rest are verified by CI only once Hafid runs it.

## Consequences

- `pubspec.yaml` ships `assets/village3d/` on all six platforms (about
  25 MB more per native build).
- Every native platform now depends on a WebView being present: system
  WebView on Android, WKWebView on Apple, WebView2 on Windows (present
  on Windows 10/11 by default).
- `docs/INVESTOR_DEMO.md` is the operating sheet for the demo.
