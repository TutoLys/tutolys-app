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
///   with decorrelated jitter: each wait is random between 5 s and three
///   times the last, capped at 60 s, forever. Random so that 50,000
///   devices failing together don't all come back in the same second
///   (the scaling plan's fix #1).
/// - The first success after a failure retries everything at once, so
///   the header catches up the moment the server answers.
/// - Coming back to the app (focus, visibility) or the network coming back
///   online retries everything too, after a random 0–3 s, for the same
///   reason: a school's Wi-Fi returning brings every tablet back at once.
class RecoveryScheduler {
  RecoveryScheduler({
    required this.retryAll,
    this.enabled = true,
    this.first = const Duration(seconds: 5),
    this.cap = const Duration(seconds: 60),
    this.nudgeSpread = const Duration(seconds: 3),
    Random? random,
  }) : _random = random ?? Random(),
       _last = first;

  /// Re-runs every reader.
  final Future<void> Function() retryAll;

  /// Off only in tests that keep a provider container past their widgets,
  /// as they do the inbox poll, so no retry timer outlives them.
  final bool enabled;
  final Duration first;
  final Duration cap;

  /// The longest random wait before a nudge's retry.
  final Duration nudgeSpread;
  final Random _random;
  Duration _last;

  int _failures = 0;
  Timer? _timer;
  Timer? _nudgeTimer;
  bool _running = false;
  bool _disposed = false;

  bool get failing => _failures > 0;

  /// The wait before the next retry: decorrelated jitter, random between
  /// [first] and three times the last wait, never above [cap].
  Duration nextBackoff() {
    final lo = first.inMilliseconds;
    final hi = max(lo, min(cap.inMilliseconds, _last.inMilliseconds * 3));
    _last = Duration(milliseconds: lo + _random.nextInt(hi - lo + 1));
    return _last;
  }

  /// Counts rounds, not readers: several reads failing together wait one
  /// backoff step, not one per reader.
  void reportFailure() {
    if (_disposed || !enabled || _timer != null) return;
    _failures++;
    _timer = Timer(nextBackoff(), () {
      _timer = null;
      unawaited(_retry());
    });
  }

  void reportSuccess() {
    if (_disposed || !enabled || _failures == 0) return;
    _failures = 0;
    _last = first;
    _timer?.cancel();
    _timer = null;
    unawaited(_retry());
  }

  /// Focus, visibility or the network back: try soon, whatever the state,
  /// after a random spread. Nudges close together share one retry.
  void nudge() {
    if (!enabled || _disposed || _nudgeTimer != null) return;
    final wait = Duration(
      milliseconds: _random.nextInt(nudgeSpread.inMilliseconds + 1),
    );
    _nudgeTimer = Timer(wait, () {
      _nudgeTimer = null;
      unawaited(_retry());
    });
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
    _nudgeTimer?.cancel();
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
