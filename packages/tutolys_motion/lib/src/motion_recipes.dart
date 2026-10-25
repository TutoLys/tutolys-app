import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'reaction.dart';

/// Where a still image sits on one frame: offset, tilt and squash, all
/// relative to its resting pose. [MotionPose.rest] is the reduced-motion
/// frame for every reaction.
class MotionPose {
  const MotionPose({
    this.dy = 0,
    this.dx = 0,
    this.turns = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  static const rest = MotionPose();

  /// Fractions of the character's size, so a 56px header fox and a 150px
  /// celebration fox move alike.
  final double dy;
  final double dx;

  /// Rotation, in turns (1 = 360°).
  final double turns;
  final double scaleX;
  final double scaleY;
}

/// The effect a reaction throws off when it starts.
enum ParticleKind { none, stars, confetti, sparkles }

/// How a bitmap renderer moves a still image for one reaction.
///
/// Two layers. A [loop] runs as long as the reaction holds (breathing,
/// a thinking tilt); a [oneShot] plays once when the reaction is cued (a
/// hop, a sway) and then hands back to the loop. Pure functions of time,
/// so every frame is testable without a ticker.
///
/// This is the replaceable part. A Rive character ignores all of it — its
/// state machine is the motion — and an artist who delivers a dedicated
/// pose image still gets this motion on top unless the manifest says
/// otherwise.
class MotionRecipe {
  const MotionRecipe({
    required this.loopPeriod,
    required this.loop,
    this.oneShotDuration = Duration.zero,
    this.oneShot,
    this.particles = ParticleKind.none,
  });

  final Duration loopPeriod;

  /// [t] in 0..1, repeating.
  final MotionPose Function(double t) loop;

  final Duration oneShotDuration;

  /// [t] in 0..1, once. Null = no one-shot.
  final MotionPose Function(double t)? oneShot;

  final ParticleKind particles;

  /// The default recipe for every reaction. A manifest can't change these
  /// yet; when one needs to, a renderer takes its own table.
  static MotionRecipe of(Reaction r) => switch (r) {
    Reaction.idle => _breathe,
    Reaction.waiting || Reaction.sleeping => _slowBreathe,
    Reaction.thinking ||
    Reaction.curious ||
    Reaction.listening => _thinking,
    Reaction.speaking => _speaking,
    Reaction.explaining => _hint,
    Reaction.encouraging => _presque,
    Reaction.celebrating => _hop,
    Reaction.victory => _victory,
  };
}

double _wave(double t) => math.sin(t * 2 * math.pi);

MotionPose _breatheAt(double t, {double depth = 0.035}) {
  // Eased so it slows at each end: breathing, not sliding.
  final e = Curves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
  return MotionPose(dy: -depth * e, scaleY: 1 + 0.02 * e);
}

final _breathe = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 3000),
  loop: _breatheAt,
);

final _slowBreathe = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 4800),
  loop: (t) => _breatheAt(t, depth: 0.02),
);

/// A slow head tilt, side to side: "hmm".
final _thinking = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 2400),
  loop: (t) => MotionPose(turns: 0.012 * _wave(t), dy: -0.01),
);

/// A quick nod while the question is read.
final _speaking = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 520),
  loop: (t) => MotionPose(dy: -0.02 * (0.5 - 0.5 * math.cos(t * 2 * math.pi))),
);

/// A hint: lean in and nod once, with a few sparkles.
final _hint = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 3000),
  loop: _breatheAt,
  oneShotDuration: const Duration(milliseconds: 700),
  oneShot: (t) {
    final lean = math.sin(t * math.pi);
    return MotionPose(turns: -0.02 * lean, dx: 0.04 * lean, dy: -0.03 * lean);
  },
  particles: ParticleKind.sparkles,
);

/// "Presque": a gentle, damped sway — never a "no" head-shake, never red.
final _presque = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 3000),
  loop: _breatheAt,
  oneShotDuration: const Duration(milliseconds: 800),
  oneShot: (t) => MotionPose(turns: 0.018 * math.sin(t * 3 * math.pi) * (1 - t)),
);

MotionPose _hopAt(double t, {double height = 0.22}) {
  // Crouch, jump, land with a squash.
  if (t < 0.15) {
    final c = t / 0.15;
    return MotionPose(scaleY: 1 - 0.08 * c, scaleX: 1 + 0.05 * c);
  }
  if (t < 0.8) {
    final a = (t - 0.15) / 0.65;
    return MotionPose(
      dy: -height * math.sin(a * math.pi),
      scaleY: 1 + 0.05 * math.sin(a * math.pi),
      scaleX: 1 - 0.03 * math.sin(a * math.pi),
    );
  }
  final l = (t - 0.8) / 0.2;
  final squash = math.sin(l * math.pi);
  return MotionPose(scaleY: 1 - 0.06 * squash, scaleX: 1 + 0.04 * squash);
}

final _hop = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 3000),
  loop: _breatheAt,
  oneShotDuration: const Duration(milliseconds: 650),
  oneShot: _hopAt,
  particles: ParticleKind.stars,
);

/// Two hops, a little wiggle at the top of the second, and confetti.
final _victory = MotionRecipe(
  loopPeriod: const Duration(milliseconds: 3000),
  loop: _breatheAt,
  oneShotDuration: const Duration(milliseconds: 1400),
  oneShot: (t) {
    if (t < 0.45) return _hopAt(t / 0.45, height: 0.16);
    final p = _hopAt((t - 0.45) / 0.55, height: 0.26);
    final a = (t - 0.45) / 0.55;
    return MotionPose(
      dy: p.dy,
      scaleX: p.scaleX,
      scaleY: p.scaleY,
      turns: 0.02 * math.sin(a * 4 * math.pi) * math.sin(a * math.pi),
    );
  },
  particles: ParticleKind.confetti,
);
