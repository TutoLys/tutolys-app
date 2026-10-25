import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../audio.dart';
import '../audio_file_stub.dart'
    if (dart.library.io) '../audio_file_io.dart'
    as platform_audio;
import 'audio_contracts.dart';
import 'audio_debug.dart';
import 'platform_channel_player.dart';

/// One player's worth of playback. An interface so the coordinator's rules
/// are tested without a platform audio backend.
abstract interface class ChannelPlayer {
  /// Start playing; completes once playback has begun (or failed to).
  Future<void> play(Uint8List bytes, {required String cacheKey});

  /// Fires when a playback reaches its end on its own.
  Stream<void> get onComplete;

  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// [ChannelPlayer] on audioplayers: native platforms, playing from a temp
/// file (ADR 0013). In a browser the default is [WebAudioChannelPlayer]
/// instead (ADR 0043): audioplayers' web backend loses the head of a clip.
class AudioplayersChannelPlayer implements ChannelPlayer {
  AudioplayersChannelPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(Uint8List bytes, {required String cacheKey}) async {
    AudioDebug.log('audioplayers path served $cacheKey (not expected on web)');
    final source = kIsWeb
        ? BytesSource(bytes)
        : await platform_audio.fileSourceFor(bytes, cacheKey);
    await _player.stop();
    await _player.play(source);
  }

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}

class _Playing {
  _Playing(this.requestId, this.priority);
  final int requestId;
  final int priority;
  final Completer<PlaybackPhase> done = Completer();
  StreamSubscription<void>? completion;

  void finish(PlaybackPhase phase) {
    completion?.cancel();
    if (!done.isCompleted) done.complete(phase);
  }
}

class _Handle implements PlaybackHandle {
  _Handle(this.requestId, this.done, this._stop);
  @override
  final int requestId;
  @override
  final Future<PlaybackPhase> done;
  final Future<void> Function() _stop;
  @override
  Future<void> stop() => _stop();
}

/// The app's one [AudioCoordinator]: a player per channel, arbitrated by
/// [AudioLanePolicy].
///
/// Nothing here throws to a caller. A missing asset, an unsupported TTS
/// locale or a platform error resolves the handle as `unavailable` or
/// `error`; the question stays answerable (brief §20).
class ChannelAudioCoordinator implements AudioCoordinator {
  ChannelAudioCoordinator({
    required this.resolver,
    ChannelPlayer Function(AudioChannel channel)? playerFactory,
    this.tts,
    this.effectBytes,
    this.effectsEnabled,
    this.musicEnabled,
    this.duckedMusicVolume = 0.3,
  }) : _factory = playerFactory ?? ((_) => platformChannelPlayer());

  final AudioResolver resolver;
  final TtsEngine? tts;

  /// Bytes for a named effect. Null = no effects bundled (true today: the
  /// old Godot SFX were never licensed, frontend spec §3.8).
  final Future<Uint8List?> Function(String name)? effectBytes;

  /// Read on every request, so a Réglages change applies immediately.
  final bool Function()? effectsEnabled;
  final bool Function()? musicEnabled;
  final double duckedMusicVolume;

  final ChannelPlayer Function(AudioChannel) _factory;
  final Map<AudioChannel, ChannelPlayer> _players = {};
  final Map<AudioChannel, _Playing> _playing = {};
  final StreamController<PlaybackStatus> _status = StreamController.broadcast();
  int _nextId = 0;
  bool _disposed = false;

  @override
  Stream<PlaybackStatus> get status => _status.stream;

  ChannelPlayer _player(AudioChannel c) =>
      _players.putIfAbsent(c, () => _factory(c));

  void _emit(int id, PlaybackPhase phase) {
    if (!_disposed) _status.add(PlaybackStatus(id, phase));
  }

  @override
  PlaybackHandle play(AudioRequest request) {
    final id = ++_nextId;
    AudioDebug.log(
      'speaker -> ChannelAudioCoordinator.play #$id on '
      '${request.channel.name}: ${_describe(request.source)}',
    );
    final entry = _Playing(id, request.priority);
    unawaited(_start(request, entry));
    return _Handle(
      id,
      entry.done.future,
      () => _stopIfCurrent(request.channel, id),
    );
  }

  Future<void> _start(AudioRequest request, _Playing entry) async {
    final channel = request.channel;
    if (_disposed ||
        (channel == AudioChannel.sfx && effectsEnabled?.call() == false) ||
        (channel == AudioChannel.music && musicEnabled?.call() == false)) {
      entry.finish(PlaybackPhase.stopped);
      _emit(entry.requestId, PlaybackPhase.stopped);
      return;
    }

    final decision = AudioLanePolicy.admit(
      request,
      playingPriorities: {
        for (final e in _playing.entries) e.key: e.value.priority,
      },
    );
    if (!decision.start) {
      entry.finish(PlaybackPhase.stopped);
      _emit(entry.requestId, PlaybackPhase.stopped);
      return;
    }
    for (final c in decision.stop) {
      await _stopChannel(c, PlaybackPhase.stopped);
    }
    _playing[channel] = entry;
    _emit(entry.requestId, PlaybackPhase.loading);
    if (decision.duckMusic && channel.isVoice) {
      await _safely(
        () => _player(AudioChannel.music).setVolume(duckedMusicVolume),
      );
    }

    final source = request.source;
    if (source is TtsUtterance) {
      await _speak(source, entry, channel);
      return;
    }

    final Uint8List? bytes = switch (source) {
      PrerecordedAudio(:final exerciseId, :final ref) => await _safelyValue(
        () => resolver.bytesFor(exerciseId: exerciseId, ref: ref),
      ),
      EffectAudio(:final name) => await _safelyValue(
        () async => effectBytes?.call(name),
      ),
      TtsUtterance() => null,
    };
    if (!identical(_playing[channel], entry)) return; // replaced while loading
    if (bytes == null) {
      AudioDebug.log('#${entry.requestId}: no cached bytes, nothing to play');
      _finish(channel, entry, PlaybackPhase.unavailable);
      return;
    }

    final player = _player(channel);
    AudioDebug.log('#${entry.requestId}: served by ${player.runtimeType}');
    entry.completion = player.onComplete.listen(
      (_) => _finish(channel, entry, PlaybackPhase.completed),
    );
    final key = switch (source) {
      PrerecordedAudio(:final exerciseId, :final ref) => '${exerciseId}_$ref',
      EffectAudio(:final name) => 'sfx_$name',
      TtsUtterance() => 'tts',
    };
    final ok = await _safely(() => player.play(bytes, cacheKey: key));
    if (!ok) {
      _finish(channel, entry, PlaybackPhase.error);
      return;
    }
    if (identical(_playing[channel], entry)) {
      _emit(entry.requestId, PlaybackPhase.playing);
    }
  }

  Future<void> _speak(
    TtsUtterance u,
    _Playing entry,
    AudioChannel channel,
  ) async {
    final engine = tts;
    final supported =
        engine != null &&
        await _safelyValue(() => engine.supportsLocale(u.locale)) == true;
    if (!supported) {
      _finish(channel, entry, PlaybackPhase.unavailable);
      return;
    }
    _emit(entry.requestId, PlaybackPhase.playing);
    final ok = await _safely(() => engine.speak(u.text, locale: u.locale));
    _finish(channel, entry, ok ? PlaybackPhase.completed : PlaybackPhase.error);
  }

  void _finish(AudioChannel channel, _Playing entry, PlaybackPhase phase) {
    if (identical(_playing[channel], entry)) _playing.remove(channel);
    entry.finish(phase);
    _emit(entry.requestId, phase);
    if (channel.isVoice &&
        !_playing.keys.any((c) => c.isVoice) &&
        _players.containsKey(AudioChannel.music)) {
      unawaited(_safely(() => _players[AudioChannel.music]!.setVolume(1)));
    }
  }

  Future<void> _stopIfCurrent(AudioChannel channel, int id) async {
    if (_playing[channel]?.requestId == id) {
      await _stopChannel(channel, PlaybackPhase.stopped);
    }
  }

  Future<void> _stopChannel(AudioChannel channel, PlaybackPhase phase) async {
    final entry = _playing[channel];
    if (entry == null) return;
    if (channel.isVoice && entry.completion == null && tts != null) {
      await _safely(() => tts!.stop());
    }
    await _safely(() => _players[channel]?.stop() ?? Future.value());
    _finish(channel, entry, phase);
  }

  @override
  Future<void> stopChannel(AudioChannel channel) =>
      _stopChannel(channel, PlaybackPhase.stopped);

  @override
  Future<void> stopAll() async {
    for (final c in [..._playing.keys]) {
      await _stopChannel(c, PlaybackPhase.stopped);
    }
  }

  @override
  Future<void> pause() async {
    for (final c in _playing.keys) {
      await _safely(() => _players[c]?.pause() ?? Future.value());
    }
  }

  @override
  Future<void> resume() async {
    for (final c in _playing.keys) {
      await _safely(() => _players[c]?.resume() ?? Future.value());
    }
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _disposed = true;
    for (final p in _players.values) {
      await _safely(p.dispose);
    }
    _players.clear();
    await _status.close();
  }

  static String _describe(AudioSource s) => switch (s) {
    PrerecordedAudio(:final exerciseId, :final ref) =>
      'prerecorded $exerciseId/$ref',
    EffectAudio(:final name) => 'effect $name',
    TtsUtterance(:final locale) => 'tts $locale',
  };

  static Future<bool> _safely(Future<void> Function() f) async {
    try {
      await f();
      return true;
    } catch (error, stack) {
      debugPrint('ChannelAudioCoordinator: $error\n$stack');
      return false;
    }
  }

  static Future<T?> _safelyValue<T>(Future<T?> Function() f) async {
    try {
      return await f();
    } catch (error) {
      debugPrint('ChannelAudioCoordinator: $error');
      return null;
    }
  }
}
