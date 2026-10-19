import 'package:go_router/go_router.dart';

import '../../data/local_db/database.dart';
import '../../features/path/path_screen.dart';
import '../../features/play/play_screen.dart';

/// The two routes inside the paired shell (A7): the path, and one exercise.
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
    initialLocation: '/path',
    routes: [
      GoRoute(path: '/path', builder: (context, state) => const PathScreen()),
      GoRoute(
        path: '/play',
        // `extra` carries the tapped node directly — this router is never
        // deep-linked into from outside the app, so there is no need to
        // encode it into the URL and parse it back out.
        builder: (context, state) =>
            PlayScreen(node: state.extra! as CachedSkillNode),
      ),
    ],
  );
}
