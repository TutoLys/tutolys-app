import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// What the mascot is currently doing. Engines drive this through the feedback
/// helpers so every engine reacts the same way to the same outcome.
enum MascotMood { idle, thinking, correct, incorrect, celebrating, hint }

/// Placeholder arctic fox.
///
/// The Phase 0 audit found the fox exists only as a *reference photograph* in
/// the design system, while the shipped games carried a different mascot
/// entirely. Until real art exists this draws a simple vector fox, so layout,
/// sizing and reaction timing can be built and reviewed now and the artwork
/// can be swapped in without touching call sites.
///
/// Deliberately geometric rather than cute-by-accident: a half-finished
/// cartoon reads as worse than a clean shape, and the brand must not look
/// generic.
class TutolysMascot extends StatefulWidget {
  const TutolysMascot({
    this.mood = MascotMood.idle,
    this.size = 96,
    super.key,
  });

  final MascotMood mood;
  final double size;

  @override
  State<TutolysMascot> createState() => _TutolysMascotState();
}

class _TutolysMascotState extends State<TutolysMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One long-running controller drives a gentle idle breath; mood changes
    // read off its value rather than spawning more controllers.
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithMotionPreference();
  }

  /// Honour the platform's reduce-motion setting.
  ///
  /// Two reasons this matters, and the second is easy to miss:
  ///
  /// 1. Accessibility. A continuously breathing character is exactly what
  ///    reduce-motion exists to stop, and some children are motion-sensitive.
  /// 2. Testability. An animation that repeats forever means `pumpAndSettle`
  ///    never settles, so every widget test touching a screen with the mascot
  ///    would hang. Respecting the flag makes the whole app testable.
  void _syncWithMotionPreference() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      _controller
        ..stop()
        // Mid-point, so the fox sits at a natural resting size rather than
        // the extreme of its breath.
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;

    final accent = switch (widget.mood) {
      MascotMood.correct || MascotMood.celebrating => extras.success,
      // Amber, never red: a wrong answer is "almost" (the design's
      // decision log), never a fault.
      MascotMood.incorrect => VillagePalette.of(context).retry,
      MascotMood.thinking || MascotMood.hint => extras.gold,
      MascotMood.idle => context.colors.primary,
    };

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final breath = math.sin(_controller.value * math.pi) * 0.02;
        final tilt = switch (widget.mood) {
          MascotMood.thinking => 0.12,
          // Opposite lean from `thinking`: a glance toward something, not a
          // ponder — the two should never read as the same pose.
          MascotMood.hint => -0.18,
          MascotMood.incorrect => -0.08,
          MascotMood.celebrating => breath * 4,
          _ => 0.0,
        };

        return Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scale: 1 + breath,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _FoxPainter(
                accent: accent,
                mood: widget.mood,
                surface: context.colors.surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FoxPainter extends CustomPainter {
  _FoxPainter({
    required this.accent,
    required this.mood,
    required this.surface,
  });

  final Color accent;
  final MascotMood mood;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeJoin = StrokeJoin.round;

    // Ears
    final leftEar = Path()
      ..moveTo(w * 0.22, h * 0.34)
      ..lineTo(w * 0.16, h * 0.08)
      ..lineTo(w * 0.42, h * 0.22)
      ..close();
    final rightEar = Path()
      ..moveTo(w * 0.78, h * 0.34)
      ..lineTo(w * 0.84, h * 0.08)
      ..lineTo(w * 0.58, h * 0.22)
      ..close();

    canvas
      ..drawPath(leftEar, body)
      ..drawPath(leftEar, stroke)
      ..drawPath(rightEar, body)
      ..drawPath(rightEar, stroke);

    // Head
    final head = Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * 0.08, h * 0.72, w * 0.12, h * 0.26, w * 0.5, h * 0.24)
      ..cubicTo(w * 0.88, h * 0.26, w * 0.92, h * 0.72, w * 0.5, h * 0.92)
      ..close();

    canvas
      ..drawPath(head, body)
      ..drawPath(head, stroke);

    // Eyes. Closed when celebrating, which reads as delight rather than
    // surprise, and avoids the dead-eyed look of two static dots.
    final eyePaint = Paint()..color = TutolysColors.darkBackground;
    final eyeY = h * 0.5;
    final eyeR = w * 0.055;

    if (mood == MascotMood.celebrating) {
      final lid = Paint()
        ..color = TutolysColors.darkBackground
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;
      _drawClosedEyes(canvas, w, eyeY, eyeR, lid);
    } else {
      for (final dx in [0.36, 0.64]) {
        canvas.drawCircle(Offset(w * dx, eyeY), eyeR, eyePaint);
      }
    }

    // Snout
    canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * 0.05, eyePaint);

    // A gold cheek flash when something went right.
    if (mood == MascotMood.correct || mood == MascotMood.celebrating) {
      final blush = Paint()..color = accent.withValues(alpha: 0.35);
      canvas
        ..drawCircle(Offset(w * 0.26, h * 0.62), w * 0.06, blush)
        ..drawCircle(Offset(w * 0.74, h * 0.62), w * 0.06, blush);
    }
  }

  void _drawClosedEyes(Canvas canvas, double w, double y, double r, Paint lid) {
    for (final dx in [0.36, 0.64]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * dx, y), radius: r * 1.6),
        0.15,
        math.pi - 0.3,
        false,
        lid,
      );
    }
  }

  @override
  bool shouldRepaint(_FoxPainter old) =>
      old.accent != accent || old.mood != mood || old.surface != surface;
}
