import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

import '../pairing/pairing_controller.dart';
import '../../data/sync/drift_audio_resolver.dart';
import '../settings/settings_controller.dart';

/// Engines on the new `LearningEngine` contract. An exercise plays on the
/// new runtime as soon as every one of its questions' engines is listed
/// here; anything else still plays through the legacy registry inside the
/// same shell. `mcq` moved in Phase 3 (ADR 0021); the legacy `McqEngine`
/// stays registered there until nothing could need it.
final learningEngineRegistryProvider = Provider<LearningEngineRegistry>(
  (ref) => LearningEngineRegistry([eraseEngine(const SingleChoiceEngine())]),
);

/// Evaluators, by engine and policy.
final evaluatorRegistryProvider = Provider<EvaluatorRegistry>(
  (ref) => EvaluatorRegistry(const [McqExactEvaluator()]),
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
