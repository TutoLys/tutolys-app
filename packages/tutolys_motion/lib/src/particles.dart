import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

import 'motion_recipes.dart';

/// Whether motion may run here: not when the child (or the OS) asked for
/// less of it, and not behind a hidden `IndexedStack` tab, which keeps
/// tickers alive (CLAUDE.md gotcha). Reading both registers a rebuild
/// dependency, so a widget that checks this stops the moment either flips.
bool motionAllowed(BuildContext context, {bool reducedMotion = false}) =>
    !reducedMotion &&
    !MediaQuery.disableAnimationsOf(context) &&
    Visibility.of(context);

/// Paints one frame of a burst at progress [t] (0..1). Stateless: the
/// renderer owns the controller, so one ticker drives pose and particles.
class ParticlePainter extends CustomPainter {
  ParticlePainter({
    required this.kind,
    required this.t,
    required this.colors,
    this.seed = 0,
  });

  final ParticleKind kind;
  final double t;
  final List<Color> colors;

  /// Varies the layout between bursts without randomness at paint time.
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == ParticleKind.none || t <= 0 || t >= 1 || colors.isEmpty) {
      return;
    }
    switch (kind) {
      case ParticleKind.stars:
        _radial(canvas, size, count: 8, reach: 0.85, radius: 0.09, star: true);
      case ParticleKind.sparkles:
        _radial(canvas, size, count: 4, reach: 0.55, radius: 0.06, star: true);
      case ParticleKind.confetti:
        _confetti(canvas, size);
      case ParticleKind.none:
        break;
    }
  }

  double _jitter(int i) => ((i * 37 + seed * 11) % 10) / 10;

  void _radial(
    Canvas canvas,
    Size size, {
    required int count,
    required double reach,
    required double radius,
    required bool star,
  }) {
    final c = size.center(Offset.zero);
    final ease = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + 0.4 * _jitter(i) + seed;
      final dist = size.shortestSide * reach * ease * (0.7 + 0.3 * _jitter(i));
      final pos = c + Offset(math.cos(angle), math.sin(angle)) * dist;
      final r = size.shortestSide * radius * (1 - 0.4 * t);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (1 - t).clamp(0.0, 1.0),
        );
      canvas.drawPath(starPath(pos, r), paint);
    }
  }

  void _confetti(Canvas canvas, Size size) {
    const count = 26;
    final s = size.shortestSide;
    for (var i = 0; i < count; i++) {
      final j = _jitter(i);
      // Thrown up and out, then falling with a flutter.
      final angle = -math.pi / 2 + (i / count - 0.5) * 2.4 + 0.2 * j;
      final speed = s * (0.9 + 0.6 * j);
      final x = math.cos(angle) * speed * t +
          math.sin(t * 9 + i) * s * 0.04;
      final y = math.sin(angle) * speed * t + s * 1.6 * t * t;
      final pos = size.center(Offset.zero) + Offset(x, y);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (1 - t * t).clamp(0.0, 1.0),
        );
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(t * 8 * (j - 0.5) + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s * 0.06, height: s * 0.1),
          Radius.circular(s * 0.015),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  static Path starPath(Offset o, double r) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + k * math.pi / 5;
      final pt = o + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(ParticlePainter old) =>
      old.t != t || old.kind != kind || old.seed != seed;
}

/// The design's celebration colours, never red (Decision Log).
List<Color> particleColors(BuildContext context) {
  final p = VillagePalette.of(context);
  return [p.gold, p.goldLight, p.quebecBlueBright, p.success];
}

/// "+N XP" floating up from where it's placed, once, then gone.
///
/// Rebuild with a new [key] (or a new [xp]) to pop again. Under reduced
/// motion or a hidden tab it shows the label still for the same time
/// instead of travelling, so the information isn't lost with the motion.
class XpPop extends StatefulWidget {
  const XpPop({
    required this.xp,
    this.duration = const Duration(milliseconds: 1100),
    super.key,
  });

  final int xp;
  final Duration duration;

  @override
  State<XpPop> createState() => _XpPopState();
}

class _XpPopState extends State<XpPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(XpPop old) {
    super.didUpdateWidget(old);
    if (old.xp != widget.xp) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = motionAllowed(context);
    if (!animate) {
      _c.stop();
    } else if (!_c.isAnimating && _c.value < 1) {
      _c.forward();
    }
    final p = VillagePalette.of(context);
    final label = Text(
      '+${widget.xp} XP',
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: p.gold,
        shadows: [Shadow(color: p.surface, blurRadius: 4)],
      ),
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: animate
            ? AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final t = _c.value;
                  return Opacity(
                    opacity: t >= 1 ? 0 : (1 - t * t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -28 * Curves.easeOut.transform(t)),
                      child: Transform.scale(
                        scale: 0.8 + 0.3 * Curves.elasticOut.transform(
                          (t * 2).clamp(0.0, 1.0),
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: label,
              )
            : label,
      ),
    );
  }
}
