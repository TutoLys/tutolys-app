import 'dart:async';
import 'dart:typed_data';

/// The few Web Audio calls the web player needs. An interface so the
/// player's ordering — wake the context, decode the whole clip, then start
/// it at sample 0 — is tested without a browser.
abstract interface class WebAudioBackend {
  /// Resume the shared context if it is suspended (it starts suspended
  /// until a user gesture, and browsers suspend it in the background), and
  /// prime the output device once. Completes when the context is running;
  /// true when it had to be woken, so the caller can give the output a
  /// moment before the first sample.
  Future<bool> ensureRunning();

  /// Keep the operating system's audio output open, or let it sleep.
  ///
  /// PipeWire/PulseAudio suspend an idle sink after ~5 s of silence, and
  /// Bluetooth headsets do the same; the first sound after that loses
  /// 200–500 ms while the sink wakes — Hafid's cut-off first words, which a
  /// replay inside the sentence never showed. While on, an inaudible
  /// constant signal plays so the sink never goes idle. A no-op until the
  /// context is running: it takes effect on the next [ensureRunning].
  void setKeepAlive(bool on);

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
