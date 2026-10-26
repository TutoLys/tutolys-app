import 'dart:math';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics/diag_log.dart';

/// The app's own sounds (ADR 0035): background music and the shell's three
/// effect moments. Bundled assets, fetched only when first played, so on
/// the web they aren't part of the first download.

/// The `exerciseId` a [PrerecordedAudio] uses for an app sound rather than
/// a lesson's synced clip.
const appAudioScope = 'app';

/// The background loops, Hafid's picks from his six (ADR 0035, #4 and #6).
/// Each was crossfaded end into start, so it repeats without a seam.
/// Rebuilt from the masters by `tools/sounds/build_app_sounds.py`.
const musicTracks = ['music/village-1.m4a', 'music/village-2.m4a'];

/// The song the Village mascot sings when tapped, in the app's language
/// (not the subject's: it isn't a lesson).
String mascotSongFor(String languageCode) =>
    languageCode == 'en' ? 'songs/mascot-en.m4a' : 'songs/mascot-fr.m4a';

/// One loop per launch, so the village doesn't sound the same every time.
String pickMusicTrack([Random? random]) =>
    musicTracks[(random ?? Random()).nextInt(musicTracks.length)];

/// The three moments every engine shares, played by the shell's host
/// (decision D3: the shell owns VALIDER), never by an engine.
enum SfxMoment {
  /// VALIDER, right answer.
  answerRight('answer_right'),

  /// VALIDER, not yet right: a gentle cue. Never a voice saying "nooo"
  /// (the design rules out punishing feedback).
  answerRetry('answer_retry'),

  /// The end-of-activity celebration.
  activityComplete('activity_complete');

  const SfxMoment(this.effectName);
  final String effectName;
}

/// Each moment's sound, or null for a silent slot. Hafid's picks from
/// `Assets/Sounds/generated/` (2026-10-26): `right_b` (marimba), `wrong_a`
/// (soft low boop-boop), and his own winning jingle, levelled.
const sfxAssets = <SfxMoment, String?>{
  SfxMoment.answerRight: 'sfx/answer-right.m4a',
  SfxMoment.answerRetry: 'sfx/answer-retry.m4a',
  SfxMoment.activityComplete: 'sfx/activity-complete.m4a',
};

/// Bytes for an effect name, for `ChannelAudioCoordinator.effectBytes`.
/// A silent slot or a missing asset is null: the coordinator then reports
/// the effect unavailable, and nothing plays.
Future<Uint8List?> appEffectBytes(String name, {AssetBundle? bundle}) async {
  final moment = SfxMoment.values.where((m) => m.effectName == name);
  final asset = moment.isEmpty ? null : sfxAssets[moment.first];
  if (asset == null) return null;
  return _load(bundle ?? rootBundle, asset);
}

Future<Uint8List?> _load(AssetBundle bundle, String path) async {
  try {
    final data = await bundle.load('assets/sounds/$path');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (e, s) {
    recordCaught('app_sounds', e, s);
    return null;
  }
}

/// Serves [appAudioScope] clips from the bundle and everything else from
/// the lesson cache.
class AppAudioResolver implements AudioResolver {
  AppAudioResolver(this.lessons, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AudioResolver lessons;
  final AssetBundle _bundle;

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) => exerciseId == appAudioScope
      ? _load(_bundle, ref)
      : lessons.bytesFor(exerciseId: exerciseId, ref: ref);
}
