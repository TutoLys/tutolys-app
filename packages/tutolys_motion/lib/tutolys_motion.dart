/// Characters and the animation director.
///
/// Consumes `RuntimeEvent`s from engine_sdk and turns them into character
/// reactions. Nothing in an engine imports this package (enforced by
/// `test/architecture_boundaries_test.dart` in the app): that's what lets a
/// Rive renderer replace the placeholder fox without a line of engine code
/// changing.
///
/// The fox is drawn by [PlaceholderCharacterRenderer] until real art exists;
/// a Rive renderer is Phase 7 and arrives as another `CharacterRenderer`.
library;

export 'src/actor_scheduler.dart';
export 'src/animation_director.dart';
export 'src/character_manifest.dart';
export 'src/character_registry.dart';
export 'src/character_stage.dart';
export 'src/placeholder_renderer.dart';
export 'src/reaction.dart';
export 'src/reaction_policy.dart';
