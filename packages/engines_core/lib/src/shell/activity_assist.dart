import 'package:flutter/widgets.dart';

/// What the shell tells an engine about the help a child is getting on
/// this question (UX review G8, G17; ADR 0108).
///
/// - [paused]: a countdown stops while the question is read aloud or the
///   hint is open, so listening never costs time.
/// - [narrow]: three misses on this question. The engine makes the problem
///   smaller: a choice dims one wrong answer, a board points at one right
///   pair or slot. It never answers for the child.
class ActivityAssist extends InheritedWidget {
  const ActivityAssist({
    required this.paused,
    required this.narrow,
    required super.child,
    super.key,
  });

  final bool paused;
  final bool narrow;

  /// Misses on one question before the problem narrows.
  static const narrowAfter = 3;

  static ActivityAssist? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActivityAssist>();

  static bool pausedOf(BuildContext context) =>
      maybeOf(context)?.paused ?? false;

  static bool narrowOf(BuildContext context) =>
      maybeOf(context)?.narrow ?? false;

  @override
  bool updateShouldNotify(ActivityAssist old) =>
      paused != old.paused || narrow != old.narrow;
}

/// The wrong answer to dim once the problem narrows: the first in [order]
/// that isn't right and hasn't been tried. None when dimming it would leave
/// fewer than two answers to choose from, so a choice stays a choice.
String? answerToDim({
  required List<String> order,
  required Set<String> right,
  required Set<String> tried,
}) {
  final open = order.where((id) => !tried.contains(id)).toList();
  if (open.length <= 2) return null;
  for (final id in open) {
    if (!right.contains(id)) return id;
  }
  return null;
}
