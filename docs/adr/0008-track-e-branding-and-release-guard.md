# ADR 0008 — Real app icon/manifest/splash, release-build fail-fast guard

Date: 2026-10-23
Status: accepted

## Context

`GO_LIVE_CHECKLIST.md` Track E, two items: the app's web icons, PWA
manifest, and window title were all unmodified Flutter scaffold defaults
(`web/manifest.json` literally said `"A new Flutter project."`, default
Flutter-mascot icons); and release builds silently default to
`http://127.0.0.1:8000`/`:8001` if `--dart-define` is forgotten, with no
CI yet to catch it (`GO_LIVE_CHECKLIST.md` Track C, still open). Mobile
(Android/iOS) is explicitly out of scope for this pass — Hafid's call to
keep it build-ready but not deploy it yet — so nothing here touches
platform targets beyond web (and, for the window title only, Linux).

## Decisions

**A new square icon, composited from the existing fleur-de-lys brand
asset** (`reference/brand/fleur-de-lys-256.png`, the same first-party mark
already used for the backend admin's favicon) centered on the brand's
Quebec-blue (`#1F3C88`). Two variants: a regular icon and a more
heavily-padded maskable one (`assets/icon/icon_maskable.png`) so a
platform's circular/squircle crop never clips the mark. Composited with
Pillow (one-off script, not a checked-in build step — the source PNGs are
the committed artifact).

**`flutter_launcher_icons`/`flutter_native_splash`, scoped to web only**
via each package's own per-platform config flags. Linux has no
Flutter-tooling icon pipeline (its window icon, if ever added, would be
set directly in `linux/runner/my_application.cc`, not generated); mobile
isn't a build target yet. Both packages' pub.dev-listed "latest compatible"
versions resolved absurdly old (`flutter_launcher_icons 0.9.3`,
`flutter_native_splash 2.2.16` — the former's config schema predates the
`flutter_launcher_icons:` key name this ADR's own config uses) — pinned to
current major versions explicitly (`^0.14.4`/`^2.4.6`) rather than
accepting the resolver's conservative default.

**Real `web/manifest.json` (name, description, theme/background color) and
`web/index.html` (title, description, apple-mobile-web-app-title) edited
by hand** — neither generator touches these fields, only the icon/splash
assets and `<link>`/`<meta>` tags that reference them.

**A release-build fail-fast guard** (`lib/core/startup/
release_config_guard.dart`), checked first thing in `main()`, before
`WidgetsFlutterBinding.ensureInitialized()`: if `kReleaseMode` is true and
either `apiBaseUrl` or `telemetryBaseUrl` still matches a loopback host
(`127.0.0.1`/`localhost`), it throws with a message naming exactly which
`--dart-define` is missing. Same fail-fast posture as the backend's own
`config.settings.production` guards (`SECRET_KEY`, `ALLOWED_HOSTS`) —
raise at the earliest possible moment, loudly, with a message that says
what to fix, rather than silently shipping a build that can never reach
anything real. Pure function, not inlined in `main()`, specifically so it
is unit-testable without needing a running app.

## Verified

7 new tests (`test/release_config_guard_test.dart`): no-op outside
release mode regardless of config, no-op in release mode with real URLs,
throws naming the right `--dart-define` for each of API-only /
telemetry-only / both misconfigured, catches `localhost` as well as the
IP literal, and confirms a real host that merely contains the substring
`"localhost"` isn't false-flagged. Full suite green (132 tests, was 125),
`flutter analyze` clean.

Icons/manifest/splash verified two ways: `flutter build web` (the
documented pattern for this project — `flutter run -d web-server` doesn't
call `main()` without a DWDS handshake, per ADR 0003) produced a real
`build/web/manifest.json` with the right name/colors, served it, and
confirmed via `curl` and reading the generated PNGs directly that the
title, description, favicon, and splash image are all the real branded
versions, not scaffold defaults.

The release guard's logic itself is proven by its unit tests. A live
browser crash/no-crash comparison was attempted (`flutter build web
--release` both with and without the real `--dart-define`s, served
statically, checked whether the splash screen was removed) but was
inconclusive: *neither* build progressed past the splash screen in this
sandbox, the same first-frame-never-renders limitation ADR 0003 already
documented as environment-specific, not code-specific. Not claimed as
visually verified in a browser; the unit tests are the real proof here.

## Not done

Linux desktop has no generated icon (its window icon was never set to
begin with — out of scope, and Linux/Windows *distribution* packaging is
tracked separately as still-open item #9). Mobile icons/splash: not
started, deliberately, per Hafid's call. Crash reporting (Sentry) needs a
real account/DSN from Hafid. The font-loading-offline tradeoff (ADR 0004)
remains genuinely undecided. The outbox local-storage growth cap
(`GO_LIVE_CHECKLIST.md` Track E's last item) was deliberately not
attempted here — it would need to either contradict or qualify
`OutboxFlusher`'s own stated "never silently drop an event" design
principle, which isn't an engineering default to make unilaterally.
