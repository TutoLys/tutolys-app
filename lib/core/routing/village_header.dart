import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../widgets/kid_avatar.dart';

/// One stat in the header: an icon and a value.
class HeaderStat {
  const HeaderStat({
    required this.asset,
    required this.label,
    this.progress,
    this.tooltip,
    this.priority = 99,
  });
  final String asset;
  final String label;

  /// Lower stays longer when the header is narrow (K1): pills that don't
  /// fit at full size are left out, never shrunk.
  final int priority;

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
    this.avatarKey = '',
    this.onIdentity,
    this.identityLabel = '',
    this.compact = false,
    this.onSettings,
    this.settingsLabel = '',
    this.onNotifications,
    this.unreadNotifications = 0,
    this.notificationsLabel = '',
    super.key,
  });

  final String name;
  final String subtitle;
  final List<HeaderStat> stats;

  /// The kid's avatar (`avatars.dart`). The design's `.student-avatar` is
  /// the kid, never the mascot.
  final String avatarKey;

  /// Tapping the avatar and name: Profil for one kid, "Qui joue ?" for
  /// several. Null makes them inert.
  final VoidCallback? onIdentity;

  /// The identity button's tooltip and screen-reader name.
  final String identityLabel;
  final bool compact;

  /// The design's `.phone-gear-btn`: where Réglages lives on a phone, whose
  /// bottom bar has room for five tabs and leaves it out. Null hides the
  /// gear; the shell passes it only when the bottom bar is showing, since
  /// the sidebar and rail list Réglages themselves.
  final VoidCallback? onSettings;

  /// The gear's tooltip and screen-reader name.
  final String settingsLabel;

  /// The design's `.bell-btn`: opens the inbox. Null hides it.
  final VoidCallback? onNotifications;

  /// Drawn as the red badge on the bell; 0 draws none.
  final int unreadNotifications;

  /// The bell's tooltip and screen-reader name, unread count included.
  final String notificationsLabel;

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
      child: LayoutBuilder(
        builder: (context, box) {
          // What the pills may take: everything but the avatar, the gear and
          // a name at least ~90px wide.
          final avatar = compact ? 36.0 : 52.0;
          final gear =
              (onSettings == null ? 0.0 : 50.0) +
              (onNotifications == null ? 0.0 : 50.0);
          final maxStatsWidth =
              (box.maxWidth - avatar - gear - Space.sm * 2 - 90).clamp(
                0.0,
                double.infinity,
              );
          return Row(
            children: [
              Expanded(
                child: _Identity(
                  onTap: onIdentity,
                  label: identityLabel,
                  child: Row(
                    children: [
                      KidAvatar(avatarKey: avatarKey, size: avatar),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              // The pills shrink as a group rather than overflow: on a narrow
              // phone, with the gear beside them, three pills and a name do not
              // fit at full size. The name gives way first (it ellipsizes),
              // then the pills scale down together.
              // K1: never scaled. A pill shrunk to fit read at ~4 px on a
              // phone. As many as fit at full size are shown, the most
              // important first (XP, then the streak), at most two on a
              // phone; level and quests stay a tap away in Progrès and
              // Quêtes.
              // Natural width: the name beside it is Expanded and gives way
              // (it ellipsizes), so the pills keep their size.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, stat) in visibleStats(
                    stats,
                    maxWidth: maxStatsWidth,
                    compact: compact,
                    // Its own width, padding back in: a phone-sized header
                    // whatever MediaQuery says.
                    phone:
                        box.maxWidth + (compact ? 32 : 56) <
                        Breakpoints.compact,
                  ).indexed) ...[
                    if (i > 0) SizedBox(width: compact ? 6 : Space.xs),
                    _StatPill(stat: stat, palette: p, compact: compact),
                  ],
                ],
              ),
              if (onNotifications != null) ...[
                SizedBox(width: compact ? 4 : Space.xs),
                _RoundButton(
                  key: const ValueKey('header-notifications'),
                  onPressed: onNotifications!,
                  label: notificationsLabel,
                  asset: 'asset-bell.webp',
                  size: compact ? 32 : 38,
                  badge: unreadNotifications,
                  palette: p,
                ),
              ],
              if (onSettings != null) ...[
                const SizedBox(width: 4),
                _RoundButton(
                  key: const ValueKey('header-settings'),
                  onPressed: onSettings!,
                  label: settingsLabel,
                  asset: 'asset-reglages.png',
                  size: 32,
                  palette: p,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The pills a header [maxWidth] wide can show at full size, in their
/// original order (K1). Each is budgeted generously; a phone shows two at
/// most.
List<HeaderStat> visibleStats(
  List<HeaderStat> stats, {
  required double maxWidth,
  required bool compact,
  required bool phone,
}) {
  final budget = compact ? 92.0 : 120.0;
  // A phone always has room for two at full size (the name gives way);
  // more would push it to nothing.
  var fit = phone ? 2 : (maxWidth / budget).floor();
  if (fit >= stats.length) return stats;
  if (fit <= 0) return const [];
  final keep = ([
    ...stats,
  ]..sort((a, b) => a.priority.compareTo(b.priority))).take(fit).toSet();
  return [
    for (final s in stats)
      if (keep.contains(s)) s,
  ];
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

/// `.bell-btn` / `.phone-gear-btn`: a round surface button with a hairline
/// and the small shadow, holding a piece of the design's art, with an
/// optional red count badge. The tap target is 44px around it.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.onPressed,
    required this.label,
    required this.asset,
    required this.size,
    required this.palette,
    this.badge = 0,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;
  final String asset;
  final double size;
  final int badge;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.line),
                      boxShadow: [
                        BoxShadow(
                          color: p.shadowSmall,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/$asset',
                      width: size * 0.47,
                      height: size * 0.47,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        key: const ValueKey('header-badge'),
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          // The nav badge's own red.
                          color: Color(0xFFEF4444),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            fontFamily: VillageType.display,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar and name as one button, or as plain content when [onTap] is
/// null.
class _Identity extends StatelessWidget {
  const _Identity({required this.child, required this.label, this.onTap});

  final Widget child;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Tooltip(
      message: label,
      child: InkWell(
        key: const ValueKey('header-identity'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: child,
        ),
      ),
    );
  }
}
