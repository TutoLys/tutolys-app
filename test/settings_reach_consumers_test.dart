import 'dart:async';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';
import 'package:tutolys_app/main.dart';

/// Records what the coordinator asks of it; plays nothing.
class _Player implements ChannelPlayer {
  final played = <String>[];
  final _complete = StreamController<void>.broadcast();
  double volume = 1;
  bool stopped = false;

  @override
  Future<void> play(Uint8List bytes, {required String cacheKey}) async =>
      played.add(cacheKey);
  @override
  Stream<void> get onComplete => _complete.stream;
  @override
  Future<void> stop() async => stopped = true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> dispose() async {}
}

/// Hafid: "make sure the settings replicate on our engines, sounds,
/// animations". Each test drives Réglages' own controller and checks the
/// thing that actually plays or moves, so a consumer that ignores a
/// setting fails here.
void main() {
  late LocalDatabase db;
  late ProviderContainer container;
  late Map<AudioChannel, _Player> players;

  setUp(() async {
    db = LocalDatabase.memory();
    players = {};
    container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        activeKidIdProvider.overrideWithValue('kid-lea'),
        audioResolverProvider.overrideWithValue(
          InMemoryAudioResolver()
            ..put('ex', 'q', Uint8List(4))
            ..put('ex', 'song', Uint8List(4)),
        ),
        channelPlayerFactoryProvider.overrideWithValue(
          (c) => players.putIfAbsent(c, _Player.new),
        ),
      ],
    );
    await container.read(storedSettingsProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SettingsController settings() =>
      container.read(settingsControllerProvider.notifier);
  AudioCoordinator audio() => container.read(audioCoordinatorProvider);

  PlaybackHandle play(AudioChannel channel, AudioSource source) =>
      audio().play(AudioRequest(source: source, channel: channel, priority: 5));

  const question = PrerecordedAudio(exerciseId: 'ex', ref: 'q');
  const song = PrerecordedAudio(exerciseId: 'ex', ref: 'song');

  test('overall volume scales what plays, and moves it live', () async {
    await settings().setVolume(40);
    play(AudioChannel.narration, question);
    await pumpEventQueue();
    expect(players[AudioChannel.narration]!.volume, closeTo(0.4, 1e-9));

    await settings().setVolume(10);
    await pumpEventQueue();
    expect(players[AudioChannel.narration]!.volume, closeTo(0.1, 1e-9));
  });

  test('sound effects off: an effect is refused before it loads', () async {
    // The app bundles no effects yet, so "on" ends `unavailable`; "off"
    // must stop at the gate instead.
    final on = play(AudioChannel.sfx, const EffectAudio('correct'));
    expect(await on.done, PlaybackPhase.unavailable);

    await settings().setSoundEffects(false);
    final off = play(AudioChannel.sfx, const EffectAudio('correct'));
    expect(await off.done, PlaybackPhase.stopped);
  });

  test('music off: nothing plays, and what was playing stops', () async {
    play(AudioChannel.music, song);
    await pumpEventQueue();
    expect(players[AudioChannel.music]!.played, ['ex_song']);

    await settings().setMusic(false);
    await pumpEventQueue();
    expect(players[AudioChannel.music]!.stopped, isTrue);

    final again = play(AudioChannel.music, song);
    expect(await again.done, PlaybackPhase.stopped);
    expect(players[AudioChannel.music]!.played, ['ex_song']);
  });

  test('read aloud off: a question being read stops', () async {
    final reading = play(AudioChannel.narration, question);
    await pumpEventQueue();
    await settings().setReadAloud(false);
    expect(await reading.done, PlaybackPhase.stopped);
    expect(players[AudioChannel.narration]!.stopped, isTrue);
  });

  group('reduce animations', () {
    Future<bool> disabledUnder(
      WidgetTester tester, {
      required bool platform,
      required bool setting,
    }) async {
      late bool seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: platform),
          child: ReduceMotionScope(
            reduceMotion: setting,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.disableAnimationsOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('the setting turns motion off for everything below', (
      tester,
    ) async {
      expect(
        await disabledUnder(tester, platform: false, setting: true),
        isTrue,
      );
      expect(
        await disabledUnder(tester, platform: false, setting: false),
        isFalse,
      );
    });

    testWidgets('it never overrides the OS asking for less motion', (
      tester,
    ) async {
      expect(
        await disabledUnder(tester, platform: true, setting: false),
        isTrue,
      );
    });
  });
}
