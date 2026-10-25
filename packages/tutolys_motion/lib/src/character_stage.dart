import 'package:flutter/widgets.dart';

import 'animation_director.dart';
import 'character_registry.dart';
import 'reaction.dart';

/// Where a character appears. The shell gives it a slot; it asks the
/// director what the actor in [role] is doing and the registry who draws it.
///
/// A renderer that throws while building shows nothing for that frame
/// rather than taking the question down with it — a character is never
/// load-bearing.
class CharacterStage extends StatelessWidget {
  const CharacterStage({
    required this.director,
    required this.registry,
    this.role = ActorRole.guide,
    this.size = 72,
    super.key,
  });

  final AnimationDirector director;
  final CharacterRegistry registry;
  final ActorRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final listenable = director.actor(role);
    if (listenable == null) return SizedBox.square(dimension: size);
    return ExcludeSemantics(
      // Decorative: the feedback banner says in words what the fox shows.
      child: SizedBox.square(
        dimension: size,
        child: ValueListenableBuilder<CharacterActorState>(
          valueListenable: listenable,
          builder: (context, state, _) {
            final renderer = registry.rendererFor(state.manifest);
            if (renderer == null) return const SizedBox.shrink();
            try {
              return renderer.build(context, state);
            } on Object catch (e) {
              debugPrint(
                'CharacterStage: ${state.manifest.id} failed to build: $e',
              );
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
