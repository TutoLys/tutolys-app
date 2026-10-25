import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'quests_model.dart';
import 'quests_screen.dart';

/// Opens the streak detail the way the design does: a 380px card over the
/// dimmed page on wider screens, full screen on a phone.
Future<void> showStreakDetail(
  BuildContext context, {
  required int? streakDays,
  required int? freezesAvailable,
  required PlayedDays played,
  VoidCallback? onOpenPath,
}) {
  final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;

  Widget detail(BuildContext routeContext) => StreakDetail(
        streakDays: streakDays,
        freezesAvailable: freezesAvailable,
        played: played,
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
/// calendar, the goal bar and the streak shield.
///
/// Left out of what the design draws, on purpose:
/// - **The "Personnelle / Entre amis" tabs.** Social features are out (open
///   item #12), and one tab alone is not a tab bar.
/// - **"Coffre de série" and "Titre : Gardien de la flamme".** No chest and
///   no titles exist; both would be rewards a kid could never receive.
/// - **"Rechargé dans 3 jours".** Shields (streak freezes) are granted
///   weekly by a backend job the app cannot see the schedule of; it shows
///   the real balance instead.
class StreakDetail extends StatefulWidget {
  const StreakDetail({
    super.key,
    required this.streakDays,
    required this.freezesAvailable,
    required this.played,
    required this.onClose,
    this.onOpenPath,
  });

  final int? streakDays;
  final int? freezesAvailable;
  final PlayedDays played;
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
          if (freezes != null)
            _Section(
              title: t.streakDetailRewards,
              child: _ShieldCard(count: freezes),
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
class _ShieldCard extends StatelessWidget {
  const _ShieldCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: p.shadowSmall, blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(Icons.shield_outlined, size: 20, color: p.quebecBlueBright),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.streakShieldTitle,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.streakShieldBody,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: p.inkMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  (count > 0 ? t.streakShieldBalance(count) : t.streakShieldNone)
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.38,
                    color: count > 0 ? p.success : p.quebecBlueBright,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
