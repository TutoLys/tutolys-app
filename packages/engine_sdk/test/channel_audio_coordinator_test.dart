import 'dart:async';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlayer implements ChannelPlayer {
  final List<String> log = [];
  final StreamController<void> _complete = StreamController.broadcast();
  bool failPlay = false;
  double volume = 1;

  void finish() => _complete.add(null);

  @override
  Future<void> play(Uint8List bytes, {required String cacheKey}) async {
    if (failPlay) throw StateError('device busy');
    log.add('play $cacheKey');
  }

  @override
  Stream<void> get onComplete => _complete.stream;
  @override
  Future<void> stop() async => log.add('stop');
  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> resume() async => log.add('resume');
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> dispose() async => log.add('dispose');
}

class FakeTts implements TtsEngine {
  FakeTts(this.locales);
  final Set<String> locales;
  final List<String> spoken = [];
  @override
  Future<bool> supportsLocale(String locale) async => locales.contains(locale);
  @override
  Future<void> speak(String text, {required String locale}) async =>
      spoken.add('$locale:$text');
  @override
  Future<void> stop() async {}
}

void main() {
  late Map<AudioChannel, FakePlayer> players;
  late InMemoryAudioResolver resolver;

  ChannelAudioCoordinator build({TtsEngine? tts, bool effects = true}) =>
      ChannelAudioCoordinator(
        resolver: resolver,
        playerFactory: (c) => players.putIfAbsent(c, FakePlayer.new),
        tts: tts,
        effectBytes: (name) async => name == 'correct' ? Uint8List(2) : null,
        effectsEnabled: () => effects,
      );

  setUp(() {
    players = {};
    resolver = InMemoryAudioResolver()..put('ex', 'audio', Uint8List(4));
  });

  AudioRequest prompt([int priority = 10]) => AudioRequest(
    source: const PrerecordedAudio(exerciseId: 'ex', ref: 'audio'),
    channel: AudioChannel.narration,
    priority: priority,
  );

  test('a prompt plays and completes', () async {
    final audio = build();
    final h = audio.play(prompt());
    await pumpEventQueue();
    expect(players[AudioChannel.narration]!.log, ['play ex_audio']);
    players[AudioChannel.narration]!.finish();
    expect(await h.done, PlaybackPhase.completed);
  });

  test('a missing asset is unavailable, not an error', () async {
    final audio = build();
    final h = audio.play(
      const AudioRequest(
        source: PrerecordedAudio(exerciseId: 'ex', ref: 'nope'),
        channel: AudioChannel.narration,
      ),
    );
    expect(await h.done, PlaybackPhase.unavailable);
  });

  test('a platform failure resolves as error and never throws', () async {
    final audio = build();
    players[AudioChannel.narration] = FakePlayer()..failPlay = true;
    expect(await audio.play(prompt()).done, PlaybackPhase.error);
  });

  test('a second voice replaces the first: no two voices at once', () async {
    final audio = build();
    final first = audio.play(prompt());
    await pumpEventQueue();
    final second = audio.play(
      const AudioRequest(
        source: PrerecordedAudio(exerciseId: 'ex', ref: 'audio'),
        channel: AudioChannel.character,
        priority: 10,
      ),
    );
    await pumpEventQueue();
    expect(await first.done, PlaybackPhase.stopped);
    expect(players[AudioChannel.narration]!.log.last, 'stop');
    expect(players[AudioChannel.character]!.log, ['play ex_audio']);
    players[AudioChannel.character]!.finish();
    expect(await second.done, PlaybackPhase.completed);
  });

  test('a lower-priority voice is dropped while a higher one plays', () async {
    final audio = build();
    audio.play(prompt(10));
    await pumpEventQueue();
    final low = audio.play(
      const AudioRequest(
        source: PrerecordedAudio(exerciseId: 'ex', ref: 'audio'),
        channel: AudioChannel.character,
        priority: 1,
      ),
    );
    expect(await low.done, PlaybackPhase.stopped);
    expect(players.containsKey(AudioChannel.character), isFalse);
  });

  test(
    'effects play alongside a voice, and respect the Réglages toggle',
    () async {
      final audio = build();
      audio.play(prompt());
      await pumpEventQueue();
      audio.play(
        const AudioRequest(
          source: EffectAudio('correct'),
          channel: AudioChannel.sfx,
        ),
      );
      await pumpEventQueue();
      expect(players[AudioChannel.narration]!.log, [
        'play ex_audio',
      ], reason: 'voice not interrupted');
      expect(players[AudioChannel.sfx]!.log, ['play sfx_correct']);

      final muted = build(effects: false);
      final h = muted.play(
        const AudioRequest(
          source: EffectAudio('correct'),
          channel: AudioChannel.sfx,
        ),
      );
      expect(await h.done, PlaybackPhase.stopped);
    },
  );

  test('tts speaks only a supported locale', () async {
    final tts = FakeTts({'fr-CA'});
    final audio = build(tts: tts);
    final ok = audio.play(
      const AudioRequest(
        source: TtsUtterance(text: 'sept plus cinq', locale: 'fr-CA'),
        channel: AudioChannel.narration,
      ),
    );
    expect(await ok.done, PlaybackPhase.completed);
    expect(tts.spoken, ['fr-CA:sept plus cinq']);

    final no = audio.play(
      const AudioRequest(
        source: TtsUtterance(text: 'seven', locale: 'en-CA'),
        channel: AudioChannel.narration,
      ),
    );
    expect(await no.done, PlaybackPhase.unavailable);
    expect(
      await build()
          .play(
            const AudioRequest(
              source: TtsUtterance(text: 'x', locale: 'fr-CA'),
              channel: AudioChannel.narration,
            ),
          )
          .done,
      PlaybackPhase.unavailable,
      reason: 'no tts engine installed',
    );
  });

  test('stopping a handle stops only its own playback', () async {
    final audio = build();
    final first = audio.play(prompt());
    await pumpEventQueue();
    final second = audio.play(prompt());
    await pumpEventQueue();
    await first.stop(); // already replaced: must not stop the second
    expect(
      players[AudioChannel.narration]!.log.where((l) => l == 'stop'),
      hasLength(1),
    );
    await second.stop();
    expect(await second.done, PlaybackPhase.stopped);
  });

  test('dispose stops everything and disposes every player', () async {
    final audio = build();
    final h = audio.play(prompt());
    await pumpEventQueue();
    await audio.dispose();
    expect(await h.done, PlaybackPhase.stopped);
    expect(players[AudioChannel.narration]!.log.last, 'dispose');
  });

  group('master volume (Réglages)', () {
    test('every play is set to the master volume first', () async {
      var master = 0.7;
      final audio = ChannelAudioCoordinator(
        resolver: resolver,
        playerFactory: (c) => players.putIfAbsent(c, FakePlayer.new),
        masterVolume: () => master,
      );
      audio.play(prompt());
      await pumpEventQueue();
      expect(players[AudioChannel.narration]!.volume, 0.7);

      // Moved while playing: pushed at once, not at the next play.
      master = 0.2;
      await audio.refreshVolume();
      expect(players[AudioChannel.narration]!.volume, 0.2);
    });

    test(
      'ducked music is a fraction of the master, not of full volume',
      () async {
        resolver.put('ex', 'music', Uint8List(4));
        final audio = ChannelAudioCoordinator(
          resolver: resolver,
          playerFactory: (c) => players.putIfAbsent(c, FakePlayer.new),
          masterVolume: () => 0.5,
        );
        audio.play(
          const AudioRequest(
            source: PrerecordedAudio(exerciseId: 'ex', ref: 'music'),
            channel: AudioChannel.music,
            priority: 1,
          ),
        );
        await pumpEventQueue();
        expect(players[AudioChannel.music]!.volume, 0.5);
        audio.play(prompt());
        await pumpEventQueue();
        expect(players[AudioChannel.music]!.volume, closeTo(0.15, 1e-9));
        players[AudioChannel.narration]!.finish();
        await pumpEventQueue();
        expect(players[AudioChannel.music]!.volume, 0.5);
      },
    );
  });
}
