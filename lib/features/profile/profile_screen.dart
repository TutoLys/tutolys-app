import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';
import '../home/subject_progress.dart';
import '../home/village_scene.dart';
import '../home/village_screen.dart' show subjectCodeFor;
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import '../quests/quest_board.dart';
import '../quests/quests_screen.dart' show achievementAsset, achievementName;

/// Profil, as the design draws it: an avatar hero, three stat tiles, and
/// per-subject progress.
///
/// The streak-freeze balance used to live here, ahead of the design. It now
/// sits in Quêtes' streak detail as the design's "Bouclier de série", which
/// is where the design puts streak detail (app ADR 0015).
///
/// The badge grid is the design's eight, earned on real data and recorded
/// once ([questBoardProvider], app ADR 0015) — the same achievements Quêtes
/// lists under "Réussites récentes". "Gardien de la flamme" shows under the
/// name once a 7-day streak has earned it.
///
/// The recent-activity feed still says what it is waiting for: nothing
/// records an activity history yet.
///
/// Everything else here is real: the name, grade, XP ledger total, streak,
/// mastered count, and the per-subject bars — the same local join the
/// Village uses.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;
    final progress = ref.watch(progressControllerProvider);
    final bySubject =
        ref.watch(subjectProgressProvider).value ?? const <String, double>{};
    final board = ref.watch(questBoardProvider).value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(
                name: kid?.displayName ?? '',
                grade: kid?.gradeLevel,
                title: (board?.has(Achievement.streak7) ?? false)
                    ? t.flameKeeperTitle
                    : null,
                palette: p,
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      asset: 'asset-xpstar.webp',
                      value: '${progress.totalXp}',
                      label: t.profileTotalXp,
                      palette: p,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _Tile(
                      asset: 'asset-flame.webp',
                      value: progress.currentStreakDays == null
                          ? '–'
                          : '${progress.isStreakEstimated ? '~' : ''}'
                              '${progress.currentStreakDays}',
                      label: t.profileStreakDays(progress.currentStreakDays ?? 0),
                      palette: p,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _Tile(
                      asset: 'asset-badge.webp',
                      value: '${progress.masteredCount}',
                      label: t.profileSkillsMastered(progress.masteredCount),
                      palette: p,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              _Card(
                title: t.profileBySubject,
                icon: Icons.insights_outlined,
                palette: p,
                child: bySubject.isEmpty
                    ? Text(
                        t.profileNoSubjects,
                        style: TextStyle(fontSize: 13, color: p.inkMuted),
                      )
                    : Column(
                        children: [
                          for (final b in villageBuildings(t))
                            if (bySubject[subjectCodeFor(b.asset)] != null)
                              _SubjectRow(
                                label: b.label,
                                value: bySubject[subjectCodeFor(b.asset)]!,
                                accent: b.accent,
                                palette: p,
                              ),
                        ],
                      ),
              ),
              const SizedBox(height: Space.md),
              _Card(
                title: t.profileBadges,
                icon: Icons.workspace_premium_outlined,
                palette: p,
                child: _BadgeGrid(
                  earned: {
                    for (final a in Achievement.values)
                      if (board?.has(a) ?? false) a,
                  },
                  palette: p,
                ),
              ),
              const SizedBox(height: Space.md),
              _Card(
                title: t.profileRecent,
                icon: Icons.history,
                palette: p,
                child: Text(
                  t.profileRecentSoon,
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.inkMuted),
                ),
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.grade,
    required this.palette,
    this.title,
  });

  final String name;
  final int? grade;

  /// An earned title ("Gardien de la flamme"), or null.
  final String? title;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BreathingMascot(height: 116),
        const SizedBox(height: Space.xs),
        Text(
          name,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: palette.ink,
          ),
        ),
        if (grade != null)
          Text(
            context.s.gradeLabel(grade!),
            style: TextStyle(fontSize: 13, color: palette.inkMuted),
          ),
        if (title != null) ...[
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('profile-title'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: palette.goldPale,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              title!,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
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
    return Material(
      color: palette.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: palette.shadowSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
        child: Column(
          children: [
            Image.asset('assets/images/$asset', width: 26, height: 26),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    required this.palette,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: palette.shadowSmall,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: palette.quebecBlue),
                const SizedBox(width: Space.xs),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.palette,
  });

  final String label;
  final double value;
  final Color accent;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: palette.ink,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: palette.track,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()} %',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: palette.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's `.badges-grid`: four columns of 54px circles, the earned
/// ones with their art, the rest dimmed behind a lock.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned, required this.palette});

  final Set<Achievement> earned;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = palette;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.78,
      children: [
        for (final a in Achievement.values)
          Column(
            key: ValueKey('badge-${a.name}-${earned.contains(a) ? 'earned' : 'locked'}'),
            children: [
              Opacity(
                opacity: earned.contains(a) ? 1 : 0.42,
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: p.shadowSmall, blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: earned.contains(a)
                      ? Image.asset('assets/images/${achievementAsset(a)}', width: 28, height: 28)
                      : Icon(Icons.lock, size: 22, color: p.inkMuted),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                achievementName(t, a),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: p.inkMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
