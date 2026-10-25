import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One stat in the header: an icon and a value.
class HeaderStat {
  const HeaderStat({
    required this.asset,
    required this.label,
    this.progress,
    this.tooltip,
  });
  final String asset;
  final String label;

  /// 0..1: draws the design's small `.xp-track` after the label (the level
  /// pill). Hidden on compact headers, as the design hides it there.
  final double? progress;

  /// Shown on hover/long-press and read by screen readers.
  final String? tooltip;
}

/// The design's persistent header: 92px, white, a hairline beneath, the
/// learner on the left and their stats on the right.
///
/// Chrome rather than page content — it belongs to the shell, so it does not
/// disappear when the kid moves between Village, Carte and Profil, and no
/// page has to remember to draw it.
///
/// Stat pills collapse to icon-and-number below the tablet breakpoint, which
/// is the design's own behaviour (`.shell-tablet .stat-pill` drops the XP
/// track and tightens its padding).
class VillageHeader extends StatelessWidget {
  const VillageHeader({
    required this.name,
    required this.subtitle,
    required this.stats,
    this.compact = false,
    super.key,
  });

  final String name;
  final String subtitle;
  final List<HeaderStat> stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Container(
      height: VillageMetrics.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/asset-mascot-welcome.webp',
            height: compact ? 36 : 52,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: p.ink,
                  ),
                ),
                // The design hides this line on tablet rather than letting
                // it squeeze the stats.
                if (!compact && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Wrap(
            spacing: compact ? 6 : Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final stat in stats)
                _StatPill(stat: stat, palette: p, compact: compact),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.stat,
    required this.palette,
    required this.compact,
  });

  final HeaderStat stat;
  final VillagePalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSmall,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/${stat.asset}',
            width: compact ? 15 : 18,
            height: compact ? 15 : 18,
          ),
          const SizedBox(width: 6),
          Text(
            stat.label,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
              color: palette.ink,
            ),
          ),
          // `.stat-pill .xp-track`: 46 x 5, 2px after the label.
          if (stat.progress != null && !compact) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              child: VillageProgressBar(value: stat.progress!, height: 5),
            ),
          ],
        ],
      ),
    );
    final tip = stat.tooltip;
    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}
