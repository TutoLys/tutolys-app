import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart';
import '../path/subject_pills.dart';
import 'progress_controller.dart';
import 'progress_model.dart';

/// A subject's leaves at the kid's own grade, synced first when online.
///
/// The same `CurriculumSync` the Carte uses, so opening a subject here fills
/// the shared cache rather than keeping a second copy. Offline it returns
/// whatever was cached before.
final progressLeavesProvider = FutureProvider.autoDispose
    .family<List<CachedSkillNode>, String>((ref, subject) async {
      final kid = ref.watch(sessionControllerProvider).kid;
      if (kid == null) return const [];
      final sync = ref.read(curriculumSyncProvider);
      await sync.sync(subject: subject, grade: kid.gradeLevel);
      return sync.cachedLeaves(subject: subject, grade: kid.gradeLevel);
    });

/// Progrès — the design's progress page: three headline stats, the subject
/// pills, and a card with one row per learning area.
///
/// Every figure is real or absent. Mastery is `/me/progress`'s own per-skill
/// list joined to the cached curriculum (no new endpoint); the level is the
/// server's, from its own curve; there are no coins, because no currency
/// exists — the design's "340 pièces" becomes the XP the level is made of.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _subject = defaultPathSubject;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressControllerProvider);
    final t = context.s;
    final p = VillagePalette.of(context);

    final streak = progress.currentStreakDays;
    final level = progress.level;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.compact;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(progressLeavesProvider(_subject));
              await ref.read(progressControllerProvider.notifier).refresh();
            },
            child: ListView(
              padding: EdgeInsets.all(compact ? Space.md : Space.lg),
              children: [
                // `.progress-summary`: tiles that wrap rather than squeeze.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      asset: 'asset-badge.webp',
                      value: '${progress.masteredCount}',
                      label: t.profileSkillsMastered(progress.masteredCount),
                      palette: p,
                    ),
                    _StatCard(
                      asset: 'asset-flame.webp',
                      // Same rule as the header: unknown is a dash, never a
                      // made-up zero; a local estimate keeps its `~`.
                      value: streak == null
                          ? '–'
                          : '${progress.isStreakEstimated ? '~' : ''}$streak',
                      label: t.profileStreakDays(streak ?? 0),
                      palette: p,
                    ),
                    _StatCard(
                      asset: 'asset-xpstar.webp',
                      value: level == null
                          ? '${progress.totalXp}'
                          : t.progressLevel(level),
                      label: level == null
                          ? t.profileTotalXp
                          : '${progress.totalXp} ${t.profileTotalXp}',
                      palette: p,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SubjectPills(
                  selected: _subject,
                  compact: compact,
                  onSelect: (code) => setState(() => _subject = code),
                ),
                _ByArea(subject: _subject, palette: p),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// `.ph-stat-card`: icon, number, label.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.asset,
    required this.value,
    required this.label,
    required this.palette,
  });

  final String asset;
  final String value;
  final String label;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: p.shadowSmall,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/$asset', width: 30, height: 30),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 10.5, color: p.inkMuted),
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

/// `.quest-panel` titled "Mathématique — par compétence", one `.strand-row`
/// per learning area.
class _ByArea extends ConsumerWidget {
  const _ByArea({required this.subject, required this.palette});

  final String subject;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final t = context.s;
    final leaves = ref.watch(progressLeavesProvider(subject));
    final masteries = ref.watch(progressControllerProvider).masteries;
    final english = Localizations.localeOf(context).languageCode == 'en';

    final Widget body = switch (leaves) {
      AsyncData(:final value) when value.isNotEmpty => Column(
        children: [
          for (final (i, row) in buildAreaProgress(
            subject: subject,
            leaves: value,
            masteries: masteries,
            english: english,
          ).indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
            _AreaRow(
              title: row.title ?? t.progressOtherSkills,
              area: row,
              palette: p,
            ),
          ],
        ],
      ),
      AsyncData() || AsyncError() => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Text(
          t.progressNothingYet,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.inkMuted),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/${subjectArt[subject]}',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    t.progressBySkill(subjectLabel(t, subject)),
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.title,
    required this.area,
    required this.palette,
  });

  final String title;
  final AreaProgress area;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final t = context.s;
    final (fill, pillBg, pillFg, pillText) = switch (area.status) {
      AreaStatus.mastered => (
        p.gold,
        p.goldPale,
        // `.status-pill.mastered { color: #8A6A1B }` — gold text dark enough
        // to read on its pale ground; on the dark ground, gold itself.
        p.isDark ? p.gold : const Color(0xFF8A6A1B),
        t.progressStatusMastered,
      ),
      AreaStatus.learning => (
        p.quebecBlueBright,
        p.navActiveFill,
        p.quebecBlueBright,
        t.progressStatusLearning,
      ),
      AreaStatus.notStarted => (
        p.inkMuted,
        p.track,
        p.inkMuted,
        t.progressStatusNew,
      ),
    };
    final pct = (area.fraction * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 6),
                // `.track`: 8px, fully rounded.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: area.fraction,
                    minHeight: 8,
                    backgroundColor: p.track,
                    valueColor: AlwaysStoppedAnimation(fill),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              child: Text(
                pillText.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: pillFg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text(
              t.progressPercent(pct),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
