import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

import '../audio/app_sounds.dart';
import '../pairing/pairing_controller.dart';
import '../../data/sync/drift_audio_resolver.dart';
import '../settings/settings_controller.dart';

/// Engines on the new `LearningEngine` contract. An exercise plays on the
/// new runtime as soon as every one of its questions' engines is listed
/// here; anything else falls back to the legacy registry inside the same
/// shell. Since Phase 4 (ADR 0022) all four launch engines are here, so the
/// legacy path serves nothing that is published today — it stays only as a
/// fallback until it is deleted.
final learningEngineRegistryProvider = Provider<LearningEngineRegistry>(
  (ref) => LearningEngineRegistry([
    eraseEngine(const SingleChoiceEngine()),
    eraseEngine(const TimedChoiceEngine()),
    eraseEngine(const PairMatchBoardEngine()),
    eraseEngine(const ComposeSlotsEngine()),
    eraseEngine(const SortBucketsEngine()),
    eraseEngine(const TimelineCalendarEngine()),
    eraseEngine(const FindItEngine()),
    eraseEngine(const DataGraphEngine()),
    eraseEngine(const PassageReaderEngine()),
    eraseEngine(const BalanceScaleEngine()),
    eraseEngine(const LabelImageEngine()),
    eraseEngine(const FillBlankEngine()),
    eraseEngine(const PatternMachineEngine()),
    eraseEngine(const MeasureToolEngine()),
    eraseEngine(const PathPlannerEngine()),
    eraseEngine(const FractionSliceEngine()),
    eraseEngine(const GeometryLabEngine()),
    eraseEngine(const ExperimentLabEngine()),
    eraseEngine(const CountersBoardEngine()),
    eraseEngine(const SkyModelEngine()),
    eraseEngine(const MailStudioEngine()),
    eraseEngine(const FeedbackStudioEngine()),
    eraseEngine(const StagePresenterEngine()),
    eraseEngine(const MyGalleryEngine()),
    eraseEngine(const PhraseLabEngine()),
    eraseEngine(const ProofreadEngine()),
  ]),
);

/// Evaluators, by engine and policy.
final evaluatorRegistryProvider = Provider<EvaluatorRegistry>(
  (ref) => EvaluatorRegistry(const [
    McqExactEvaluator(),
    SpeedTapExactEvaluator(),
    PairMatchEvaluator(),
    ComposeBuildEvaluator(),
    SortBucketsEvaluator(),
    TimelineCalendarEvaluator(),
    FindItEvaluator(),
    DataGraphEvaluator(),
    PassageReaderEvaluator(),
    BalanceScaleEvaluator(),
    LabelImageEvaluator(),
    FillBlankEvaluator(),
    PatternMachineEvaluator(),
    MeasureToolEvaluator(),
    PathPlannerEvaluator(),
    FractionSliceEvaluator(),
    GeometryLabEvaluator(),
    ExperimentLabEvaluator(),
    CountersBoardEvaluator(),
    SkyModelEvaluator(),
    MailStudioEvaluator(),
    FeedbackStudioEvaluator(),
    StagePresenterEvaluator(),
    MyGalleryEvaluator(),
    PhraseLabEvaluator(),
    ProofreadEvaluator(),
  ]),
);

/// Who can appear in an activity and who draws them. The fox is the real
/// art, moved natively (`BitmapCharacterRenderer`); the painted placeholder
/// stays installed as the fallback. New art or a new renderer (Rive, one
/// day) is a change here and nowhere else — ADR 0060.
final characterRegistryProvider = Provider<CharacterRegistry>(
  (ref) => CharacterRegistry(
    manifests: [villageFox],
    renderers: const [
      BitmapCharacterRenderer(),
      PlaceholderCharacterRenderer(),
    ],
  ),
);

/// The fox as the Village and the Carte draw it, in every reaction (N6,
/// ADR 0112). The joyful, victory and surprised renders are a different
/// model (blue body, scarf instead of the cape), so the celebration showed
/// another character. Until renders of this fox arrive, its one pose plays
/// every reaction and the motion recipes tell them apart. Re-adding a pose
/// slot here is all a matching render needs.
final villageFox = CharacterManifest(
  id: BitmapCharacterRenderer.fox.id,
  version: BitmapCharacterRenderer.fox.version,
  rendererType: BitmapCharacterRenderer.fox.rendererType,
  supported: BitmapCharacterRenderer.fox.supported,
  fallbacks: BitmapCharacterRenderer.fox.fallbacks,
  idle: BitmapCharacterRenderer.fox.idle,
  assets: {
    for (final MapEntry(:key, :value)
        in BitmapCharacterRenderer.fox.assets.entries)
      if (!_offModelPoses.contains(key)) key: value,
  },
);

const _offModelPoses = {'pose.celebrating', 'pose.victory', 'pose.encouraging'};

/// The cast for every activity, for now. Subject-specific companions arrive
/// as data here, never as a name inside an engine.
const defaultCast = CastAssignment({ActorRole.guide: 'fox'});

/// Where the coordinator finds a clip's bytes: the synced audio cache.
final audioResolverProvider = Provider<AudioResolver>(
  (ref) =>
      AppAudioResolver(DriftAudioResolver(ref.watch(localDatabaseProvider))),
);

/// The coordinator's players. Null is the platform's own; tests put fakes
/// here to check that Réglages reaches what actually plays.
final channelPlayerFactoryProvider =
    Provider<ChannelPlayer Function(AudioChannel)?>((ref) => null);

/// The app's one audio coordinator: one player per channel for the whole
/// app, so a question being read and a character speaking can never overlap.
final audioCoordinatorProvider = Provider<AudioCoordinator>((ref) {
  final coordinator = ChannelAudioCoordinator(
    resolver: ref.watch(audioResolverProvider),
    playerFactory: ref.watch(channelPlayerFactoryProvider),
    effectsEnabled: () => ref.read(settingsControllerProvider).soundEffects,
    musicEnabled: () => ref.read(settingsControllerProvider).music,
    masterVolume: () => ref.read(settingsControllerProvider).volume / 100,
    // Background music sits well under voices and effects (ADR 0035).
    musicVolume: 0.35,
    effectBytes: appEffectBytes,
  );
  // Réglages applies live: the toggles are read on every request, and
  // these two act on what is already playing.
  ref.listen(settingsControllerProvider.select((s) => s.volume), (_, _) {
    unawaited(coordinator.refreshVolume());
  });
  ref.listen(settingsControllerProvider.select((s) => s.readAloud), (_, on) {
    if (!on) unawaited(coordinator.stopChannel(AudioChannel.narration));
  });
  ref.listen(settingsControllerProvider.select((s) => s.music), (_, on) {
    if (!on) unawaited(coordinator.stopChannel(AudioChannel.music));
  });
  ref.listen(settingsControllerProvider.select((s) => s.soundEffects), (_, on) {
    if (!on) unawaited(coordinator.stopChannel(AudioChannel.sfx));
  });
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// One progress line for the end-of-exercise celebration — the design's
/// `.quest-update-row` ("Termine 5 exercices · 3/5").
class CelebrationRowData {
  const CelebrationRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
  });

  final IconData icon;
  final String label;
  final int value;
  final int max;
}

/// Rows the celebration shows under the XP — daily-quest progress, a streak
/// extended. **Empty here on purpose**: quests are another feature's data.
/// Their owner overrides this provider (or replaces its body) to return the
/// progress *including* the exercise just finished; the play screen
/// invalidates `nodeProgressProvider` and the stats it records before the
/// celebration builds, so a provider watching those is already current.
final celebrationRowsProvider = FutureProvider<List<CelebrationRowData>>(
  (ref) async => const [],
);
