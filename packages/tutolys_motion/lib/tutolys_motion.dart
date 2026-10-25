/// Characters and the animation director.
///
/// Consumes `RuntimeEvent`s from engine_sdk and turns them into character
/// reactions. Nothing in an engine imports this package (enforced by
/// `test/architecture_boundaries_test.dart` in the app): that's what lets a
/// Rive renderer replace the placeholder fox without a line of engine code
/// changing.
///
/// Phase 1 ships the contracts and the pure parts — manifest fallbacks,
/// the default reaction policy, per-actor scheduling. The director itself
/// and the placeholder renderer are Phase 2.
library;

export 'src/actor_scheduler.dart';
export 'src/character_manifest.dart';
export 'src/character_registry.dart';
export 'src/reaction.dart';
export 'src/reaction_policy.dart';
