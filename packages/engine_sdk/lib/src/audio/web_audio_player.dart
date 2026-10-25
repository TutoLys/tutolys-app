import 'dart:async';

import 'dart:typed_data';

import 'audio_debug.dart';
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
  WebAudioChannelPlayer(
    this.backend, {
    this.wakeSettle = const Duration(milliseconds: 50),
  });

  final WebAudioBackend backend;

  /// The pause between waking a sleeping context and the first sample.
  final Duration wakeSettle;

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

  /// The clip repeats until stopped. A paused loop resumes from its start:
  /// background music has no place to keep.
  bool _loop = false;

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> play(
    Uint8List bytes, {
    required String cacheKey,
    bool loop = false,
  }) async {
    final gen = ++_generation;
    _loop = loop;
    _stopVoice();
    _paused = false;
    if (AudioDebug.enabled) {
      AudioDebug.log(
        'WebAudio play $cacheKey: ${bytes.length} bytes, sha '
        '${AudioDebug.sha(bytes)}; before resume ${backend.debugState()}',
      );
    }
    final woke = await backend.ensureRunning();
    final buffer = await backend.decode(bytes);
    if (AudioDebug.enabled) {
      AudioDebug.log(
        'decoded $cacheKey: ${backend.debugBuffer(buffer)}; context woke: $woke',
      );
    }
    // A context that was asleep reports running before the output has
    // settled; give it a moment so the first syllable isn't spent there.
    if (woke) await Future<void>.delayed(wakeSettle);
    if (gen != _generation) return; // replaced or stopped while decoding
    _buffer = buffer;
    _startAt(0);
  }

  void _startAt(double offset) {
    final buffer = _buffer;
    if (buffer == null) return;
    // Only a clip's first start gets the pre-roll; a resume continues.
    final delay = offset == 0 ? backend.keepAliveConfig.preRollMs / 1000 : 0.0;
    final now = backend.currentTime;
    final voice = backend.start(
      buffer,
      offsetSeconds: offset,
      volume: _volume,
      delaySeconds: delay,
      loop: _loop,
    );
    if (AudioDebug.enabled) {
      AudioDebug.log(
        'start: offset ${offset}s, pre-roll ${(delay * 1000).round()} ms, '
        'first sample scheduled at context time '
        '${(now + delay).toStringAsFixed(3)} (now ${now.toStringAsFixed(3)}): '
        '${backend.debugState()}',
      );
    }
    _voice = voice;
    _offset = offset;
    // The clip's own clock starts when its first sample does.
    _startedAt = now + delay;
    _endedSub = voice.ended.listen((_) {
      if (identical(_voice, voice)) {
        AudioDebug.log('clip ended on its own');
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
    // Paused inside the pre-roll: nothing has played yet.
    final played = backend.currentTime - _startedAt;
    _offset += played > 0 ? played : 0;
    _paused = true;
    _stopVoice();
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    await backend.ensureRunning();
    _startAt(_loop ? 0 : _offset);
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
