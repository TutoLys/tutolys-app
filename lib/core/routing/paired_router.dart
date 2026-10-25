import 'package:flutter/widgets.dart' show ValueKey;
import 'package:go_router/go_router.dart';

import '../../data/local_db/database.dart';
import '../../features/play/play_screen.dart';
import 'village_shell.dart';

/// What `/play` needs: the tapped node (for its title) and the exercise
/// envelope already resolved for it — the path screen looks this up
/// (it already has exercise-cache access to decide locked/available) rather
/// than `PlayScreen` re-querying for itself.
class PlayRequest {
  const PlayRequest({required this.node, required this.envelope});

  final CachedSkillNode node;
  final Map<String, Object?> envelope;
}

/// The routes inside the paired shell: one URL per page of the learner's
/// shell (`/village`, `/carte`, …), and one exercise.
///
/// Deliberately not the app's top-level router — `AppShell`'s own
/// checking/unpaired/paired switch stays a plain Dart switch (its own doc
/// comment explains why: "no URL that can land an unpaired device on a play
/// screen"). This `GoRouter` only exists for navigation *within* the paired
/// branch, nested via `Router.withConfig` rather than a second
/// `MaterialApp.router` — so it inherits the outer `MaterialApp`'s theme and
/// localizations instead of needing its own copy.
/// The in-app location the browser was showing when the app launched.
///
/// Captured in `main` before `runApp`, because by the time this router is
/// built (after the splash and session restore) the outer `MaterialApp`'s
/// own navigator has already reset the browser URL to `/`. Reading it then
/// sent every refresh back to the Village.
String? _launchLocation;

/// Records where the app was launched, from the browser URL's `#/…`
/// fragment (the web's hash URL strategy). A no-op on desktop, where
/// [url] is a file path with no fragment.
void rememberLaunchLocation(Uri url) {
  final fragment = url.fragment;
  if (fragment.startsWith('/') && fragment != '/') _launchLocation = fragment;
}

/// [initialLocation] defaults to the launch location, used once: a kid who
/// forgets the device and re-pairs starts back at the Village, not on the
/// page they had open before.
GoRouter buildPairedRouter({String? initialLocation}) {
  final start = initialLocation ?? _launchLocation;
  _launchLocation = null;
  return GoRouter(
    initialLocation: start ?? '/${VillageShell.defaultPage}',
    routes: [
      GoRoute(
        path: '/play',
        // A refresh during a game reloads the URL but loses `extra`, which
        // lived only in memory. Back to the Carte, where the kid picks the
        // node again, rather than a crash on a missing request.
        redirect: (context, state) =>
            state.extra is PlayRequest ? null : '/carte',
        // `extra` carries the request directly — this router is never
        // deep-linked into from outside the app, so there is no need to
        // encode it into the URL and parse it back out.
        builder: (context, state) {
          final request = state.extra! as PlayRequest;
          return PlayScreen(node: request.node, envelope: request.envelope);
        },
      ),
      GoRoute(
        path: '/:page',
        // Unknown pages, and `/home` from before pages had URLs, land on
        // the Village rather than an error screen.
        redirect: (context, state) =>
            VillageShell.pages.contains(state.pathParameters['page'])
                ? null
                : '/${VillageShell.defaultPage}',
        // One fixed page key for every page: the navigator then updates
        // the same shell instead of building a new one per URL, so the
        // pages in its IndexedStack stay alive and their loads don't
        // re-fire. No transition — switching pages is not navigating away.
        pageBuilder: (context, state) => NoTransitionPage(
          key: const ValueKey('village-shell'),
          child: VillageShell(page: state.pathParameters['page']!),
        ),
      ),
    ],
    // `/` (a bare origin) has no page segment for the route above.
    redirect: (context, state) => state.uri.path == '/'
        ? '/${VillageShell.defaultPage}'
        : null,
  );
}
