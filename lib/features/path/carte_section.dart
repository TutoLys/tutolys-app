import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';
import 'carte_model.dart';
import 'skill_path.dart';

/// One section of the Carte that rolls up (ADR 0124): a header that is the
/// tap target, and under it the path.
///
/// Closing, the path rolls up from its last orb, each orb shrinking as the
/// edge reaches it, while the header's mini trail pops in dot by dot.
/// Opening plays that in reverse. A closed section builds no path at all,
/// so its orbs are out of the tab order and a long subject stays cheap.
/// Instant under reduced motion. Nothing waits on the motion: a tap during
/// it just turns it around.
class CarteSection extends StatefulWidget {
  const CarteSection({
    required this.section,
    required this.title,
    required this.open,
    required this.holdsNext,
    required this.compact,
    required this.pathHeight,
    required this.onToggle,
    required this.onSettled,
    required this.path,
    super.key,
  });

  final PathSection section;
  final String title;
  final bool open;

  /// The kid's next lesson is in here: the fox points at it while closed.
  final bool holdsNext;
  final bool compact;

  /// The path's full height, from [SkillPath.heightOf].
  final double pathHeight;
  final VoidCallback onToggle;

  /// The motion ended, with the section open or not.
  final ValueChanged<bool> onSettled;

  /// The path, given how far down it is showing, for [SkillPath.revealedTo].
  final Widget Function(ValueListenable<double> revealedTo) path;

  @override
  State<CarteSection> createState() => _CarteSectionState();
}

class _CarteSectionState extends State<CarteSection>
    with SingleTickerProviderStateMixin {
  /// Past this, the rest of a long path goes by in the motion's last beat,
  /// so what the kid can see always gets most of the time.
  static const _sweep = 900.0;
  static const _gap = 10.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
    value: widget.open ? 1 : 0,
  )..addStatusListener(_onStatus);

  late final _roll = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  final _revealed = ValueNotifier<double>(double.infinity);

  EdgeInsets get _pad => widget.compact
      ? const EdgeInsets.fromLTRB(6, 6, 6, 22)
      : const EdgeInsets.fromLTRB(10, 10, 10, 30);

  double get _fullHeight => widget.pathHeight + _pad.vertical + _gap;

  /// How much of the card shows at [t].
  double _shown(double t) {
    final full = _fullHeight;
    final sweep = math.min(full, _sweep);
    return sweep * t + (full - sweep) * math.pow(t, 6);
  }

  @override
  void initState() {
    super.initState();
    _roll.addListener(_track);
  }

  void _track() {
    _revealed.value = _c.isCompleted
        ? double.infinity
        : _shown(_roll.value) - _gap - _pad.top;
  }

  void _onStatus(AnimationStatus status) {
    if (status.isAnimating || !mounted) return;
    widget.onSettled(status.isCompleted);
  }

  @override
  void didUpdateWidget(CarteSection old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _c.dispose();
    _revealed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            section: widget.section,
            title: widget.title,
            open: widget.open,
            holdsNext: widget.holdsNext,
            progress: _c.value,
            onTap: widget.onToggle,
          ),
          if (!_c.isDismissed)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              // Orbs and the fox may overhang the card once it's still.
              clipBehavior: _c.isCompleted ? Clip.none : Clip.antiAlias,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _c.isCompleted
                    ? 1
                    : (_shown(_roll.value) / _fullHeight).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: _gap),
                  // `.path-card`
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: p.isDark ? 0.25 : 0.4),
                      border: Border.all(
                        color: p.surface.withValues(
                          alpha: p.isDark ? 0.35 : 0.6,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: _pad,
                      child: widget.path(_revealed),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.title,
    required this.open,
    required this.holdsNext,
    required this.progress,
    required this.onTap,
  });

  final PathSection section;
  final String title;
  final bool open;
  final bool holdsNext;

  /// 1 open, 0 closed.
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final done = section.finishedCount;
    final total = section.nodes.length;
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: open,
        label: '$title, ${t.carteSectionSpoken(done, total)}',
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('carte-section-${section.key}'),
            hoverColor: p.navHoverFill,
            focusColor: p.navHoverFill,
            onTap: onTap,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VillageType.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.2,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  t.carteSectionProgress(done, total),
                                  key: ValueKey(
                                    'carte-section-count-${section.key}',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: p.inkMuted,
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                Flexible(
                                  child: _Trail(
                                    done: done,
                                    total: total,
                                    holdsNext: holdsNext,
                                    progress: progress,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (holdsNext && progress < 1)
                        Padding(
                          padding: const EdgeInsets.only(left: Space.xs),
                          child: Opacity(
                            opacity: 1 - progress,
                            child: const BreathingMascot(
                              key: ValueKey('carte-section-fox'),
                              height: 36,
                              hoverLift: false,
                            ),
                          ),
                        ),
                      const SizedBox(width: Space.xs),
                      _Chevron(progress: progress),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: p.track),
      child: Transform.rotate(
        // The overshoot is the spring.
        angle: math.pi * Curves.easeOutBack.transform(progress),
        child: Icon(
          Icons.expand_more_rounded,
          size: 24,
          color: p.quebecBlueBright,
        ),
      ),
    );
  }
}

/// A closed section's path in miniature: the orbs that tucked in, in order,
/// the last orb first. A long section samples its progress over the dots.
class _Trail extends StatelessWidget {
  const _Trail({
    required this.done,
    required this.total,
    required this.holdsNext,
    required this.progress,
  });

  static const _most = 8;
  static const _dot = 9.0;

  final int done;
  final int total;
  final bool holdsNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final n = math.min(total, _most);
    final filled = trailFilled(done: done, total: total, dots: n);
    return ExcludeSemantics(
      child: Wrap(
        key: const ValueKey('carte-section-trail'),
        spacing: 3,
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < n; i++)
            Transform.scale(
              scale: _pop(i, n),
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled
                      ? p.quebecBlueBright
                      : i == filled && holdsNext
                      ? p.gold
                      : p.track,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Each dot's own beat, the last dot first, as the orbs roll up.
  double _pop(int i, int n) {
    final start = n < 2 ? 0.0 : (n - 1 - i) / (n - 1) * 0.6;
    final beat = ((1 - progress - start) / 0.4).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(beat);
  }
}

/// How many of [dots] show as done: never all until all are, and at least
/// one once any is.
@visibleForTesting
int trailFilled({required int done, required int total, required int dots}) {
  if (total == 0 || done == 0) return 0;
  if (done >= total) return dots;
  return (done * dots / total).round().clamp(1, math.max(1, dots - 1));
}
