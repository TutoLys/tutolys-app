import 'dart:async';

import 'dart:typed_data';

import 'channel_audio_coordinator.dart';
import 'web_audio_backend.dart';

export 'web_audio_backend.dart';

/// The web [ChannelPlayer] (ADR 0043): a decoded buffer on one shared,
/// kept-warm `AudioContext`, instead of audioplayers' streaming `<audio>`
/// element.
///
/// The bug it fixes (Hafid, :8080): tapping the speaker often cut the first
/// word or two, by a different amount each time. audioplayers' web backend
/// turns the bytes into a data URI labelled `audio/mpeg` (ours are WAV),
/// calls it prepared on `loadeddata` — before it can play through — and
/// plays it through a Web Audio context it creates lazily and that may
/// still be suspended or waking. The element's clock runs meanwhile, so the
/// head of the clip is lost. Here the context is running and the whole
/// clip decoded **before** anything starts, so playback begins at sample 0
/// every time.
class WebAudioChannelPlayer implements ChannelPlayer {
  WebAudioChannelPlayer(this.backend);

  final WebAudioBackend backend;

  final StreamController<void> _complete = StreamController.broadcast();
  WebVoice? _voice;
  StreamSubscription<void>? _endedSub;
  Object? _buffer;
  double _volume = 1;

  /// Bumped by every play and stop, so a decode that finishes after the
  /// child tapped again (or moved on) never starts a stale clip.
  int _generation = 0;

  // Where a paused clip stands: started at [_startedAt] on the context's
  // clock, from [_offset] seconds in.
  double _startedAt = 0;
  double _offset = 0;
  bool _paused = false;

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> play(Uint8List bytes, {required String cacheKey}) async {
    final gen = ++_generation;
    _stopVoice();
    _paused = false;
    await backend.ensureRunning();
    final buffer = await backend.decode(bytes);
    if (gen != _generation) return; // replaced or stopped while decoding
    _buffer = buffer;
    _startAt(0);
  }

  void _startAt(double offset) {
    final buffer = _buffer;
    if (buffer == null) return;
    final voice = backend.start(buffer, offsetSeconds: offset, volume: _volume);
    _voice = voice;
    _offset = offset;
    _startedAt = backend.currentTime;
    _endedSub = voice.ended.listen((_) {
      if (identical(_voice, voice)) {
        _voice = null;
        _buffer = null;
        _complete.add(null);
      }
    });
  }

  void _stopVoice() {
    final voice = _voice;
    _voice = null;
    unawaited(_endedSub?.cancel());
    _endedSub = null;
    voice?.stop();
  }

  @override
  Future<void> stop() async {
    _generation++;
    _paused = false;
    _buffer = null;
    _stopVoice();
  }

  @override
  Future<void> pause() async {
    if (_voice == null || _paused) return;
    _offset += backend.currentTime - _startedAt;
    _paused = true;
    _stopVoice();
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    await backend.ensureRunning();
    _startAt(_offset);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    _voice?.volume = volume;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _complete.close();
  }
}
