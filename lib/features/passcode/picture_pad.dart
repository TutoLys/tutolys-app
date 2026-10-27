import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'passcode_pictures.dart';

/// Three slots and the nine pictures: how a passcode is chosen and entered.
///
/// Presentation only. The parent owns [picked] and decides what a full row
/// means; a picture already picked can't be picked again, since every
/// passcode is three different pictures.
///
/// When [errorTick] changes, the slots give a short shake, so a wrong try
/// reads as "not that" without any red. With reduced motion there is no
/// shake: the message under the pad says it alone.
class PicturePad extends StatelessWidget {
  const PicturePad({
    required this.picked,
    required this.onPick,
    required this.onUndo,
    this.errorTick = 0,
    this.enabled = true,
    super.key,
  });

  final List<int> picked;
  final ValueChanged<int> onPick;
  final VoidCallback onUndo;
  final int errorTick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = math.min(
          112.0,
          (constraints.maxWidth - 2 * Space.sm) / 3,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('passcode-shake-$errorTick'),
              tween: Tween(begin: errorTick == 0 || still ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 420),
              builder: (context, t, child) => Transform.translate(
                offset: Offset(math.sin(t * math.pi * 6) * (1 - t) * 14, 0),
                child: child,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < passcodeLength; i++) ...[
                    if (i > 0) const SizedBox(width: Space.sm),
                    _Slot(
                      position: i + 1,
                      picture: i < picked.length
                          ? passcodePictures[picked[i]]
                          : null,
                      size: tile * 0.62,
                    ),
                  ],
                  const SizedBox(width: Space.sm),
                  IconButton(
                    key: const ValueKey('passcode-undo'),
                    tooltip: s.passcodeUndo,
                    onPressed: enabled && picked.isNotEmpty ? onUndo : null,
                    icon: const Icon(Icons.backspace_outlined),
                    color: p.inkMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final picture in passcodePictures)
                  _PictureTile(
                    picture: picture,
                    size: tile,
                    used: picked.contains(picture.index),
                    onTap: enabled &&
                            picked.length < passcodeLength &&
                            !picked.contains(picture.index)
                        ? () => onPick(picture.index)
                        : null,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.position, required this.picture, required this.size});

  final int position;
  final PasscodePicture? picture;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final s = context.s;
    final filled = picture != null;
    return Semantics(
      label: filled
          ? '${s.passcodeSlot(position)} : ${picture!.name(s)}'
          : s.passcodeSlot(position),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.quick,
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? p.surface : p.track,
          border: Border.all(
            color: filled ? p.quebecBlueBright : p.line,
            width: 2.5,
          ),
        ),
        child: filled
            ? Image.asset(
                picture!.asset,
                key: ValueKey('passcode-slot-$position-${picture!.index}'),
                fit: BoxFit.contain,
              )
            : null,
      ),
    );
  }
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({
    required this.picture,
    required this.size,
    required this.used,
    required this.onTap,
  });

  final PasscodePicture picture;
  final double size;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: used,
      label: picture.name(context.s),
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.quick,
        opacity: used ? 0.35 : 1,
        child: Material(
          color: p.surface,
          elevation: VillageColors.elevationSmall,
          shadowColor: p.shadowSmall,
          borderRadius: VillageMetrics.mdAll,
          child: InkWell(
            key: ValueKey('passcode-picture-${picture.index}'),
            borderRadius: VillageMetrics.mdAll,
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.all(size * 0.14),
                child: Image.asset(picture.asset, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
