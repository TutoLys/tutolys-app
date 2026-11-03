import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A character that lives *on* a board: Foxy walking the path planner's
/// grid. The engine places it (which cell, how big), and that placement may
/// tween like any board geometry; who the character is and how it reacts
/// belong to the host (plan PLAN_GRADES_2_6_ENGINES §3.3, fix 4).
///
/// The host supplies [BoardActorScope.builder], typically the motion
/// package's stage driven by the `AnimationDirector`, so a Rive Foxy can
/// walk the grid without the engine changing. The activity view provides a
/// default that reacts to the session's verdicts.
typedef BoardActorBuilder = Widget Function(
  BuildContext context,
  String role,
  double size,
);

class BoardActorScope extends InheritedWidget {
  const BoardActorScope({
    required this.builder,
    required super.child,
    super.key,
  });

  final BoardActorBuilder builder;

  static BoardActorBuilder? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BoardActorScope>()?.builder;

  @override
  bool updateShouldNotify(BoardActorScope old) => builder != old.builder;
}

/// The board's character slot. [role] names the part it plays (`walker`),
/// never a character: the cast is the host's.
class BoardActor extends StatelessWidget {
  const BoardActor({required this.role, required this.size, super.key});

  final String role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final builder = BoardActorScope.maybeOf(context);
    return ExcludeSemantics(
      child: builder == null
          // No host: an engine on its own, in a test or a sample.
          ? TutolysMascot(size: size)
          : builder(context, role, size),
    );
  }
}
