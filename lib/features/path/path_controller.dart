import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/content_api.dart';
import '../../data/api/curriculum_api.dart';
import '../../data/local_db/database.dart';
import '../../data/sync/content_sync.dart';
import '../../data/sync/curriculum_sync.dart';
import '../pairing/pairing_controller.dart';
import '../settings/settings_controller.dart';
import 'subject_language.dart';

/// Where the Carte opens. Math was A7's whole thin slice and is still the
/// subject with the most real content; the subject pills switch from here.
const defaultPathSubject = 'MATH';

/// The subjects the Carte can show: every subject with real curriculum.
const pathSubjects = ['MATH', 'FR', 'EN', 'SCI', 'SOC', 'CCQ'];

/// What the path screen renders.
class PathState {
  const PathState({
    this.subject = defaultPathSubject,
    this.leaves = const [],
    this.exerciseByNodeId = const {},
    this.loading = true,
    this.offline = false,
    this.error,
    this.contentLocale = 'fr-CA',
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

  /// The language this subject's lessons were asked for
  /// (`contentLocaleFor`). A node whose lesson came back in another
  /// language is marked as such on the Carte.
  final String contentLocale;

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
    // A language change is a new manifest (backend ADR 0026): re-sync, or a
    // kid stays on whichever language they first synced. Only when it
    // changes what this subject asks for — Français and English don't
    // follow the app.
    ref.listen(settingsControllerProvider.select((s) => s.english), (
      previous,
      next,
    ) {
      if (previous == next) return;
      final subject = state.subject;
      if (contentLocaleFor(subject, _localeOf(previous ?? false)) !=
          contentLocaleFor(subject, _localeOf(next))) {
        refresh();
      }
    });
    return const PathState();
  }

  static Locale _localeOf(bool english) =>
      english ? const Locale('en', 'CA') : const Locale('fr', 'CA');

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
    final locale = contentLocaleFor(
      subject,
      _localeOf(ref.read(settingsControllerProvider).english),
    );
    await contentSync.sync(subject: subject, locale: locale);

    final leaves = await curriculumSync.cachedLeaves(
      subject: subject,
      grade: kid.gradeLevel,
    );
    final exerciseByNodeId = pickLessonsByNode(
      await contentSync.cachedExercises(
        subject: subject,
        grade: kid.gradeLevel,
      ),
      locale: locale,
    );

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
      contentLocale: locale,
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

/// One lesson per node, in the kid's language where it exists.
///
/// [envelopes] are rank-ordered (`ContentSync.cachedExercises`) and may hold
/// one lesson in two languages: siblings share the cache, and a translation
/// is another exercise on the same node and rank. For each (node, rank) this
/// takes the version in [locale], else French, else whatever was authored;
/// then the first rank per node, as before.
Map<String, Map<String, Object?>> pickLessonsByNode(
  List<Map<String, Object?>> envelopes, {
  required String locale,
}) {
  final byLesson = <(String, int), List<Map<String, Object?>>>{};
  for (final e in envelopes) {
    byLesson
        .putIfAbsent((e['skill_node_id'] as String, e['rank'] as int), () => [])
        .add(e);
  }
  Map<String, Object?> choose(List<Map<String, Object?>> versions) =>
      versions.firstWhere(
        (e) => e['locale'] == locale,
        orElse: () => versions.firstWhere(
          (e) => (e['locale'] ?? 'fr-CA') == 'fr-CA',
          orElse: () => versions.first,
        ),
      );

  final picked = <String, Map<String, Object?>>{};
  for (final MapEntry(key: (node, _), value: versions) in byLesson.entries) {
    // Map insertion follows rank order, so the first per node is the lowest.
    picked.putIfAbsent(node, () => choose(versions));
  }
  return picked;
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
