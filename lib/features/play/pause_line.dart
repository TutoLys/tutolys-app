import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// « Une pause ? » on the celebration, past the session length a guardian
/// set. A suggestion, not a limit: the buttons below it stay as they are.
class PauseLine extends StatelessWidget {
  const PauseLine({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Padding(
      key: const ValueKey('pause-line'),
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_outlined, size: 18, color: p.inkMuted),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              context.s.pauseSuggestion,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: p.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
