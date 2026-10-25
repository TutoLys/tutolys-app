import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/progress_api.dart';
import '../../data/local_db/streak_local.dart';
import '../pairing/pairing_controller.dart';

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
  });

  final int? currentStreakDays;
  final int masteredCount;
  final int totalSkills;
  final bool loading;
  final bool offline;

  /// True when `currentStreakDays` came from this device's own local play
  /// history (plan §5.8), not a live read — the backend is still the
  /// source of truth and this is only ever shown while it's unreachable.
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

  /// The kid's level, from the server's own curve. Null while offline — a
  /// level computed here would be a second curve that can disagree.
  final int? level;
}

class ProgressController extends Notifier<ProgressState> {
  @override
  ProgressState build() {
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

    state = switch (result) {
      ProgressFetched(:final snapshot) => ProgressState(
        currentStreakDays: snapshot.currentStreakDays,
        masteredCount: snapshot.masteredCount,
        totalSkills: snapshot.masteries.length,
        loading: false,
        freezesAvailable: snapshot.freezesAvailable,
        dailyQuest: snapshot.dailyQuest,
        totalXp: snapshot.totalXp,
        masteries: snapshot.masteries,
        level: snapshot.level,
      ),
      ProgressOffline() => ProgressState(
        loading: false,
        offline: true,
        currentStreakDays: await StreakLocal(
          ref.read(localDatabaseProvider),
          kidId: ref.read(activeKidIdProvider) ?? unpairedKidId,
        )
            .currentStreak(),
        isStreakEstimated: true,
      ),
      // Unauthorized/failed: show nothing rather than a stale/fabricated
      // number — the session controller handles a real 401 (token revoked)
      // separately; this view just has nothing to show this time.
      ProgressUnauthorized() ||
      ProgressFailed() => const ProgressState(loading: false),
    };
  }

  Future<void> refresh() => _load();
}

final progressControllerProvider =
    NotifierProvider<ProgressController, ProgressState>(ProgressController.new);

final progressApiProvider = Provider<ProgressApi>(
  (ref) => ProgressApi(dio: ref.watch(dioProvider)),
);
