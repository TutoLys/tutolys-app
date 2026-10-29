import '../../data/local_db/node_progress_local.dart';
import 'path_controller.dart';

/// A node's lessons and how far this kid is through them.
///
/// A node can carry several lessons (exercises at ranks 0..N). Tapping it
/// plays the first unfinished one in rank order; the node is complete only
/// when every lesson is. "Finished" is this device's record
/// (`nodeProgressProvider`), never server mastery.
class NodeLessons {
  const NodeLessons({required this.lessons, required this.done});

  /// Rank order, one envelope per lesson, already in the kid's language.
  final List<Map<String, Object?>> lessons;

  /// Exercise ids among [lessons] the kid has finished.
  final Set<String> done;

  int get total => lessons.length;
  int get doneCount => done.length;
  bool get complete => lessons.isNotEmpty && doneCount == total;

  /// The lesson a tap plays: the first unfinished, or the first again once
  /// all are done (a replay).
  Map<String, Object?> get next => lessons.firstWhere(
    (l) => !done.contains(l['exercise_id']),
    orElse: () => lessons.first,
  );
}

NodeLessons nodeLessons(
  List<Map<String, Object?>> lessons,
  NodeProgress? progress,
) {
  final ids = lessons.map((l) => l['exercise_id'] as String).toList();
  final recorded = progress?.exerciseIds;
  final Set<String> done;
  if (progress == null || ids.isEmpty) {
    done = const {};
  } else if (recorded == null) {
    // Written before lessons were tracked: the node had one lesson then,
    // its first, and that is the one that was finished.
    done = {ids.first};
  } else {
    // A lesson counts once whatever language it was played in. The
    // backend's `lesson_group` is the original lesson's exercise id, shared
    // by its translations: a French lesson's group is its own id, and its
    // English twin carries that same id as its group. So a lesson is done
    // when the record holds its id or its group (2026-10-26: Yelhan's
    // French completions read 0/2 once the app was set to English).
    done = {
      for (final lesson in lessons)
        if (recorded.contains(lesson['exercise_id']) ||
            recorded.contains(lesson['lesson_group']))
          lesson['exercise_id'] as String,
    };
  }
  return NodeLessons(lessons: lessons, done: done);
}

/// [nodeLessons] for every node on the current Carte with a published
/// lesson, downloaded or not (`PathState.carteLessons`).
Map<String, NodeLessons> nodeLessonsOf(
  PathState state,
  Map<String, NodeProgress> progress,
) => {
  for (final MapEntry(:key, :value) in state.carteLessons.entries)
    key: nodeLessons(value, progress[key]),
};
