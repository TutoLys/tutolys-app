/// Active learning time: elapsed time with pauses taken out.
///
/// Built on a monotonic source (a `Stopwatch` by default), never the wall
/// clock — a device clock change mid-question must not produce negative or
/// hour-long answer times, and background time is not learning time
/// (brief §14).
class ActiveClock {
  ActiveClock({Duration Function()? monotonic, int initialActiveMs = 0})
    : _now = monotonic ?? _stopwatchSource(),
      _bankedMs = initialActiveMs;

  static Duration Function() _stopwatchSource() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  final Duration Function() _now;

  /// Active time accumulated before the current running stretch. Seeded from
  /// a snapshot on resume, so active time survives a crash.
  int _bankedMs;
  Duration? _runningSince;

  bool get isRunning => _runningSince != null;

  void start() {
    _runningSince ??= _now();
  }

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    _bankedMs += (_now() - since).inMilliseconds;
    _runningSince = null;
  }

  int get activeMs {
    final since = _runningSince;
    return since == null
        ? _bankedMs
        : _bankedMs + (_now() - since).inMilliseconds;
  }
}
