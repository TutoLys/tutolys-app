import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One navigable destination in the village shell.
class VillageDestination {
  const VillageDestination({
    required this.label,
    required this.asset,
    this.badge,
    this.icon,
  });

  final String label;

  /// Path under `assets/images/`, e.g. `asset-village.png`. The design ships
  /// these as real illustrated icons rather than glyphs, so they are images
  /// and not an `IconData` — see `docs/design/README.md`.
  final String asset;

  /// Unread/pending count, rendered as the red pill. Null means no badge;
  /// zero is treated the same, so a caller never has to special-case it.
  final int? badge;

  /// Draws the icon at a given size instead of [asset], for an icon that is
  /// the kid's own (Profil shows their avatar). [asset] stays the fallback.
  final Widget Function(double size)? icon;

  Widget iconAt(double size) =>
      icon?.call(size) ??
      Image.asset(
        'assets/images/$asset',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
}

/// The shell chrome every page sits inside, in all three of the design's
/// breakpoints.
///
/// Presentation only: it owns no routing and no state. The caller says which
/// destination is current and what to do when one is tapped, which is what
/// lets it be widget-tested without a router and reused by whatever drives
/// navigation later.
///
/// Three layouts, from `docs/design/01-design-system-gallery.html`:
///
/// - **>= 1024px** — a 224px sidebar, icon and label, the active row tinted
///   with a 4px indicator bleeding off its left edge.
/// - **768-1023px** — the same sidebar collapsed to an 84px rail: icons
///   only, labels hidden, badges moved into the icon's corner.
/// - **< 768px** — a 78px bottom tab bar of five, with Réglages promoted to
///   the header instead (the design's own split; six tabs in a thumb's reach
///   is one too many).
class VillageNavShell extends StatelessWidget {
  const VillageNavShell({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.child,
    this.secondary,
    this.onSecondarySelect,
    this.onHelp,
    this.helpLabel = '',
    super.key,
  });

  /// The primary destinations: Village, Carte, Quêtes, Progrès, Profil.
  final List<VillageDestination> destinations;

  /// Index into [destinations], or into [secondary] offset by its length.
  final int currentIndex;

  final ValueChanged<int> onSelect;

  /// Below the divider — Réglages today. Shown in the sidebar and rail; on
  /// mobile these move to the header rather than crowding the tab bar.
  final List<VillageDestination>? secondary;
  final ValueChanged<int>? onSecondarySelect;

  /// "Aide & support", pinned to the sidebar's foot above a hairline.
  final VoidCallback? onHelp;

  /// Its label. Passed in rather than read from `Strings`, so this widget
  /// stays pure presentation and has no opinion about the app's i18n.
  final String helpLabel;

  final Widget child;

  static const _hoverFill = Color(0xFFF4F8FF);
  static const _activeFill = Color(0xFFE8F0FF);
  static const _badgeFill = Color(0xFFEF4444);

  bool get _hasSecondary => (secondary?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final width = MediaQuery.sizeOf(context).width;

    if (width >= Breakpoints.medium) {
      return _withSky(p, Row(children: [_sidebar(p, expanded: true), _content()]));
    }
    if (width >= Breakpoints.compact) {
      return _withSky(p, Row(children: [_sidebar(p, expanded: false), _content()]));
    }
    return _withSky(p, 
      Column(children: [Expanded(child: child), _tabBar(p)]),
    );
  }

  /// `--sky-top` to `--sky-bottom`. Painted here rather than by the theme so
  /// one widget owns the background and the scaffold never competes with it.
  Widget _withSky(VillagePalette p, Widget body) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ),
      ),
      child: body,
    );
  }

  Widget _content() => Expanded(child: child);

  Widget _sidebar(VillagePalette p, {required bool expanded}) {
    return Container(
      width: expanded
          ? VillageMetrics.sidebarWidth
          : VillageMetrics.railWidth,
      padding: expanded
          ? EdgeInsets.fromLTRB(14, 22, 14, 16)
          : EdgeInsets.fromLTRB(0, 22, 0, 16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment:
            expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          _brand(p, expanded: expanded),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              // `gap: 3px` between rows.
              padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
              child: _navRow(
                p,
                destinations[i],
                expanded: expanded,
                active: currentIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          if (_hasSecondary) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Divider(height: 1, color: p.line),
            ),
            for (var i = 0; i < secondary!.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
                child: _navRow(
                  p,
                  secondary![i],
                  expanded: expanded,
                  active: currentIndex == destinations.length + i,
                  onTap: () => onSecondarySelect?.call(i),
                ),
              ),
          ],
          const Spacer(),
          if (onHelp != null) _helpFooter(p, expanded: expanded),
        ],
      ),
    );
  }

  Widget _brand(VillagePalette p, {required bool expanded}) {
    final mark = Image.asset(
      'assets/images/asset-logo.webp',
      width: 19,
      height: 30,
      fit: BoxFit.contain,
    );

    if (!expanded) {
      return Padding(
        padding: EdgeInsets.only(bottom: 22),
        child: mark,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 2, 8, 22),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 9),
          Text(
            'TutoLys',
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.2,
              color: p.quebecBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRow(
    VillagePalette p,
    VillageDestination destination, {
    required bool expanded,
    required bool active,
    required VoidCallback onTap,
  }) {
    final icon = destination.iconAt(expanded ? 22 : 24);

    final row = Material(
      color: active ? _activeFill : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        hoverColor: _hoverFill,
        child: Padding(
          padding: expanded
              ? EdgeInsets.fromLTRB(17, 11, 14, 11)
              : EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              icon,
              if (expanded) ...[
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14.5,
                      color: active
                          ? p.quebecBlueBright
                          : p.inkMuted,
                    ),
                  ),
                ),
                if ((destination.badge ?? 0) > 0) _badge(p, destination.badge!),
              ],
            ],
          ),
        ),
      ),
    );

    // The active indicator bleeds 14px past the row's left edge, which is
    // exactly the sidebar's own horizontal padding — so it sits flush
    // against the panel edge rather than floating inside it.
    return SizedBox(
      width: expanded ? null : 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          row,
          if (active && expanded)
            Positioned(
              left: -14,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 4,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.quebecBlueBright,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!expanded && (destination.badge ?? 0) > 0)
            Positioned(top: 2, right: 2, child: _badge(p, destination.badge!)),
        ],
      ),
    );
  }

  Widget _badge(VillagePalette p, int count) {
    return Container(
      constraints: BoxConstraints(minWidth: 18),
      height: 18,
      padding: EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _badgeFill,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontFamily: VillageType.display,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }

  Widget _helpFooter(VillagePalette p, {required bool expanded}) {
    return Container(
      padding: EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onHelp,
          borderRadius: BorderRadius.circular(12),
          hoverColor: _hoverFill,
          child: Padding(
            padding: expanded
                ? EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : EdgeInsets.all(10),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.help_outline,
                  size: 17,
                  color: p.inkMuted,
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  // Flexible, not bare: at 224px the sidebar is narrow
                  // enough that a longer translation of this label would
                  // overflow rather than wrap. Ellipsis beats a yellow
                  // stripe in front of a child.
                  Flexible(
                    child: Text(
                      helpLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: p.inkMuted,
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

  Widget _tabBar(VillagePalette p) {
    return Container(
      height: 78,
      padding: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++)
            _tabItem(p, destinations[i], active: currentIndex == i, index: i),
        ],
      ),
    );
  }

  Widget _tabItem(
    VillagePalette p,
    VillageDestination destination, {
    required bool active,
    required int index,
  }) {
    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: () => onSelect(index),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The pill sits *behind* the icon and above the bar's top edge.
            if (active)
              const Positioned(
                top: -7,
                child: SizedBox(
                  width: 34,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _activeFill,
                      borderRadius: BorderRadius.all(Radius.circular(13)),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                destination.iconAt(23),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? p.quebecBlueBright
                        : p.inkMuted,
                  ),
                ),
              ],
            ),
            if ((destination.badge ?? 0) > 0)
              Positioned(top: -6, right: 4, child: _badge(p, destination.badge!)),
          ],
        ),
      ),
    );
  }
}
