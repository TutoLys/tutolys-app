import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'ambient_loop.dart';
import 'sparkle_field.dart';

/// The night-blue sky behind the loader and the welcome screen: a gradient
/// whose light source drifts slowly, a soft aurora of Quebec blue, and a
/// field of tiny twinkling stars.
///
/// [dawn] bends the bottom of the gradient into the village's own pale sky
/// (`VillageColors.skyTop`), which is how the welcome screen hands over to
/// the Village without a colour jump. The loader stays night.
class LaunchBackdrop extends StatefulWidget {
  const LaunchBackdrop({required this.child, this.dawn = false, super.key});

  final Widget child;
  final bool dawn;

  /// The loader's flat ground colour. `web/index.html` paints the same value
  /// before Flutter starts, so the hand-over has no flash.
  static const Color night = Color(0xFF1F3C88);
  static const Color deepNight = Color(0xFF142A66);

  @override
  State<LaunchBackdrop> createState() => _LaunchBackdropState();
}

class _LaunchBackdropState extends AmbientLoopState<LaunchBackdrop> {
  static final _stars = [
    ...Sparkle.scatter(
      count: 22,
      seed: 3,
      minSize: 1.5,
      maxSize: 3.2,
      color: Colors.white,
    ),
    ...Sparkle.scatter(count: 8, seed: 5, minSize: 2.5, maxSize: 4.5),
  ];

  @override
  Duration get period => const Duration(seconds: 14);

  @override
  Widget build(BuildContext context) {
    syncLoop(context);

    final background = AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loopValue;
        final angle = 2 * math.pi * t;
        // The aurora drifts on a slow ellipse — far too slow to watch, just
        // enough that the sky never looks like a flat fill.
        final aurora = Alignment(0.35 * math.cos(angle), -0.55 + 0.12 * math.sin(angle));
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.dawn
                      ? const [
                          LaunchBackdrop.deepNight,
                          LaunchBackdrop.night,
                          VillageColors.quebecBlueBright,
                          VillageColors.skyTop,
                        ]
                      : const [
                          LaunchBackdrop.deepNight,
                          LaunchBackdrop.night,
                          LaunchBackdrop.night,
                          LaunchBackdrop.deepNight,
                        ],
                  stops: widget.dawn
                      ? const [0.0, 0.35, 0.72, 1.0]
                      : const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: aurora,
                  radius: 0.9,
                  colors: [
                    VillageColors.quebecBlueBright.withValues(alpha: 0.38),
                    VillageColors.quebecBlueBright.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            CustomPaint(
              painter: SparklePainter(
                sparkles: _stars,
                // Twinkle faster than the drift: the stars share the cycle
                // but run it several times over.
                t: (t * 5) % 1,
                resting: still,
              ),
            ),
          ],
        );
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: background),
        widget.child,
      ],
    );
  }
}

/// "TutoLys" set in Baloo 2: "Tuto" in white, "Lys" in gold, the way the
/// emblem pairs the white fox with its gold lily.
class TutolysWordmark extends StatelessWidget {
  const TutolysWordmark({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1.0,
      letterSpacing: -0.5,
      shadows: [
        Shadow(
          color: const Color(0xFF0B1A45).withValues(alpha: 0.55),
          offset: Offset(0, fontSize * 0.06),
          blurRadius: fontSize * 0.18,
        ),
      ],
    );
    return Semantics(
      label: 'TutoLys',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Tuto', style: base.copyWith(color: Colors.white)),
            TextSpan(
              text: 'Lys',
              style: base.copyWith(
                foreground: Paint()
                  ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [VillageColors.goldPale, VillageColors.goldLight, VillageColors.gold],
                  ).createShader(Rect.fromLTWH(0, 0, fontSize * 1.6, fontSize)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
