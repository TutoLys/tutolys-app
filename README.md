# tutolys-app

Kid-facing TutoLys app. One Flutter codebase for desktop, mobile and web.

> The app knows nothing about organizations, billing or tutors. A kid is a kid.

## Running

```bash
flutter pub get
flutter run -d chrome                      # web
flutter run -d linux                       # desktop (see prerequisites)
flutter test
```

The backend address defaults to `http://127.0.0.1:8000` (the dev-stack).
Override it at build time:

```bash
flutter build web --dart-define=TUTOLYS_API_BASE=https://api.tutolys.ca
```

### Linux desktop prerequisites

```bash
sudo apt install clang ninja-build libgtk-3-dev libsecret-1-dev
```

`libsecret-1-dev` is easy to miss: the Flutter toolchain check passes without
it, and the build only fails at CMake time. It is needed because the device
token is stored in the real system keyring via `flutter_secure_storage`, and
libsecret *is* the Linux keyring. That is the point — a long-lived credential
on a child's device does not belong in shared preferences.

Web builds need nothing extra.

## Layout

```
lib/
  core/      theme wiring, i18n, routing shell, responsive helpers
  features/  pairing, path, play, settings
  data/      api clients, local storage, sync
packages/
  design_system/  brand tokens, themes, shared widgets — Flutter only
  engine_sdk/     the engine contract: registry, context, telemetry client
  engines_core/   the launch engines
```

**The dependency rule that pays for itself:** engines depend on `engine_sdk`
and `design_system` only — never on the app, the API client or the database.
The Godot games had that property (they held no credentials and never talked to
Django) and it is worth keeping.

## Things that are deliberate

- **French first.** `fr-CA` is the default locale, not a fallback. A missing
  French string is a bug.
- **One widget tree per screen**, with breakpoints. Presentation adapts;
  logic is never forked per platform.
- **Pairing errors are specific.** "No internet" and "wrong code" get different
  words — a child told the code is wrong when the Wi-Fi is off will retype a
  code that was never the problem.
- **Offline never un-pairs the device.** Only a server rejection does. Dropping
  the credential on a Wi-Fi blip would force a parent to generate a new code
  every time and would break offline play.
- **Reduce-motion is honoured.** The mascot stops breathing when the platform
  asks for less motion — an accessibility requirement, and the reason widget
  tests can settle at all.
- **Only the code alphabet is accepted** in the pairing field. A mistyped `O`
  or `1` visibly does not appear rather than being silently remapped.
