import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/api/progress_api.dart';
import 'progress_controller.dart';
import 'weekly_league.dart';

/// Progrès' « Cette semaine » card (app ADR 0117): the kid's personal
/// league, how far to the next one, and one effort line.
///
/// Only the kid's own data is drawn. No names, no ranks, no list; the one
/// number about other children is the anonymous percentile, and only when
/// the backend serves it (at or above the median). Hidden entirely until a
/// backend serves a league.
class WeeklyLeagueCard extends ConsumerWidget {
  const WeeklyLeagueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressControllerProvider);
    final league = progress.league;
    if (league == null) return const SizedBox.shrink();
    return WeeklyLeagueView(
      league: league,
      percentile: progress.effortPercentile,
    );
  }
}

/// The card itself, from plain data, so tests need no providers.
class WeeklyLeagueView extends StatelessWidget {
  const WeeklyLeagueView({
    required this.league,
    this.percentile,
    this.now,
    super.key,
  });

  final LeagueDto league;
  final EffortPercentileDto? percentile;

  /// For tests; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final division = divisionOf(league.division);
    final next = nextDivision(division);
    final name = divisionName(t, division);
    final medal = medalColor(division, p.gold, p.quebecBlueBright);

    final promoteAt = league.promoteAtXp;
    final toGo = league.xpToPromote;
    final String goal;
    final double? fraction;
    if (next == null || promoteAt == null || toGo == null) {
      goal = t.leagueTop;
      fraction = null;
    } else {
      final nextName = divisionName(t, next);
      goal = toGo > 0
          ? t.leagueToNext(toGo, nextName)
          : t.leagueGoalReached(nextName);
      fraction = promoteAt <= 0 ? 1 : league.xpThisWeek / promoteAt;
    }

    return Container(
      key: const ValueKey('weekly-league-card'),
      margin: const EdgeInsets.only(bottom: Space.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LeagueMedal(
                key: const ValueKey('weekly-league-medal'),
                color: medal,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.leagueCardTitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: p.inkMuted,
                      ),
                    ),
                    Text(
                      t.leagueName(name),
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
              // The effort line says "this week" already; here, the number.
              Semantics(
                label: t.leagueWeekXp(league.xpThisWeek),
                child: ExcludeSemantics(
                  child: Text(
                    t.leagueXp(league.xpThisWeek),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (fraction != null) ...[
            VillageProgressBar(value: fraction),
            const SizedBox(height: 8),
          ],
          Text(
            goal,
            key: const ValueKey('weekly-league-goal'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            effortText(t, effortLine(league, percentile)),
            key: const ValueKey('weekly-league-effort'),
            style: TextStyle(fontSize: 12.5, color: p.ink),
          ),
          const SizedBox(height: 4),
          Text(
            t.leagueDaysLeft(leagueDaysLeft(league, now: now)),
            style: TextStyle(fontSize: 11.5, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A round medal in a division's colour. Static: it never animates, so
/// reduced motion has nothing to stop here.
class LeagueMedal extends StatelessWidget {
  const LeagueMedal({required this.color, this.size = 44, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: p.surface, width: 3),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8)],
        ),
        child: Icon(
          Icons.military_tech_rounded,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
