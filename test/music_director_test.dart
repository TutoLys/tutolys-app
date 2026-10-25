import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/audio/app_sounds.dart';
import 'package:tutolys_app/features/audio/music_director.dart';

/// Records requests; a handle completes `stopped` when stopped.
class _Audio implements AudioCoordinator {
  final requests = <AudioRequest>[];
  final _handles = <_Handle>[];

  int get running => _handles.where((h) => !h.c.isCompleted).length;

  @override
  PlaybackHandle play(AudioRequest request) {
    requests.add(request);
    final h = _Handle(requests.length);
    _handles.add(h);
    return h;
  }

  @override
  Future<void> stopChannel(AudioChannel channel) async {
    for (final h in _handles) {
      if (!h.c.isCompleted) h.c.complete(PlaybackPhase.stopped);
    }
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Stream<PlaybackStatus> get status => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

class _Handle implements PlaybackHandle {
  _Handle(this.requestId);
  final c = Completer<PlaybackPhase>();
  @override
  final int requestId;
  @override
  Future<PlaybackPhase> get done => c.future;
  @override
  Future<void> stop() async {
    if (!c.isCompleted) c.complete(PlaybackPhase.stopped);
  }
}

void main() {
  late _Audio audio;
  late bool musicOn;
  late MusicDirector music;

  setUp(() {
    audio = _Audio();
    musicOn = true;
    music = MusicDirector(
      audio,
      enabled: () => musicOn,
      track: 'music/village-1.ogg',
    );
  });

  test('the shell pages play the loop, on the music channel', () {
    music.shellShown();
    final r = audio.requests.single;
    expect(r.channel, AudioChannel.music);
    expect(r.loop, isTrue);
    expect(
      (r.source as PrerecordedAudio).exerciseId,
      appAudioScope,
      reason: 'a bundled sound, not a lesson clip',
    );
    expect(audio.running, 1);
  });

  test('an activity stops it, and leaving brings it back', () async {
    music.shellShown();
    music.activityEntered();
    await pumpEventQueue();
    expect(audio.running, 0);
    music.activityLeft();
    expect(audio.running, 1);
    expect(audio.requests, hasLength(2));
  });

  test('the music toggle stops it and starts it again, live', () async {
    music.shellShown();
    musicOn = false;
    music.settingsChanged();
    await pumpEventQueue();
    expect(audio.running, 0);
    musicOn = true;
    music.settingsChanged();
    expect(audio.running, 1);
  });

  test('off from the start: nothing plays at all', () {
    musicOn = false;
    music.shellShown();
    expect(audio.requests, isEmpty);
  });

  test('a hidden app is silent', () async {
    music.shellShown();
    music.appHidden();
    await pumpEventQueue();
    expect(audio.running, 0);
    music.appShown();
    expect(audio.running, 1);
  });

  test('stopped from elsewhere, it starts again on the next change', () async {
    music.shellShown();
    await audio.stopChannel(AudioChannel.music);
    await pumpEventQueue();
    expect(music.playing, isFalse);
    music.settingsChanged();
    expect(audio.running, 1);
  });

  group('bundled sounds', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('every music track and filled effect slot is in the bundle', () async {
      for (final t in musicTracks) {
        final data = await rootBundle.load('assets/sounds/$t');
        expect(data.lengthInBytes, greaterThan(10000), reason: t);
      }
      for (final path in sfxAssets.values.whereType<String>()) {
        expect(
          (await rootBundle.load('assets/sounds/$path')).lengthInBytes,
          greaterThan(1000),
          reason: path,
        );
      }
    });

    test('the celebration has the win jingle; right and retry are silent '
        'until Hafid picks', () async {
      expect(await appEffectBytes('activity_complete'), isNotNull);
      expect(await appEffectBytes('answer_right'), isNull);
      expect(await appEffectBytes('answer_retry'), isNull);
      expect(await appEffectBytes('nooo'), isNull);
    });

    test(
      'app sounds come from the bundle, lesson clips from the cache',
      () async {
        final lessons = InMemoryAudioResolver()..put('ex', 'q', Uint8List(3));
        final resolver = AppAudioResolver(lessons);
        expect(
          await resolver.bytesFor(
            exerciseId: appAudioScope,
            ref: musicTracks.first,
          ),
          isNotNull,
        );
        expect(
          (await resolver.bytesFor(exerciseId: 'ex', ref: 'q'))!.length,
          3,
        );
      },
    );
  });
}
