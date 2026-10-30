import 'package:flutter/material.dart';

/// A call to action with a trailing arrow, drawn as an icon.
///
/// Baloo 2 has no "→" (U+2192): typed into a label, it fell back to
/// another font, which the web build downloads from the network, so
/// offline it drew a box (UX review, A12).
class ArrowLabel extends StatelessWidget {
  const ArrowLabel(this.label, {required this.style, super.key});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 14) + 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, style: style)),
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Icon(
            Icons.arrow_forward_rounded,
            size: size,
            color: style.color,
          ),
        ),
      ],
    );
  }
}
