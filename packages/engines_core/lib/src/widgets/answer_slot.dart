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
    super.key,
  });

  /// 1-based position; spoken (via [emptyLabel]), never drawn.
  final int index;

  /// Null when empty.
  final String? label;
  final AnswerTileState state;
  final VoidCallback? onTap;

  /// Semantics for an empty slot, e.g. "case 2, vide".
  final String emptyLabel;
  final String? semanticsState;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text != null) {
      return AnswerTile(
        label: text,
        state: state,
        onTap: onTap,
        semanticsState: semanticsState,
      );
    }
    final p = VillagePalette.of(context);
    return Semantics(
      label: emptyLabel,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: p.track.withValues(alpha: 0.35),
          borderRadius: Radii.cardMd,
          border: Border.all(color: p.line, width: 2),
        ),
        // Deliberately blank: a number here reads as a tile's value in a
        // math exercise ("1", "2"). The position is in the semantics label.
        alignment: Alignment.center,
      ),
    );
  }
}
