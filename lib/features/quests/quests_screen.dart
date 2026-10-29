import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/page_column.dart';
import '../../core/i18n/strings.dart';
import '../../data/api/assignments_api.dart';
import '../assignments/assignments_controller.dart';
import '../progress/progress_controller.dart';
import 'quest_board.dart';
import 'quests_model.dart';
import 'streak_detail.dart';

/// Quêtes, as the design draws it: the streak card with its week strip,
/// "Quêtes du jour" beside "Badge de la semaine", then "Réussites récentes".
///
/// Every number is measured, never mocked — see [questBoardProvider] for
/// what each quest and achievement is counted on. Two things the design
/// draws stay out: the coin reward (no currency exists; every reward chip is
/// XP) and the streak modal's *Entre amis* tab (open item #12, out).
///
/// The streak number is the backend's. The week strip is this device's own
/// play history (`played_date`), because no device-facing endpoint serves
/// per-day play — see [StreakLocal.playedDays] for what that leaves out.
class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key, this.onOpenPath});

  /// Where a quest row and the streak nudge lead: the Carte, the only place
  /// a kid can actually play.
  final VoidCallback? onOpenPath;

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

/// Holds which of the two views is showing: the quest list, or the "Série"
/// page the streak card opens. A page in the tab, not a pushed route or a
/// dialog, so the shell stays around it.
class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  bool _serie = false;

  void _showSerie(bool show) => setState(() => _serie = show);

  @override
  Widget build(BuildContext context) {
    final onOpenPath = widget.onOpenPath;
    final t = context.s;
    final p = VillagePalette.of(context);
    final progress = ref.watch(progressControllerProvider);
    final played = ref.watch(playedDaysProvider).value;
    final boardAsync = ref.watch(questBoardProvider);
    final board = boardAsync.value;
    final boardFailed = board == null && boardAsync.hasError;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final gap = compact ? Space.sm : 18.0;

    final serie = _serie && played != null;

    // Shared by both views: where you are, and the way to the other one.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.questsEyebrow.toUpperCase(),
          style: TextStyle(
            fontFamily: VillageType.display,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.md,
          runSpacing: Space.sm,
          children: [
            Text(
              t.questsTitle,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontSize: compact ? 17 : 21,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
            // Scales down rather than overflowing on a narrow phone.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: QuestsViewSwitch(
                serie: serie,
                streakDays: progress.currentStreakDays,
                onSelect: played == null ? null : _showSerie,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? Space.sm : 18),
      ],
    );

    if (serie) {
      return PageColumn(
        scrollKey: const PageStorageKey('serie'),
        maxWidth: PageWidth.content,
        wideMaxWidth: PageWidth.content,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            StreakDetail(
              streakDays: progress.currentStreakDays,
              freezesAvailable: progress.freezesAvailable,
              streakFreeze: progress.streakFreeze,
              played: played,
              board: board,
              onClose: () => _showSerie(false),
              onOpenPath: onOpenPath == null
                  ? null
                  : () {
                      _showSerie(false);
                      onOpenPath();
                    },
            ),
            const SizedBox(height: Space.xl),
          ],
        ),
      );
    }

    return PageColumn(
      scrollKey: const PageStorageKey('quests'),
      maxWidth: PageWidth.content,
      wideMaxWidth: PageWidth.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          StreakCard(
            streakDays: progress.currentStreakDays,
            played: played,
            compact: compact,
            onTap: played == null ? null : () => _showSerie(true),
          ),
          SizedBox(height: gap),
          if (ref.watch(assignmentsControllerProvider) case final work
              when work.isNotEmpty) ...[
            HomeworkCard(work: work, onOpenPath: onOpenPath),
            SizedBox(height: gap),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final list = QuestListCard(
                quests: board?.quests,
                failed: boardFailed,
                onRetry: () => ref.invalidate(questBoardProvider),
                onOpenPath: onOpenPath,
              );
              final badge = WeeklyBadgeCard(
                done: board?.weekCompleted ?? 0,
                earned: board?.weeklyBadgeEarned ?? false,
                compact: compact,
              );
              // The design's `.quetes-grid`: 1fr + 300px side by side,
              // stacked once there is no room for both.
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    list,
                    SizedBox(height: gap),
                    badge,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: list),
                  const SizedBox(width: 18),
                  SizedBox(width: 300, child: badge),
                ],
              );
            },
          ),
          SizedBox(height: gap),
          RecentAchievementsCard(earned: board?.recent ?? const []),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

/// "Mes quêtes | Ma série": two pills under the page title, on both views,
/// so the Série page is visible before anyone thinks to tap the streak card
/// and it is always clear which view is showing. The design reached Série
/// only through the card; on its own that had no visible affordance.
class QuestsViewSwitch extends StatelessWidget {
  const QuestsViewSwitch({
    super.key,
    required this.serie,
    required this.streakDays,
    this.onSelect,
  });

  final bool serie;
  final int? streakDays;

  /// Null while the play history is still loading; the pills are inert.
  final ValueChanged<bool>? onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    Widget pill({
      required Key key,
      required bool selected,
      required String asset,
      required String label,
      String? count,
      required bool value,
    }) {
      return Semantics(
        button: true,
        selected: selected,
        child: Material(
          key: key,
          color: selected ? p.surface : Colors.transparent,
          elevation: selected ? 2 : 0,
          shadowColor: p.shadowSmall,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onSelect == null || selected ? null : () => onSelect!(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/$asset', width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? p.quebecBlueBright : p.inkMuted,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: p.goldPale,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(
            key: const ValueKey('view-quests'),
            selected: !serie,
            asset: 'asset-target.webp',
            label: t.questsViewQuests,
            value: false,
          ),
          const SizedBox(width: 4),
          pill(
            key: const ValueKey('view-serie'),
            selected: serie,
            asset: 'asset-flame.webp',
            label: t.questsViewSerie,
            count: streakDays == null ? null : '$streakDays',
            value: true,
          ),
        ],
      ),
    );
  }
}

/// The design's `.quest-panel`: white, 20px corners, the soft navy shadow.
class QuestPanel extends StatelessWidget {
  const QuestPanel({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    const radius = BorderRadius.all(Radius.circular(20));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: p.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

/// "4 jours de suite", the line under it, and the Monday-first week strip.
/// Tapping it opens the streak detail.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streakDays,
    required this.played,
    required this.compact,
    this.onTap,
  });

  /// Null means unknown — shown as a dash, never as zero.
  final int? streakDays;
  final PlayedDays? played;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final streak = streakDays;

    final number = streak == null ? '–' : t.questsStreakDays(streak);
    final String line;
    if (streak == null) {
      line = t.questsStreakUnknown;
    } else if (streak == 0) {
      line = t.questsStreakStart;
    } else if (played?.playedToday ?? false) {
      line = t.questsStreakNextTomorrow(streak + 1);
    } else {
      line = t.questsStreakNextToday(streak + 1);
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 15 : 20,
            color: p.ink,
          ),
        ),
        Text(line, style: TextStyle(fontSize: 12, color: p.inkMuted)),
      ],
    );

    final flame = Image.asset(
      'assets/images/asset-flame.webp',
      width: compact ? 40 : 54,
      height: compact ? 40 : 54,
    );

    final week = played == null
        ? null
        : WeekStrip(
            days: weekOf(played!.today, played!.days),
            initials: t.weekdayInitials,
            spread: compact,
          );

    // The visible "this opens something" cue — the card alone looked like
    // every other panel.
    final see = onTap == null
        ? null
        : Row(
            key: const ValueKey('streak-see'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.questsSeeStreak,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.quebecBlueBright,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.quebecBlueBright),
            ],
          );

    return Semantics(
      button: onTap != null,
      hint: onTap == null ? null : t.questsStreakOpenHint,
      child: QuestPanel(
        onTap: onTap,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      flame,
                      const SizedBox(width: Space.sm),
                      Expanded(child: text),
                    ],
                  ),
                  if (week != null) ...[const SizedBox(height: Space.xs), week],
                  if (see != null) ...[
                    const SizedBox(height: Space.xs),
                    Align(alignment: Alignment.centerRight, child: see),
                  ],
                ],
              )
            : Row(
                children: [
                  flame,
                  const SizedBox(width: 18),
                  Expanded(child: text),
                  ?week,
                  if (see != null) ...[const SizedBox(width: 18), see],
                ],
              ),
      ),
    );
  }
}

/// Seven 30×34 cells: gold with a check for a day played, track grey with a
/// dash otherwise, an outline on today.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.initials,
    this.spread = false,
  });

  final List<WeekDay> days;
  final List<String> initials;

  /// On a phone the strip takes the full card width, cells spread apart.
  final bool spread;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final cells = [
      for (var i = 0; i < days.length; i++)
        _WeekCell(day: days[i], initial: initials[i], palette: p),
    ];
    return Row(
      mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: spread
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0 && !spread) const SizedBox(width: 6),
          cells[i],
        ],
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.day,
    required this.initial,
    required this.palette,
  });

  final WeekDay day;
  final String initial;
  final VillagePalette palette;

  static const _onGold = Color(0xFF241A04);

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fg = day.played ? _onGold : p.inkMuted;
    final cell = Container(
      key: ValueKey('week-${day.date.day}-${day.played ? 'done' : 'open'}'),
      width: 30,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: day.played ? null : p.track,
        gradient: day.played
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.goldLight, p.gold],
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            initial,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: fg.withValues(alpha: 0.7),
            ),
          ),
          Text(
            day.played ? '✓' : '–',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (!day.isToday) return cell;
    return TodayRing(radius: 9, color: p.quebecBlueBright, child: cell);
  }
}

/// While the quest board isn't there (A3): grey rows while it loads, or,
/// if it failed, the fox saying so with Réessayer. Never "Aucune quête
/// aujourd'hui", which only a real empty board may say.
class QuestListPending extends StatelessWidget {
  const QuestListPending({super.key, required this.failed, this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;
    if (!failed) {
      Widget bar(double width) => Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: p.track,
          borderRadius: BorderRadius.circular(6),
        ),
      );
      return Padding(
        key: const ValueKey('quests-loading'),
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(160),
            const SizedBox(height: Space.sm),
            bar(120),
            const SizedBox(height: Space.sm),
            bar(140),
          ],
        ),
      );
    }
    return Padding(
      key: const ValueKey('quests-failed'),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Image.asset(
            'assets/images/asset-mascot-welcome.webp',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              t.questsLoadFailed,
              style: TextStyle(fontSize: 13, color: p.ink),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const ValueKey('quests-retry'),
              onPressed: onRetry,
              child: Text(t.retry),
            ),
        ],
      ),
    );
  }
}

/// "Quêtes du jour": the board's quests, one row each. Null while the board
/// is still being read.
class QuestListCard extends StatelessWidget {
  const QuestListCard({
    super.key,
    required this.quests,
    this.onOpenPath,
    this.failed = false,
    this.onRetry,
  });

  final List<DailyQuestItem>? quests;
  final VoidCallback? onOpenPath;

  /// The board couldn't be read (A3): say so, with Réessayer, rather than
  /// "no quests today".
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final items = quests;

    return QuestPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(asset: 'asset-target.webp', title: t.villageQuestsTitle),
          const SizedBox(height: Space.xs),
          if (items == null)
            QuestListPending(failed: failed, onRetry: onRetry)
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Text(
                t.villageNoQuests,
                style: TextStyle(fontSize: 12.5, color: p.inkMuted),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
              QuestItem(
                key: ValueKey('quest-${items[i].key}'),
                title: questTitle(t, items[i]),
                done: items[i].done,
                current: items[i].progress,
                target: items[i].target,
                xpReward: items[i].xpReward,
                onTap: items[i].done ? null : onOpenPath,
              ),
            ],
        ],
      ),
    );
  }
}

/// A quest's title in the reader's language — the quest carries its shape,
/// never its words.
String questTitle(Strings t, DailyQuestItem q) => switch (q.kind) {
  QuestKind.challenge => t.streakQuestTitle(q.target),
  QuestKind.exercises => t.questExercisesTitle(q.target),
  QuestKind.minutes => t.questMinutesTitle(q.target),
};

/// The design's `.quest-panel h2`: an 18px icon and a 14.5px display title.
class PanelTitle extends StatelessWidget {
  const PanelTitle({super.key, required this.asset, required this.title});

  final String asset;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Row(
      children: [
        Image.asset('assets/images/$asset', width: 18, height: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

/// One quest: check circle, icon tile, title, a progress track with "3 / 5"
/// until it is done, and the reward chip.
class QuestItem extends StatelessWidget {
  const QuestItem({
    super.key,
    required this.title,
    required this.done,
    required this.current,
    required this.target,
    this.icon = 'asset-target.webp',
    this.xpReward,
    this.onTap,
  });

  final String title;
  final String icon;
  final bool done;
  final int current;
  final int target;
  final int? xpReward;
  final VoidCallback? onTap;

  static const _doneGreen = Color(0xFF3DBE7A);

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final struck = done ? TextDecoration.lineThrough : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              key: ValueKey(done ? 'quest-check-done' : 'quest-check-open'),
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _doneGreen : null,
                border: Border.all(
                  color: done ? _doneGreen : p.track,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: Space.sm),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('assets/images/$icon', width: 20, height: 20),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: done ? p.inkMuted : p.ink,
                      decoration: struck,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: VillageProgressBar(
                        value: target == 0 ? 0 : current / target,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$current / $target',
                      style: TextStyle(fontSize: 10.5, color: p.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (xpReward != null) ...[
              const SizedBox(width: Space.xs),
              Row(
                key: const ValueKey('quest-reward'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/asset-xpstar.webp',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    context.s.questRewardXp(xpReward!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: done ? p.inkMuted : p.gold,
                      decoration: struck,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Badge de la semaine": the badge art, the rule, and a track counting
/// this week's finished quests toward [weeklyBadgeTarget].
class WeeklyBadgeCard extends StatelessWidget {
  const WeeklyBadgeCard({
    super.key,
    required this.done,
    required this.earned,
    this.compact = false,
  });

  final int done;
  final bool earned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final shown = done.clamp(0, weeklyBadgeTarget);
    return QuestPanel(
      child: Column(
        children: [
          Opacity(
            opacity: earned ? 1 : 0.9,
            child: Image.asset(
              'assets/images/asset-badge.webp',
              width: compact ? 72 : 92,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            t.weeklyBadgeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13.5 : 15,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t.weeklyBadgeBody(weeklyBadgeTarget),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: p.inkMuted),
          ),
          const SizedBox(height: 10),
          VillageProgressBar(value: shown / weeklyBadgeTarget),
          const SizedBox(height: 5),
          Text(
            earned
                ? t.weeklyBadgeEarned
                : t.weeklyBadgeProgress(shown, weeklyBadgeTarget),
            key: const ValueKey('weekly-badge-progress'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: earned ? p.success : p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The art and the name of each earned thing.
String achievementAsset(Achievement? a) => switch (a) {
  Achievement.streak3 || Achievement.streak7 => 'asset-flame.webp',
  Achievement.questMaster || Achievement.quests50 => 'asset-quetes.png',
  Achievement.level10 || Achievement.level20 => 'asset-xpstar.webp',
  Achievement.allSubjects50 => 'asset-progres.png',
  Achievement.explorer => 'asset-carte.png',
  null => 'asset-badge.webp',
};

String achievementName(Strings t, Achievement? a) => switch (a) {
  Achievement.streak3 => t.achStreak3,
  Achievement.questMaster => t.achQuestMaster,
  Achievement.level10 => t.achLevel10,
  Achievement.streak7 => t.achStreak7,
  Achievement.allSubjects50 => t.achAllSubjects50,
  Achievement.level20 => t.achLevel20,
  Achievement.quests50 => t.achQuests50,
  Achievement.explorer => t.achExplorer,
  null => t.weeklyBadgeTitle,
};

/// "Réussites récentes": five round slots, the latest earned first, the
/// rest locked — as many locked as there is room for, like the design.
class RecentAchievementsCard extends StatelessWidget {
  const RecentAchievementsCard({super.key, required this.earned});

  static const slots = 5;

  final List<EarnedItem> earned;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final shown = earned.take(slots).toList();
    return QuestPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(asset: 'asset-target.webp', title: t.recentTitle),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in shown)
                _RoundIcon(
                  key: ValueKey('recent-${item.key}'),
                  label: achievementName(t, item.achievement),
                  palette: p,
                  child: Image.asset(
                    'assets/images/${achievementAsset(item.achievement)}',
                    width: 24,
                    height: 24,
                  ),
                ),
              for (var i = shown.length; i < slots; i++)
                _RoundIcon(
                  key: ValueKey('recent-locked-$i'),
                  label: t.lockedLabel,
                  palette: p,
                  locked: true,
                  child: Icon(Icons.lock, size: 20, color: p.inkMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    super.key,
    required this.label,
    required this.child,
    required this.palette,
    this.locked = false,
  });

  final String label;
  final Widget child;
  final VillagePalette palette;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Opacity(
          opacity: locked ? 0.4 : 1,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.shadowSmall,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The design's `outline: 2px; outline-offset: 1px` on today: a ring drawn
/// outside the child, which — like a CSS outline — takes no layout space,
/// so today's cell lines up with the others.
class TodayRing extends StatelessWidget {
  const TodayRing({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;

  /// The child's own corner radius; the ring's is this plus its offset.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('today'),
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -3,
          top: -3,
          right: -3,
          bottom: -3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 3),
                border: Border.all(color: color, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "De ton enseignant·e": work a teacher gave this kid (backend ADR 0123).
/// The kid's own list only; nothing about who else has it or has done it.
class HomeworkCard extends StatelessWidget {
  const HomeworkCard({super.key, required this.work, this.onOpenPath});

  final List<AssignmentDto> work;
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    return QuestPanel(
      key: const ValueKey('homework-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.homeworkTitle,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final a in work)
            InkWell(
              onTap: a.done ? null : onOpenPath,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      a.done ? Icons.check_circle : Icons.assignment_outlined,
                      color: a.done ? p.success : p.gold,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            [
                              t.homeworkFrom(a.fromName),
                              if (a.dueOn != null) t.homeworkDue(a.dueOn!),
                            ].join(' · '),
                            style: TextStyle(fontSize: 12.5, color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (a.done)
                      Text(
                        t.homeworkDone,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: p.success,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
