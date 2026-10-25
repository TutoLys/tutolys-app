import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

import 'character_manifest.dart';
import 'character_registry.dart';
import 'reaction.dart';

/// Draws a character with the existing painted fox, until real art exists.
///
/// The point of this renderer is the seam, not the look: it proves that a
/// reaction travels runtime event → director → policy → renderer with no
/// engine knowing, so a Rive renderer can replace it by manifest alone.
class PlaceholderCharacterRenderer implements CharacterRenderer {
  const PlaceholderCharacterRenderer();

  /// The fox as a manifest. Supports what `TutolysMascot` can show; the
  /// fallbacks send the rest to the nearest pose.
  static final fox = CharacterManifest(
    id: 'fox',
    version: 1,
    rendererType: RendererType.placeholder,
    supported: {
      Reaction.thinking,
      Reaction.explaining,
      Reaction.encouraging,
      Reaction.celebrating,
    },
    fallbacks: {
      Reaction.victory: Reaction.celebrating,
      Reaction.curious: Reaction.thinking,
      Reaction.speaking: Reaction.explaining,
      Reaction.listening: Reaction.thinking,
    },
  );

  @override
  RendererType get type => RendererType.placeholder;

  /// The closest `MascotMood`. Note what is *not* here: `MascotMood.incorrect`
  /// paints the danger red, and the design never shows red for a wrong
  /// answer — so `encouraging` borrows the gold `hint` pose instead.
  static MascotMood moodFor(Reaction r) => switch (r) {
    Reaction.thinking ||
    Reaction.curious ||
    Reaction.listening => MascotMood.thinking,
    Reaction.explaining ||
    Reaction.speaking ||
    Reaction.encouraging => MascotMood.hint,
    Reaction.celebrating || Reaction.victory => MascotMood.celebrating,
    Reaction.idle || Reaction.waiting || Reaction.sleeping => MascotMood.idle,
  };

  @override
  Widget build(BuildContext context, CharacterActorState state) =>
      LayoutBuilder(
        builder: (context, c) {
          final size = c.biggest.shortestSide.isFinite
              ? c.biggest.shortestSide
              : 96.0;
          // TutolysMascot already rests on a still pose when
          // MediaQuery.disableAnimations is set; reducedMotion here comes from
          // the same place.
          return TutolysMascot(mood: moodFor(state.reaction), size: size);
        },
      );
}
