/// Fails loudly, at startup, if a release build is still pointed at
/// localhost.
///
/// `apiBaseUrl`/`telemetryBaseUrl` are `--dart-define` values with a
/// loopback default (so local debug runs work with zero flags) — the same
/// property that makes a *forgotten* `--dart-define` on a real release
/// build fail silently instead of loudly: the app just never reaches
/// anything real for any actual user, and nothing else would ever say why.
/// No CI exists yet to catch this before it ships
/// (`GO_LIVE_CHECKLIST.md` Track E). Same fail-fast posture as the
/// backend's own `config.settings.production` guards (`SECRET_KEY`,
/// `ALLOWED_HOSTS`) — raise at the earliest possible moment, with a message
/// that says exactly what to fix.
void assertReleaseConfigIsReal({
  required bool isReleaseMode,
  required String apiBaseUrl,
  required String telemetryBaseUrl,
}) {
  if (!isReleaseMode) return;

  final misconfigured = <String, String>{
    if (_isLoopback(apiBaseUrl)) 'TUTOLYS_API_BASE': apiBaseUrl,
    if (_isLoopback(telemetryBaseUrl)) 'TUTOLYS_TELEMETRY_BASE': telemetryBaseUrl,
  };

  if (misconfigured.isEmpty) return;

  final detail = misconfigured.entries
      .map((entry) => '${entry.key} (currently "${entry.value}")')
      .join(', ');
  throw StateError(
    'Release build still points at localhost: $detail. This would silently '
    'fail for every real user — pass --dart-define for each at build time '
    'rather than removing this check.',
  );
}

final _loopbackHost = RegExp(r'^https?://(127\.0\.0\.1|localhost)(:\d+)?/?$');

bool _isLoopback(String url) => _loopbackHost.hasMatch(url);
