import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio/audio_debug.dart';
import 'audio/channel_audio_coordinator.dart';
import 'audio/platform_channel_player.dart';

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
/// Plays through the same [ChannelPlayer] as the new runtime's
/// coordinator, so the legacy runner gets the same fix (ADR 0043): native
/// platforms play from a temp file through audioplayers; a browser plays a
/// fully decoded buffer on a warm Web Audio context, so the first words are
/// never cut off.
class ExercisePromptAudio {
  ExercisePromptAudio({AudioPlayer? player, ChannelPlayer? channel})
    : _channel =
          channel ??
          (player != null
              ? AudioplayersChannelPlayer(player)
              : platformChannelPlayer());

  final ChannelPlayer _channel;

  Future<void> play(Uint8List bytes, {required String cacheKey}) async {
    AudioDebug.log(
      'speaker -> legacy ExercisePromptAudio.play $cacheKey via '
      '${_channel.runtimeType}',
    );
    try {
      await _channel.play(bytes, cacheKey: cacheKey);
    } catch (error, stack) {
      // A kid never sees this; the text prompt is still right there.
      debugPrint(
        'ExercisePromptAudio: playback failed for $cacheKey: $error\n$stack',
      );
    }
  }

  Future<void> stop() => _channel.stop();

  void dispose() {
    unawaited(_channel.dispose());
  }
}
