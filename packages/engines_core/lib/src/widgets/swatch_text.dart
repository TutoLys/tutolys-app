import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shape emoji that carries a colour, drawn by the app instead of a font.
///
/// Flutter web's font fallback can pick a monochrome symbol font for these
/// (Noto Sans Symbols 2 covers U+1F7E0–1F7EB), so « Find blue » showed three
/// identical grey squares (UX review N17). Painting them makes the colour
/// independent of whatever font the platform has.
class Swatch {
  const Swatch(this.color, this.shape);
  final Color color;
  final SwatchShape shape;
}

enum SwatchShape { square, circle, star }

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
};

/// Whether [text] holds at least one painted swatch.
bool hasSwatch(String text) => text.runes.any(swatches.containsKey);

/// A drop-in for [Text] on content strings: swatch emoji are painted, the
/// rest is ordinary text. With no swatch in [data] it *is* a plain [Text].
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
    final size =
        (style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14);
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
          child: SwatchMark(swatch: s, size: size * 1.05),
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
/// white and black reads in dark mode.
class SwatchMark extends StatelessWidget {
  const SwatchMark({required this.swatch, required this.size, super.key});
  final Swatch swatch;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SwatchPainter(swatch)),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.swatch);
  final Swatch swatch;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.08;
    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final fill = Paint()..color = swatch.color;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.05).clamp(1.0, 3.0)
      ..color = const Color(0x55000000);
    final Path path = switch (swatch.shape) {
      SwatchShape.square =>
        Path()..addRRect(
          RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.14)),
        ),
      SwatchShape.circle => Path()..addOval(r),
      SwatchShape.star => _star(r),
    };
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, edge);
  }

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
  bool shouldRepaint(_SwatchPainter old) => old.swatch != swatch;
}
