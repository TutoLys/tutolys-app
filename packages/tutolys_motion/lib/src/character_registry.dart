import 'package:flutter/widgets.dart';

import 'character_manifest.dart';
import 'reaction.dart';

/// What a renderer is told to show.
class CharacterActorState {
  const CharacterActorState({
    required this.manifest,
    required this.reaction,
    required this.generation,
    required this.reducedMotion,
  });

  final CharacterManifest manifest;

  /// Already resolved through the manifest's fallbacks.
  final Reaction reaction;

  /// Bumped on every accepted cue. A renderer finishing an old reaction
  /// compares generations instead of resetting the actor itself — the race
  /// animation-system-plan §4 found in `MascotEngineFeedback`.
  final int generation;

  /// Rest on a still pose for [reaction]; no looping or travelling motion.
  final bool reducedMotion;
}

/// Draws a character. Implementations are independent of animation
/// technology; nothing above this interface knows whether a fox is painted,
/// a PNG, or a Rive state machine.
abstract interface class CharacterRenderer {
  RendererType get type;

  /// Must not throw for a reaction it lacks art for — draw the idle pose.
  Widget build(BuildContext context, CharacterActorState state);
}

/// Resolves character ids to manifests and renderer types to renderers.
class CharacterRegistry {
  CharacterRegistry({
    required Iterable<CharacterManifest> manifests,
    required Iterable<CharacterRenderer> renderers,
  }) : _manifests = {for (final m in manifests) m.id: m},
       _renderers = {for (final r in renderers) r.type: r};

  final Map<String, CharacterManifest> _manifests;
  final Map<RendererType, CharacterRenderer> _renderers;

  CharacterManifest? manifest(String id) => _manifests[id];

  /// The renderer for [manifest], falling back to the placeholder when its
  /// own type isn't installed (a Rive character on a build without Rive).
  CharacterRenderer? rendererFor(CharacterManifest manifest) =>
      _renderers[manifest.rendererType] ?? _renderers[RendererType.placeholder];
}

/// Which characters fill an activity's roles. Comes from activity or
/// subject configuration — never from an engine.
class CastAssignment {
  const CastAssignment(this.characterIdByRole);
  final Map<ActorRole, String> characterIdByRole;
}
