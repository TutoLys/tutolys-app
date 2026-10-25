import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'ambient_loop.dart';
import 'sparkle_field.dart';

/// The fleur-de-lys fox emblem, alive: it floats, breathes, glows, catches a
/// glint of light, and has a few sparkles orbiting it.
///
/// Everything runs off one 4.8 s cycle, so the parts stay in step: the glow
/// peaks as the emblem reaches the top of its float, and the shine crosses
/// it once per cycle, on the way up. Under reduced motion it is the same
/// composition standing still — the glow and the sparkles stay, because
/// they are decoration, not motion.
///
/// [size] is the emblem's own box; the glow and sparkles spill outside it,
/// so give it about 30 % breathing room on every side.
class TutolysAnimatedLogo extends StatefulWidget {
  const TutolysAnimatedLogo({required this.size, this.sparkles = true, super.key});

  final double size;

  /// Whether to draw the orbiting sparkles. Off where the logo is small.
  final bool sparkles;

  @override
  State<TutolysAnimatedLogo> createState() => _TutolysAnimatedLogoState();
}

class _TutolysAnimatedLogoState extends AmbientLoopState<TutolysAnimatedLogo> {
  static final _sparkles = Sparkle.scatter(
    count: 12,
    seed: 11,
    avoidCenter: 0.3,
    minSize: 3,
    maxSize: 8,
  );

  @override
  Duration get period => const Duration(milliseconds: 4800);

  @override
  Widget build(BuildContext context) {
    syncLoop(context);
    final size = widget.size;

    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          final t = loopValue;
          final wave = math.sin(2 * math.pi * t); // -1..1, peaks at t = .25
          final float = still ? 0.0 : -size * 0.035 * wave;
          final breathe = still ? 1.0 : 1 + 0.018 * wave;
          final glow = still ? 0.6 : 0.6 + 0.25 * wave;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Glow: a soft gold-and-blue halo behind the emblem.
              Positioned(
                left: -size * 0.3,
                right: -size * 0.3,
                top: -size * 0.3,
                bottom: -size * 0.3,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          VillageColors.goldLight.withValues(alpha: 0.30 * glow),
                          VillageColors.quebecBlueBright
                              .withValues(alpha: 0.22 * glow),
                          VillageColors.quebecBlueBright.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.sparkles)
                Positioned(
                  left: -size * 0.32,
                  right: -size * 0.32,
                  top: -size * 0.32,
                  bottom: -size * 0.32,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: SparklePainter(
                        sparkles: _sparkles,
                        t: t,
                        resting: still,
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, float),
                child: Transform.scale(
                  scale: breathe,
                  child: _Shine(
                    // The glint crosses during the first 40 % of the cycle
                    // and is gone the rest of it — a sweep every few
                    // seconds reads as polish; a constant one as a loader.
                    progress: still ? null : (t / 0.4).clamp(0.0, 1.0),
                    child: Image.asset(
                      'assets/images/asset-logo.webp',
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      semanticLabel: 'TutoLys',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A diagonal band of light that crosses [child] as [progress] goes 0 → 1,
/// painted only where the child is opaque (`srcATop`), so it lights the
/// emblem and never the empty corners of its box.
class _Shine extends StatelessWidget {
  const _Shine({required this.progress, required this.child});

  /// 0 → 1 across the sweep; `null` for no shine at all.
  final double? progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null || p <= 0 || p >= 1) return child;
    // The band's centre travels from well off the left edge to well off the
    // right, so it enters and leaves rather than popping in.
    final centre = -0.6 + 2.2 * p;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [
          (centre - 0.12).clamp(0.0, 1.0),
          centre.clamp(0.0, 1.0),
          (centre + 0.12).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: child,
    );
  }
}
