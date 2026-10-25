import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'village_scene.dart';

/// The design's mobile answer to the village: a horizontal strip of subject
/// tiles instead of the scene.
///
/// The scene places buildings at fixed fractions of a wide canvas. On a
/// phone that canvas is ~390px, so the tiles overlap, their pills collide
/// and the whole thing clips — which is what it did. The design does not
/// scale the scene down; it replaces it, and so does this.
///
/// `.building-scroll .building-tile { width: 98px }` with a 12px gap, from
/// the design's own rules.
class SubjectStrip extends StatelessWidget {
  const SubjectStrip({
    required this.buildings,
    required this.title,
    this.onTapBuilding,
    super.key,
  });

  final List<VillageBuilding> buildings;
  final String title;
  final ValueChanged<VillageBuilding>? onTapBuilding;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: Space.xs),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            itemCount: buildings.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _Tile(
              building: buildings[i],
              palette: p,
              onTap: onTapBuilding == null
                  ? null
                  : () => onTapBuilding!(buildings[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.building, required this.palette, this.onTap});

  final VillageBuilding building;
  final VillagePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = building.progress ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 98,
        child: Column(
          children: [
            // The image takes whatever height the text and bar leave. At its
            // natural size it overflowed the strip by 14px — but only once
            // decoded, so a cold test run (image still 0px tall) never saw it.
            Expanded(
              child: Image.asset(
                'assets/images/${building.asset}',
                width: 98,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              building.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                height: 1.2,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            VillageProgressBar(value: value, height: 6),
            const SizedBox(height: 2),
            Text(
              '${(value * 100).round()} %',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: palette.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
