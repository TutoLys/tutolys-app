import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'answer_tile.dart';

/// A place an answer goes — one blank of a built number or sentence
/// (`compose_build`; the design's `.compose-slot`).
///
/// Empty, it is an outlined gap the child fills by choosing a tile; filled,
/// it is an [AnswerTile] that sends the tile back when tapped, unless it
/// has been checked right and locked.
class AnswerSlot extends StatelessWidget {
  const AnswerSlot({
    required this.index,
    required this.label,
    required this.state,
    required this.onTap,
    required this.emptyLabel,
    this.semanticsState,
    this.imageRef,
    this.audioRef,
    this.large = false,
    super.key,
  });

  /// As [AnswerTile.large], so a slot matches the big tiles that fill it
  /// (UX review G14).
  final bool large;

  /// 1-based position; spoken (via [emptyLabel]), never drawn.
  final int index;

  /// Null when empty.
  final String? label;
  final AnswerTileState state;
  final VoidCallback? onTap;

  /// Semantics for an empty slot, e.g. "case 2, vide".
  final String emptyLabel;
  final String? semanticsState;

  /// The placed item's picture, passed on to its [AnswerTile].
  final String? imageRef;

  /// The placed item's recording, passed on to its [AnswerTile].
  final String? audioRef;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text != null) {
      return AnswerTile(
        label: text,
        large: large,
        state: state,
        onTap: onTap,
        semanticsState: semanticsState,
        imageRef: imageRef,
        audioRef: audioRef,
      );
    }
    final p = VillagePalette.of(context);
    return Semantics(
      label: emptyLabel,
      excludeSemantics: true,
      // A dashed 3:1 outline (UX review G11): it reads as a gap to fill,
      // where the old faint fill and `line` border were 1.2:1.
      child: CustomPaint(
        key: const ValueKey('slot-dash'),
        painter: _DashedOutline(color: p.inkMuted),
        child: Container(
          constraints: BoxConstraints(
            minHeight: !large
                ? 52
                : MediaQuery.sizeOf(context).width < Breakpoints.compact
                ? 72
                : 88,
          ),
          decoration: BoxDecoration(
            color: p.track.withValues(alpha: 0.35),
            borderRadius: Radii.cardMd,
          ),
          // Deliberately blank: a number here reads as a tile's value in a
          // math exercise ("1", "2"). The position is in the semantics
          // label.
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outline = Path()
      ..addRRect(Radii.cardMd.toRRect(Offset.zero & size).deflate(1));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) => old.color != color;
}
