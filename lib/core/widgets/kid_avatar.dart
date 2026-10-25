import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../features/profile/avatars.dart';

/// A kid's avatar as the design draws it (`.student-avatar`, `.ph-avatar`):
/// round, a white ring, a small shadow.
///
/// An avatar whose art isn't drawn yet shows a neutral face in its place,
/// so the catalog and picker work before `docs/design/AVATARS.md` is
/// delivered. For the picker, [locked] draws it blurred under a dim veil
/// in the theme's surface colour, so a kid can tell roughly what they're
/// playing towards without seeing it clearly, and [hidden] draws a "?"
/// instead, for a rare avatar not found yet.
class KidAvatar extends StatelessWidget {
  const KidAvatar({
    required this.avatarKey,
    required this.size,
    this.locked = false,
    this.hidden = false,
    super.key,
  });

  final String avatarKey;
  final double size;
  final bool locked;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final asset = avatarFor(avatarKey).asset;
    final ring = size >= 60 ? 3.0 : 2.0;
    final Widget art = hidden
        ? Center(
            child: Text(
              '?',
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.5,
                color: p.inkMuted,
              ),
            ),
          )
        : asset == null
        ? Icon(Icons.face_rounded, size: size * 0.62, color: p.quebecBlue)
        : Image.asset('assets/images/$asset', fit: BoxFit.cover);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.track,
        border: Border.all(color: p.surface, width: ring),
        boxShadow: [
          BoxShadow(
            color: p.shadowSmall,
            blurRadius: size / 6,
            offset: Offset(0, size / 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // A tint keyed to the art's alpha left ragged white edges in the dark
      // theme. A uniform blur and a veil look the same on cut-out art and
      // on scene art, in both themes.
      child: locked && !hidden
          ? Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: size * 0.07,
                    sigmaY: size * 0.07,
                  ),
                  child: art,
                ),
                ColoredBox(color: p.surface.withValues(alpha: 0.55)),
              ],
            )
          : art,
    );
  }
}
