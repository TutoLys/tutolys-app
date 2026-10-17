import 'dart:async';
import 'dart:math';

import '../api/telemetry_api.dart';
import 'drift_event_outbox.dart';

/// Uploads queued events, and keeps trying until they land.
///
/// The contract it has to honour: **never drop an event silently**. The product
/// is the data — an event that vanishes is a gap in a tutor's report that
/// nobody will ever notice. So every outcome is accounted for: delivered rows
/// are cleared, transient failures back off and retry, and events the server
/// will never accept are surfaced rather than quietly deleted.
class OutboxFlusher {
  OutboxFlusher({
    required this.outbox,
    required this.api,
    required this.accessToken,
    this.batchSize = 50,
    this.interval = const Duration(seconds: 30),
    this.maxAttempts = 10,
    Random? random,
    DateTime Function()? clock,
  })  : _random = random ?? Random(),
        _now = clock ?? DateTime.now;

  final DriftEventOutbox outbox;
  final TelemetryApi api;

  /// Supplies the current access token. A flush may happen long after the
  /// token it started with expired, so this is read per attempt rather than
  /// captured once.
  final String? Function() accessToken;

  /// Upload trigger: this many events, or [interval] elapsed. Matches plan
  /// §5.8 — 50 events or 30 seconds.
  final int batchSize;
  final Duration interval;

  /// After this many failures an event is reported as stuck rather than
  /// retried indefinitely. It is still never deleted.
  final int maxAttempts;

  final Random _random;
  final DateTime Function() _now;

  Timer? _timer;
  bool _flushing = false;

  /// Set when the credential is rejected, so a flusher does not spin against
  /// a revoked device. Cleared by [resume] once the app re-pairs.
  bool _paused = false;

  bool get isPaused => _paused;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    _paused = false;
  }

  /// Called when the app goes to the background or is closing.
  ///
  /// The last events of a session are the most interesting ones — an abandoned
  /// exercise, a run of wrong answers — so they must not wait for the next
  /// tick that may never come.
  Future<void> flushNow() => flush();

  /// Upload what is pending. Safe to call concurrently: overlapping calls
  /// return immediately rather than double-sending.
  Future<void> flush() async {
    if (_flushing || _paused) return;
    _flushing = true;

    try {
      final token = accessToken();
      if (token == null || token.isEmpty) {
        // Not paired yet, or mid-refresh. Events stay queued.
        return;
      }

      // One batch per call. Draining everything in a loop would mean a device
      // returning from a week offline blocks startup; the timer picks up the
      // rest.
      final batch = await outbox.pending(limit: batchSize);
      if (batch.isEmpty) return;

      final result = await api.uploadBatch(events: batch, accessToken: token);

      switch (result) {
        case UploadProcessed(:final delivered, :final rejected):
          if (delivered.isNotEmpty) {
            await outbox.markDelivered(delivered);
          }
          if (rejected.isNotEmpty) {
            // The server will never take these. Backing off is the honest
            // behaviour: they are not lost, and `stuck()` surfaces them.
            await outbox.recordFailure(
              rejected.keys.toList(),
              error: rejected.values.first,
              backoff: _backoff,
            );
          }
          await outbox.pruneDelivered();

        case UploadOffline():
          // Not the events' fault. Short, uniform retry — no need to escalate
          // backoff for something that will fix itself when the Wi-Fi returns.
          await outbox.recordFailure(
            batch.map((e) => e['event_id'] as String).toList(),
            error: 'offline',
            backoff: (_) => _jittered(interval),
          );

        case UploadUnauthorized():
          // Stop until the app re-pairs. Spinning here would burn battery and
          // hammer the server with a credential that cannot work.
          _paused = true;

        case UploadRetryable(:final detail):
          await outbox.recordFailure(
            batch.map((e) => e['event_id'] as String).toList(),
            error: detail,
            backoff: _backoff,
          );
      }
    } finally {
      _flushing = false;
    }
  }

  /// Exponential backoff with jitter, capped.
  ///
  /// Jitter matters more than it looks: a classroom of tablets that lost Wi-Fi
  /// together would otherwise retry in lockstep and arrive as one spike every
  /// time the window opens.
  Duration _backoff(int attempts) {
    final capped = min(attempts, 8); // 2^8 * 2s ≈ 8.5 min ceiling
    final base = Duration(seconds: 2 * pow(2, capped - 1).toInt());
    return _jittered(base);
  }

  /// Full jitter: a random point in [0, duration].
  Duration _jittered(Duration duration) {
    final millis = duration.inMilliseconds;
    if (millis <= 0) return Duration.zero;
    return Duration(milliseconds: _random.nextInt(millis) + 1);
  }

  /// Health counters, reported alongside request ids and ingest counters
  /// (plan §8). Outbox depth is the number that tells you sync is failing.
  Future<OutboxHealth> health() async {
    return OutboxHealth(
      depth: await outbox.depth(),
      stuck: (await outbox.stuck(afterAttempts: maxAttempts)).length,
      paused: _paused,
      at: _now(),
    );
  }
}

class OutboxHealth {
  const OutboxHealth({
    required this.depth,
    required this.stuck,
    required this.paused,
    required this.at,
  });

  /// Events waiting to upload.
  final int depth;

  /// Events that have failed enough times to need attention.
  final int stuck;

  /// Whether uploads are halted pending a re-pair.
  final bool paused;

  final DateTime at;

  bool get isHealthy => stuck == 0 && !paused;
}
