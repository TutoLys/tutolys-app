import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_audio_backend.dart';

/// The real [WebAudioBackend], on the browser's Web Audio API.
///
/// **One `AudioContext` for the whole app**, created on the first play —
/// which is always a tap, so the browser allows it — and never closed or
/// suspended by us, so later clips start on a context that is already
/// awake. Safari caps the number of contexts, another reason for one.
WebAudioBackend createWebAudioBackend() => _JsWebAudioBackend();

class _JsWebAudioBackend implements WebAudioBackend {
  static web.AudioContext? _shared;
  static bool _primed = false;

  web.AudioContext get _ctx => _shared ??= web.AudioContext();

  @override
  double get currentTime => _ctx.currentTime;

  @override
  Future<void> ensureRunning() async {
    final ctx = _ctx;
    if (ctx.state != 'running') await ctx.resume().toDart;
    if (!_primed) {
      // Play one silent frame so the output device is already open when
      // the first real clip starts; some outputs take a moment to wake and
      // would otherwise eat the first syllable.
      _primed = true;
      final silence = ctx.createBuffer(1, 1, ctx.sampleRate);
      final src = ctx.createBufferSource()..buffer = silence;
      src.connect(ctx.destination);
      src.start();
    }
  }

  @override
  Future<Object> decode(Uint8List bytes) async {
    // decodeAudioData detaches the buffer it's given: hand it a copy, so
    // the cached bytes stay usable for the next replay.
    final copy = Uint8List.fromList(bytes);
    final buffer = await _ctx.decodeAudioData(copy.buffer.toJS).toDart;
    return buffer;
  }

  @override
  WebVoice start(Object buffer, {double offsetSeconds = 0, double volume = 1}) {
    final ctx = _ctx;
    final src = ctx.createBufferSource()..buffer = buffer as web.AudioBuffer;
    final gain = ctx.createGain();
    gain.gain.value = volume;
    src.connect(gain);
    gain.connect(ctx.destination);
    final voice = _JsVoice(src, gain);
    src.onended = ((web.Event _) => voice._end()).toJS;
    src.start(0, offsetSeconds);
    return voice;
  }
}

class _JsVoice implements WebVoice {
  _JsVoice(this._src, this._gain);

  final web.AudioBufferSourceNode _src;
  final web.GainNode _gain;
  final StreamController<void> _ended = StreamController.broadcast();
  bool _stopped = false;

  void _end() {
    if (_stopped || _ended.isClosed) return;
    _ended.add(null);
    unawaited(_ended.close());
  }

  @override
  Stream<void> get ended => _ended.stream;

  @override
  set volume(double v) => _gain.gain.value = v;

  @override
  void stop() {
    if (_stopped) return;
    _stopped = true;
    try {
      _src.stop();
    } on Object {
      // Already ended: nothing to stop.
    }
    _src.disconnect();
    _gain.disconnect();
    unawaited(_ended.close());
  }
}
