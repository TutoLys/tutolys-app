import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../play/learning_platform_providers.dart';
import '../settings/settings_controller.dart';
import 'app_sounds.dart';

/// Background music on the shell pages (ADR 0035).
///
/// It plays while a shell page shows (Village, Carte, Quêtes…) and stops
/// inside an activity, so it never competes with a question being read.
/// It also stops while the app is hidden or the music toggle is off. Its
/// level is the coordinator's: master volume times a low music level, and
/// ducked under narration.
class MusicDirector {
  MusicDirector(this._audio, {required this.enabled, String? track})
    : _track = track ?? pickMusicTrack();

  final AudioCoordinator _audio;

  /// The music toggle, read on every change.
  final bool Function() enabled;
  final String _track;

  bool _shell = false;
  int _activities = 0;
  bool _hidden = false;
  PlaybackHandle? _playing;

  bool get shouldPlay => _shell && _activities == 0 && !_hidden && enabled();

  /// Whether a loop is running now, for tests.
  bool get playing => _playing != null;

  void shellShown() => _set(() => _shell = true);
  void shellGone() => _set(() => _shell = false);
  void activityEntered() => _set(() => _activities++);
  void activityLeft() =>
      _set(() => _activities = _activities > 0 ? _activities - 1 : 0);
  void appHidden() => _set(() => _hidden = true);
  void appShown() => _set(() => _hidden = false);

  /// Re-checks after the music toggle changes.
  void settingsChanged() => _apply();

  void _set(VoidCallback change) {
    change();
    _apply();
  }

  void _apply() {
    if (shouldPlay && _playing == null) {
      final handle = _audio.play(
        AudioRequest(
          source: PrerecordedAudio(exerciseId: appAudioScope, ref: _track),
          channel: AudioChannel.music,
          loop: true,
        ),
      );
      _playing = handle;
      // Stopped from elsewhere (a toggle, the lane policy): forget it, so
      // the next apply can start it again.
      unawaited(
        handle.done.then((_) {
          if (identical(_playing, handle)) _playing = null;
        }),
      );
    } else if (!shouldPlay && _playing != null) {
      final handle = _playing!;
      _playing = null;
      unawaited(handle.stop());
    }
  }
}

final musicDirectorProvider = Provider<MusicDirector>((ref) {
  final director = MusicDirector(
    ref.watch(audioCoordinatorProvider),
    enabled: () => ref.read(settingsControllerProvider).music,
  );
  ref.listen(settingsControllerProvider.select((s) => s.music), (_, _) {
    director.settingsChanged();
  });
  final lifecycle = AppLifecycleListener(
    onHide: director.appHidden,
    onShow: director.appShown,
  );
  ref.onDispose(lifecycle.dispose);
  return director;
});
