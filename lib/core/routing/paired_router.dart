import 'package:go_router/go_router.dart';

import '../../data/local_db/database.dart';
import '../../features/play/play_screen.dart';
import 'home_shell.dart';

/// What `/play` needs: the tapped node (for its title) and the exercise
/// envelope already resolved for it — the path screen looks this up
/// (it already has exercise-cache access to decide locked/available) rather
/// than `PlayScreen` re-querying for itself.
class PlayRequest {
  const PlayRequest({required this.node, required this.envelope});

  final CachedSkillNode node;
  final Map<String, Object?> envelope;
}

/// The two routes inside the paired shell (A7, A7.2): the learner's three
/// tabs (home/path/profile, switched locally inside `HomeShell` — none of
/// them need their own URL), and one exercise.
///
/// Deliberately not the app's top-level router — `AppShell`'s own
/// checking/unpaired/paired switch stays a plain Dart switch (its own doc
/// comment explains why: "no URL that can land an unpaired device on a play
/// screen"). This `GoRouter` only exists for navigation *within* the paired
/// branch, nested via `Router.withConfig` rather than a second
/// `MaterialApp.router` — so it inherits the outer `MaterialApp`'s theme and
/// localizations instead of needing its own copy.
GoRouter buildPairedRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/play',
        // `extra` carries the request directly — this router is never
        // deep-linked into from outside the app, so there is no need to
        // encode it into the URL and parse it back out.
        builder: (context, state) {
          final request = state.extra! as PlayRequest;
          return PlayScreen(node: request.node, envelope: request.envelope);
        },
      ),
    ],
  );
}
