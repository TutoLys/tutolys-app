import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One twinkling four-point star.
@immutable
class Sparkle {
  const Sparkle({
    required this.position,
    required this.size,
    required this.phase,
    this.color = const Color(0xFFFDE68A),
  });

  /// Fractional position inside the painted box, 0..1 on each axis.
  final Offset position;

  /// Radius of the star's longest point, in logical pixels.
  final double size;

  /// Offset into the twinkle cycle, 0..1, so the stars don't blink together.
  final double phase;

  final Color color;

  /// A seeded scatter of [count] sparkles — deterministic, so the same screen
  /// draws the same sky on every launch and in every golden/widget test.
  ///
  /// [avoidCenter] keeps a disc of that fractional radius empty, so a field
  /// laid behind a logo frames it instead of covering it.
  static List<Sparkle> scatter({
    required int count,
    int seed = 7,
    double minSize = 3,
    double maxSize = 7,
    double avoidCenter = 0,
    Color color = const Color(0xFFFDE68A),
  }) {
    final random = math.Random(seed);
    final sparkles = <Sparkle>[];
    while (sparkles.length < count) {
      final p = Offset(random.nextDouble(), random.nextDouble());
      if ((p - const Offset(0.5, 0.5)).distance < avoidCenter) continue;
      sparkles.add(Sparkle(
        position: p,
        size: minSize + random.nextDouble() * (maxSize - minSize),
        phase: random.nextDouble(),
        color: color,
      ));
    }
    return sparkles;
  }
}

/// Paints [sparkles] at cycle position [t] (0..1).
///
/// Each star twinkles twice per cycle — a sharp rise and a long fade, which
/// reads as a glint rather than a blink. At [resting] every star is drawn at
/// a quiet, constant brightness instead: still decorative, never moving.
class SparklePainter extends CustomPainter {
  SparklePainter({
    required this.sparkles,
    required this.t,
    this.resting = false,
  });

  final List<Sparkle> sparkles;
  final double t;
  final bool resting;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final double glint;
      if (resting) {
        glint = 0.45;
      } else {
        final wave = math.sin(2 * math.pi * (t * 2 + s.phase));
        glint = math.pow(math.max(0, wave), 3).toDouble();
      }
      if (glint < 0.02) continue;
      final center = Offset(
        s.position.dx * size.width,
        s.position.dy * size.height,
      );
      _star(canvas, center, s.size * (0.6 + 0.4 * glint), s.color, glint);
    }
  }

  static void _star(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double opacity,
  ) {
    // Soft halo first, then the crisp four-point star on top.
    canvas.drawCircle(
      c,
      r * 1.6,
      Paint()
        ..color = color.withValues(alpha: 0.18 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );
    final w = r * 0.28;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.3, c.dy - w * 0.3, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.3, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.3, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.3, c.dy - w * 0.3, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(SparklePainter old) =>
      old.t != t || old.resting != resting || old.sparkles != sparkles;
}
