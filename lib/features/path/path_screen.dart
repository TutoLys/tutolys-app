import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../core/routing/paired_router.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import 'carte_model.dart';
import 'node_lessons.dart';
import 'path_controller.dart';
import 'skill_path.dart';
import 'subject_pills.dart';

/// Carte — the design's skill path, one subject at a time.
///
/// Subject pills across the top, then the subject's leaves in titled
/// stretches, one per learning area. Node states are real: mastery comes
/// from `/me/progress` (the same per-skill list the Village joins), and a
/// node is locked only when nothing is synced to play on it.
///
/// It always opens on where the kid is: on showing the tab, switching
/// subject, or coming back from a game, it scrolls the frontier node (the
/// fox and the Continuer card) to the middle of the screen.
class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({super.key});

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  final _focusKey = GlobalKey(debugLabel: 'carte-focus');
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell's IndexedStack keeps the Carte built while hidden, so
    // "opening" it is this turning true.
    final visible = Visibility.of(context);
    if (visible && !_visible) _scrollToFocus();
    _visible = visible;
  }

  /// Centres the frontier node after the next frame, with a short eased
  /// scroll, or a jump when motion is reduced. Does nothing while hidden.
  void _scrollToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Visibility.of(context)) return;
      final target = _focusKey.currentContext;
      if (target == null) return;
      final still = MediaQuery.disableAnimationsOf(context);
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: still ? Duration.zero : Motion.normal,
        curve: Motion.enter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pathControllerProvider);
    final t = context.s;
    ref.listen(pathControllerProvider, (prev, next) {
      final loaded = prev?.loading == true && !next.loading;
      if (loaded || prev?.subject != next.subject) _scrollToFocus();
    });
    // A finished lesson moves the frontier.
    ref.listen(nodeProgressProvider, (_, next) {
      if (next.hasValue) _scrollToFocus();
    });

    // No Scaffold or AppBar: the shell owns the chrome, and a second app
    // bar under the header was the duplication the Village had.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.compact;
          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.read(pathControllerProvider.notifier).refresh(),
              ref.read(progressControllerProvider.notifier).refresh(),
            ]),
            child: ListView(
              padding: EdgeInsets.all(compact ? Space.md : Space.lg),
              children: [
                SubjectPills(
                  selected: state.subject,
                  compact: compact,
                  onSelect: (code) => ref
                      .read(pathControllerProvider.notifier)
                      .selectSubject(code),
                ),
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.all(Space.xl),
                    child: Center(child: VillageLoader()),
                  )
                else ...[
                  if (carteGapOf(state) case final gap?)
                    _Empty(
                      key: ValueKey('carte-gap-${gap.name}'),
                      text: switch (gap) {
                        CarteGap.offline => t.pathEmptyOffline,
                        CarteGap.noSkillsAtGrade => t.pathEmptyAtGrade(
                          ref
                                  .watch(sessionControllerProvider)
                                  .kid
                                  ?.gradeLevel ??
                              1,
                        ),
                        CarteGap.noLessonsYet => t.pathNoLessonsYet,
                      },
                    ),
                  // Skills with no lessons yet still show, locked: the kid
                  // sees what's coming.
                  if (state.leaves.isNotEmpty)
                    _Sections(
                      state: state,
                      compact: compact,
                      focusKey: _focusKey,
                      onReturned: _scrollToFocus,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Sections extends ConsumerWidget {
  const _Sections({
    required this.state,
    required this.compact,
    required this.focusKey,
    required this.onReturned,
  });

  final PathState state;
  final bool compact;
  final GlobalKey focusKey;

  /// Called once the kid is back from a game.
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final masteries = ref.watch(progressControllerProvider).masteries;
    // Finished on this device: refreshed by the play screen after every
    // completed exercise, so the map changes the moment the kid is back.
    final lessons = nodeLessonsOf(
      state,
      ref.watch(nodeProgressProvider).value ?? const {},
    );

    final sections = buildCarteSections(
      subject: state.subject,
      leaves: state.leaves,
      playable: state.lessonsByNodeId.keys.toSet(),
      masteries: masteries,
      appLocale: Localizations.localeOf(context),
      completed: {
        for (final MapEntry(:key, :value) in lessons.entries)
          if (value.complete) key,
      },
      // The tag describes the lesson a tap would play.
      lessonLocales: {
        for (final MapEntry(:key, :value) in lessons.entries)
          key: (value.next['locale'] as String?) ?? 'fr-CA',
      },
      lessonCounts: {
        for (final MapEntry(:key, :value) in lessons.entries)
          key: (value.doneCount, value.total),
      },
      describeLanguage: t.lessonLanguage,
      describeLessons: t.pathLessonsDone,
      describeState: (state) => switch (state) {
        PathNodeState.locked => t.pathLocked,
        PathNodeState.soon => t.pathSoon,
        _ => null,
      },
    );

    final focusNodeId = focusNodeIdOf(sections);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          // `.carte-breadcrumb`: the subject as eyebrow, the area as title.
          Text(
            subjectLabel(t, state.subject).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.66,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            section.title ?? t.pathTitle,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 21,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 18),
          // `.path-card`
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: p.isDark ? 0.25 : 0.4),
              border: Border.all(
                color: p.surface.withValues(alpha: p.isDark ? 0.35 : 0.6),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(6, 6, 6, 22)
                  : const EdgeInsets.fromLTRB(10, 10, 10, 30),
              child: SkillPath(
                nodes: section.nodes,
                compact: compact,
                continueLabel: t.villageContinueCta,
                statusLabel: (node) {
                  final pct = ((node.masteryPct ?? 0) * 100).round();
                  return pct > 0 ? t.pathInProgress(pct) : t.pathNotStarted;
                },
                focusNodeId: focusNodeId,
                focusKey: focusKey,
                onTapNode: (node) =>
                    _play(context, ref, node, lessons[node.id]),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    PathNode node,
    NodeLessons? lessons,
  ) async {
    // The orb and card already have no handler past the frontier; this is
    // the last word, so no path into a game can skip the sequence.
    if (!isOpenState(node.state) || lessons == null) return;
    final envelope = lessons.next;
    final leaf = state.leaves.firstWhere(
      (l) => l.id == envelope['skill_node_id'],
    );
    await GoRouter.of(context).push(
      '/play',
      extra: PlayRequest(node: leaf, envelope: envelope),
    );
    // The header's XP and streak, and this map's mastery, all moved. The
    // shell keeps tabs alive, so nothing re-reads on its own.
    ref.read(progressControllerProvider.notifier).refresh();
    onReturned();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: Column(
        children: [
          Image.asset(
            'assets/images/asset-mascot-welcome.webp',
            height: 110,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: Space.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}
