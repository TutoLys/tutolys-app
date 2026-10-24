# ADR 0012 — Real brand icon everywhere, including a real Linux window icon

Date: 2026-10-24
Status: accepted

## Context

Hafid supplied a new brand mark — `Arctic Fox Fleur-de-lis Emblem` — and
asked for it as the icon across every app in the stack. On this repo
that means the web app icon/manifest/splash (ADR 0008's existing
pipeline, just new source art) and, it turned out while doing this,
closing a real gap ADR 0008 itself didn't catch: the Linux window icon
was never actually wired, despite a comment in `pubspec.yaml` claiming
it was.

## Decisions

**Source art was defringed before use, not dropped in raw.** The
supplied PNG had a bad alpha matte — low-alpha edge pixels carried
strongly saturated yellow/red colors baked in from its own generation
pipeline, invisible against white but a visible fringe against anything
darker. Cleaned once (nearest-opaque-color fill to decontaminate the
edge RGB, then a light blur+resharpen on alpha) and reused as the master
source for the backend and telemetry icons too, not a per-app fix.

**Two padding levels, not one — and `assets/icon/icon.png` had to move
to the more conservative one.** A proper maskable icon needs its content
within roughly an 80%-diameter safe zone so a circular/squircle OS mask
never clips it; a non-masked icon can use less padding without looking
lost. This app's `flutter_launcher_icons` web config, however, has no
separate maskable-source key — both the plain and
`"purpose": "maskable"` entries in `web/manifest.json` are generated
from the same `image_path`. That meant **both** purposes had to share
one padding level, so `assets/icon/icon.png` moved to the safer ~68%
content fill (verified by rendering it inside an 80%-diameter safe-zone
circle and confirming the glyph stays fully inside). This was a latent
risk in the *previous* icon too (its content also touched close to the
canvas edge) — not something this change introduced, but worth fixing
properly while already touching every icon in the repo rather than
reproducing the same gap with new art. `assets/icon/icon_maskable.png`
(the dedicated splash-screen source, a separate asset
`flutter_native_splash` reads on its own) kept its own, similarly
generous padding.

**The Linux window icon is now actually set, closing a stale claim.**
`pubspec.yaml`'s own comment said "the Linux window icon is set directly
in `linux/runner/my_application.cc`" — true of nothing; no such code
existed anywhere in `linux/`. Added a `gtk_window_set_icon_from_file`
call resolving the path via `/proc/self/exe` rather than a bare relative
path: GTK resolves relative paths against the process's current working
directory, not the executable's location, and a desktop launcher isn't
guaranteed to set that to the bundle root. `assets/icon/` is already a
declared Flutter asset, so it ships inside `data/flutter_assets/` next
to the executable in every build — no new bundling step needed, just the
path math to find it reliably. Best-effort: a missing or unreadable icon
logs a warning and leaves GTK's own default rather than failing to
start.

## Verified

`flutter analyze`: 0 issues. Full suite: 151 passed (unchanged — no
logic changed, only asset bytes and the new C++ icon-loading code, which
Dart tests can't exercise). `flutter build linux` compiles clean with
the new `my_application.cc` code, and the built bundle was confirmed to
actually contain `data/flutter_assets/assets/icon/icon.png` at exactly
the path the new code constructs — the furthest this sandbox can verify
a GTK window icon without a display server to screenshot (same
limitation class as every Flutter *web* visual check this session, ADR
0003/0008/0010/0011).

`flutter build web` + a live browser check: confirmed `web/favicon.png`
serves 200 with the new art, confirmed via DOM inspection that
`index.html`'s `<link rel="icon">` resolves to it, zero new console
errors (only the already-documented sandbox WebGL-fallback warning).

## Not done

No mobile launcher icons — mobile stays a non-target, same as ADR 0008.
No regeneration of a `.desktop` file's own icon reference, because no
`.desktop` file exists in this repo to begin with (a packaging/
distribution concern, not reached yet).
