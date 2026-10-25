import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/progress_api.dart';
import '../../data/local_db/streak_local.dart';
import '../pairing/pairing_controller.dart';
import 'grade_level.dart';
import 'progress_cache.dart';
import 'local_progress.dart';

/// Real mastery/streak counts only — `null` streak means "couldn't read it
/// this time at all, not even an offline estimate", never a fabricated 0.
/// Shared by `HomeScreen` and `ProfileScreen` rather than each fetching its
/// own copy: it's the same kid, the same one network call either way.
class ProgressState {
  const ProgressState({
    this.currentStreakDays,
    this.masteredCount = 0,
    this.totalSkills = 0,
    this.loading = true,
    this.offline = false,
    this.isStreakEstimated = false,
    this.freezesAvailable,
    this.dailyQuest,
    this.totalXp = 0,
    this.masteries = const [],
    this.level,
    this.skillsCompleted,
    this.skillsTotal,
    this.levelProgress,
    this.stale = false,
  });

  final int? currentStreakDays;
  final int masteredCount;
  final int totalSkills;
  final bool loading;
  final bool offline;

  /// True when the server couldn't be reached and `currentStreakDays` is
  /// this device's own count alone. No longer drawn as a `~` prefix: the
  /// streak shown is always the larger of the two (ADR 0032).
  final bool isStreakEstimated;

  /// Null while offline/loading/unreachable — same "unknown, not a
  /// fabricated 0" rule as `currentStreakDays`. The offline local estimate
  /// has no opinion on freeze balance, so this stays null there too.
  final int? freezesAvailable;

  /// Null for the same reasons, or for a kid who's never played.
  final DailyQuestDto? dailyQuest;

  /// Always a real number, even offline — see `ProgressSnapshot.totalXp`.
  /// Stays `0` (the default) while offline, same as the local streak
  /// estimate has no opinion on freeze balance: XP has no local-estimate
  /// path, only a real server read.
  final int totalXp;

  /// Per-skill mastery, exactly as the backend served it. Kept raw so a
  /// caller can join it against the cached curriculum — which is how the
  /// Village gets a per-subject figure without a new endpoint.
  final List<SkillMasteryDto> masteries;

  /// The school year's level, 1–99 (ADR 0033): this device's count of
  /// completed skills merged with the server's, never lower than a level
  /// already shown in this grade. Null until there's a grade to measure.
  final int? level;

  /// The level's numerator and denominator, as merged.
  final int? skillsCompleted;
  final int? skillsTotal;

  /// How far toward the next level, 0..1. Null whenever [level] is.
  final double? levelProgress;

  /// The last read failed, and these are the last good values this device
  /// saw (`ProgressCache`), never zeros. At most a subtle hint.
  final bool stale;

  ProgressState withLevel(GradeLevel? g) => ProgressState(
    currentStreakDays: currentStreakDays,
    masteredCount: masteredCount,
    totalSkills: totalSkills,
    loading: loading,
    offline: offline,
    isStreakEstimated: isStreakEstimated,
    freezesAvailable: freezesAvailable,
    dailyQuest: dailyQuest,
    totalXp: totalXp,
    masteries: masteries,
    level: g?.level,
    skillsCompleted: g?.completed,
    skillsTotal: g?.total,
    levelProgress: g?.progress,
    stale: stale,
  );
}

class ProgressController extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    // Rebuilt, and so reloaded, when "Qui joue ?" switches kid.
    ref.watch(activeKidIdProvider);
    _server = null;
    // A finished lesson moves the level at once, without a network read.
    ref.listen(localNodeProgressProvider, (_, next) {
      if (next.hasValue) _applyLevel();
    });
    // Same reasoning as HomeController/PathController: build() must stay
    // synchronous, so the screen shows a loading state until `_load` ends.
    Future.microtask(_load);
    return const ProgressState();
  }

  Future<void> _load() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      state = const ProgressState(loading: false);
      return;
    }

    final result = await ref
        .read(progressApiProvider)
        .fetchMyProgress(accessToken: token);
    // This device's own count of consecutive days played. Today's play
    // reaches the server only once telemetry uploads, so the server can
    // trail it; the streak shown is whichever is larger, so a child never
    // watches it go backwards while the server catches up (ADR 0032).
    final local = await StreakLocal(
      ref.read(localDatabaseProvider),
      kidId: ref.read(activeKidIdProvider) ?? unpairedKidId,
    ).currentStreak();

    // A failed read must never look like lost progress: the last good read
    // stands in, and fills what a degraded read left empty (ADR 0033).
    final cache = ProgressCache(
      ref.read(localDatabaseProvider),
      kidId: ref.read(activeKidIdProvider) ?? unpairedKidId,
    );
    final cached = await cache.read();
    final ProgressSnapshot? shown;
    switch (result) {
      case ProgressFetched(:final snapshot):
        shown = mergeWithCached(snapshot, cached);
        await cache.write(shown);
      case ProgressOffline() || ProgressUnauthorized() || ProgressFailed():
        shown = cached;
    }
    if (!ref.mounted) return;

    final offline = result is ProgressOffline;
    state = shown == null
        // Never read successfully on this device: offline shows the local
        // streak, anything else shows nothing rather than a made-up zero.
        ? ProgressState(
            loading: false,
            offline: offline,
            // This device's own count is real whatever the failure; only a
            // local 0 says nothing, and that stays a dash.
            currentStreakDays: offline || local > 0 ? local : null,
            isStreakEstimated: true,
            stale: result is! ProgressFetched,
          )
        : ProgressState(
            currentStreakDays: switch (shown.currentStreakDays) {
              final server? => server > local ? server : local,
              // Unknown on the server: this device's count is still real,
              // but a local 0 says nothing, so that stays a dash.
              null => local > 0 ? local : null,
            },
            masteredCount: shown.masteredCount,
            totalSkills: shown.masteries.length,
            loading: false,
            offline: offline,
            isStreakEstimated: result is! ProgressFetched,
            stale: result is! ProgressFetched,
            freezesAvailable: shown.freezesAvailable,
            dailyQuest: shown.dailyQuest,
            totalXp: shown.totalXp,
            masteries: shown.masteries,
          );
    _server = shown;
    await _applyLevel();
  }

  /// The read being shown (fresh or cached), for its level fields.
  ProgressSnapshot? _server;

  /// Merges this device's completed skills with the server's (ADR 0033)
  /// and remembers the level shown, so it never goes down within a grade.
  Future<void> _applyLevel() async {
    final kid = ref.read(sessionControllerProvider).kid;
    final kidId = ref.read(activeKidIdProvider);
    if (kid == null || kidId == null) return;
    final db = ref.read(localDatabaseProvider);
    final leaves = await (db.select(
      db.skillNodeTable,
    )..where((t) => t.grade.equals(kid.gradeLevel))).get();
    final local = await ref.read(localNodeProgressProvider.future);
    final store = GradeLevelStore(db, kidId: kidId, grade: kid.gradeLevel);
    final (high, lastTotal) = await store.read();
    final server = _server;
    final merged = mergeGradeLevel(
      localCompleted: leaves.where((l) => (local[l.id] ?? 0) >= 1).length,
      localTotal: leaves.length,
      serverCompleted: server?.skillsCompleted,
      serverTotal: server?.skillsTotal,
      serverLevel: server?.level,
      lastServerTotal: lastTotal,
      highWater: high,
    );
    if (!ref.mounted) return;
    if (merged != null) {
      await store.write(high: merged.level, total: server?.skillsTotal);
    }
    if (!ref.mounted) return;
    state = state.withLevel(merged);
  }

  Future<void> refresh() => _load();
}

final progressControllerProvider =
    NotifierProvider<ProgressController, ProgressState>(ProgressController.new);

final progressApiProvider = Provider<ProgressApi>(
  (ref) => ProgressApi(dio: ref.watch(dioProvider)),
);
