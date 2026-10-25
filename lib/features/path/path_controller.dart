import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/content_api.dart';
import '../../data/api/curriculum_api.dart';
import '../../data/local_db/database.dart';
import '../../data/sync/content_sync.dart';
import '../../data/sync/curriculum_sync.dart';
import '../pairing/pairing_controller.dart';

/// Where the Carte opens. Math was A7's whole thin slice and is still the
/// subject with the most real content; the subject pills switch from here.
const defaultPathSubject = 'MATH';

/// The subjects the Carte can show — the five with real curriculum data.
/// Culture québécoise is drawn by the design but has no backend subject yet
/// (open item #13), and a pill opening an empty map is worse than no pill.
const pathSubjects = ['MATH', 'FR', 'EN', 'SCI', 'SOC'];

/// What the path screen renders.
class PathState {
  const PathState({
    this.subject = defaultPathSubject,
    this.leaves = const [],
    this.exerciseByNodeId = const {},
    this.loading = true,
    this.offline = false,
    this.error,
  });

  /// Backend subject code (`MATH`, `FR`, …) this state describes.
  final String subject;

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
    final subject = state.subject;
    final kid = ref.read(sessionControllerProvider).kid;
    if (kid == null) {
      state = PathState(subject: subject, loading: false);
      return;
    }

    final curriculumSync = ref.read(curriculumSyncProvider);
    final contentSync = ref.read(contentSyncProvider);

    final curriculumReport = await curriculumSync.sync(
      subject: subject,
      grade: kid.gradeLevel,
    );
    // Exercise content for the same slice, so a tapped node actually has
    // something to play — ContentSync already existed (B8) but nothing in
    // the app ever called it before this.
    await contentSync.sync(subject: subject);

    final leaves = await curriculumSync.cachedLeaves(
      subject: subject,
      grade: kid.gradeLevel,
    );
    // Already rank-ordered (ContentSync.cachedExercises's own contract) —
    // the first write per node id wins, which is exactly "first by rank".
    final exerciseByNodeId = <String, Map<String, Object?>>{};
    for (final envelope in await contentSync.cachedExercises(
      subject: subject,
      grade: kid.gradeLevel,
    )) {
      exerciseByNodeId.putIfAbsent(
        envelope['skill_node_id'] as String,
        () => envelope,
      );
    }

    // A slow sync for one subject must not land on top of another the kid
    // has switched to in the meantime.
    if (state.subject != subject) return;

    state = PathState(
      subject: subject,
      leaves: leaves,
      exerciseByNodeId: exerciseByNodeId,
      loading: false,
      offline: curriculumReport.offline,
      error: curriculumReport.error,
    );
  }

  Future<void> refresh() => _load();

  /// Switches the Carte to another subject and loads it.
  Future<void> selectSubject(String subject) {
    if (subject == state.subject && !state.loading) return Future.value();
    state = PathState(subject: subject);
    return _load();
  }
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
