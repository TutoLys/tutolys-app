import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/home_stats.dart';
import '../pairing/pairing_controller.dart';

/// Today's real stats only — no "this week" rollup, because that would need
/// real per-day history this pass deliberately doesn't build (A7.2's
/// visual-layer-only scope: real counts, never a fabricated number).
class HomeState {
  const HomeState({
    this.exercisesCompletedToday = 0,
    this.msPlayedToday = 0,
    this.loading = true,
  });

  final int exercisesCompletedToday;
  final int msPlayedToday;
  final bool loading;
}

class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    // Same reasoning as PathController.build(): must stay synchronous, so
    // the screen shows a loading state until `_load` finishes.
    Future.microtask(_load);
    return const HomeState();
  }

  Future<void> _load() async {
    final stats = await ref.read(homeStatsProvider).today();
    state = HomeState(
      exercisesCompletedToday: stats.exercisesCompleted,
      msPlayedToday: stats.msPlayed,
      loading: false,
    );
  }

  Future<void> refresh() => _load();
}

final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

final homeStatsProvider = Provider<HomeStats>(
  (ref) => HomeStats(ref.watch(localDatabaseProvider)),
);
