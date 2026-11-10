import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';

/// What the scene box shows until the 3D village says it's `ready`: the
/// sky and a light loader, never the 2D village (Hafid, 2026-11-10: the 2D
/// village flashing first, then the 3D one, read as a bug). The 2D village
/// shows only when the 3D one can't run or is off (ADR 0126).
///
/// The scene sends no load progress, so this is a plain loader. Reduced
/// motion: the sky and the words, no spinner. With [loading] false (the
/// native view lifted under a dialog, nothing loading) it's the sky alone.
class VillageSceneLoading extends StatelessWidget {
  const VillageSceneLoading({this.loading = true, super.key});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      key: const ValueKey('village-3d-pending'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ),
      ),
      child: !loading
          ? null
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!still) ...[
                    SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: p.quebecBlueBright,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.s.village3dLoading,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: p.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
