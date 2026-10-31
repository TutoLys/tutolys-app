import 'package:design_system/design_system.dart';
import '../../core/time/quebec_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/page_column.dart';
import '../../core/i18n/strings.dart';
import '../../core/routing/page_tab.dart';
import '../../core/widgets/kid_avatar.dart';
import '../../core/widgets/pill_tabs.dart';
import '../home/subject_progress.dart';
import '../path/programme.dart';
import '../home/village_scene.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import '../quests/quest_board.dart';
import '../quests/quests_screen.dart' show achievementAsset, achievementName;
import 'avatar_picker.dart';
import 'avatars.dart';

/// Profil, as the design draws it: an avatar hero card (the kid's avatar,
/// its edit dot, the design's three stats: level, streak, badges earned)
/// and, below it, three pill tabs (app ADR 0051): progress by subject, the
/// badge grid and recent activity, the last tab remembered per kid.
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
/// "Activité récente" lists the latest badges earned, with the day each
/// was earned, from the same record ([QuestBoard.recent]).
///
/// Everything else here is real: the name, grade, level and XP ledger
/// total, streak, badge count, and the per-subject bars — the same local
/// join the Village uses. The mastered-skills count lives on Progrès.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.onSwitchProfile, super.key});

  /// Opens "Qui joue ?". Null hides the button (no shell, as in tests).
  final VoidCallback? onSwitchProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;
    final progress = ref.watch(progressControllerProvider);
    final bySubject =
        ref.watch(subjectProgressProvider).value ?? const <String, double>{};
    final board = ref.watch(questBoardProvider).value;
    final tab = ProfileTab.from(ref.watch(pageTabProvider(TabbedPage.profile)));
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;

    return PageColumn(
      maxWidth: PageWidth.column,
      child: Builder(
        builder: (column) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              name: kid?.displayName ?? '',
              grade: kid?.gradeLevel,
              avatarKey: ref.watch(selectedAvatarKeyProvider),
              onEditAvatar: () => showAvatarPicker(context, alignTo: column),
              onSwitchProfile: onSwitchProfile,
              title: (board?.has(Achievement.streak7) ?? false)
                  ? t.flameKeeperTitle
                  : null,
              stats: [
                _HeroStat(
                  asset: 'asset-xpstar.webp',
                  value: progress.level == null
                      ? '${progress.totalXp}'
                      : t.progressLevel(progress.level!),
                  label: progress.level == null
                      ? t.profileTotalXp
                      : '${progress.totalXp} ${t.profileTotalXp}',
                ),
                _HeroStat(
                  asset: 'asset-flame.webp',
                  value: progress.currentStreakDays == null
                      ? '–'
                      : '${progress.currentStreakDays}',
                  label: t.profileStreakLabel,
                ),
                _HeroStat(
                  asset: 'asset-badge.webp',
                  value:
                      '${Achievement.values.where((a) => board?.has(a) ?? false).length}',
                  label: t.profileBadgesEarned,
                ),
              ],
              palette: p,
            ),
            const SizedBox(height: Space.md),
            PillTabs<ProfileTab>(
              keyPrefix: 'profile-tab',
              selected: tab,
              compact: compact,
              onSelect: (next) => ref
                  .read(pageTabProvider(TabbedPage.profile).notifier)
                  .select(next.name),
              tabs: [
                for (final pt in ProfileTab.values)
                  PillTab(
                    value: pt,
                    label: pt.label(t),
                    leading: Icon(
                      pt.icon,
                      size: compact ? 18 : 20,
                      color: pt == tab ? p.quebecBlueBright : p.inkMuted,
                    ),
                  ),
              ],
            ),
            PillTabPanel(
              tabKey: tab,
              child: _Card(
                palette: p,
                child: switch (tab) {
                  ProfileTab.subjects =>
                    bySubject.isEmpty
                        ? Text(
                            t.profileNoSubjects,
                            style: TextStyle(fontSize: 13, color: p.inkMuted),
                          )
                        : Column(
                            children: [
                              for (final b in villageBuildings(
                                t,
                                subjects: ref.watch(programmeSubjectsProvider),
                              ))
                                if (bySubject[b.subject] != null)
                                  _SubjectRow(
                                    label: b.label,
                                    value: bySubject[b.subject]!,
                                    accent: b.accent,
                                    palette: p,
                                  ),
                            ],
                          ),
                  ProfileTab.badges => _BadgeGrid(
                    earned: {
                      for (final a in Achievement.values)
                        if (board?.has(a) ?? false) a,
                    },
                    palette: p,
                  ),
                  ProfileTab.recent => _RecentActivity(
                    items: board?.recent ?? const [],
                    today: board?.today ?? quebecToday(),
                    palette: p,
                  ),
                },
              ),
            ),
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}

class _HeroStat {
  const _HeroStat({
    required this.asset,
    required this.value,
    required this.label,
  });

  final String asset;
  final String value;
  final String label;
}

/// The design's `.profile-hero`: the avatar with its edit dot, the name and
/// grade, and the three `.ph-stat-card`s, in one white panel.
///
/// The design's header already shows the same face, name and grade, so
/// this is the only place Profil shows them, and it puts them beside what
/// only Profil has: the edit dot and the stats. It replaces a centred
/// mascot-and-name banner that just repeated the header.
///
/// Wide, it is one row (avatar, name, stats), as the design's desktop
/// draws it. Narrow, it stacks and centres with a 76px avatar, as the
/// design's phone does.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.grade,
    required this.avatarKey,
    required this.onEditAvatar,
    required this.stats,
    required this.palette,
    this.onSwitchProfile,
    this.title,
  });

  final String name;
  final int? grade;
  final String avatarKey;
  final VoidCallback onEditAvatar;
  final List<_HeroStat> stats;
  final VillagePalette palette;

  /// Opens "Qui joue ?". Null hides the button.
  final VoidCallback? onSwitchProfile;

  /// An earned title ("Gardien de la flamme"), or null.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = palette;
    return Material(
      color: p.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadowSmall,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 560;
            final avatar = Stack(
              clipBehavior: Clip.none,
              children: [
                KidAvatar(
                  key: const ValueKey('profile-avatar'),
                  avatarKey: avatarKey,
                  size: wide ? 92 : 76,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: _EditDot(
                    onTap: onEditAvatar,
                    label: t.avatarEdit,
                    palette: p,
                  ),
                ),
              ],
            );
            final meta = Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: wide ? 22 : 18,
                    color: p.ink,
                  ),
                ),
                if (grade != null)
                  Text(
                    t.gradeLabel(grade!),
                    style: TextStyle(fontSize: 13, color: p.inkMuted),
                  ),
                if (title != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: const ValueKey('profile-title'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.goldPale,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ),
                ],
                if (onSwitchProfile != null) ...[
                  const SizedBox(height: Space.xs),
                  TextButton.icon(
                    key: const ValueKey('profile-switch'),
                    onPressed: onSwitchProfile,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(t.switchProfile),
                    style: TextButton.styleFrom(
                      // Bright blue: navy on navy vanished in dark (AM10).
                      foregroundColor: p.quebecBlueBright,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            );
            final statCards = Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: wide ? WrapAlignment.end : WrapAlignment.center,
              children: [for (final s in stats) _StatCard(stat: s, palette: p)],
            );
            if (!wide) {
              return Column(
                children: [
                  avatar,
                  const SizedBox(height: Space.sm),
                  meta,
                  const SizedBox(height: Space.sm),
                  statCards,
                ],
              );
            }
            return Row(
              children: [
                avatar,
                const SizedBox(width: 20),
                Expanded(child: meta),
                const SizedBox(width: Space.sm),
                Flexible(flex: 2, child: statCards),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The design's `.ph-edit-dot`: a 30px white circle on the avatar's corner.
class _EditDot extends StatelessWidget {
  const _EditDot({
    required this.onTap,
    required this.label,
    required this.palette,
  });

  final VoidCallback onTap;
  final String label;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          key: const ValueKey('profile-avatar-edit'),
          color: palette.surface,
          shape: const CircleBorder(),
          elevation: VillageColors.elevationSmall,
          shadowColor: palette.shadowSmall,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: Image.asset(
                  'assets/images/asset-edit.webp',
                  width: 16,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's `.ph-stat-card`: icon left, value over label.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat, required this.palette});

  final _HeroStat stat;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSmall,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/${stat.asset}', width: 30, height: 30),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: palette.ink,
                ),
              ),
              Text(
                stat.label,
                style: TextStyle(fontSize: 10.5, color: palette.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The white card holding a tab's content. The pill names it, so the card
/// has no heading of its own.
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.palette});

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
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Profil's three tabs under the hero (app ADR 0051).
enum ProfileTab {
  subjects(Icons.insights_outlined),
  badges(Icons.workspace_premium_outlined),
  recent(Icons.history);

  const ProfileTab(this.icon);

  final IconData icon;

  static ProfileTab from(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => subjects);

  String label(Strings t) => switch (this) {
    subjects => t.profileTabSubjects,
    badges => t.profileBadges,
    recent => t.profileTabRecent,
  };
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
          Expanded(child: VillageProgressBar(value: value)),
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
/// ones with their art, the rest dimmed behind a lock. The card hugs them.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned, required this.palette});

  final Set<Achievement> earned;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = palette;
    Widget badge(Achievement a) => Column(
      key: ValueKey(
        'badge-${a.name}-${earned.contains(a) ? 'earned' : 'locked'}',
      ),
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
                BoxShadow(
                  color: p.shadowSmall,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: earned.contains(a)
                ? Image.asset(
                    'assets/images/${achievementAsset(a)}',
                    width: 28,
                    height: 28,
                  )
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
    );
    // Rows of four, each as tall as its badges. A grid cell with a fixed
    // aspect ratio grew with the card's width and left most of each row
    // empty on desktop.
    const perRow = 4;
    final all = Achievement.values;
    return Column(
      key: const ValueKey('profile-badges'),
      children: [
        for (var i = 0; i < all.length; i += perRow) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + perRow; j++) ...[
                if (j > i) const SizedBox(width: 14),
                Expanded(
                  child: j < all.length ? badge(all[j]) : const SizedBox(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// The latest badges earned, newest first, with the day: what `QuestLog`
/// records. Before the first one, it says how to earn it.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.items,
    required this.today,
    required this.palette,
  });

  static const shown = 5;

  final List<EarnedItem> items;
  final DateTime today;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = palette;
    if (items.isEmpty) {
      return Text(
        t.profileRecentEmpty,
        style: TextStyle(fontSize: 13, height: 1.4, color: p.inkMuted),
      );
    }
    final day = DateTime(today.year, today.month, today.day);
    return Column(
      children: [
        for (final item in items.take(shown))
          Padding(
            key: ValueKey('recent-activity-${item.key}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/${achievementAsset(item.achievement)}',
                  width: 28,
                  height: 28,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    achievementName(t, item.achievement),
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: p.ink,
                    ),
                  ),
                ),
                if (DateTime.tryParse(item.day) case final earned?)
                  Text(
                    t.profileRecentDay(day.difference(earned).inDays),
                    style: TextStyle(fontSize: 12, color: p.inkMuted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
