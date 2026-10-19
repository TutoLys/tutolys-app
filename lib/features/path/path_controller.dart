import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/content_api.dart';
import '../../data/api/curriculum_api.dart';
import '../../data/local_db/database.dart';
import '../../data/sync/content_sync.dart';
import '../../data/sync/curriculum_sync.dart';
import '../pairing/pairing_controller.dart';

/// Hardcoded for A7's thin slice (Hafid's scope decision) — math is the
/// one Phase-4 dataset not mid-repair (see `a7-skill-path-plan.md`'s own
/// "B7 status" section). Subject switching is explicitly out of scope,
/// not an oversight.
const pathSubject = 'MATH';

/// What the path screen renders.
class PathState {
  const PathState({
    this.leaves = const [],
    this.exerciseByNodeId = const {},
    this.loading = true,
    this.offline = false,
    this.error,
  });

  final List<CachedSkillNode> leaves;

  /// One resolved exercise envelope per node — the first by rank, when a
  /// node has several (A7 plan's own simplification). A node's presence
  /// here is the only real, non-fabricated signal this pass has for
  /// "available" vs "locked": there is no progress/mastery model yet (A7
  /// plan's gap #5), so nothing is ever locked for having-been-attempted
  /// reasons, only for having nothing to play yet.
  final Map<String, Map<String, Object?>> exerciseByNodeId;

  final bool loading;
  final bool offline;
  final String? error;

  bool isAvailable(CachedSkillNode leaf) =>
      exerciseByNodeId.containsKey(leaf.id);
}

class PathController extends Notifier<PathState> {
  @override
  PathState build() {
    // Deliberately not awaited here: `build` must be synchronous (same
    // reasoning as `SessionController.build`'s own `restore()` deferral).
    // The screen shows a loading state until `_load` finishes.
    Future.microtask(_load);
    return const PathState();
  }

  Future<void> _load() async {
    final kid = ref.read(sessionControllerProvider).kid;
    if (kid == null) {
      state = const PathState(loading: false);
      return;
    }

    final curriculumSync = ref.read(curriculumSyncProvider);
    final contentSync = ref.read(contentSyncProvider);

    final curriculumReport = await curriculumSync.sync(
      subject: pathSubject,
      grade: kid.gradeLevel,
    );
    // Exercise content for the same slice, so a tapped node actually has
    // something to play — ContentSync already existed (B8) but nothing in
    // the app ever called it before this.
    await contentSync.sync(subject: pathSubject);

    final leaves = await curriculumSync.cachedLeaves(
      subject: pathSubject,
      grade: kid.gradeLevel,
    );
    // Already rank-ordered (ContentSync.cachedExercises's own contract) —
    // the first write per node id wins, which is exactly "first by rank".
    final exerciseByNodeId = <String, Map<String, Object?>>{};
    for (final envelope in await contentSync.cachedExercises(
      subject: pathSubject,
      grade: kid.gradeLevel,
    )) {
      exerciseByNodeId.putIfAbsent(
        envelope['skill_node_id'] as String,
        () => envelope,
      );
    }

    state = PathState(
      leaves: leaves,
      exerciseByNodeId: exerciseByNodeId,
      loading: false,
      offline: curriculumReport.offline,
      error: curriculumReport.error,
    );
  }

  Future<void> refresh() => _load();
}

final pathControllerProvider = NotifierProvider<PathController, PathState>(
  PathController.new,
);

// --- providers ---------------------------------------------------------

final curriculumApiProvider = Provider<CurriculumApi>(
  (ref) => CurriculumApi(dio: ref.watch(dioProvider)),
);

final curriculumSyncProvider = Provider<CurriculumSync>((ref) {
  return CurriculumSync(
    db: ref.watch(localDatabaseProvider),
    api: ref.watch(curriculumApiProvider),
    accessToken: () => ref.read(sessionControllerProvider).accessToken,
  );
});

final contentApiProvider = Provider<ContentApi>(
  (ref) => ContentApi(dio: ref.watch(dioProvider)),
);

final contentSyncProvider = Provider<ContentSync>((ref) {
  return ContentSync(
    db: ref.watch(localDatabaseProvider),
    api: ref.watch(contentApiProvider),
    accessToken: () => ref.read(sessionControllerProvider).accessToken,
  );
});
