import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/kid_avatar.dart';

/// The moment a perfect lesson reveals a rare avatar, on the celebration
/// screen: the avatar pops in, with its name.
///
/// A plain first version. The animations session can replace the entrance
/// with a proper reveal; this only needs to say what was found.
class RareAvatarFound extends StatelessWidget {
  const RareAvatarFound({required this.avatarKey, super.key});

  final String avatarKey;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = VillagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final avatar = KidAvatar(avatarKey: avatarKey, size: 88);
    final caption = t.avatarCaption(avatarKey);
    return Semantics(
      liveRegion: true,
      label: [t.avatarRareFound, t.avatarName(avatarKey), ?caption].join(' '),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('rare-avatar-found'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: Space.sm),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.gold, width: 2),
          ),
          child: Row(
            children: [
              if (still)
                avatar
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: avatar,
                ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.avatarRareFound,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.avatarName(avatarKey),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.inkMuted,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption,
                        style: TextStyle(fontSize: 13, color: p.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
