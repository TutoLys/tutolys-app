import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// `?audiodebug=1` in the page URL: a timestamped trace of every read-aloud
/// step in the browser console (ADR 0043). Off otherwise, and always off
/// on native, so it costs nothing in normal play.
///
/// It exists because the cut-off first words reproduce only on real
/// hardware (Hafid's), so the trace has to say from his machine what the
/// context, the output and the clip were doing at the moment of a cut tap.
abstract final class AudioDebug {
  static final Stopwatch _clock = Stopwatch()..start();

  /// Read once, at first use (startup), before any route changes the URL.
  static final bool enabled =
      kIsWeb && Uri.base.queryParameters['audiodebug'] == '1';

  static void log(String message) {
    if (!enabled) return;
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(3);
    // ignore: avoid_print
    print('[audiodebug +${t}s] $message');
  }

  /// Short content hash, to tell a new clip from an old cached one.
  static String sha(Uint8List bytes) =>
      sha256.convert(bytes).toString().substring(0, 12);
}
