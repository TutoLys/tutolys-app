import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../progress/progress_controller.dart';
import 'carte_model.dart';
import 'path_controller.dart';
import 'skill_path.dart';

/// Carte — the design's skill path, one subject at a time.
///
/// Subject pills across the top, then the subject's leaves in titled
/// stretches, one per learning area. Node states are real: mastery comes
/// from `/me/progress` (the same per-skill list the Village joins), and a
/// node is locked only when nothing is synced to play on it.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pathControllerProvider);
    final t = context.s;

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
                _SubjectPills(
                  selected: state.subject,
                  compact: compact,
                  onSelect: (code) => ref
                      .read(pathControllerProvider.notifier)
                      .selectSubject(code),
                ),
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.all(Space.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.leaves.isEmpty)
                  _Empty(text: t.pathEmpty)
                else
                  _Sections(state: state, compact: compact),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The subject buildings, shared with the Village, keyed by backend code.
const _subjectArt = {
  'MATH': 'asset-bldg-math.webp',
  'FR': 'asset-bldg-francais.webp',
  'EN': 'asset-bldg-anglais.webp',
  'SCI': 'asset-bldg-science.webp',
  'SOC': 'asset-bldg-univers-social.webp',
};

String _subjectLabel(Strings t, String code) => switch (code) {
  'MATH' => t.subjectMath,
  'FR' => t.subjectFrancais,
  'EN' => t.subjectAnglais,
  'SCI' => t.subjectScience,
  'SOC' => t.subjectUniversSocial,
  _ => code,
};

/// `.subject-tabs`: a scrolling row of pills, the building as each icon.
class _SubjectPills extends StatelessWidget {
  const _SubjectPills({
    required this.selected,
    required this.compact,
    required this.onSelect,
  });

  final String selected;
  final bool compact;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 18),
      child: SizedBox(
        height: compact ? 38 : 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pathSubjects.length,
          separatorBuilder: (_, _) => SizedBox(width: compact ? 8 : 10),
          itemBuilder: (context, i) {
            final code = pathSubjects[i];
            final active = code == selected;
            return Material(
              // `.subject-tab.is-active { background: #E8F0FF; border: none }`
              color: active ? p.navActiveFill : p.surface,
              shape: StadiumBorder(
                side: active
                    ? BorderSide.none
                    : BorderSide(color: p.line),
              ),
              child: InkWell(
                key: ValueKey('subject-pill-$code'),
                customBorder: const StadiumBorder(),
                onTap: active ? null : () => onSelect(code),
                mouseCursor: active
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(6, 6, 13, 6)
                      : const EdgeInsets.fromLTRB(8, 7, 16, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/${_subjectArt[code]}',
                        width: compact ? 24 : 30,
                        height: compact ? 24 : 30,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _subjectLabel(t, code),
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 13,
                          color: active ? p.quebecBlueBright : p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Sections extends ConsumerWidget {
  const _Sections({required this.state, required this.compact});

  final PathState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final masteries = ref.watch(progressControllerProvider).masteries;

    final sections = buildCarteSections(
      subject: state.subject,
      leaves: state.leaves,
      playable: state.exerciseByNodeId.keys.toSet(),
      masteries: masteries,
      english: Localizations.localeOf(context).languageCode == 'en',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          // `.carte-breadcrumb`: the subject as eyebrow, the area as title.
          Text(
            _subjectLabel(t, state.subject).toUpperCase(),
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
                onTapNode: (node) => _play(context, ref, node),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
      ],
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref, PathNode node) async {
    final envelope = state.exerciseByNodeId[node.id];
    if (envelope == null) return;
    final leaf = state.leaves.firstWhere((l) => l.id == node.id);
    await GoRouter.of(context).push(
      '/play',
      extra: PlayRequest(node: leaf, envelope: envelope),
    );
    // The header's XP and streak, and this map's mastery, all moved. The
    // shell keeps tabs alive, so nothing re-reads on its own.
    ref.read(progressControllerProvider.notifier).refresh();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

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
