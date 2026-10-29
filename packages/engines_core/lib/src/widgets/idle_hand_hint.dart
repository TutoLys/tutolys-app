import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A pointing hand over the tile to tap first, for a child who can't read
/// the instruction (UX review G3). It shows after a short wait with
/// nothing touched, taps three times, then rests on the tile, so the
/// screen settles instead of moving forever. Under reduced motion it
/// shows at once, still.
///
/// Decoration only: it lets taps through and says nothing to a screen
/// reader. The shell's instruction line says it in words.
class IdleHandHint extends StatefulWidget {
  const IdleHandHint({required this.show, required this.child, super.key});

  /// Whether the board is still waiting for this first tap.
  final bool show;
  final Widget child;

  /// The idle time before the hand appears.
  static const wait = Duration(milliseconds: 2400);
  static const _bobs = 3;
  static const _bob = Duration(milliseconds: 800);

  @override
  State<IdleHandHint> createState() => _IdleHandHintState();
}

class _IdleHandHintState extends State<IdleHandHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IdleHandHint.wait + IdleHandHint._bob * IdleHandHint._bobs,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(IdleHandHint old) {
    super.didUpdateWidget(old);
    if (old.show != widget.show) _sync();
  }

  void _sync() {
    if (widget.show && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating && _c.value == 0) _c.forward();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack with the child first, so showing or hiding the hand
    // never rebuilds the tile (and never drops its focus).
    if (!widget.show) {
      return Stack(clipBehavior: Clip.none, children: [widget.child]);
    }
    final still = MediaQuery.disableAnimationsOf(context);
    final p = VillagePalette.of(context);
    final waitShare =
        IdleHandHint.wait.inMilliseconds / _c.duration!.inMilliseconds;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          right: 4,
          bottom: -14,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, hand) {
                  if (still) return hand!;
                  final t = _c.value;
                  if (t < waitShare) return const SizedBox.shrink();
                  final bob = (t - waitShare) / (1 - waitShare);
                  final dy = t >= 1
                      ? 0.0
                      : -8 * math.sin(bob * IdleHandHint._bobs * math.pi).abs();
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: hand,
                  );
                },
                child: Icon(
                  Icons.touch_app_rounded,
                  key: const ValueKey('idle-hand'),
                  size: 40,
                  color: p.isDark ? p.quebecBlueBright : p.quebecBlue,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
