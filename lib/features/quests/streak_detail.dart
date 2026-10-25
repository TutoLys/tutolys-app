import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'quest_board.dart';
import 'quests_model.dart';
import 'quests_screen.dart';

/// Opens the streak detail the way the design does: a 380px card over the
/// dimmed page on wider screens, full screen on a phone.
Future<void> showStreakDetail(
  BuildContext context, {
  required int? streakDays,
  required int? freezesAvailable,
  required PlayedDays played,
  QuestBoard? board,
  VoidCallback? onOpenPath,
}) {
  final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;

  Widget detail(BuildContext routeContext) => StreakDetail(
        streakDays: streakDays,
        freezesAvailable: freezesAvailable,
        played: played,
        board: board,
        onClose: () => Navigator.of(routeContext).pop(),
        onOpenPath: onOpenPath == null
            ? null
            : () {
                Navigator.of(routeContext).pop();
                onOpenPath();
              },
      );

  if (phone) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (c) => Scaffold(
          backgroundColor: VillagePalette.of(c).surface,
          body: detail(c),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: VillagePalette.of(c).surface,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(Space.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: detail(c),
      ),
    ),
  );
}

/// "Série": the gold hero, a nudge when today is not played yet, the month
/// calendar, the goal bar and the three streak rewards.
///
/// The rewards are earned on the real streak and recorded once, never taken
/// back ([QuestBoard.unlocked]): the chest opens at 3 days, "Gardien de la
/// flamme" activates at 7 and shows on Profil, and the shield is the real
/// streak-freeze balance (backend ADR 0019).
///
/// Left out, on purpose:
/// - **The *Entre amis* tab.** Social features are out (open item #12), and
///   one tab alone is not a tab bar.
/// - **"Rechargé dans 3 jours".** The backend grants a shield a week after
///   its last grant and does not serve that date; until it does (work order Q2,
///   `Platforms/BACKEND_WORKORDER_QUESTS.md`), the tag shows the real balance.
class StreakDetail extends StatefulWidget {
  const StreakDetail({
    super.key,
    required this.streakDays,
    required this.freezesAvailable,
    required this.played,
    required this.onClose,
    this.board,
    this.onOpenPath,
  });

  final int? streakDays;
  final int? freezesAvailable;
  final PlayedDays played;
  final QuestBoard? board;
  final VoidCallback onClose;
  final VoidCallback? onOpenPath;

  @override
  State<StreakDetail> createState() => _StreakDetailState();
}

class _StreakDetailState extends State<StreakDetail> {
  late DateTime _month = DateTime(
    widget.played.today.year,
    widget.played.today.month,
  );

  /// How far back the arrows go: the first month this kid played here, or
  /// the current one if never. Paging into empty months teaches nothing.
  DateTime get _earliest {
    final days = widget.played.days;
    final first = days.isEmpty
        ? widget.played.today
        : days.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(first.year, first.month);
  }

  DateTime get _current =>
      DateTime(widget.played.today.year, widget.played.today.month);

  void _shift(int months) => setState(
        () => _month = DateTime(_month.year, _month.month + months),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final streak = widget.streakDays;
    final freezes = widget.freezesAvailable;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(streakDays: streak, onClose: widget.onClose),
          if (!widget.played.playedToday)
            Transform.translate(
              offset: const Offset(0, -10),
              child: _Nudge(onOpenPath: widget.onOpenPath),
            )
          else
            const SizedBox(height: 18),
          _Section(
            title: t.streakDetailCalendar,
            child: _Calendar(
              month: _month,
              played: widget.played,
              onPrev: _month.isAfter(_earliest) ? () => _shift(-1) : null,
              onNext: _month.isBefore(_current) ? () => _shift(1) : null,
            ),
          ),
          if (streak != null)
            _Section(
              title: t.streakDetailGoal,
              child: _GoalTrack(streak: streak),
            ),
          _Section(
            title: t.streakDetailRewards,
            child: Column(
              children: [
                _RewardCard(
                  key: const ValueKey('reward-chest'),
                  leading: Image.asset('assets/images/asset-chest.webp', width: 42, height: 42),
                  title: t.chestTitle,
                  body: (widget.board?.has(Achievement.streak3) ?? false)
                      ? t.chestBody
                      : t.chestBodyLocked,
                  tag: (widget.board?.has(Achievement.streak3) ?? false)
                      ? _Tag.ok(t.rewardObtained)
                      : _Tag.pending(t.rewardDaysLeft(3 - (streak ?? 0).clamp(0, 2))),
                ),
                if (freezes != null) ...[
                  const SizedBox(height: 10),
                  _RewardCard(
                    key: const ValueKey('reward-shield'),
                    leading: Image.asset('assets/images/asset-badge.webp', width: 42, height: 42),
                    title: t.streakShieldTitle,
                    body: t.streakShieldBody,
                    tag: freezes > 0
                        ? _Tag.ok(t.streakShieldBalance(freezes))
                        : _Tag.pending(t.streakShieldNone),
                  ),
                ],
                const SizedBox(height: 10),
                _RewardCard(
                  key: const ValueKey('reward-title'),
                  leading: _RoundLeading(
                    child: Icon(Icons.receipt_long_outlined, size: 20, color: VillagePalette.of(context).quebecBlueBright),
                  ),
                  title: '${t.flameKeeperTitlePrefix}${t.flameKeeperTitle}',
                  body: t.flameKeeperBody,
                  tag: (widget.board?.has(Achievement.streak7) ?? false)
                      ? _Tag.active(t.rewardActive)
                      : _Tag.pending(t.rewardDaysLeft(7 - (streak ?? 0).clamp(0, 6))),
                ),
              ],
            ),
          ),
          SizedBox(height: Space.xs + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.streakDays, required this.onClose});

  final int? streakDays;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final pale = p.isDark ? VillageDarkColors.goldPale : VillageColors.goldPale;
    final bottom = p.isDark ? const Color(0xFF241C0A) : const Color(0xFFFBEFC7);
    final headline = p.isDark ? p.gold : const Color(0xFFA9791A);
    final eyebrowInk = p.isDark ? p.goldLight : const Color(0xFF8A6A1B);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20 + MediaQuery.paddingOf(context).top,
        20,
        26,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pale, bottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: t.closeLabel,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.75),
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('streak-detail-close'),
                      customBorder: const CircleBorder(),
                      onTap: onClose,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close,
                          size: 15,
                          color: VillageColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                t.streakDetailTitle,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x38D4AF37),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.streakDetailEyebrow.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: eyebrowInk,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  streakDays == null
                      ? '–'
                      : t.streakDetailHeadline(streakDays!),
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 25,
                    color: headline,
                  ),
                ),
              ),
              Image.asset('assets/images/asset-flame.webp', width: 66, height: 66),
            ],
          ),
        ],
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({this.onOpenPath});

  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final pale = p.isDark ? VillageDarkColors.goldPale : VillageColors.goldPale;
    return Container(
      key: const ValueKey('streak-nudge'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: p.shadowSmall, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: pale, shape: BoxShape.circle),
            child: Icon(Icons.bolt, size: 17, color: p.isDark ? p.goldLight : const Color(0xFF8A6A1B)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.streakDetailNudge,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: p.ink),
                ),
                if (onOpenPath != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onOpenPath,
                    child: Text(
                      t.streakDetailNudgeCta.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.33,
                        color: p.quebecBlueBright,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: p.ink,
            ),
          ),
          const SizedBox(height: Space.sm),
          child,
        ],
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.played,
    this.onPrev,
    this.onNext,
  });

  final DateTime month;
  final PlayedDays played;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final initials = t.weekdayInitials;
    // The strings are Monday first; the calendar is Sunday first.
    final dow = [initials[6], ...initials.take(6)];
    final cells = monthGrid(month.year, month.month);

    Widget arrow(IconData icon, String label, VoidCallback? onTap, Key key) =>
        IconButton(
          key: key,
          onPressed: onTap,
          tooltip: label,
          iconSize: 15,
          visualDensity: VisualDensity.compact,
          color: p.inkMuted,
          disabledColor: p.track,
          icon: Icon(icon),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              arrow(Icons.chevron_left, t.streakDetailPrevMonth, onPrev,
                  const ValueKey('cal-prev')),
              Expanded(
                child: Text(
                  t.monthYear(month.year, month.month).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.36,
                    color: p.ink,
                  ),
                ),
              ),
              arrow(Icons.chevron_right, t.streakDetailNextMonth, onNext,
                  const ValueKey('cal-next')),
            ],
          ),
          const SizedBox(height: Space.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: [
              for (final d in dow)
                Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.inkMuted,
                    ),
                  ),
                ),
              for (final day in cells)
                day == null
                    ? const SizedBox.shrink()
                    : _CalendarDay(day: day, played: played),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.day, required this.played});

  final DateTime day;
  final PlayedDays played;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final isPlayed = played.days.contains(day);
    final isToday = day == played.today;
    final isPast = day.isBefore(played.today);

    final Color ink;
    if (isPlayed) {
      ink = const Color(0xFF241A04);
    } else if (isToday) {
      ink = p.quebecBlueBright;
    } else if (isPast) {
      ink = p.isDark ? p.line : const Color(0xFFD7DEEA);
    } else {
      ink = p.inkMuted;
    }

    final cell = Container(
      key: ValueKey('cal-${day.day}-${isPlayed ? 'played' : 'open'}'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isPlayed
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.goldLight, p.gold],
              )
            : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
      ),
    );
    if (!isToday) return cell;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: TodayRing(radius: 999, color: p.quebecBlueBright, child: cell),
    );
  }
}

class _GoalTrack extends StatelessWidget {
  const _GoalTrack({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final goal = nextStreakGoal(streak);

    Widget chip(int n) => Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.isDark ? VillageDarkColors.goldPale : VillageColors.goldPale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.isDark ? p.goldLight : const Color(0xFF8A6A1B),
            ),
          ),
        );

    return Row(
      key: ValueKey('goal-$streak-$goal'),
      children: [
        chip(streak),
        const SizedBox(width: 10),
        Expanded(child: GradientTrack(value: streak / goal, height: 10)),
        const SizedBox(width: 10),
        chip(goal),
      ],
    );
  }
}

/// "Bouclier de série" — the real streak freeze, under the design's name.
enum _TagKind { ok, pending, active }

/// The design's `.sm-reward-tag`: green for earned, blue for still to come,
/// a green pill for an active title.
class _Tag {
  const _Tag.ok(this.text) : kind = _TagKind.ok;
  const _Tag.pending(this.text) : kind = _TagKind.pending;
  const _Tag.active(this.text) : kind = _TagKind.active;

  final String text;
  final _TagKind kind;
}

class _RoundLeading extends StatelessWidget {
  const _RoundLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: p.shadowSmall, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// The design's `.sm-reward-card`.
class _RewardCard extends StatelessWidget {
  const _RewardCard({
    super.key,
    required this.leading,
    required this.title,
    required this.body,
    required this.tag,
  });

  final Widget leading;
  final String title;
  final String body;
  final _Tag tag;

  static const _okGreen = Color(0xFF2E9E5B);
  static const _okPale = Color(0xFFDFF3E6);

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final tagStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.38,
      color: tag.kind == _TagKind.pending ? p.quebecBlueBright : _okGreen,
    );
    final tagText = Text(tag.text.toUpperCase(), style: tagStyle);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 42, height: 42, child: leading),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: p.inkMuted),
                ),
                const SizedBox(height: 5),
                if (tag.kind == _TagKind.active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: _okPale,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: tagText,
                  )
                else
                  tagText,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
