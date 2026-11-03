/// Characters and the animation director.
///
/// Consumes `RuntimeEvent`s from engine_sdk and turns them into character
/// reactions. Nothing in an engine imports this package (enforced by
/// `test/architecture_boundaries_test.dart` in the app): that's what lets a
/// Rive renderer replace the placeholder fox without a line of engine code
/// changing.
///
/// The fox is drawn by [BitmapCharacterRenderer]: the real fox art, moved
/// by native Flutter motion. [PlaceholderCharacterRenderer] is the painted
/// last-resort fallback. A Rive renderer (not approved yet) would arrive as
/// another `CharacterRenderer` plus a manifest — see ADR 0060.
library;

export 'src/actor_scheduler.dart';
export 'src/animation_director.dart';
export 'src/bitmap_renderer.dart';
export 'src/character_manifest.dart';
export 'src/character_registry.dart';
export 'src/character_stage.dart';
export 'src/engine_moments.dart';
export 'src/motion_recipes.dart';
export 'src/particles.dart';
export 'src/placeholder_renderer.dart';
export 'src/reaction.dart';
export 'src/reaction_policy.dart';
