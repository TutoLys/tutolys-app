import 'dart:async';

import 'package:sentry/sentry.dart';

import '../../features/pairing/pairing_controller.dart' show appVersion;
import 'boot_log.dart';
import 'diag_log.dart';
import 'request_id.dart';

/// Where crash reports go: our self-hosted GlitchTip. Empty means crash
/// reporting is **off**, and then nothing below runs at all (ADR 0052).
///
/// Set at build time: `--dart-define=TUTOLYS_SENTRY_DSN=http://<key>@host/3`.
const sentryDsn = String.fromEnvironment('TUTOLYS_SENTRY_DSN');

/// The commit the build came from, when the build script passes it.
const gitSha = String.fromEnvironment('TUTOLYS_GIT_SHA');

String get crashReportRelease =>
    gitSha.isEmpty ? 'tutolys-app@$appVersion' : 'tutolys-app@$appVersion+$gitSha';

typedef SentryInit = Future<void> Function(OptionsConfiguration configure);

/// Starts crash reporting when [dsn] is set; otherwise does nothing, and
/// [init] is never called.
///
/// It reuses the hooks `DiagLog.installHooks` already installed: they
/// forward uncaught errors here through [DiagLog.reporter]. Sentry's own
/// isolate-error hook is removed, so there is one set of hooks, not two.
Future<void> startCrashReporting({
  String dsn = sentryDsn,
  SentryInit init = Sentry.init,
  DiagLog? log,
}) async {
  if (dsn.isEmpty) return;
  final diag = log ?? DiagLog.instance;
  await init((options) => configureCrashReporting(options, dsn: dsn));
  diag.reporter = (error, stack) =>
      unawaited(Sentry.captureException(error, stackTrace: stack));
}

/// Every option that keeps a report free of anything about the child. Kept
/// apart from [startCrashReporting] so tests can assert on it.
void configureCrashReporting(SentryOptions o, {required String dsn}) {
  o
    ..dsn = dsn
    ..release = crashReportRelease
    // Nothing that identifies a person or a device: no IP, no host name,
    // no request headers or bodies.
    ..sendDefaultPii = false
    // No performance tracing: errors only.
    ..tracesSampleRate = null
    ..beforeSend = scrubCrashReport
    ..beforeBreadcrumb = filterBreadcrumb;
  for (final i in o.integrations.whereType<IsolateErrorIntegration>().toList()) {
    o.removeIntegration(i);
  }
}

/// `beforeSend`: no user, no request, no host name or culture; the message
/// and every exception value run through the same scrubber as the on-device
/// log (JWTs, bearer tokens, emails, pairing codes). Adds the tags that
/// link a report to the server's logs and to the boot log.
SentryEvent? scrubCrashReport(SentryEvent event, Hint hint) {
  event
    ..user = null
    ..request = null
    ..serverName = null;
  event.contexts.remove(SentryCulture.type);
  event.contexts.device?.name = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(
      DiagLog.scrub(message.formatted),
      template: message.template == null
          ? null
          : DiagLog.scrub(message.template!),
    );
  }
  for (final e in event.exceptions ?? const <SentryException>[]) {
    final v = e.value;
    if (v != null) e.value = DiagLog.scrub(v);
  }
  final tags = {...?event.tags};
  final requestId = RequestIdInterceptor.lastFailedId;
  if (requestId != null) tags['request_id'] = requestId;
  final boot = BootLog.instance.stuckOn ?? _lastStep();
  if (boot != null) tags['boot_step'] = boot.name;
  event.tags = tags;
  return event;
}

BootStep? _lastStep() {
  final steps = BootLog.instance.steps;
  return steps.isEmpty ? null : steps.last;
}

/// `beforeBreadcrumb`: only navigation (route names) and HTTP (method, path,
/// status) survive. Console, log and anything else is dropped; a URL loses
/// its query and fragment.
Breadcrumb? filterBreadcrumb(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;
  switch (crumb.category) {
    case 'navigation':
      final data = crumb.data ?? const {};
      crumb
        ..message = null
        ..data = {
          for (final key in const ['from', 'to'])
            if (data[key] is String) key: data[key],
        };
      return crumb;
    case 'http':
      final data = crumb.data ?? const {};
      final url = Uri.tryParse('${data['url'] ?? ''}');
      crumb
        ..message = null
        ..data = {
          'url': url?.path ?? '',
          'method': ?data['method'],
          'status_code': ?data['status_code'],
        };
      return crumb;
    default:
      return null;
  }
}
