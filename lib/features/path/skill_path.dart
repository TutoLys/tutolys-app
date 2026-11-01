import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/arrow_label.dart';

import '../../core/widgets/breathing_mascot.dart';
import '../../core/i18n/strings.dart';

/// Where a node sits in a kid's progress through a strand.
/// `completed` is local and immediate (the kid finished it on this device);
/// `mastered` is the server's verdict and outranks it. `locked` waits for
/// the nodes before it; `soon` has no lesson yet and is skipped (ADR 0032).
/// The Carte no longer produces `available` (unlocking is sequential), but
/// the widget still draws it.
enum PathNodeState { mastered, completed, active, available, locked, soon }

/// Whether a node in [state] can be opened at all. `locked` and `soon`
/// can't, and get no tap handler.
bool isOpenState(PathNodeState state) =>
    state != PathNodeState.locked && state != PathNodeState.soon;

/// One stop on the path.
class PathNode {
  const PathNode({
    required this.id,
    required this.label,
    required this.state,
    this.fullStatement,
    this.masteryPct,
    this.otherLanguage,
    this.otherLanguageLabel,
    this.lessons,
    this.lessonsLabel,
    this.stateLabel,
    this.assigned = false,
    this.notDownloaded = false,
  });

  /// Open, but its lesson isn't on the device and the device is offline
  /// (ADR 0095): the orb wears a cloud tag. Never drawn as locked.
  final bool notDownloaded;

  /// A teacher gave this skill as homework and it isn't done yet: the orb
  /// wears a small tag (backend ADR 0123). Never says who else has it.
  final bool assigned;

  final String id;
  final String label;
  final PathNodeState state;

  /// The skill's whole curriculum statement, up to 300 characters: a
  /// screen reader's hint, never its label, so it isn't read on every orb.
  /// Null when [label] already is the whole statement.
  final String? fullStatement;

  /// Set when this node's lesson is in another language than the subject
  /// asked for: `'FR'` for a French lesson in an English-mode maths path.
  /// The backend serves the authored version rather than nothing, so
  /// switching language never empties the map; the app must not pass it off
  /// as translated, so it wears a small language tag.
  final String? otherLanguage;

  /// Read to screen readers with the tag ("Lesson in French").
  final String? otherLanguageLabel;

  /// Lessons finished and in all, for a node with more than one: drawn
  /// under the orb as "2/4". Null for a single-lesson node.
  final (int done, int total)? lessons;

  /// Read to screen readers with the count ("2 of 4 lessons done").
  final String? lessonsLabel;

  /// Why the node can't be played ("Pas encore débloqué", "Bientôt"), read
  /// to screen readers; a `soon` node also shows it under its caption.
  final String? stateLabel;

  /// 0..1 from the backend, shown on the active node's ring and card. Null
  /// when the kid has never played it — which is not the same as zero.
  final double? masteryPct;
}

/// The design's sizes, desktop and phone (`.m-path-card` overrides).
class _Metrics {
  const _Metrics({
    required this.maxWidth,
    required this.orb,
    required this.row,
    required this.topPad,
    required this.capWidth,
    required this.capSize,
    required this.cardWidth,
    required this.cardTop,
    required this.cardPad,
    required this.mascot,
    required this.icon,
    required this.activeIcon,
  });

  final double maxWidth;
  final double orb;
  final double row;
  final double topPad;
  final double capWidth;
  final double capSize;
  final double cardWidth;
  final double cardTop;
  final double cardPad;
  final double mascot;
  final double icon;
  final double activeIcon;

  /// The design gives the active row 150px and lets its card hang over the
  /// next orb. Here the row is as tall as the card needs, so the card never
  /// covers a node a kid might want to tap.
  double get activeRow => cardTop + 128;

  static const wide = _Metrics(
    maxWidth: 380,
    orb: 60,
    row: 104,
    topPad: 16,
    capWidth: 96,
    capSize: 11,
    cardWidth: 208,
    cardTop: 68,
    cardPad: 13,
    mascot: 58,
    icon: 24,
    activeIcon: 26,
  );

  static const compact = _Metrics(
    maxWidth: 280,
    orb: 50,
    row: 86,
    topPad: 10,
    capWidth: 78,
    capSize: 10,
    cardWidth: 180,
    cardTop: 58,
    cardPad: 11,
    mascot: 42,
    icon: 20,
    activeIcon: 22,
  );
}

/// For each connector (node i-1 → node i), whether it is drawn dotted.
/// Solid only between two open nodes, so a line out of an hourglass or a
/// padlock never reads as a road (K10).
List<bool> dottedConnectors(List<PathNode> nodes) => [
  for (var i = 1; i < nodes.length; i++)
    !isOpenState(nodes[i - 1].state) || !isOpenState(nodes[i].state),
];

/// The design's serpentine path.
///
/// Nodes weave across four columns — 50%, 28%, 50%, 72%, repeating — inside a
/// 380px column (280px on a phone). Those are the design's own numbers; the
/// weaving is what makes a strand read as a journey rather than a list.
///
/// Connectors are the design's bezier curves, drawn behind the orbs: solid
/// blue between two open nodes, dotted grey touching a locked or `soon` one, so
/// A caption as a screen reader should say it: no trailing ellipsis.
String spokenName(String label) => label.endsWith('…')
    ? label.substring(0, label.length - 1).trimRight()
    : label;

/// "how far can I go" is legible without reading a label.
///
/// The **active** node carries the "Continuer" card and the fox beside it.
class SkillPath extends StatelessWidget {
  const SkillPath({
    required this.nodes,
    required this.statusLabel,
    required this.continueLabel,
    this.onTapNode,
    this.compact = false,
    this.focusNodeId,
    this.focusKey,
    this.inlineCard = true,
    super.key,
  });

  final List<PathNode> nodes;

  /// Draw the « Continuer » card under the active orb. False on a phone,
  /// where the Carte pins it above the tab bar instead: hung under the orb,
  /// it covered the next node (AM9).
  final bool inlineCard;

  /// The active card's eyebrow, e.g. "En cours · 60 % maîtrisé".
  final String Function(PathNode node) statusLabel;
  final String continueLabel;
  final ValueChanged<PathNode>? onTapNode;

  /// Phone sizing, below `Breakpoints.compact`.
  final bool compact;

  /// The node that gets [focusKey], so the Carte can scroll to it.
  final String? focusNodeId;
  final GlobalKey? focusKey;

  /// `left: 50% / 28% / 50% / 72%`, repeating.
  static const _columns = <double>[0.5, 0.28, 0.5, 0.72];

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final m = compact ? _Metrics.compact : _Metrics.wide;

    final tops = <double>[];
    var y = m.topPad;
    for (final node in nodes) {
      tops.add(y);
      y += node.state == PathNodeState.active && inlineCard
          ? m.activeRow
          : m.row;
    }
    final height = y;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: m.maxWidth),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              double xOf(int i) => w * _columns[i % _columns.length];
              final centres = [
                for (var i = 0; i < nodes.length; i++)
                  Offset(xOf(i), tops[i] + m.orb / 2),
              ];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConnectorPainter(
                        centres: centres,
                        lockedAhead: dottedConnectors(nodes),
                        solid: p.quebecBlueBright,
                        // The design's `--track` itself is invisible on the
                        // pale path card (#E1E9F7 on ~#E6F3FF); a third of
                        // the way to muted ink reads as the faint grey dots
                        // the prototype actually shows.
                        dotted: Color.lerp(p.track, p.inkMuted, 0.35)!,
                      ),
                    ),
                  ),
                  for (var i = 0; i < nodes.length; i++) ...[
                    Positioned(
                      left: xOf(i) - m.capWidth / 2,
                      top: tops[i],
                      width: m.capWidth,
                      child: KeyedSubtree(
                        key: nodes[i].id == focusNodeId ? focusKey : null,
                        child: _Node(
                          node: nodes[i],
                          metrics: m,
                          palette: p,
                          onTap: isOpenState(nodes[i].state)
                              ? () => onTapNode?.call(nodes[i])
                              : null,
                        ),
                      ),
                    ),
                    if (nodes[i].state == PathNodeState.active)
                      _mascotFor(xOf(i), tops[i], w, m),
                    if (nodes[i].state == PathNodeState.active &&
                        inlineCard) ...[
                      Positioned(
                        left: (xOf(i) - m.cardWidth / 2).clamp(
                          0.0,
                          math.max(0.0, w - m.cardWidth),
                        ),
                        top: tops[i] + m.cardTop,
                        width: m.cardWidth,
                        child: ContinueCard(
                          languageTag: nodes[i].otherLanguage,
                          status: statusLabel(nodes[i]),
                          title: nodes[i].label,
                          cta: continueLabel,
                          compact: compact,
                          onTap: () => onTapNode?.call(nodes[i]),
                        ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// `.mascot-hint` sits just left of the active orb. Where a left-hand
  /// column leaves no room for it, it moves to the right rather than off
  /// the card's edge.
  Widget _mascotFor(double x, double top, double w, _Metrics m) {
    // The welcome art is 420x409.
    final foxWidth = m.mascot * 420 / 409;
    const gap = 8.0;
    final leftSide = x - m.orb / 2 - gap - foxWidth;
    final left = leftSide >= 0 ? leftSide : x + m.orb / 2 + gap;
    return Positioned(
      left: left.clamp(0.0, math.max(0.0, w - foxWidth)),
      top: top + 4,
      child: IgnorePointer(
        child: BreathingMascot(height: m.mascot, hoverLift: false),
      ),
    );
  }
}

/// An orb and its caption.
class _Node extends StatelessWidget {
  const _Node({
    required this.node,
    required this.metrics,
    required this.palette,
    this.onTap,
  });

  final PathNode node;
  final _Metrics metrics;
  final VillagePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final p = palette;
    final locked =
        node.state == PathNodeState.locked || node.state == PathNodeState.soon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: !locked,
          // The short label, or the trimmed name without its ellipsis,
          // which read aloud as « …. » before the next part.
          label: [
            spokenName(node.label),
            ?node.otherLanguageLabel,
            ?node.lessonsLabel,
            ?node.stateLabel,
          ].join('. '),
          hint: node.fullStatement,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _Orb(
                key: ValueKey('path-orb-${node.id}'),
                node: node,
                metrics: m,
                palette: p,
                onTap: onTap,
              ),
              if (node.otherLanguage case final tag?)
                Positioned(
                  top: -4,
                  right: -10,
                  child: ExcludeSemantics(
                    child: LanguageTag(tag: tag, palette: p),
                  ),
                ),
              if (node.notDownloaded)
                Positioned(
                  bottom: -4,
                  right: -8,
                  child: ExcludeSemantics(
                    child: NotDownloadedTag(
                      key: ValueKey('not-downloaded-${node.id}'),
                      palette: p,
                    ),
                  ),
                ),
              if (node.assigned && !locked)
                Positioned(
                  top: -8,
                  left: -14,
                  child: ExcludeSemantics(
                    child: HomeworkTag(
                      key: ValueKey('homework-tag-${node.id}'),
                      palette: p,
                    ),
                  ),
                ),
              if (node.state == PathNodeState.soon && node.stateLabel != null)
                Positioned(
                  bottom: -6,
                  left: -12,
                  right: -12,
                  child: Center(
                    child: ExcludeSemantics(
                      child: Container(
                        key: ValueKey('soon-tag-${node.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(color: p.line),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          node.stateLabel!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: p.inkMuted,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (node.lessons case (final done, final total)? when !locked)
                Positioned(
                  bottom: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ExcludeSemantics(
                      child: LessonCountTag(
                        key: ValueKey('lesson-count-${node.id}'),
                        done: done,
                        total: total,
                        palette: p,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        // The orb above already says it, in full: read once, not twice.
        ExcludeSemantics(
          child: Text(
            node.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: m.capSize,
              fontWeight: FontWeight.w700,
              // `.path-node.mastered/.active/.available .cap { color: ink }`
              color: locked ? p.inkMuted : p.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// The orb: a card-coloured disc whose state is carried by its ring, glow
/// and icon — never by a solid fill.
class _Orb extends StatefulWidget {
  const _Orb({
    required this.node,
    super.key,
    required this.metrics,
    required this.palette,
    this.onTap,
  });

  final PathNode node;
  final _Metrics metrics;
  final VillagePalette palette;
  final VoidCallback? onTap;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  /// `pulse-glow 2.2s ease-in-out infinite` on available orbs.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Same two guards as `BreathingMascot`: reduced motion stops it outright,
  /// and so does a hidden tab — `IndexedStack` does not mute tickers.
  void _syncTicker({required bool shouldRun}) {
    if (shouldRun && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!shouldRun && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final m = widget.metrics;
    final p = widget.palette;

    final pulses = node.state == PathNodeState.available;
    _syncTicker(
      shouldRun:
          pulses &&
          !MediaQuery.disableAnimationsOf(context) &&
          Visibility.of(context),
    );

    final ring = switch (node.state) {
      PathNodeState.mastered => p.gold,
      PathNodeState.completed ||
      PathNodeState.active ||
      PathNodeState.available => p.quebecBlueBright,
      PathNodeState.locked ||
      PathNodeState.soon => p.isDark ? VillageDarkColors.lockedRing : p.track,
    };
    final dim =
        node.state == PathNodeState.locked || node.state == PathNodeState.soon;
    final icon = switch (node.state) {
      PathNodeState.mastered => _Check(size: m.icon, color: p.gold),
      // Done here, not yet mastered on the server: the same check, in blue.
      PathNodeState.completed => _Check(
        size: m.icon,
        color: p.quebecBlueBright,
      ),
      PathNodeState.active => _Target(size: m.activeIcon),
      PathNodeState.available => _Target(size: m.activeIcon - 4),
      PathNodeState.locked => Icon(
        Icons.lock_outline_rounded,
        size: m.icon,
        color: p.inkMuted,
      ),
      // No lesson yet: an hourglass, not a lock, so it never reads as the
      // reason the kid is stuck.
      PathNodeState.soon => Icon(
        Icons.hourglass_empty_rounded,
        size: m.icon,
        color: p.inkMuted,
      ),
    };

    final orb = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final shadows = <BoxShadow>[
          // `0 0 0 6px rgba(gold, .14)` / `rgba(blue, .16)` — a flat halo.
          if (node.state == PathNodeState.mastered)
            BoxShadow(color: p.gold.withValues(alpha: 0.14), spreadRadius: 6),
          if (node.state == PathNodeState.active)
            BoxShadow(
              color: p.quebecBlueBright.withValues(alpha: 0.16),
              spreadRadius: 6,
            ),
          // `0 0 0 0 → 0 0 0 9px`, fading .28 → 0, out and back.
          if (pulses && _pulse.isAnimating)
            () {
              final t = Curves.easeInOut.transform(
                1 - (2 * _pulse.value - 1).abs(),
              );
              return BoxShadow(
                color: p.quebecBlueBright.withValues(alpha: 0.28 * (1 - t)),
                spreadRadius: 9 * t,
              );
            }(),
          BoxShadow(
            color: p.shadowSmall,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dim && p.isDark ? VillageDarkColors.lockedFill : p.surface,
            border: Border.all(color: ring, width: 3),
            boxShadow: shadows,
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: m.orb,
        height: m.orb,
        child: Center(child: icon),
      ),
    );

    final progress = node.state == PathNodeState.active
        ? (node.masteryPct ?? 0)
        : 0.0;

    return Opacity(
      // `.path-node.locked .orb { opacity: .5 }`, light only: on navy it
      // left the lock nearly invisible (AM10), so dark has its own colours.
      opacity: dim && !p.isDark ? 0.5 : 1,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: CustomPaint(
            // The active orb's conic arc: how much of this skill is
            // mastered, drawn over the ring from twelve o'clock.
            foregroundPainter: progress > 0
                ? _ArcPainter(fraction: progress, color: p.quebecBlueBright)
                : null,
            child: orb,
          ),
        ),
      ),
    );
  }
}

/// "En cours · 60 % maîtrisé", the skill's name, and the gold CTA. Under
/// the active orb on wide screens; pinned above the tab bar on a phone
/// (AM9).
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    this.languageTag,
    required this.status,
    required this.title,
    required this.cta,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final String? languageTag;
  final String status;
  final String title;
  final String cta;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final metrics = compact ? _Metrics.compact : _Metrics.wide;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: p.quebecBlueBright,
                    ),
                  ),
                ),
                if (languageTag case final tag?) ...[
                  const SizedBox(width: 6),
                  LanguageTag(tag: tag, palette: p),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [p.goldLight, p.gold],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: ArrowLabel(
                          cta,
                          style: const TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Color(0xFF241A04),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's `#i-target`: a red-and-white bullseye.
class _Target extends StatelessWidget {
  const _Target({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _TargetPainter());
}

class _TargetPainter extends CustomPainter {
  static const _red = Color(0xFFEF4444);

  @override
  void paint(Canvas canvas, Size size) {
    // Radii from the symbol's 24-unit viewBox: 9, 6.2, 3.6, 1.3.
    final c = size.center(Offset.zero);
    final u = size.width / 24;
    final fill = Paint();
    canvas
      ..drawCircle(c, 9 * u, fill..color = _red)
      ..drawCircle(c, 6.2 * u, fill..color = Colors.white)
      ..drawCircle(c, 3.6 * u, fill..color = _red)
      ..drawCircle(c, 1.3 * u, fill..color = Colors.white);
  }

  @override
  bool shouldRepaint(_TargetPainter old) => false;
}

/// The design's `#i-check-bold`: `M5 12l4 4 10-10`, stroke 3.
class _Check extends StatelessWidget {
  const _Check({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CheckPainter(color));
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(5 * u, 12 * u)
        ..lineTo(9 * u, 16 * u)
        ..lineTo(19 * u, 6 * u),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

/// `conic-gradient(blue 0 216deg, transparent 216deg)` masked to a 4px band
/// over the ring: the share of the skill already mastered.
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // `inset: -3px`, band 4px wide: centred 1px outside the orb's edge.
    final rect = (Offset.zero & size).inflate(1);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// The design's connectors: `M x1 y1 C x1 midY x2 midY x2 y2`, stroke 3,
/// solid blue into an open node, `stroke-dasharray: 2 8` in track grey into a
/// locked one — round caps turn those dashes into dots.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.centres,
    required this.lockedAhead,
    required this.solid,
    required this.dotted,
  });

  final List<Offset> centres;
  final List<bool> lockedAhead;
  final Color solid;
  final Color dotted;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < centres.length - 1; i++) {
      final a = centres[i];
      final b = centres[i + 1];
      final midY = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final locked = lockedAhead[i];
      final paint = Paint()
        ..color = locked ? dotted : solid
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (!locked) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 2, metric.length)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.centres != centres ||
      old.lockedAhead != lockedAhead ||
      old.solid != solid ||
      old.dotted != dotted;
}

/// A lesson's language, when it is not the one its subject asked for: a
/// small muted pill ("FR"), quiet but never silent (app ADR 0023).
class LanguageTag extends StatelessWidget {
  const LanguageTag({required this.tag, required this.palette, super.key});

  final String tag;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      key: const ValueKey('lesson-language-tag'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: p.inkMuted,
          height: 1.1,
        ),
      ),
    );
  }
}

/// "2/4" under a node's orb: lessons finished out of the node's lessons.
/// Gold once all are done, blue while some are left.
class LessonCountTag extends StatelessWidget {
  const LessonCountTag({
    required this.done,
    required this.total,
    required this.palette,
    super.key,
  });

  final int done;
  final int total;
  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final finished = done >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: finished ? p.gold : p.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$done/$total',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: finished ? p.ink : p.quebecBlueBright,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A cloud on an open leaf whose lesson isn't on the device, offline.
class NotDownloadedTag extends StatelessWidget {
  const NotDownloadedTag({super.key, required this.palette});

  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(color: p.line),
      ),
      child: Icon(Icons.cloud_download_rounded, size: 14, color: p.inkMuted),
    );
  }
}

/// "Devoir": open teacher-assigned work on this skill.
class HomeworkTag extends StatelessWidget {
  const HomeworkTag({super.key, required this.palette});

  final VillagePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: p.goldPale,
        border: Border.all(color: p.gold),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.s.homeworkTag.toUpperCase(),
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: p.ink,
          height: 1.1,
        ),
      ),
    );
  }
}
