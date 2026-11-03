import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shape emoji that carries a colour, drawn by the app instead of a font.
///
/// Flutter web's font fallback can pick a monochrome symbol font for these
/// (Noto Sans Symbols 2 covers U+1F7E0–1F7EB), so « Find blue » showed three
/// identical grey squares (UX review N17). Painting them makes the colour
/// independent of whatever font the platform has.
///
/// Plane figures (▭ △ ◇…) are painted too, for a different reason: Baloo 2,
/// TutolysEmoji and Roboto all lack them, so they drew as boxes on some
/// machines. They carry no colour of their own: [color] is null and they
/// take the text's, so they stay readable in dark mode.
class Swatch {
  const Swatch(this.color, this.shape, {this.outline = false});

  /// A figure in the text's colour.
  const Swatch.figure(this.shape, {this.outline = false}) : color = null;

  final Color? color;
  final SwatchShape shape;

  /// Only the edge is drawn: ▭, against the filled ▬.
  final bool outline;
}

enum SwatchShape {
  square,
  roundedSquare,
  circle,
  star,
  rectangle,
  triangle,
  triangleDown,
  rightTriangle,
  rhombus,
  trapezoid,
  parallelogram,
  pentagon,
  hexagon,
  octagon,
  ellipse,
  die1,
  die2,
  die3,
  die4,
  die5,
  die6,
  tallyFive,
  notEqual,
}

const _black = Color(0xFF26262B);
const _white = Color(0xFFFFFFFF);

/// Every colour-bearing shape emoji the content uses (the backend content
/// tree, 2026-10-31). Colours follow Noto Color Emoji's own palette.
const Map<int, Swatch> swatches = {
  0x1F7E5: Swatch(Color(0xFFE53935), SwatchShape.square), // 🟥
  0x1F7E7: Swatch(Color(0xFFFB8C00), SwatchShape.square), // 🟧
  0x1F7E8: Swatch(Color(0xFFFDD835), SwatchShape.square), // 🟨
  0x1F7E9: Swatch(Color(0xFF43A047), SwatchShape.square), // 🟩
  0x1F7E6: Swatch(Color(0xFF1E88E5), SwatchShape.square), // 🟦
  0x1F7EA: Swatch(Color(0xFF8E24AA), SwatchShape.square), // 🟪
  0x1F7EB: Swatch(Color(0xFF795548), SwatchShape.square), // 🟫
  0x2B1B: Swatch(_black, SwatchShape.square), // ⬛
  0x2B1C: Swatch(_white, SwatchShape.square), // ⬜
  0x1F534: Swatch(Color(0xFFE53935), SwatchShape.circle), // 🔴
  0x1F7E0: Swatch(Color(0xFFFB8C00), SwatchShape.circle), // 🟠
  0x1F7E1: Swatch(Color(0xFFFDD835), SwatchShape.circle), // 🟡
  0x1F7E2: Swatch(Color(0xFF43A047), SwatchShape.circle), // 🟢
  0x1F535: Swatch(Color(0xFF1E88E5), SwatchShape.circle), // 🔵
  0x1F7E3: Swatch(Color(0xFF8E24AA), SwatchShape.circle), // 🟣
  0x1F7E4: Swatch(Color(0xFF795548), SwatchShape.circle), // 🟤
  0x26AB: Swatch(_black, SwatchShape.circle), // ⚫
  0x26AA: Swatch(_white, SwatchShape.circle), // ⚪
  0x2B50: Swatch(Color(0xFFFFC107), SwatchShape.star), // ⭐
  // Plane figures, outlined then filled. The tokens lessons use for real
  // figures: `Platforms/ENGINE_CONTRACTS_GRADES_2_6.md`, « Figures ».
  0x25A1: Swatch.figure(SwatchShape.square, outline: true), // □
  0x25A0: Swatch.figure(SwatchShape.square), // ■
  0x25A2: Swatch.figure(SwatchShape.roundedSquare, outline: true), // ▢
  0x25AD: Swatch.figure(SwatchShape.rectangle, outline: true), // ▭
  0x25AC: Swatch.figure(SwatchShape.rectangle), // ▬
  0x25B3: Swatch.figure(SwatchShape.triangle, outline: true), // △
  0x25B2: Swatch.figure(SwatchShape.triangle), // ▲
  0x25BD: Swatch.figure(SwatchShape.triangleDown, outline: true), // ▽
  0x25BC: Swatch.figure(SwatchShape.triangleDown), // ▼
  0x25FA: Swatch.figure(SwatchShape.rightTriangle, outline: true), // ◺
  0x25E3: Swatch.figure(SwatchShape.rightTriangle), // ◣
  0x25C7: Swatch.figure(SwatchShape.rhombus, outline: true), // ◇
  0x25C6: Swatch.figure(SwatchShape.rhombus), // ◆
  0x25CB: Swatch.figure(SwatchShape.circle, outline: true), // ○
  0x25CF: Swatch.figure(SwatchShape.circle), // ●
  0x2B2D: Swatch.figure(SwatchShape.ellipse, outline: true), // ⬭
  0x2B2C: Swatch.figure(SwatchShape.ellipse), // ⬬
  0x23E2: Swatch.figure(SwatchShape.trapezoid, outline: true), // ⏢
  0x25B1: Swatch.figure(SwatchShape.parallelogram, outline: true), // ▱
  0x25B0: Swatch.figure(SwatchShape.parallelogram), // ▰
  0x2B20: Swatch.figure(SwatchShape.pentagon, outline: true), // ⬠
  0x2B1F: Swatch.figure(SwatchShape.pentagon), // ⬟
  0x2B21: Swatch.figure(SwatchShape.hexagon, outline: true), // ⬡
  0x2B22: Swatch.figure(SwatchShape.hexagon), // ⬢
  0x2BC3: Swatch.figure(SwatchShape.octagon), // ⯃
  // Counting marks: the dots and strokes are what these lessons count, so
  // a missing glyph loses the question itself.
  0x2680: Swatch.figure(SwatchShape.die1), // ⚀
  0x2681: Swatch.figure(SwatchShape.die2), // ⚁
  0x2682: Swatch.figure(SwatchShape.die3), // ⚂
  0x2683: Swatch.figure(SwatchShape.die4), // ⚃
  0x2684: Swatch.figure(SwatchShape.die5), // ⚄
  0x2685: Swatch.figure(SwatchShape.die6), // ⚅
  0x534C: Swatch.figure(SwatchShape.tallyFive, outline: true), // 卌
  0x2260: Swatch.figure(SwatchShape.notEqual, outline: true), // ≠
};

/// The bundled colour emoji font (UX review AM2, ADR 0105): Noto Color
/// Emoji cut to the emoji lessons use. Flutter web's own fallback drew many
/// of them as grey outlines (🐟, 🏖️, 🏫), so counting questions couldn't be
/// answered. A package font, so its registered name carries the prefix.
const emojiFontFamily = 'packages/engines_core/TutolysEmoji';

/// [style] with the colour emoji font as its last fallback. Text glyphs
/// still come from the primary font; only emoji fall through to it.
TextStyle withEmojiFallback(TextStyle? style) {
  final base = style ?? const TextStyle();
  final fallback = base.fontFamilyFallback ?? const <String>[];
  if (fallback.contains(emojiFontFamily)) return base;
  return base.copyWith(fontFamilyFallback: [...fallback, emojiFontFamily]);
}

/// Whether [text] is only pictures (emoji), with no letters or digits, so
/// it can be drawn at picture size.
bool isPictureOnly(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  // 卌 is a letter to Unicode, but a painted mark here.
  final unpainted = String.fromCharCodes(
    t.runes.where((r) => !swatches.containsKey(r)),
  );
  return !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(unpainted);
}

/// Whether [text] holds at least one painted swatch.
bool hasSwatch(String text) => text.runes.any(swatches.containsKey);

/// A drop-in for [Text] on content strings: swatch emoji are painted,
/// other emoji come from the bundled colour font, the rest is ordinary
/// text. With no swatch in [data] it *is* a plain [Text].
/// The screen-reader name stays the original string.
class SwatchText extends StatelessWidget {
  const SwatchText(
    this.data, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final style = withEmojiFallback(this.style);
    if (!hasSwatch(data)) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
      );
    }
    final inherited = DefaultTextStyle.of(context).style;
    final size = style.fontSize ?? inherited.fontSize ?? 14;
    final ink = style.color ?? inherited.color ?? _black;
    final spans = <InlineSpan>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      spans.add(TextSpan(text: buf.toString()));
      buf.clear();
    }

    final runes = data.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final r = runes[i];
      final s = swatches[r];
      if (s == null) {
        // A variation selector after a painted swatch has nothing to modify.
        if (r == 0xFE0F && i > 0 && swatches.containsKey(runes[i - 1])) {
          continue;
        }
        buf.writeCharCode(r);
        continue;
      }
      flush();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SwatchMark(swatch: s, size: size * 1.05, ink: ink),
        ),
      );
    }
    flush();
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      semanticsLabel: data,
    );
  }
}

/// One painted swatch, [size] square, with a thin edge so white reads on
/// white and black reads in dark mode. A figure takes [ink], the text's
/// colour.
class SwatchMark extends StatelessWidget {
  const SwatchMark({
    required this.swatch,
    required this.size,
    this.ink = _black,
    super.key,
  });
  final Swatch swatch;
  final double size;
  final Color ink;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SwatchPainter(swatch, ink)),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.swatch, this.ink);
  final Swatch swatch;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.08;
    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final pips = _pips(swatch.shape);
    if (pips != null) {
      final frame = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.16));
      canvas.drawRRect(
        frame,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.07).clamp(1.2, 4.0),
      );
      final dot = Paint()..color = ink;
      for (final (x, y) in pips) {
        canvas.drawCircle(
          Offset(r.left + r.width * x, r.top + r.height * y),
          r.width * 0.095,
          dot,
        );
      }
      return;
    }
    final path = _path(r);
    final colour = swatch.color;
    if (colour == null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = (size.width * 0.09).clamp(1.5, 5.0)
          ..style = swatch.outline ? PaintingStyle.stroke : PaintingStyle.fill,
      );
      return;
    }
    final fill = Paint()..color = colour;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.05).clamp(1.0, 3.0)
      ..color = const Color(0x55000000);
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, edge);
  }

  /// A die face's dots, as fractions of its box; null for anything else.
  static List<(double, double)>? _pips(SwatchShape shape) {
    const a = 0.27, m = 0.5, z = 0.73;
    return switch (shape) {
      SwatchShape.die1 => const [(m, m)],
      SwatchShape.die2 => const [(a, a), (z, z)],
      SwatchShape.die3 => const [(a, a), (m, m), (z, z)],
      SwatchShape.die4 => const [(a, a), (z, a), (a, z), (z, z)],
      SwatchShape.die5 => const [(a, a), (z, a), (m, m), (a, z), (z, z)],
      SwatchShape.die6 => const [
        (a, a),
        (z, a),
        (a, m),
        (z, m),
        (a, z),
        (z, z),
      ],
      _ => null,
    };
  }

  Path _path(Rect r) {
    final w = r.width;
    final h = r.height;
    // A wide figure sits in the middle of the square box.
    final wide = Rect.fromCenter(center: r.center, width: w, height: h * 0.62);
    Path poly(List<Offset> points) => Path()..addPolygon(points, true);
    return switch (swatch.shape) {
      SwatchShape.square =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            r,
            Radius.circular(swatch.color == null ? 0 : w * 0.14),
          ),
        ),
      SwatchShape.roundedSquare =>
        Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(w * 0.18))),
      SwatchShape.circle => Path()..addOval(r),
      SwatchShape.ellipse => Path()..addOval(wide),
      SwatchShape.star => _star(r),
      SwatchShape.rectangle => Path()..addRect(wide),
      SwatchShape.triangle => poly([r.topCenter, r.bottomRight, r.bottomLeft]),
      SwatchShape.triangleDown => poly([r.topLeft, r.topRight, r.bottomCenter]),
      SwatchShape.rightTriangle => poly([
        r.topLeft,
        r.bottomRight,
        r.bottomLeft,
      ]),
      SwatchShape.rhombus => poly([
        r.topCenter,
        r.centerRight,
        r.bottomCenter,
        r.centerLeft,
      ]),
      SwatchShape.trapezoid => poly([
        wide.topLeft + Offset(w * 0.22, 0),
        wide.topRight - Offset(w * 0.22, 0),
        wide.bottomRight,
        wide.bottomLeft,
      ]),
      SwatchShape.parallelogram => poly([
        wide.topLeft + Offset(w * 0.25, 0),
        wide.topRight,
        wide.bottomRight - Offset(w * 0.25, 0),
        wide.bottomLeft,
      ]),
      SwatchShape.pentagon => _regular(r, 5, -math.pi / 2),
      SwatchShape.hexagon => _regular(r, 6, -math.pi / 2),
      SwatchShape.octagon => _regular(r, 8, -math.pi / 2 + math.pi / 8),
      SwatchShape.tallyFive => _tally(r),
      SwatchShape.notEqual => _notEqual(r),
      // Drawn from _pips in paint.
      SwatchShape.die1 ||
      SwatchShape.die2 ||
      SwatchShape.die3 ||
      SwatchShape.die4 ||
      SwatchShape.die5 ||
      SwatchShape.die6 => Path(),
    };
  }

  /// Four strokes and the fifth across them.
  Path _tally(Rect r) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final x = r.left + r.width * (0.2 + i * 0.2);
      path
        ..moveTo(x, r.top + r.height * 0.08)
        ..lineTo(x, r.bottom - r.height * 0.08);
    }
    return path
      ..moveTo(r.left, r.bottom - r.height * 0.2)
      ..lineTo(r.right, r.top + r.height * 0.2);
  }

  Path _notEqual(Rect r) {
    final path = Path();
    for (final y in [0.36, 0.64]) {
      path
        ..moveTo(r.left + r.width * 0.1, r.top + r.height * y)
        ..lineTo(r.right - r.width * 0.1, r.top + r.height * y);
    }
    return path
      ..moveTo(r.left + r.width * 0.7, r.top + r.height * 0.1)
      ..lineTo(r.left + r.width * 0.3, r.bottom - r.height * 0.1);
  }

  Path _regular(Rect r, int sides, double start) => Path()
    ..addPolygon([
      for (var i = 0; i < sides; i++)
        r.center +
            Offset(
              r.width / 2 * math.cos(start + i * 2 * math.pi / sides),
              r.height / 2 * math.sin(start + i * 2 * math.pi / sides),
            ),
    ], true);

  Path _star(Rect r) {
    final c = r.center;
    final outer = r.width / 2;
    final inner = outer * 0.45;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(rad * math.cos(a), rad * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.swatch != swatch || old.ink != ink;
}
