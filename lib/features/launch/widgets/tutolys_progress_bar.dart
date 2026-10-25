import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'ambient_loop.dart';

/// The launch progress bar: a glossy rounded pill with a blue → cyan fill, a
/// gold glint sweeping through the filled part and a glowing tip.
///
/// [value] is real progress (0..1), and the fill **only ever moves forward**:
/// a lower value than the one already shown is ignored rather than drawn as
/// the bar shrinking, because a child reads a bar going backwards as
/// something going wrong. Changes are eased over 600 ms so step-wise
/// milestones still read as one smooth fill.
///
/// Reduced motion: the fill jumps to each new value and the glint and pulse
/// stop; the bar itself still reports progress, which is information, not
/// decoration.
class TutolysProgressBar extends StatefulWidget {
  const TutolysProgressBar({
    required this.value,
    this.height = 14,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double height;

  /// Read by screen readers alongside the percentage.
  final String? semanticLabel;

  @override
  State<TutolysProgressBar> createState() => _TutolysProgressBarState();
}

class _TutolysProgressBarState extends AmbientLoopState<TutolysProgressBar> {
  static const _fillDuration = Duration(milliseconds: 600);

  /// The furthest value shown so far — the forward-only floor.
  double _shown = 0;

  @override
  Duration get period => const Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _shown = widget.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(TutolysProgressBar old) {
    super.didUpdateWidget(old);
    _shown = math.max(_shown, widget.value.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    syncLoop(context);
    final h = widget.height;
    final radius = BorderRadius.circular(h);

    return Semantics(
      label: widget.semanticLabel,
      value: '${(_shown * 100).round()} %',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _shown),
        duration: still ? Duration.zero : _fillDuration,
        curve: Curves.easeOutCubic,
        builder: (context, fill, _) {
          return AnimatedBuilder(
            animation: loop,
            builder: (context, _) {
              final t = loopValue;
              final pulse = still ? 0.5 : 0.5 + 0.5 * math.sin(2 * math.pi * t);
              return Container(
                height: h,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // The channel: a deep inset navy with a hairline rim, so
                  // the bar reads as a groove the light fills.
                  color: const Color(0xFF14295F),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8)
                          .withValues(alpha: 0.18 + 0.17 * pulse),
                      blurRadius: 14 + 8 * pulse,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fill,
                      heightFactor: 1,
                      child: _Fill(t: t, still: still, height: h),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.t, required this.still, required this.height});

  final double t;
  final bool still;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Quebec blue → bright blue → cyan.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: const LinearGradient(
              colors: [
                VillageColors.quebecBlueBright,
                Color(0xFF3B9BFF),
                Color(0xFF38D5F8),
              ],
            ),
          ),
        ),
        // Gloss: the upper half catches the light.
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.5,
            widthFactor: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: height * 0.35),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // The gold glint, sweeping left to right through the fill.
        if (!still)
          LayoutBuilder(
            builder: (context, box) {
              final band = math.max(28.0, box.maxWidth * 0.22);
              final x = -band + (box.maxWidth + band) * Curves.easeInOut.transform(t);
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 0,
                    bottom: 0,
                    width: band,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            VillageColors.goldPale.withValues(alpha: 0),
                            VillageColors.goldPale.withValues(alpha: 0.75),
                            VillageColors.goldPale.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        // A glowing gold tip at the leading edge.
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: height * 0.7,
            height: height * 0.7,
            margin: EdgeInsets.only(right: height * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VillageColors.goldPale,
              boxShadow: [
                BoxShadow(
                  color: VillageColors.goldLight.withValues(alpha: 0.9),
                  blurRadius: height * 0.8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
