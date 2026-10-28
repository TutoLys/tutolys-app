# ADR 0052 — Request ids and crash reports

Date: 2026-10-28
Status: accepted

## Context

This is Observability Phase 2, "know what broke": items A1 and A2 of
`Platforms/OBSERVABILITY_WORKORDER_P2.md`. Hafid's go came through the
Manager. P1 (ADR 0038) already keeps a scrubbed, on-device diag log, fed
by three global hooks: `FlutterError.onError`,
`PlatformDispatcher.onError` and `runZonedGuarded`.

## Decision

### A1 — `X-Request-ID`

`RequestIdInterceptor` is on **both** Dio instances: `dioProvider` (the
API) and `telemetryDioProvider`.

- Each request gets a fresh uuid v4, kept in `options.extra`.
- On a failure (an error, or a status of 400 or more), the interceptor
  records a `http:<service>` entry in the diag log. The entry holds the
  method, the path **without its query**, the status (or "no response"),
  the `request_id` and the error type. It never holds bodies or headers.
- The last failed id is kept app-wide. Crash reports carry it as a tag.

**The web build doesn't send the header yet.** A custom header makes the
browser preflight every request. Neither service lists `X-Request-ID` in
its CORS allow-list yet (work order B1/T1). Until they do, sending it
would fail **every** request from :8080.

So the header is sent:
- always on native builds;
- on web only when built with
  `--dart-define=TUTOLYS_REQUEST_ID_ON_WEB=true`. Turn that on once B1
  and T1 have landed.

The id is made and recorded locally either way.

### A2 — crash reports to our GlitchTip

**Off unless built with `--dart-define=TUTOLYS_SENTRY_DSN=…`.** With no
define, `startCrashReporting` returns before touching Sentry. `init` is
never called and no request goes to GlitchTip. A test pins this.

**The plain Dart `sentry` package, not `sentry_flutter`.** The work order
named `sentry_flutter`; this is a deliberate deviation, for three reasons:

- **The Linux build.** `sentry_flutter` builds sentry-native, with
  Breakpad, through CMake `FetchContent` from GitHub. Every
  `flutter build linux` would download and compile native crash code, even
  with no DSN. That is a network step at build time and a native crash
  handler on the child's machine, neither of which the work order asked
  for.
- **The web build.** `sentry_flutter` hands web events to the Sentry
  JavaScript SDK. The plain package posts the envelope itself, with no
  extra script.
- **What it can't do, it can't leak.** The plain package has no
  screenshots, no view hierarchy, no user-interaction breadcrumbs and no
  automatic performance tracing. The options the work order asks to turn
  off (`attachScreenshot`, `attachViewHierarchy`,
  `enableUserInteractionBreadcrumbs`, `enableAutoPerformanceTracing`)
  don't exist in it.

**Options** (`configureCrashReporting`, asserted in tests):
- `sendDefaultPii` false, which also keeps the host name off device
  contexts;
- no tracing;
- `release` is `tutolys-app@<version>`, plus `+<sha>` when the build passes
  `TUTOLYS_GIT_SHA`;
- `setUser` is never called.

**`beforeSend`** (`scrubCrashReport`):
- drops the user, the request, the server name and the culture context,
  and blanks the device name;
- runs the P1 scrubber over the message and every exception value. That
  scrubber removes JWTs, bearer tokens, emails and pairing codes;
- tags the report with `request_id` (the last failed request) and
  `boot_step` (where boot is stuck, or else the last step).

**`beforeBreadcrumb`** (`filterBreadcrumb`) keeps only two kinds:
- **navigation**, reduced to `from` and `to` route names;
- **http**, reduced to the method, the path (no query or fragment) and
  the status.

Everything else is dropped, including console and log breadcrumbs. Only
the interceptor adds HTTP breadcrumbs, and only while crash reporting is
on.

**One set of hooks.** The P1 hooks forward uncaught errors (`flutter`,
`platform`, `zone`) to Sentry through `DiagLog.reporter`. Caught errors
and HTTP entries stay local. Sentry's own `IsolateErrorIntegration` is
removed. No zone is added, because no `appRunner` is passed. A reporter
that throws can't break the hooks.

## Consequences

- **Compared with the privacy addendum** (`ADDENDUM_CRASH_DIAGNOSTICS.md`):
  - It matches: the error type and stack, the app version, and the OS and
    device model.
  - It sends less than the addendum allows: no culture context (locale and
    time zone), and no device name.
  - No navigation breadcrumbs exist yet, because nothing records route
    names. The filter is in place for when something does.
- Until `TUTOLYS_REQUEST_ID_ON_WEB` is set, the web build can't correlate
  a failure with the server's log line. Native builds can.
- Tests:
  - `test/request_id_test.dart`: the header and uuid v4 format, a failure
    recorded without its query or body, a transport error, and the
    no-header mode.
  - `test/crash_reporting_test.dart`: no DSN means no init; the options;
    the isolate hook removed; `beforeSend` stripping a JWT, an email, a
    pairing code and the user; `beforeBreadcrumb` dropping console and
    reducing HTTP and navigation; hooks forwarding only uncaught errors;
    a failing reporter.
