import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

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
  ]),
);

/// Who can appear in an activity and who draws them. Only the fox, drawn by
/// the placeholder renderer, until real character art exists (Phase 7).
final characterRegistryProvider = Provider<CharacterRegistry>(
  (ref) => CharacterRegistry(
    manifests: [PlaceholderCharacterRenderer.fox],
    renderers: const [PlaceholderCharacterRenderer()],
  ),
);

/// The cast for every activity, for now. Subject-specific companions arrive
/// as data here, never as a name inside an engine.
const defaultCast = CastAssignment({ActorRole.guide: 'fox'});

/// The app's one audio coordinator: one player per channel for the whole
/// app, so a question being read and a character speaking can never overlap.
final audioCoordinatorProvider = Provider<AudioCoordinator>((ref) {
  final coordinator = ChannelAudioCoordinator(
    resolver: DriftAudioResolver(ref.watch(localDatabaseProvider)),
    effectsEnabled: () => ref.read(settingsControllerProvider).soundEffects,
    musicEnabled: () => ref.read(settingsControllerProvider).music,
  );
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
