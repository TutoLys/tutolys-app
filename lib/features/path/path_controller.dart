import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/content_api.dart';
import '../../data/api/curriculum_api.dart';
import '../../data/local_db/database.dart';
import '../../data/sync/content_freshness.dart';
import '../../data/sync/content_sync.dart';
import '../../data/sync/curriculum_sync.dart';
import '../../data/sync/content_in_use.dart';
import '../../data/sync/lesson_key.dart';
import '../../data/local_db/node_progress_local.dart';
import '../progress/progress_controller.dart';
import 'offline_window.dart';
import '../pairing/pairing_controller.dart';
import '../settings/settings_controller.dart';
import 'subject_language.dart';
import '../../core/diagnostics/diag_log.dart';
import '../../core/net/recovery.dart';

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
    this.lessonsByNodeId = const {},
    this.allLessonsByNodeId = const {},
    this.loading = true,
    this.offline = false,
    this.error,
    this.contentLocale = 'fr-CA',
    this.syncFailed = false,
    this.syncedAt,
    this.syncing = false,
  });

  /// Lessons are still downloading behind a map that is already drawn
  /// (A1). The Carte shows a small loader rather than "no lessons yet".
  final bool syncing;

  /// This state, drawn, with its lessons still syncing.
  PathState syncingCopy({bool? offline, String? error}) => PathState(
    subject: subject,
    leaves: leaves,
    lessonsByNodeId: lessonsByNodeId,
    allLessonsByNodeId: allLessonsByNodeId,
    loading: false,
    offline: offline ?? this.offline,
    error: error ?? this.error,
    contentLocale: contentLocale,
    syncFailed: syncFailed,
    syncedAt: syncedAt,
    syncing: true,
  );

  /// This state with nothing in flight any more.
  PathState copyDone() => PathState(
    subject: subject,
    leaves: leaves,
    lessonsByNodeId: lessonsByNodeId,
    allLessonsByNodeId: allLessonsByNodeId,
    loading: false,
    offline: offline,
    error: error,
    contentLocale: contentLocale,
    syncFailed: syncFailed,
    syncedAt: syncedAt,
  );

  /// Backend subject code (`MATH`, `FR`, …) this state describes.
  final String subject;

  final List<CachedSkillNode> leaves;

  /// Every lesson on each node, rank order, in the kid's language
  /// ([pickLessons]). A node's presence here is what makes it playable
  /// rather than locked; nothing gates on order.
  final Map<String, List<Map<String, Object?>>> lessonsByNodeId;

  /// Every published lesson per node, downloaded or not (ADR 0095): the
  /// cached envelope where it's on the device, a stub marked
  /// [isNotDownloaded] where it isn't. What the Carte draws, so a leaf
  /// outside the offline window keeps its real state instead of "soon".
  /// Empty until a manifest has been stored; the Carte then falls back to
  /// [lessonsByNodeId].
  final Map<String, List<Map<String, Object?>>> allLessonsByNodeId;

  /// [allLessonsByNodeId], or the cache when no manifest is stored yet.
  Map<String, List<Map<String, Object?>>> get carteLessons =>
      allLessonsByNodeId.isEmpty ? lessonsByNodeId : allLessonsByNodeId;

  /// Each node's first lesson.
  Map<String, Map<String, Object?>> get exerciseByNodeId => {
    for (final MapEntry(:key, :value) in lessonsByNodeId.entries)
      key: value.first,
  };

  final bool loading;

  /// The last sync of this subject couldn't reach the server.
  final bool offline;
  final String? error;

  /// The last sync of this subject's curriculum or lessons failed, so what
  /// shows is the cache: a lesson published since then is missing, and its
  /// node reads "soon". The Carte says so rather than letting it pass.
  final bool syncFailed;

  /// When this subject's lessons last synced, or null if never.
  final DateTime? syncedAt;

  /// The language this subject's lessons were asked for
  /// (`contentLocaleFor`). A node whose lesson came back in another
  /// language is marked as such on the Carte.
  final String contentLocale;

  bool isAvailable(CachedSkillNode leaf) =>
      lessonsByNodeId.containsKey(leaf.id);
}

/// Why the Carte has nothing to play, so the message can say which.
enum CarteGap {
  /// Nothing cached and the sync couldn't reach the server.
  offline,

  /// The curriculum has no skills in this subject at the kid's grade.
  noSkillsAtGrade,

  /// The skills exist but no lesson is written for any of them yet.
  noLessonsYet,
}

/// Null while loading, and whenever at least one lesson is playable.
CarteGap? carteGapOf(PathState state) {
  if (state.loading || state.lessonsByNodeId.isNotEmpty) return null;
  // Still downloading, or published but outside the window: not a gap.
  if (state.syncing || state.allLessonsByNodeId.isNotEmpty) return null;
  final unreachable = state.offline || state.error != null;
  // Unreachable with nothing cached says nothing about the content itself.
  if (unreachable) return CarteGap.offline;
  return state.leaves.isEmpty
      ? CarteGap.noSkillsAtGrade
      : CarteGap.noLessonsYet;
}

class PathController extends Notifier<PathState> {
  @override
  PathState build() {
    // Rebuilt, and so reloaded, when "Qui joue ?" switches kid.
    ref.watch(activeKidIdProvider);
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
    // A finished lesson moves the frontier: the window follows in the
    // background (ADR 0095). The Carte keeps showing what it has.
    ref.listen(nodeProgressProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue && !state.loading) {
        _load();
      }
    });
    return const PathState();
  }

  static Locale _localeOf(bool english) =>
      english ? const Locale('en', 'CA') : const Locale('fr', 'CA');

  /// Loads in flight, by subject: the recovery scheduler, a finished
  /// lesson and the Carte reappearing all call [refresh], and they share one
  /// load rather than stacking (A1: twelve tree fetches for one visit).
  final _loads = <String, Future<void>>{};

  Future<void> _load() {
    final subject = state.subject;
    return _loads[subject] ??= _loadGuarded(subject).whenComplete(() {
      _loads.remove(subject);
    });
  }

  /// How long the curriculum may take before the Carte gives up waiting
  /// on it and shows its cache (A1).
  static const curriculumTimeout = Duration(seconds: 15);

  /// [_loadOnce], but it always ends with `loading: false` (A1). A throw
  /// anywhere in a sync, a parse or a cast used to leave the Carte on its
  /// loader for good.
  Future<void> _loadGuarded(String subject) async {
    try {
      await _loadOnce(subject);
    } catch (e, st) {
      recordCaught('carte_load', e, st);
      ref.read(recoveryProvider).reportFailure();
      if (state.subject != subject) return;
      final kid = ref.read(sessionControllerProvider).kid;
      PathState? cached;
      try {
        if (kid != null) cached = await _fromCache(subject, kid.gradeLevel);
      } catch (e2, st2) {
        recordCaught('carte_cache', e2, st2);
      }
      if (state.subject != subject) return;
      state = PathState(
        subject: subject,
        leaves: cached?.leaves ?? state.leaves,
        lessonsByNodeId: cached?.lessonsByNodeId ?? state.lessonsByNodeId,
        allLessonsByNodeId:
            cached?.allLessonsByNodeId ?? state.allLessonsByNodeId,
        loading: false,
        error: '$e',
        contentLocale: state.contentLocale,
        syncFailed: true,
        syncedAt: state.syncedAt,
      );
    } finally {
      if (state.subject == subject && (state.loading || state.syncing)) {
        state = state.copyDone();
      }
    }
  }

  Future<void> _loadOnce(String subject) async {
    final kid = ref.read(sessionControllerProvider).kid;
    if (kid == null) {
      state = PathState(subject: subject, loading: false);
      return;
    }

    final curriculumSync = ref.read(curriculumSyncProvider);
    final contentSync = ref.read(contentSyncProvider);

    // The cache first, so neither the Carte nor play waits on the network
    // (ADR 0095); the sync's result replaces it when it lands.
    if (state.loading && state.leaves.isEmpty) {
      final cached = await _fromCache(subject, kid.gradeLevel);
      if (state.subject != subject || !state.loading) return;
      if (cached.leaves.isNotEmpty) state = cached.syncingCopy();
    }

    final curriculumReport = await curriculumSync
        .sync(subject: subject, grade: kid.gradeLevel)
        .timeout(
          curriculumTimeout,
          onTimeout: () =>
              const CurriculumSyncReport(count: 0, error: 'timeout'),
        );
    // The map is drawn from here on (A1): the lessons download in the
    // background and land on it as they come. Before, the Carte waited for
    // the whole download — tens of MB of audio on a first visit.
    if (state.subject != subject) return;
    state = (await _fromCache(subject, kid.gradeLevel)).syncingCopy(
      offline: curriculumReport.offline,
      error: curriculumReport.error,
    );

    final locale = contentLocaleFor(
      subject,
      _localeOf(ref.read(settingsControllerProvider).english),
    );
    final contentReport = await contentSync.sync(
      subject: subject,
      locale: locale,
      // The manifest says what exists before anything downloads: redraw
      // so a first visit shows the path, not "soon" everywhere.
      onManifest: () async {
        if (state.subject != subject) return;
        final known = await _fromCache(subject, kid.gradeLevel);
        if (state.subject != subject) return;
        state = known.syncingCopy(
          offline: curriculumReport.offline,
          error: curriculumReport.error,
        );
      },
    );
    _lastLoad = DateTime.now();
    final freshness = ContentFreshness(ref.read(localDatabaseProvider));
    final synced = curriculumReport.isOk && contentReport.isOk;
    final recovery = ref.read(recoveryProvider);
    if (synced) {
      recovery.reportSuccess();
    } else {
      recovery.reportFailure();
    }
    final syncedAt = synced
        ? await freshness.markSynced(subject, kid.gradeLevel)
        : await freshness.lastSynced(subject, kid.gradeLevel);

    final fresh = await _fromCache(subject, kid.gradeLevel);

    // A slow sync for one subject must not land on top of another the kid
    // has switched to in the meantime.
    if (state.subject != subject) return;

    state = PathState(
      subject: subject,
      leaves: fresh.leaves,
      lessonsByNodeId: fresh.lessonsByNodeId,
      allLessonsByNodeId: fresh.allLessonsByNodeId,
      loading: false,
      offline: curriculumReport.offline || contentReport.offline,
      error: curriculumReport.error,
      contentLocale: locale,
      syncFailed: !synced,
      syncedAt: syncedAt,
    );
    _prefetchOthers(subject);
  }

  /// This subject as the device has it, with no network.
  Future<PathState> _fromCache(String subject, int grade) async {
    final contentSync = ref.read(contentSyncProvider);
    final locale = contentLocaleFor(
      subject,
      _localeOf(ref.read(settingsControllerProvider).english),
    );
    final cached = await contentSync.cachedExercises(
      subject: subject,
      grade: grade,
    );
    final cachedIds = {for (final e in cached) e['exercise_id']};
    final manifest = await contentSync.storedManifest(
      subject: subject,
      grade: grade,
      askedLocale: locale,
    );
    return PathState(
      subject: subject,
      leaves: await ref
          .read(curriculumSyncProvider)
          .cachedLeaves(subject: subject, grade: grade),
      lessonsByNodeId: pickLessons(cached, locale: locale),
      allLessonsByNodeId: manifest.isEmpty
          ? const {}
          : pickLessons([
              ...cached,
              for (final e in manifest)
                if (!cachedIds.contains(e.exerciseId)) e.stub,
            ], locale: locale),
      loading: false,
      contentLocale: locale,
      syncedAt: state.syncedAt,
      offline: state.offline,
      syncFailed: state.syncFailed,
    );
  }

  /// Downloads a leaf outside the offline window, then shows it as
  /// playable (ADR 0095). Offline, says so rather than failing.
  Future<NodeDownload> download(String skillNodeId) async {
    final kid = ref.read(sessionControllerProvider).kid;
    if (kid == null) return NodeDownload.failed;
    final subject = state.subject;
    final result = await ref
        .read(contentSyncProvider)
        .downloadNode(
          skillNodeId: skillNodeId,
          grade: kid.gradeLevel,
          askedLocale: state.contentLocale,
        );
    if (result == NodeDownload.done && state.subject == subject) {
      final fresh = await _fromCache(subject, kid.gradeLevel);
      if (state.subject != subject) return result;
      state = PathState(
        subject: subject,
        leaves: state.leaves,
        lessonsByNodeId: fresh.lessonsByNodeId,
        allLessonsByNodeId: fresh.allLessonsByNodeId,
        loading: false,
        offline: false,
        error: state.error,
        contentLocale: state.contentLocale,
        syncFailed: state.syncFailed,
        syncedAt: state.syncedAt,
      );
    }
    return result;
  }

  /// Kids whose other subjects were already prefetched this run.
  final _prefetched = <String>{};

  /// Once per kid per run, after the first successful load: every other
  /// subject's window, one at a time, in the background, so the whole
  /// village plays offline (ADR 0095). Never awaited by anything.
  void _prefetchOthers(String loaded) {
    final kid = ref.read(sessionControllerProvider).kid;
    if (kid == null ||
        state.offline ||
        !ref.read(offlinePrefetchProvider) ||
        !_prefetched.add(kid.id)) {
      return;
    }
    final english = ref.read(settingsControllerProvider).english;
    final curriculumSync = ref.read(curriculumSyncProvider);
    final contentSync = ref.read(contentSyncProvider);
    Future(() async {
      for (final subject in pathSubjects) {
        if (subject == loaded) continue;
        if (ref.read(sessionControllerProvider).kid?.id != kid.id) return;
        final curriculum = await curriculumSync.sync(
          subject: subject,
          grade: kid.gradeLevel,
        );
        if (curriculum.offline) return;
        final content = await contentSync.sync(
          subject: subject,
          locale: contentLocaleFor(subject, _localeOf(english)),
        );
        if (content.offline) return;
      }
    }).catchError((Object _) {});
  }

  DateTime? _lastLoad;

  Future<void> refresh() => _load();

  /// Re-syncs when the Carte is shown again and the last attempt is older
  /// than [maxAge], so a lesson published meanwhile appears without a
  /// subject switch or a restart.
  Future<void> refreshIfStale({Duration maxAge = const Duration(minutes: 2)}) {
    final last = _lastLoad;
    if (state.loading || last == null) return Future.value();
    // Lessons cached in the wrong language are stale whatever their age:
    // a subject synced before its English versions existed kept showing
    // French in an English app (Hafid, Social studies).
    final wanted = contentLocaleFor(
      state.subject,
      _localeOf(ref.read(settingsControllerProvider).english),
    );
    if (wanted != state.contentLocale) return _load();
    // A lesson served in the other language is a translation that may
    // have been published since: worth asking again sooner.
    final fallbacks = state.lessonsByNodeId.values.any(
      (lessons) => lessons.any(
        (l) => (l['locale'] as String? ?? 'fr-CA') != state.contentLocale,
      ),
    );
    final age = fallbacks ? const Duration(seconds: 30) : maxAge;
    if (DateTime.now().difference(last) < age) return Future.value();
    return _load();
  }

  /// Switches the Carte to another subject and loads it.
  Future<void> selectSubject(String subject) {
    // Tapping the subject already shown re-syncs it if it's stale, rather
    // than doing nothing: it's the obvious "show me the latest" gesture.
    if (subject == state.subject) {
      return state.loading ? Future.value() : refreshIfStale();
    }
    state = PathState(subject: subject);
    return _load();
  }
}

/// Every lesson per node, in the kid's language where it exists.
///
/// [envelopes] may hold one lesson in several languages: siblings share the
/// cache, and a translation is another exercise of the same lesson
/// (`lessonKey`: its `lesson_group`, else node + engine + rank). Per
/// lesson this takes the version in [locale], else French, else whatever
/// was authored. Distinct exercises are never merged, so none is hidden;
/// lessons are ordered by (rank, engine, exercise id).
Map<String, List<Map<String, Object?>>> pickLessons(
  List<Map<String, Object?>> envelopes, {
  required String locale,
}) {
  final byLesson = <String, List<Map<String, Object?>>>{};
  for (final e in envelopes) {
    byLesson.putIfAbsent(lessonKeyOf(e), () => []).add(e);
  }
  Map<String, Object?> choose(List<Map<String, Object?>> versions) =>
      versions.firstWhere(
        (e) => e['locale'] == locale,
        orElse: () => versions.firstWhere(
          (e) => (e['locale'] ?? 'fr-CA') == 'fr-CA',
          orElse: () => versions.first,
        ),
      );

  final picked = <String, List<Map<String, Object?>>>{};
  for (final versions in byLesson.values) {
    final lesson = choose(versions);
    picked.putIfAbsent(lesson['skill_node_id'] as String, () => []).add(lesson);
  }
  for (final lessons in picked.values) {
    lessons.sort(_lessonOrder);
  }
  return picked;
}

int _lessonOrder(Map<String, Object?> a, Map<String, Object?> b) {
  final byRank = (a['rank'] as int).compareTo(b['rank'] as int);
  if (byRank != 0) return byRank;
  final byEngine = (a['engine_key'] as String).compareTo(
    b['engine_key'] as String,
  );
  if (byEngine != 0) return byEngine;
  return (a['exercise_id'] as String).compareTo(b['exercise_id'] as String);
}

/// Each node's first lesson only ([pickLessons]'s rank 0).
Map<String, Map<String, Object?>> pickLessonsByNode(
  List<Map<String, Object?>> envelopes, {
  required String locale,
}) => {
  for (final MapEntry(:key, :value) in pickLessons(
    envelopes,
    locale: locale,
  ).entries)
    key: value.first,
};

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

/// Whether a first successful Carte load prefetches every other subject's
/// offline window in the background (ADR 0095). Off in tests that count
/// sync calls.
final offlinePrefetchProvider = Provider<bool>((ref) => true);

/// Lessons on screen now: the offline window never evicts them.
final contentInUseProvider = Provider<ContentInUse>((ref) => ContentInUse());

final contentSyncProvider = Provider<ContentSync>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ContentSync(
    db: db,
    api: ref.watch(contentApiProvider),
    accessToken: () => ref.read(sessionControllerProvider).accessToken,
    inUse: ref.watch(contentInUseProvider),
    planWindow: OfflineWindowPlanner(
      db: db,
      kids: () async => ref.read(sessionControllerProvider).kids,
      activeKidId: () => ref.read(sessionControllerProvider).kid?.id,
      // Only when progress is already loaded: reading it here must not
      // start a network load of its own.
      mastered: () => ref.exists(progressControllerProvider)
          ? {
              for (final m in ref.read(progressControllerProvider).masteries)
                if (m.isMastered) m.skillNodeId,
            }
          : const {},
    ).plan,
  );
});
