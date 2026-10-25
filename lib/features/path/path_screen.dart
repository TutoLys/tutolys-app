import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
///
/// The pills and the current strand's title are pinned above the path,
/// like a frozen header row: only the path scrolls, so switching subject
/// never means scrolling back up (Hafid).
class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({super.key});

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  final _focusKey = GlobalKey(debugLabel: 'carte-focus');
  bool _visible = false;

  /// One key per section, to find which one is under the pinned header.
  final _sectionKeys = <GlobalKey>[];

  /// The section whose title the pinned header shows.
  int _topSection = 0;
  bool _topUpdateQueued = false;

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
  /// The path's own scroll view starts below the pinned header, so its
  /// middle is the middle of what the kid can see.
  void _scrollToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Visibility.of(context)) return;
      final target = _focusKey.currentContext;
      if (target == null) {
        _queueTopUpdate();
        return;
      }
      final still = MediaQuery.disableAnimationsOf(context);
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: still ? Duration.zero : Motion.normal,
        curve: Motion.enter,
      ).then((_) => _queueTopUpdate());
    });
  }

  /// Recomputes [_topSection] after the frame, never mid-layout.
  void _queueTopUpdate() {
    if (_topUpdateQueued) return;
    _topUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _topUpdateQueued = false;
      if (!mounted) return;
      final top = _sectionAtTop();
      if (top != _topSection) setState(() => _topSection = top);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The last section whose top has scrolled up to the pinned header.
  int _sectionAtTop() {
    var top = 0;
    for (var i = 1; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      final box = ctx?.findRenderObject();
      if (ctx == null || box is! RenderBox || !box.attached) break;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) break;
      final reveal = viewport.getOffsetToReveal(box, 0).offset;
      if (reveal > Scrollable.of(ctx).position.pixels + 1) break;
      top = i;
    }
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pathControllerProvider);
    final t = context.s;
    ref.listen(pathControllerProvider, (prev, next) {
      final loaded = prev?.loading == true && !next.loading;
      if (prev?.subject != next.subject) _topSection = 0;
      if (loaded || prev?.subject != next.subject) _scrollToFocus();
    });
    // A finished lesson moves the frontier.
    ref.listen(nodeProgressProvider, (_, next) {
      if (next.hasValue) _scrollToFocus();
    });

    final showPath = !state.loading && state.leaves.isNotEmpty;
    final lessons = nodeLessonsOf(
      state,
      ref.watch(nodeProgressProvider).value ?? const {},
    );
    final sections = showPath
        ? _sectionsOf(context, state, lessons)
        : const <PathSection>[];
    while (_sectionKeys.length < sections.length) {
      _sectionKeys.add(GlobalKey(debugLabel: 'carte-section'));
    }
    final top = sections.isEmpty
        ? null
        : sections[_topSection.clamp(0, sections.length - 1)];

    // No Scaffold or AppBar: the shell owns the chrome, and a second app
    // bar under the header was the duplication the Village had.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.compact;
          final pad = compact ? Space.md : Space.lg;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pinned: the path scrolls under nothing, it is clipped below.
              Padding(
                key: const ValueKey('carte-header'),
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SubjectPills(
                      selected: state.subject,
                      compact: compact,
                      onSelect: (code) => ref
                          .read(pathControllerProvider.notifier)
                          .selectSubject(code),
                    ),
                    if (top != null) ...[
                      _Breadcrumb(
                        subject: state.subject,
                        title: top.title ?? t.pathTitle,
                        titleKey: const ValueKey('carte-strand-title'),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => Future.wait([
                    ref.read(pathControllerProvider.notifier).refresh(),
                    ref.read(progressControllerProvider.notifier).refresh(),
                  ]),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.depth == 0 &&
                          (n is ScrollUpdateNotification ||
                              n is ScrollEndNotification)) {
                        _queueTopUpdate();
                      }
                      return false;
                    },
                    child: ListView(
                      key: const ValueKey('carte-path'),
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                      children: [
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
                          // Skills with no lessons yet still show, locked:
                          // the kid sees what's coming.
                          if (showPath)
                            _Sections(
                              state: state,
                              sections: sections,
                              lessons: lessons,
                              sectionKeys: _sectionKeys,
                              compact: compact,
                              focusKey: _focusKey,
                              onReturned: _scrollToFocus,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<PathSection> _sectionsOf(
    BuildContext context,
    PathState state,
    Map<String, NodeLessons> lessons,
  ) {
    final t = context.s;
    return buildCarteSections(
      subject: state.subject,
      leaves: state.leaves,
      playable: state.lessonsByNodeId.keys.toSet(),
      masteries: ref.watch(progressControllerProvider).masteries,
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
  }
}

/// `.carte-breadcrumb`: the subject as eyebrow, the area as title.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.subject,
    required this.title,
    this.titleKey,
  });

  final String subject;
  final String title;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subjectLabel(context.s, subject).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          key: titleKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 21,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

class _Sections extends ConsumerWidget {
  const _Sections({
    required this.state,
    required this.sections,
    required this.lessons,
    required this.sectionKeys,
    required this.compact,
    required this.focusKey,
    required this.onReturned,
  });

  final PathState state;
  final List<PathSection> sections;

  /// Finished on this device: refreshed by the play screen after every
  /// completed exercise, so the map changes the moment the kid is back.
  final Map<String, NodeLessons> lessons;
  final List<GlobalKey> sectionKeys;
  final bool compact;
  final GlobalKey focusKey;

  /// Called once the kid is back from a game.
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final focusNodeId = focusNodeIdOf(sections);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed)
          Column(
            key: sectionKeys[i],
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The first title is the pinned header's; later ones mark
              // where the next area starts, and take over the header once
              // they reach it.
              if (i > 0) ...[
                _Breadcrumb(
                  subject: state.subject,
                  title: section.title ?? t.pathTitle,
                ),
                const SizedBox(height: 18),
              ],
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
                      return pct > 0
                          ? t.pathInProgress(pct)
                          : t.pathNotStarted;
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
          ),
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
