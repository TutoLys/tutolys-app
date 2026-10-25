import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'web_audio_backend.dart';
import 'web_audio_backend_stub.dart'
    if (dart.library.js_interop) 'web_audio_backend_js.dart';

/// Keeps the audio output awake while an activity is on screen (ADR 0043).
///
/// The operating system sleeps an idle output after a few seconds (PipeWire,
/// PulseAudio, Bluetooth headsets), and the first sound after that is
/// clipped while it wakes: Hafid's "it cuts the start, but a second click
/// before the sentence ends always works". So while at least one holder is
/// mounted *and* the app is visible, an inaudible signal keeps the output
/// open. Holders are counted, so nested or overlapping screens are fine;
/// when the last one leaves, or the app is hidden, it stops — never left
/// running in the background.
///
/// Web only. Native audio plays through audioplayers and isn't affected, so
/// there the instance has no backend and does nothing.
class AudioOutputKeepAlive {
  AudioOutputKeepAlive(this._backend);

  /// The app's one instance.
  static final AudioOutputKeepAlive instance = AudioOutputKeepAlive(
    kIsWeb ? createWebAudioBackend() : null,
  );

  final WebAudioBackend? _backend;
  int _holders = 0;
  bool _hidden = false;
  AppLifecycleListener? _lifecycle;

  bool get active => _holders > 0 && !_hidden;

  void acquire() {
    _holders++;
    if (_holders == 1) {
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    }
    _apply();
  }

  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) {
      _lifecycle?.dispose();
      _lifecycle = null;
      _hidden = false;
    }
    _apply();
  }

  void _onLifecycle(AppLifecycleState state) {
    _hidden = switch (state) {
      AppLifecycleState.resumed || AppLifecycleState.inactive => false,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
    };
    _apply();
  }

  void _apply() {
    final backend = _backend;
    if (backend == null) return;
    final on = active;
    backend.setKeepAlive(on);
    if (on) {
      // Opening an activity is a tap, so the browser lets the context
      // resume now — and the output is awake before the first clip. If it
      // refuses, the next play's own resume starts the signal instead.
      unawaited(backend.ensureRunning().then((_) {}, onError: (Object _) {}));
    }
  }
}

/// Holds [AudioOutputKeepAlive] while this widget is mounted. Wrap an
/// activity screen in it.
class AudioOutputKeepAliveScope extends StatefulWidget {
  const AudioOutputKeepAliveScope({
    required this.child,
    this.keepAlive,
    super.key,
  });

  final Widget child;

  /// For tests; the app's instance by default.
  final AudioOutputKeepAlive? keepAlive;

  @override
  State<AudioOutputKeepAliveScope> createState() =>
      _AudioOutputKeepAliveScopeState();
}

class _AudioOutputKeepAliveScopeState extends State<AudioOutputKeepAliveScope> {
  late final AudioOutputKeepAlive _keepAlive =
      widget.keepAlive ?? AudioOutputKeepAlive.instance;

  @override
  void initState() {
    super.initState();
    _keepAlive.acquire();
  }

  @override
  void dispose() {
    _keepAlive.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
