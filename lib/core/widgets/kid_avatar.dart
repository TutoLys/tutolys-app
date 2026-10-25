import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../features/profile/avatars.dart';

/// A kid's avatar as the design draws it (`.student-avatar`, `.ph-avatar`):
/// round, a white ring, a small shadow.
///
/// An avatar whose art isn't drawn yet shows a neutral face in its place,
/// so the catalog and picker work before `docs/design/AVATARS.md` is
/// delivered. For the picker, [locked] draws it as a dark silhouette (the
/// shape still reads, so a kid sees what they're playing towards) and
/// [hidden] draws a "?" instead, for a rare avatar not found yet.
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
      child: locked && !hidden
          // srcATop keeps the art's own alpha, so the figure keeps its
          // outline; 15% of the art shows through.
          ? ColorFiltered(
              colorFilter: ColorFilter.mode(
                p.ink.withValues(alpha: 0.85),
                BlendMode.srcATop,
              ),
              child: art,
            )
          : art,
    );
  }
}
