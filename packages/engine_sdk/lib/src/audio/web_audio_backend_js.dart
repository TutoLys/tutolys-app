import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
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

  // The keep-alive signal: one per page, like the context.
  static bool _keepAliveWanted = false;
  static web.ConstantSourceNode? _keepAliveSource;
  static web.GainNode? _keepAliveGain;

  /// Low enough to be inaudible, not zero: some audio stacks treat an
  /// exactly-silent stream as idle and suspend the output anyway.
  static const _keepAliveLevel = 0.0001;

  web.AudioContext get _ctx => _shared ??= web.AudioContext();

  @override
  double get currentTime => _ctx.currentTime;

  @override
  Future<bool> ensureRunning() async {
    final ctx = _ctx;
    final woke = ctx.state != 'running';
    if (woke) await ctx.resume().toDart;
    _applyKeepAlive();
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
    return woke;
  }

  @override
  void setKeepAlive(bool on) {
    _keepAliveWanted = on;
    _applyKeepAlive();
  }

  @override
  Map<String, Object?> debugState() {
    final ctx = _shared;
    if (ctx == null) return {'context': 'not created yet'};
    return {
      'state': ctx.state,
      'currentTime': ctx.currentTime.toStringAsFixed(3),
      'baseLatency': ctx.baseLatency.toStringAsFixed(4),
      'outputLatency': ctx.outputLatency.toStringAsFixed(4),
      'sampleRate': ctx.sampleRate,
      'keepAliveWanted': _keepAliveWanted,
      'keepAliveRunning': _keepAliveSource != null,
    };
  }

  @override
  Map<String, Object?> debugBuffer(Object buffer) {
    final b = buffer as web.AudioBuffer;
    final data = b.getChannelData(0).toDart;
    final rate = b.sampleRate;
    final head = math.min(data.length, (rate * 0.3).round());
    var sum = 0.0;
    for (var i = 0; i < head; i++) {
      sum += data[i] * data[i];
    }
    var firstSound = -1;
    for (var i = 0; i < data.length; i++) {
      if (data[i].abs() > 0.01) {
        firstSound = i;
        break;
      }
    }
    return {
      'durationMs': (b.duration * 1000).round(),
      'sampleRate': rate,
      'rmsFirst300ms': head == 0 ? 0 : math.sqrt(sum / head).toStringAsFixed(5),
      'firstAudibleMs': firstSound < 0
          ? 'none'
          : (firstSound * 1000 / rate).round(),
    };
  }

  void _applyKeepAlive() {
    final ctx = _shared;
    final running = ctx != null && ctx.state == 'running';
    if (_keepAliveWanted && running && _keepAliveSource == null) {
      final gain = ctx.createGain()..gain.value = _keepAliveLevel;
      final src = ctx.createConstantSource();
      src.connect(gain);
      gain.connect(ctx.destination);
      src.start();
      _keepAliveSource = src;
      _keepAliveGain = gain;
    } else if (!_keepAliveWanted && _keepAliveSource != null) {
      try {
        _keepAliveSource!.stop();
      } on Object {
        // Already stopped.
      }
      _keepAliveSource!.disconnect();
      _keepAliveGain?.disconnect();
      _keepAliveSource = null;
      _keepAliveGain = null;
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
