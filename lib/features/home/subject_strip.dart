import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'village_scene.dart';

/// The design's mobile answer to the village: the subject tiles instead of
/// the scene.
///
/// The scene places buildings at fixed fractions of a wide canvas. On a
/// phone that canvas is ~390px, so the tiles overlap, their pills collide
/// and the whole thing clips — which is what it did. The design does not
/// scale the scene down; it replaces it, and so does this.
///
/// A grid, three across (two on the narrowest phones), not a strip: the
/// horizontal strip showed exactly three of six subjects with nothing
/// peeking out, so a child never found the rest (UX review A7). No fixed
/// height either, so scaled text grows the tile instead of clipping (A14).
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

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: Space.xs),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth < 300 ? 2 : 3;
            final width = (box.maxWidth - _gap * (columns - 1)) / columns;
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final b in buildings)
                    SizedBox(
                      width: width,
                      child: _Tile(
                        building: b,
                        palette: p,
                        width: width,
                        onTap: onTapBuilding == null || !b.live
                            ? null
                            : () => onTapBuilding!(b),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.building,
    required this.palette,
    required this.width,
    this.onTap,
  });

  final VillageBuilding building;
  final VillagePalette palette;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = building.progress;

    final tile = GestureDetector(
      // The whole tile takes the tap: deferring to the art missed whenever
      // it hadn't decoded (`f59975f`).
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            // A fixed box from the art's aspect: the tile's height never
            // waits for the image to decode.
            VillageBuildingArt(building: building, width: width * 0.8),
            const SizedBox(height: 5),
            Text(
              building.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.2,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            if (!building.measured)
              const SizedBox.shrink()
            else if (!building.live || !building.hasLessons) ...[
              ComingSoonTag(key: ValueKey('strip-soon-${building.subject}')),
              const SizedBox(height: 4),
            ] else if (value == null)
              // A8: nothing measured yet is not 0 %: a child reads that as
              // failing. Same rule as everywhere else, unknown is not zero.
              Text(
                context.s.pathNotStarted,
                key: ValueKey('strip-new-${building.subject}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.quebecBlueBright,
                ),
              )
            else ...[
              VillageProgressBar(value: value, height: 6),
              const SizedBox(height: 2),
              Text(
                '${(value * 100).round()} %',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (building.live) {
      return Semantics(
        key: ValueKey('strip-building-${building.subject}'),
        button: true,
        label: building.label,
        child: tile,
      );
    }
    final soon = context.s.villageSubjectSoon(building.label);
    return Tooltip(
      message: soon,
      child: Semantics(
        label: soon,
        child: ExcludeSemantics(child: tile),
      ),
    );
  }
}
