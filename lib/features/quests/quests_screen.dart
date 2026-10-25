import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../progress/progress_controller.dart';
import 'quests_model.dart';
import 'streak_detail.dart';

/// Quêtes, as the design draws it: the streak card with its week strip,
/// then "Quêtes du jour".
///
/// Three things the design draws are **not** here, each for a reason that
/// is not "later":
/// - **Three quests.** Exactly one quest type exists — the daily challenge
///   (backend ADR 0019). Teacher-assigned and bonus-review quests need
///   school plumbing (open item #11). One real row, not three.
/// - **"+15 XP" on each quest.** The daily challenge awards no XP; XP comes
///   per question answered (ADR 0022). A reward chip would promise one.
/// - **"Badge de la semaine" and "Réussites récentes".** Badges are open
///   item #3. Profil already says so in words; drawing a locked badge here
///   would imply a system a kid could unlock.
///
/// The streak number is the backend's. The week strip is this device's own
/// play history (`played_date`), because no device-facing endpoint serves
/// per-day play — see [StreakLocal.playedDays] for what that leaves out.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key, this.onOpenPath});

  /// Where a quest row and the streak nudge lead: the Carte, the only place
  /// a kid can actually play.
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final progress = ref.watch(progressControllerProvider);
    final played = ref.watch(playedDaysProvider).value;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? Space.md : Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
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
              Text(
                t.questsTitle,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontSize: compact ? 17 : 21,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              SizedBox(height: compact ? Space.sm : 18),
              StreakCard(
                streakDays: progress.currentStreakDays,
                estimated: progress.isStreakEstimated,
                played: played,
                compact: compact,
                onTap: played == null
                    ? null
                    : () => showStreakDetail(
                          context,
                          streakDays: progress.currentStreakDays,
                          freezesAvailable: progress.freezesAvailable,
                          played: played,
                          onOpenPath: onOpenPath,
                        ),
              ),
              SizedBox(height: compact ? Space.sm : 18),
              _QuestListCard(progress: progress, onOpenPath: onOpenPath),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
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
          BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 16)),
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
    required this.estimated,
    required this.played,
    required this.compact,
    this.onTap,
  });

  /// Null means unknown — shown as a dash, never as zero.
  final int? streakDays;
  final bool estimated;
  final PlayedDays? played;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final streak = streakDays;

    final number = streak == null
        ? '–'
        : '${estimated ? '~' : ''}${t.questsStreakDays(streak)}';
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
                ],
              )
            : Row(
                children: [
                  flame,
                  const SizedBox(width: 18),
                  Expanded(child: text),
                  ?week,
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
      mainAxisAlignment:
          spread ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
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
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
    if (!day.isToday) return cell;
    return TodayRing(radius: 9, color: p.quebecBlueBright, child: cell);
  }
}

class _QuestListCard extends StatelessWidget {
  const _QuestListCard({required this.progress, this.onOpenPath});

  final ProgressState progress;
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final quest = progress.dailyQuest;

    return QuestPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset('assets/images/asset-target.webp', width: 18),
              const SizedBox(width: 7),
              Text(
                t.villageQuestsTitle,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          if (quest == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Text(
                t.villageNoQuests,
                style: TextStyle(fontSize: 12.5, color: p.inkMuted),
              ),
            )
          else
            QuestItem(
              // The daily challenge has one fixed shape, so its title is
              // derived from the target rather than transported.
              title: t.streakQuestTitle(quest.target),
              done: quest.completed,
              current: quest.progress,
              target: quest.target,
              onTap: quest.completed ? null : onOpenPath,
            ),
        ],
      ),
    );
  }
}

/// One quest: check circle, icon tile, title, and — until it is done — a
/// progress track with "3 / 5" under it.
class QuestItem extends StatelessWidget {
  const QuestItem({
    super.key,
    required this.title,
    required this.done,
    required this.current,
    required this.target,
    this.onTap,
  });

  final String title;
  final bool done;
  final int current;
  final int target;
  final VoidCallback? onTap;

  static const _doneGreen = Color(0xFF3DBE7A);

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
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
                border: Border.all(color: done ? _doneGreen : p.track, width: 2),
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
                color: p.line,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('assets/images/asset-target.webp', width: 20),
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
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: GradientTrack(
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
          ],
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

/// The design's `.track`: a rounded bar filled blue-to-gold.
class GradientTrack extends StatelessWidget {
  const GradientTrack({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: p.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.quebecBlueBright, p.goldLight],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
