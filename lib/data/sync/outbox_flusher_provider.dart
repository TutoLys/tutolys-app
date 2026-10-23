import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pairing/pairing_controller.dart';
import '../api/telemetry_api.dart';
import 'drift_event_outbox.dart';
import 'outbox_flusher.dart';

/// Base URL of the telemetry service.
///
/// A separate deployment from the backend (`apiBaseUrl`), so it gets its own
/// dart-define rather than reusing it. Defaults to the dev-stack address.
/// Overridden at build time with
/// `--dart-define=TUTOLYS_TELEMETRY_BASE=https://telemetry.tutolys.ca`.
const telemetryBaseUrl = String.fromEnvironment(
  'TUTOLYS_TELEMETRY_BASE',
  defaultValue: 'http://127.0.0.1:8001',
);

final telemetryDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: telemetryBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      contentType: 'application/json',
    ),
  );
});

/// `DriftEventOutbox` is stateless aside from the database handle, so one
/// shared instance is enough for every writer and the flusher alike.
final eventOutboxProvider = Provider<DriftEventOutbox>((ref) {
  return DriftEventOutbox(ref.watch(localDatabaseProvider));
});

/// Plain `Provider`, not `autoDispose`: the flusher's own retry timer and
/// `_paused` flag must survive for the app's whole lifetime, not get torn
/// down and rebuilt whenever something elsewhere in the tree stops watching
/// it.
final outboxFlusherProvider = Provider<OutboxFlusher>((ref) {
  return OutboxFlusher(
    outbox: ref.watch(eventOutboxProvider),
    api: TelemetryApi(dio: ref.watch(telemetryDioProvider)),
    // Read per attempt, never captured: a flush may happen long after the
    // token it started with expired.
    accessToken: () => ref.read(sessionControllerProvider).accessToken,
  );
});

/// Same idiom as `sessionAutoRefreshProvider`: production always starts the
/// flusher, but an armed periodic timer fails widget tests' pending-timer
/// check, so tests override this to `false` and drive flushing explicitly.
final outboxFlusherAutoStartProvider = Provider<bool>((ref) => true);
