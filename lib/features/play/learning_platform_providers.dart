import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

import '../pairing/pairing_controller.dart';
import '../../data/sync/drift_audio_resolver.dart';
import '../settings/settings_controller.dart';

/// Engines on the new `LearningEngine` contract. **Empty in Phase 2**: every
/// exercise still plays through the legacy registry inside the shell.
/// Phase 3 adds the ported `mcq` here, and an exercise moves to the new
/// runtime as soon as all of its questions' engines are listed.
final learningEngineRegistryProvider = Provider<LearningEngineRegistry>(
  (ref) => LearningEngineRegistry(const []),
);

/// Evaluators, by engine and policy. Empty until Phase 3, like the engines.
final evaluatorRegistryProvider = Provider<EvaluatorRegistry>(
  (ref) => EvaluatorRegistry(const []),
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
