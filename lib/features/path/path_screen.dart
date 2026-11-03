import 'dart:async';

import '../../data/local_db/database.dart' show CachedSkillNode;
import 'review.dart';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../data/sync/window_plan.dart';
import '../pairing/pairing_controller.dart';
import '../assignments/assignments_controller.dart';
import '../progress/progress_controller.dart';
import 'carte_model.dart';
import 'carte_section.dart';
import 'node_lessons.dart';
import 'path_controller.dart';
import 'play_node.dart';
import 'section_fold.dart';
import 'kid_label.dart';
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
/// Each section rolls up behind its header (ADR 0124). The one holding the
/// next lesson starts open and the rest closed, until the kid says otherwise.
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

  /// The frontier last scrolled to. Lessons often arrive after the tree,
  /// moving the frontier with no load or subject change; it is followed
  /// then too (K10).
  String? _focusId;
  bool _topUpdateQueued = false;

  /// The section holding the next lesson, and whether a finished lesson
  /// may be about to move it: only that reopens a section the kid closed.
  String? _nextSection;
  bool _lessonFinished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell's IndexedStack keeps the Carte built while hidden, so
    // "opening" it is this turning true.
    final visible = Visibility.of(context);
    if (visible && !_visible) {
      _scrollToFocus();
      // Lessons published while the kid was elsewhere show up on return.
      ref.read(pathControllerProvider.notifier).refreshIfStale();
    }
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

  /// A section finished rolling. Opened, it comes into view: to the next
  /// lesson if that's in it, otherwise just far enough that a kid who
  /// tapped a header low on the screen sees what unrolled.
  void _sectionSettled(int index, {required bool open, required bool next}) {
    _queueTopUpdate();
    if (!open) return;
    if (next) {
      _scrollToFocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _sectionKeys.length) return;
      final target = _sectionKeys[index].currentContext;
      final box = target?.findRenderObject();
      if (target == null || box is! RenderBox) return;
      final height = MediaQuery.sizeOf(context).height;
      if (box.localToGlobal(Offset.zero).dy < height / 2) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.normal,
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
      if (prev?.subject != next.subject) {
        _topSection = 0;
        _lessonFinished = false;
      }
      if (loaded || prev?.subject != next.subject) _scrollToFocus();
    });
    // A finished lesson moves the frontier.
    ref.listen(nodeProgressProvider, (prev, next) {
      if (next.hasValue) _scrollToFocus();
      if (prev?.hasValue == true && next.hasValue) _lessonFinished = true;
    });

    final showPath = !state.loading && state.leaves.isNotEmpty;
    final lessons = nodeLessonsOf(
      state,
      ref.watch(nodeProgressProvider).value ?? const {},
    );
    final sections = showPath
        ? _sectionsOf(context, state, lessons)
        : const <PathSection>[];
    final review = showPath
        ? reviewLeaves(
            masteries: ref.watch(progressControllerProvider).masteries,
            leaves: state.leaves,
            playable: lessons.keys.toSet(),
          )
        : const <CachedSkillNode>[];
    final activeNode = sections
        .expand((section) => section.nodes)
        .where((node) => node.state == PathNodeState.active)
        .firstOrNull;
    final focusId = focusNodeIdOf(sections);
    if (focusId != null && focusId != _focusId) _scrollToFocus();
    _focusId = focusId;
    final nextSection = nextSectionKey(sections);
    if (nextSection != _nextSection) {
      if (_lessonFinished && nextSection != null) {
        _lessonFinished = false;
        Future.microtask(
          () => ref.read(sectionFoldsProvider.notifier).forget(nextSection),
        );
      }
      if (nextSection != null) _nextSection = nextSection;
    }
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
                          _SlowLoader(
                            onRetry: () => ref
                                .read(pathControllerProvider.notifier)
                                .refresh(),
                          )
                        else ...[
                          // Cached lessons after a failed sync: a lesson
                          // published since reads "soon", so say why.
                          if (state.syncFailed && state.leaves.isNotEmpty)
                            _StaleNote(
                              text: t.pathStale(state.syncedAt),
                              retryLabel: t.retry,
                              onRetry: () => ref
                                  .read(pathControllerProvider.notifier)
                                  .refresh(),
                            ),
                          // Drawn, lessons still arriving (A1).
                          if (state.syncing && state.carteLessons.isEmpty)
                            const Padding(
                              key: ValueKey('carte-syncing'),
                              padding: EdgeInsets.all(Space.lg),
                              child: Center(child: VillageLoader()),
                            ),
                          if (carteGapOf(state) case final gap?)
                            _Empty(
                              key: ValueKey('carte-gap-${gap.name}'),
                              onRetry: gap == CarteGap.offline
                                  ? () => ref
                                        .read(pathControllerProvider.notifier)
                                        .refresh()
                                  : null,
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
                          // Evidence-only review, in its own row (OW3).
                          if (showPath && review.isNotEmpty)
                            _ReviewRow(
                              leaves: review,
                              onTap: (leaf) async {
                                final l = lessons[leaf.id];
                                if (l == null) return;
                                await playNode(
                                  context,
                                  ref,
                                  leaf: leaf,
                                  lessons: l,
                                );
                                _scrollToFocus();
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
                              onSettled: _sectionSettled,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // A phone pins « Continuer » here, above the tab bar, rather
              // than under the orb where it covered the next node (AM9).
              if (compact && activeNode != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, Space.xs, pad, Space.sm),
                  child: ContinueCard(
                    key: const ValueKey('carte-continue-bar'),
                    languageTag: activeNode.otherLanguage,
                    status: continueStatus(t, activeNode),
                    title: activeNode.label,
                    cta: t.villageContinueCta,
                    compact: true,
                    onTap: () => _playActive(activeNode, lessons),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _playActive(
    PathNode node,
    Map<String, NodeLessons> lessons,
  ) async {
    final state = ref.read(pathControllerProvider);
    final l = lessons[node.id];
    if (!isOpenState(node.state) || l == null) return;
    await playNode(
      context,
      ref,
      leaf: state.leaves.firstWhere((leaf) => leaf.id == node.id),
      lessons: l,
    );
    _scrollToFocus();
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
      playable: state.carteLessons.keys.toSet(),
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
      assigned: ref.watch(assignedSkillIdsProvider),
      notDownloaded: {
        for (final MapEntry(:key, :value) in lessons.entries)
          if (isNotDownloaded(value.next)) key,
      },
      offline: state.offline,
      describeLanguage: t.lessonLanguage,
      describeLessons: t.pathLessonsDone,
      describeState: (node) => switch (node) {
        PathNodeState.locked => t.pathLocked,
        PathNodeState.soon => t.pathSoon,
        _ => null,
      },
      describeNotDownloaded: t.pathNotDownloaded,
    );
  }
}

/// « Révision » (OW3, ADR 0111): up to three skills the kid's own data says
/// to go back to, above the path. Gold and calm, never amber: a review is
/// an invitation, not a mark against them.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.leaves, required this.onTap});

  final List<CachedSkillNode> leaves;
  final Future<void> Function(CachedSkillNode leaf) onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final locale = Localizations.localeOf(context);
    return Padding(
      key: const ValueKey('carte-review'),
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.gold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.replay_rounded, color: p.gold, size: 26),
                  const SizedBox(width: Space.xs),
                  Text(
                    t.reviewTitle,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                t.reviewSubtitle,
                style: TextStyle(fontSize: 14, color: p.inkMuted),
              ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final leaf in leaves)
                    Material(
                      color: p.navActiveFill,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        key: ValueKey('carte-review-${leaf.id}'),
                        customBorder: const StadiumBorder(),
                        onTap: () => onTap(leaf),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.md,
                              vertical: Space.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: p.quebecBlue,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    // Language subjects keep their own
                                    // language (ADR 0023), as on the path.
                                    kidLabelFor(leaf, locale),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: VillageType.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: p.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    required this.onSettled,
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

  /// A section stopped rolling: which one, and how it ended.
  final void Function(int index, {required bool open, required bool next})
  onSettled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final focusNodeId = focusNodeIdOf(sections);
    final folds = ref.watch(sectionFoldsProvider).value ?? const {};
    final nextKey = nextSectionKey(sections);

    SkillPath path(
      PathSection section, [
      ValueListenable<double>? revealedTo,
    ]) => SkillPath(
      nodes: section.nodes,
      compact: compact,
      inlineCard: !compact,
      continueLabel: t.villageContinueCta,
      statusLabel: (node) => continueStatus(t, node),
      focusNodeId: focusNodeId,
      focusKey: focusKey,
      revealedTo: revealedTo,
      onTapNode: (node) => _play(context, ref, node, lessons[node.id]),
    );

    if (sections.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, section) in sections.indexed)
            KeyedSubtree(
              key: sectionKeys[i],
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _foldable(ref, t, i, section, folds, nextKey, path),
              ),
            ),
          const SizedBox(height: Space.lg),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed)
          Column(
            key: sectionKeys[i],
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  child: path(section),
                ),
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
      ],
    );
  }

  Widget _foldable(
    WidgetRef ref,
    Strings t,
    int index,
    PathSection section,
    Map<String, bool> folds,
    String? nextKey,
    SkillPath Function(PathSection, [ValueListenable<double>?]) path,
  ) {
    final open = isSectionOpen(section, folds: folds, nextKey: nextKey);
    final holdsNext = section.key == nextKey;
    return CarteSection(
      key: ValueKey(section.key),
      section: section,
      title: section.title ?? t.pathTitle,
      open: open,
      holdsNext: holdsNext,
      compact: compact,
      pathHeight: SkillPath.heightOf(
        section.nodes,
        compact: compact,
        inlineCard: !compact,
      ),
      onToggle: () => ref
          .read(sectionFoldsProvider.notifier)
          .set(section.key, open: !open),
      onSettled: (open) => onSettled(index, open: open, next: holdsNext),
      path: (revealedTo) => path(section, revealedTo),
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
    await playNode(
      context,
      ref,
      leaf: state.leaves.firstWhere((l) => l.id == node.id),
      lessons: lessons,
    );
    onReturned();
  }
}

/// The Carte's loader. Past [patience] it says so, with the fox and a big
/// "Réessayer" (A1): a wait with no word reads as broken to a child.
class _SlowLoader extends StatefulWidget {
  const _SlowLoader({required this.onRetry});

  final VoidCallback onRetry;

  static const patience = Duration(seconds: 8);

  @override
  State<_SlowLoader> createState() => _SlowLoaderState();
}

class _SlowLoaderState extends State<_SlowLoader> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_SlowLoader.patience, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_slow) {
      return const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: VillageLoader()),
      );
    }
    final p = VillagePalette.of(context);
    final t = context.s;
    return Padding(
      key: const ValueKey('carte-slow'),
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
            t.pathSlow,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton.icon(
            key: const ValueKey('carte-slow-retry'),
            onPressed: () {
              setState(() => _slow = false);
              _timer?.cancel();
              _timer = Timer(_SlowLoader.patience, () {
                if (mounted) setState(() => _slow = true);
              });
              widget.onRetry();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retry),
            style: FilledButton.styleFrom(
              backgroundColor: p.gold,
              // The gold pills' own dark ink, in both themes.
              foregroundColor: const Color(0xFF241A04),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xl,
                vertical: Space.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.onRetry, super.key});

  final String text;

  /// Offline (A10): a child can't fix Wi-Fi, but can tap this once an
  /// adult has.
  final VoidCallback? onRetry;

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
          if (onRetry != null) ...[
            const SizedBox(height: Space.sm),
            FilledButton.icon(
              key: const ValueKey('carte-gap-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.s.retry),
              style: FilledButton.styleFrom(
                backgroundColor: p.gold,
                foregroundColor: const Color(0xFF241A04),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaleNote extends StatelessWidget {
  const _StaleNote({
    required this.text,
    required this.retryLabel,
    required this.onRetry,
  });

  final String text;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Padding(
      key: const ValueKey('carte-stale'),
      padding: const EdgeInsets.only(bottom: Space.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 20, color: p.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, color: p.inkMuted),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The « Continuer » card's eyebrow: "En cours · 60 %" or "Pas commencé".
String continueStatus(Strings t, PathNode node) {
  final pct = ((node.masteryPct ?? 0) * 100).round();
  return pct > 0 ? t.pathInProgress(pct) : t.pathNotStarted;
}
