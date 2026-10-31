import 'package:flutter/material.dart';

/// How a choice question lays out its answers (UX review AM3).
///
/// Two or three short answers with no picture (« 1 · 3 · 2 », « 20 °C »)
/// are a row of big square tiles; four are a 2 × 2 grid. Anything else is
/// the list, one tile per row. [tile] builds one answer; `square` says
/// which layout it's in.
class ChoiceLayout extends StatelessWidget {
  const ChoiceLayout({
    required this.ids,
    required this.labelOf,
    required this.tile,
    this.hasPicture,
    super.key,
  });

  final List<String> ids;
  final String Function(String id) labelOf;
  final Widget Function(String id, {required bool square}) tile;

  /// Whether an answer has a picture (`image_ref`); such a list stays a list.
  final bool Function(String id)? hasPicture;

  /// The longest label that still reads as one big number or word.
  static const shortLabel = 6;

  /// Whether [ids] go in square tiles.
  bool get squares =>
      ids.length >= 2 &&
      ids.length <= 4 &&
      ids.every(
        (id) =>
            labelOf(id).trim().length <= shortLabel &&
            !(hasPicture?.call(id) ?? false),
      );

  @override
  Widget build(BuildContext context) {
    if (!squares) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, id) in ids.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            tile(id, square: false),
          ],
        ],
      );
    }
    final perRow = ids.length == 4 ? 2 : ids.length;
    final rows = [
      for (var i = 0; i < ids.length; i += perRow)
        ids.sublist(i, (i + perRow).clamp(0, ids.length)),
    ];
    return Column(
      key: const ValueKey('choice-squares'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, id) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: AspectRatio(
                    // A 2 × 2 grid is wider than tall, so it keeps the
                    // whole question on a phone screen.
                    aspectRatio: perRow == 2 ? 1.5 : 1,
                    child: tile(id, square: true),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
