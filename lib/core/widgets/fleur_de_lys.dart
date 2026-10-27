import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Québec's fleur-de-lys, drawn in the logo's gold with a thin outline.
///
/// Drawn, not an emoji: ⚜️ falls back to whatever emoji font the platform
/// has, and on several that is a flat monochrome glyph (white on the
/// village sign, pale grey in À propos). Never the Canadian leaf — that is
/// Canada, not Québec.
///
/// [outline] defaults to the palette's Québec blue, the logo's accent; pass
/// a ground-specific colour where blue would vanish (the wooden sign).
class FleurDeLys extends StatelessWidget {
  const FleurDeLys({this.size = 16, this.outline, super.key});

  /// The height. The width is a little less (the drawing's own ratio).
  final double size;
  final Color? outline;

  static const _aspect = 100 / 108;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size * _aspect, size),
        painter: _FleurDeLysPainter(
          outline: outline ?? p.quebecBlue,
          gold: p.gold,
        ),
      ),
    );
  }
}

class _FleurDeLysPainter extends CustomPainter {
  _FleurDeLysPainter({required this.outline, required this.gold});

  final Color outline;
  final Color gold;

  /// The drawing, in a 100 × 108 box: one union, so the outline traces the
  /// silhouette and never the seams between petals.
  static final Path _shape = _build();

  static Path _build() {
    final half = Path()
      // Centre petal, right half.
      ..moveTo(50, 2)
      ..cubicTo(58, 14, 66, 26, 64, 42)
      ..cubicTo(63, 54, 56, 62, 54, 70)
      ..lineTo(50, 70)
      ..close()
      // Side petal, curling back down.
      ..moveTo(53, 70)
      ..cubicTo(58, 54, 70, 40, 84, 42)
      ..cubicTo(96, 44, 100, 58, 93, 68)
      ..cubicTo(89, 74, 81, 73, 80, 67)
      ..cubicTo(79, 62, 84, 59, 87, 62)
      ..cubicTo(88, 56, 82, 52, 75, 55)
      ..cubicTo(67, 59, 61, 66, 59, 72)
      ..close()
      // Stem below the band.
      ..moveTo(50, 80)
      ..lineTo(54, 80)
      ..cubicTo(55, 90, 58, 98, 63, 104)
      ..cubicTo(57, 105, 52, 101, 50, 96)
      ..close()
      // Lower side leaf.
      ..moveTo(56, 80)
      ..cubicTo(66, 81, 74, 87, 75, 98)
      ..cubicTo(71, 93, 65, 91, 60, 93)
      ..cubicTo(59, 88, 58, 84, 56, 80)
      ..close()
      // Band.
      ..addRRect(RRect.fromLTRBR(49, 69, 72, 80, const Radius.circular(4)));
    // x → 100 − x, column-major.
    final mirrored = half.transform(
      Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 100, 0, 0, 1]),
    );
    var shape = Path();
    for (final piece in [half, mirrored]) {
      shape = Path.combine(PathOperation.union, shape, piece);
    }
    return shape;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 108;
    canvas.save();
    canvas.scale(scale);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(gold, Colors.white, 0.18)!,
          gold,
          Color.lerp(gold, Colors.black, 0.25)!,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 108));
    // Drawn under the fill, so half of it shows: about 1 px at icon size,
    // where the gold needs the edge to read on the wooden sign, and about
    // 2 % of the height when large.
    final stroke = (2.0 / scale).clamp(4.0, 16.0);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke
      ..color = outline;
    canvas.drawPath(_shape, line);
    // Fill over the stroke, so the outline never eats the thin petal tips.
    canvas.drawPath(_shape, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FleurDeLysPainter old) =>
      old.outline != outline || old.gold != gold;
}
