import 'dart:async';

import 'package:flutter/foundation.dart';

import 'diag_log.dart';

enum BootOutcome { running, ok, error, timeout }

/// One named boot step (ADR 0038).
class BootStep {
  BootStep(this.name, this.startedAt);

  final String name;
  final Duration startedAt;
  Duration? endedAt;
  BootOutcome outcome = BootOutcome.running;
  String? errorType;
  String? errorMessage;

  Duration? get took => endedAt == null ? null : endedAt! - startedAt;

  String describe() {
    final at = (startedAt.inMilliseconds / 1000).toStringAsFixed(3);
    final ms = took == null ? '' : ' (${took!.inMilliseconds} ms)';
    final error = errorType == null ? '' : ' $errorType: $errorMessage';
    return '[boot +${at}s] $name ${outcome.name}$ms$error';
  }
}

/// Every boot step with its timing and outcome. A step that runs past its
/// timeout is recorded as `timeout` and fails, so boot proceeds or fails
/// visibly instead of waiting forever.
class BootLog extends ChangeNotifier {
  BootLog({bool? verbose, Stopwatch? clock})
    : verbose = verbose ?? _verboseByDefault(),
      _clock = (clock ?? Stopwatch())..start();

  /// The app's one boot log. Tests make their own.
  static final BootLog instance = BootLog();

  /// Network steps wait longer than local ones.
  static const localTimeout = Duration(seconds: 10);
  static const networkTimeout = Duration(seconds: 20);

  /// Prints each step: always in debug and profile, and in release behind
  /// `?bootdebug=1` on web.
  final bool verbose;
  final Stopwatch _clock;
  final _steps = <BootStep>[];

  List<BootStep> get steps => List.unmodifiable(_steps);

  /// The first step still running, the one a stuck boot is waiting on.
  BootStep? get stuckOn {
    for (final step in _steps) {
      if (step.outcome == BootOutcome.running) return step;
    }
    return null;
  }

  static bool _verboseByDefault() =>
      !kReleaseMode || Uri.base.queryParameters['bootdebug'] == '1';

  BootStep start(String name) {
    final step = BootStep(name, _clock.elapsed);
    _steps.add(step);
    notifyListeners();
    return step;
  }

  void finish(BootStep step, BootOutcome outcome, [Object? error]) {
    if (step.outcome != BootOutcome.running) return;
    step
      ..endedAt = _clock.elapsed
      ..outcome = outcome
      ..errorType = error?.runtimeType.toString()
      ..errorMessage = error == null ? null : DiagLog.scrub('$error');
    if (verbose) debugPrint(step.describe());
    notifyListeners();
  }

  /// Marks a step that has no future to wait on, such as the first frame.
  void mark(String name) => finish(start(name), BootOutcome.ok);

  /// Runs [body] as step [name]. Past [timeout] the step is recorded as
  /// `timeout` and a [TimeoutException] is thrown; [body] keeps running in
  /// the background, but nobody waits on it any more.
  Future<T> run<T>(
    String name,
    Future<T> Function() body, {
    Duration timeout = localTimeout,
  }) async {
    final step = start(name);
    try {
      final value = await body().timeout(timeout);
      finish(step, BootOutcome.ok);
      return value;
    } on TimeoutException catch (e, s) {
      finish(step, BootOutcome.timeout, e);
      DiagLog.instance.record('boot:$name', e, s);
      rethrow;
    } catch (e, s) {
      finish(step, BootOutcome.error, e);
      DiagLog.instance.record('boot:$name', e, s);
      rethrow;
    }
  }

  /// Forgets the steps, for "Réessayer".
  void reset() {
    _steps.clear();
    notifyListeners();
  }
}
