import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/notifications_controller.dart';
import '../../features/pairing/pairing_controller.dart';
import '../../features/path/path_controller.dart';
import '../../features/progress/progress_controller.dart';
import 'network_online.dart';

/// Brings every server read back after an outage (Hafid's tab froze at
/// XP 0 / "–" for 40 minutes after the backend returned).
///
/// Each reader (progress, the inbox, the Carte's sync, the token refresh)
/// reports how its last call went:
/// - After a failure, everything is retried on a capped backoff
///   (5 s, 10 s, 20 s, 40 s, then every 60 s), forever.
/// - The first success after a failure retries everything at once, so
///   the header catches up the moment the server answers.
/// - Coming back to the app (focus, visibility) or the network coming back
///   online retries everything at once too.
class RecoveryScheduler {
  RecoveryScheduler({
    required this.retryAll,
    this.enabled = true,
    this.first = const Duration(seconds: 5),
    this.cap = const Duration(seconds: 60),
  });

  /// Re-runs every reader.
  final Future<void> Function() retryAll;

  /// Off only in tests that keep a provider container past their widgets,
  /// as they do the inbox poll, so no retry timer outlives them.
  final bool enabled;
  final Duration first;
  final Duration cap;

  int _failures = 0;
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  bool get failing => _failures > 0;

  /// The wait before the next retry, after [failures] failures in a row.
  Duration backoffAfter(int failures) {
    final ms = first.inMilliseconds * pow(2, max(0, failures - 1));
    return Duration(milliseconds: min(ms.toInt(), cap.inMilliseconds));
  }

  /// Counts rounds, not readers: several reads failing together wait one
  /// backoff step, not one per reader.
  void reportFailure() {
    if (_disposed || !enabled || _timer != null) return;
    _failures++;
    _timer = Timer(backoffAfter(_failures), () {
      _timer = null;
      unawaited(_retry());
    });
  }

  void reportSuccess() {
    if (_disposed || !enabled || _failures == 0) return;
    _failures = 0;
    _timer?.cancel();
    _timer = null;
    unawaited(_retry());
  }

  /// Focus, visibility or the network back: try now, whatever the state.
  void nudge() {
    if (enabled) unawaited(_retry());
  }

  Future<void> _retry() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      await retryAll();
    } catch (_) {
      // A reader that throws counts as a failure, never as a stop.
      reportFailure();
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

/// Every reader the scheduler re-runs: a fresh token first if the last
/// refresh never got one, then progress (the header), the inbox, and the
/// Carte's sync.
Future<void> _retryAll(Ref ref) async {
  final session = ref.read(sessionControllerProvider);
  if (session.status != SessionStatus.paired) return;
  if (session.accessToken == null) {
    await ref.read(sessionControllerProvider.notifier).ensureFreshToken();
    if (ref.read(sessionControllerProvider).accessToken == null) return;
  }
  await Future.wait([
    ref.read(progressControllerProvider.notifier).refresh(),
    ref.read(notificationsControllerProvider.notifier).refresh(),
    ref.read(pathControllerProvider.notifier).refresh(),
  ]);
}

/// Whether failed reads are retried. On in the app.
final recoveryRetriesProvider = Provider<bool>((ref) => true);

final recoveryProvider = Provider<RecoveryScheduler>((ref) {
  final scheduler = RecoveryScheduler(
    retryAll: () => _retryAll(ref),
    enabled: ref.watch(recoveryRetriesProvider),
  );
  // No binding in a plain unit test: the scheduler still works, it just
  // has no app lifecycle to listen to.
  AppLifecycleListener? lifecycle;
  try {
    lifecycle = AppLifecycleListener(
      onShow: scheduler.nudge,
      onResume: scheduler.nudge,
    );
  } catch (_) {}
  listenForNetworkOnline(scheduler.nudge);
  ref.onDispose(() {
    lifecycle?.dispose();
    scheduler.dispose();
  });
  return scheduler;
});
