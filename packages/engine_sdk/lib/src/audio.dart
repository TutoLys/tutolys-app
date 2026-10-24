import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_file_stub.dart'
    if (dart.library.io) 'audio_file_io.dart'
    as platform_audio;

/// Resolves a question prompt's `audio_ref` to the actual cached bytes.
///
/// Deliberately an interface, not a concrete type — same pattern
/// [EventOutbox] already uses: this package never touches the app's own
/// database directly, so the app supplies a drift-backed implementation
/// and tests supply [InMemoryAudioResolver].
abstract interface class AudioResolver {
  /// The cached audio bytes for one question's `audio_ref`, or `null` if
  /// it hasn't been synced yet (offline, first-ever play, or the exercise
  /// genuinely has no audio for this prompt).
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  });
}

/// In-memory stand-in, for tests and for a host that hasn't wired a real
/// cache yet. Never used in the running app — [bytesFor] always returning
/// `null` is a legitimate state (no audio synced yet), so this is also
/// a safe default, not just a test double.
class InMemoryAudioResolver implements AudioResolver {
  InMemoryAudioResolver([Map<String, Uint8List>? seed]) : _bytes = {...?seed};

  final Map<String, Uint8List> _bytes;

  void put(String exerciseId, String ref, Uint8List bytes) {
    _bytes['$exerciseId/$ref'] = bytes;
  }

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) async {
    return _bytes['$exerciseId/$ref'];
  }
}

/// Plays one question prompt's audio on tap (or automatically once the
/// prompt appears — see `ExerciseRunner`).
///
/// Not a security- or correctness-critical path: a playback failure is
/// logged and swallowed rather than surfaced, the same posture a
/// decorative sound effect would get — a kid who can't hear the prompt
/// still has the text on screen.
///
/// Native platforms play from a temp file (`DeviceFileSource`, the
/// best-supported source type everywhere `dart:io` exists); web plays
/// straight from bytes (`BytesSource`, which `audioplayers`' web backend
/// implements via a standard Blob URL). The `dart:io`-touching half of
/// this split lives in `audio_file_io.dart`, selected by a conditional
/// import — `dart:io` does not compile for a web target at all, so the
/// branch has to happen at the import level, not just at runtime behind
/// `kIsWeb` (same class of problem ADR 0002/0003 already hit with
/// drift's native backend).
class ExercisePromptAudio {
  ExercisePromptAudio({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> play(Uint8List bytes, {required String cacheKey}) async {
    try {
      final source = kIsWeb
          ? BytesSource(bytes)
          : await platform_audio.fileSourceFor(bytes, cacheKey);
      await _player.stop();
      await _player.play(source);
    } catch (error, stack) {
      // A kid never sees this; the text prompt is still right there.
      debugPrint(
        'ExercisePromptAudio: playback failed for $cacheKey: $error\n$stack',
      );
    }
  }

  Future<void> stop() => _player.stop();

  void dispose() {
    unawaited(_player.dispose());
  }
}
