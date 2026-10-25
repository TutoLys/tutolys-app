import 'dart:async';
import 'dart:typed_data';

/// The few Web Audio calls the web player needs. An interface so the
/// player's ordering — wake the context, decode the whole clip, then start
/// it at sample 0 — is tested without a browser.
abstract interface class WebAudioBackend {
  /// Resume the shared context if it is suspended (it starts suspended
  /// until a user gesture, and browsers suspend it in the background), and
  /// prime the output device once. Completes when audio will be heard.
  Future<void> ensureRunning();

  /// Decode a whole clip into memory. Nothing plays until this is done, so
  /// nothing can be lost to buffering.
  Future<Object> decode(Uint8List bytes);

  /// The context's clock, in seconds.
  double get currentTime;

  /// Start [buffer] now, from [offsetSeconds], at [volume].
  WebVoice start(Object buffer, {double offsetSeconds = 0, double volume = 1});
}

/// One clip playing.
abstract interface class WebVoice {
  /// Fires once when the clip reaches its end on its own (not on [stop]).
  Stream<void> get ended;

  set volume(double v);

  void stop();
}
