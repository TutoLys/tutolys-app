import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

enum SkyTask { dayNight, seasons, moon }

/// Angles are degrees, counter-clockwise, 0 pointing right (the far side
/// from the Sun, which is always on the left). Every body turns
/// counter-clockwise seen from above the North Pole, as the real ones do.
abstract final class SkyAngles {
  /// Where each target sits, by task.
  static const targets = {
    SkyTask.dayNight: {
      'noon': 180,
      'midnight': 0,
      'sunrise': 90,
      'sunset': 270,
      // Day and night are halves, not points: see [inside].
      'day': 180,
      'night': 0,
    },
    // The axis leans to the right. The North Pole leans toward the Sun
    // when the Earth is left of it: northern summer.
    SkyTask.seasons: {'winter': 0, 'spring': 90, 'summer': 180, 'fall': 270},
    SkyTask.moon: {
      'new': 180,
      'first_quarter': 270,
      'full': 0,
      'last_quarter': 90,
    },
  };

  /// How far inside a half day or night must be, so the edge of the
  /// terminator never counts.
  static const halfMargin = 15;

  static int norm(int a) => ((a % 360) + 360) % 360;

  static int distance(int a, int b) {
    final d = (norm(a) - norm(b)).abs();
    return math.min(d, 360 - d);
  }

  /// Whether [angle] meets [target] for [task].
  static bool inside(SkyTask task, String target, int angle, int tolerance) {
    final centre = targets[task]![target]!;
    final half =
        task == SkyTask.dayNight && (target == 'day' || target == 'night');
    return distance(angle, centre) <= (half ? 90 - halfMargin : tolerance);
  }
}

class SkyNearMiss {
  const SkyNearMiss({required this.at, required this.diagnosis});

  /// Another target of the same task the child reached instead.
  final String at;
  final ErrorClassification diagnosis;
}

class SkyContent {
  const SkyContent({
    required this.task,
    required this.target,
    required this.start,
    this.tolerance = 25,
    this.town = 'Québec',
    this.nearMisses = const [],
  });

  final SkyTask task;
  final String target;
  final int start;
  final int tolerance;

  /// day_night: the marked town's name.
  final String town;
  final List<SkyNearMiss> nearMisses;
}

class SkyState {
  const SkyState({
    required this.angle,
    this.moved = false,
    this.solved = false,
  });
  final int angle;

  /// VALIDER waits for the child to have moved something.
  final bool moved;
  final bool solved;

  SkyState copyWith({int? angle, bool? moved, bool? solved}) => SkyState(
    angle: angle ?? this.angle,
    moved: moved ?? this.moved,
    solved: solved ?? this.solved,
  );
}

sealed class SkyAction {
  const SkyAction();
}

/// Put the body at an angle (a drag).
class SetSkyAngle extends SkyAction {
  const SetSkyAngle(this.angle);
  final int angle;
}

/// Turn by a step (the ↺ ↻ buttons).
class NudgeSky extends SkyAction {
  const NudgeSky(this.delta);
  final int delta;
}

/// "Le Soleil, la Terre et la Lune" — the `sky_model` engine (app ADR
/// 0086; requested by the Questions Maker for strand 2).
///
/// A model of the sky drawn in code, the Sun always on the left:
/// - `day_night`: the Earth seen from above the North Pole, a marked
///   town on its edge. Turn it so the town is in day or night, or at
///   noon, midnight, sunrise or sunset.
/// - `seasons`: the Earth on its orbit, its axis always leaning the same
///   way. Move it to a season (for Québec, in the north).
/// - `moon`: the Moon on its orbit round the Earth, with how it looks from
///   the Earth beside it. Move it to a phase.
///
/// Graded on the final angle against the target within `tolerance`
/// degrees; day and night are halves, and count once well inside. A
/// declared near miss (the full moon for the new moon) names the
/// confusion.
class SkyModelEngine
    implements LearningEngine<SkyContent, SkyState, SkyAction, BlanksAnswer> {
  const SkyModelEngine();

  static const key = 'sky_model';
  static const step = 15;

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // The ↺ ↻ buttons do everything a drag does, and the model speaks
    // where things are after every move.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static const _tasks = {
    'day_night': SkyTask.dayNight,
    'seasons': SkyTask.seasons,
    'moon': SkyTask.moon,
  };

  @override
  ParseResult<SkyContent> parse(Map<String, Object?> config) {
    final task = _tasks[config['task']];
    if (task == null) {
      return const ParseResult.invalid('task is day_night, seasons or moon.');
    }
    final names = SkyAngles.targets[task]!.keys;
    final target = config['target'];
    if (target is! String || !names.contains(target)) {
      return ParseResult.invalid(
        'target for this task is ${names.join(', ')}.',
      );
    }
    final tolerance = config['tolerance'] ?? 25;
    if (tolerance is! int || tolerance < 10 || tolerance > 45) {
      return const ParseResult.invalid('tolerance is 10 to 45 degrees.');
    }
    final start = config['start'] ?? 0;
    if (start is! int || start < 0 || start > 359) {
      return const ParseResult.invalid('start is 0 to 359 degrees.');
    }
    if (SkyAngles.inside(task, target, start, tolerance)) {
      return const ParseResult.invalid(
        'start already meets the target: there is nothing to do.',
      );
    }
    final town = config['town'] ?? 'Québec';
    if (town is! String || town.trim().isEmpty || town.length > 20) {
      return const ParseResult.invalid('town is 1 to 20 characters.');
    }
    if (task != SkyTask.dayNight && config.containsKey('town')) {
      return const ParseResult.invalid('town is for day_night.');
    }
    final rawMisses = config['near_misses'] ?? const [];
    if (rawMisses is! List) {
      return const ParseResult.invalid('near_misses is a list.');
    }
    final misses = <SkyNearMiss>[];
    for (final m in rawMisses) {
      final at = m is Map ? m['at'] : null;
      final diag = m is Map ? m['diagnosis'] : null;
      final code = diag is Map ? diag['code'] : null;
      final version = diag is Map ? diag['taxonomy_version'] : null;
      if (at is! String ||
          !names.contains(at) ||
          at == target ||
          code is! String ||
          code.isEmpty ||
          version is! int) {
        return const ParseResult.invalid(
          'A near_miss is {at: another target, diagnosis: {code, '
          'taxonomy_version}}.',
        );
      }
      misses.add(
        SkyNearMiss(
          at: at,
          diagnosis: ErrorClassification(code: code, taxonomyVersion: version),
        ),
      );
    }
    return ParseResult.ok(
      SkyContent(
        task: task,
        target: target,
        start: start,
        tolerance: tolerance,
        town: town,
        nearMisses: List.unmodifiable(misses),
      ),
    );
  }

  @override
  SkyState initialize(SkyContent content, EngineSeed seed) =>
      SkyState(angle: content.start);

  @override
  Transition<SkyState> reduce(SkyState s, SkyAction action) {
    if (s.solved) return Transition(s);
    final angle = switch (action) {
      SetSkyAngle(:final angle) => SkyAngles.norm(angle),
      NudgeSky(:final delta) => SkyAngles.norm(s.angle + delta),
    };
    if (angle == s.angle) return Transition(s);
    return Transition(s.copyWith(angle: angle, moved: true), [
      InteractionEvent('item_placed', {'item_id': 'angle', 'value': angle}),
    ]);
  }

  @override
  BlanksAnswer? extractAnswer(SkyState s) =>
      !s.moved || s.solved ? null : BlanksAnswer({'angle': '${s.angle}'});

  @override
  SkyState applyFeedback(SkyState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    return s.copyWith(solved: result.outcome == Outcome.correct);
  }

  @override
  Map<String, Object?> snapshot(SkyState s) => {
    'angle': s.angle,
    'moved': s.moved,
    'solved': s.solved,
  };

  @override
  SkyState? restore(SkyContent content, Map<String, Object?> snap) {
    final angle = snap['angle'];
    if (angle is! int || angle < 0 || angle > 359) return null;
    final solved = snap['solved'] == true;
    if (solved &&
        !SkyAngles.inside(
          content.task,
          content.target,
          angle,
          content.tolerance,
        )) {
      return null;
    }
    return SkyState(angle: angle, moved: snap['moved'] == true, solved: solved);
  }

  /// "à gauche", "en haut à droite": where an angle points, for speech.
  static String direction(int angle, bool fr) {
    const fr8 = [
      'à droite',
      'en haut à droite',
      'en haut',
      'en haut à gauche',
      'à gauche',
      'en bas à gauche',
      'en bas',
      'en bas à droite',
    ];
    const en8 = [
      'to the right',
      'up and to the right',
      'at the top',
      'up and to the left',
      'to the left',
      'down and to the left',
      'at the bottom',
      'down and to the right',
    ];
    final i = ((SkyAngles.norm(angle) + 22) ~/ 45) % 8;
    return (fr ? fr8 : en8)[i];
  }

  static String describe(SkyContent c, int angle, bool fr) {
    switch (c.task) {
      case SkyTask.dayNight:
        final day = SkyAngles.distance(angle, 180) < 90;
        final edge = SkyAngles.distance(angle, 90) <= 20
            ? (fr ? ', au lever du Soleil' : ', at sunrise')
            : SkyAngles.distance(angle, 270) <= 20
            ? (fr ? ', au coucher du Soleil' : ', at sunset')
            : '';
        return fr
            ? '${c.town} est du côté ${day ? 'éclairé, le jour' : 'sombre, la nuit'}$edge.'
            : '${c.town} is on the ${day ? 'lit side, in daytime' : 'dark side, at night'}$edge.';
      case SkyTask.seasons:
        return fr
            ? 'La Terre est ${direction(angle, fr)} du Soleil. Son axe penche toujours vers la droite.'
            : 'The Earth is ${direction(angle, fr)} of the Sun. Its axis always leans right.';
      case SkyTask.moon:
        return fr
            ? 'La Lune est ${direction(angle, fr)} de la Terre. Le Soleil est à gauche.'
            : 'The Moon is ${direction(angle, fr)} of the Earth. The Sun is on the left.';
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<SkyContent, SkyState, SkyAction> view,
  ) => _SkyView(view: view);
}

class _SkyView extends StatefulWidget {
  const _SkyView({required this.view});
  final EngineView<SkyContent, SkyState, SkyAction> view;

  static const _squash = 0.42;

  static Offset _centre(SkyTask task, Size size) => switch (task) {
    // The Sun sits at the left edge; the Earth in the middle.
    SkyTask.dayNight => Offset(size.width * 0.6, size.height / 2),
    SkyTask.seasons => Offset(size.width / 2, size.height / 2),
    SkyTask.moon => Offset(size.width * 0.58, size.height / 2),
  };

  @override
  State<_SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<_SkyView> {
  /// Where the finger was, as an angle round the Earth, so a drag turns it
  /// by what the finger swept. Kept here: the view rebuilds mid-drag.
  double _dragFrom = 0;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final p = VillagePalette.of(context);
    final open = view.enabled && !s.solved;

    final model = AspectRatio(
      aspectRatio: 1.5,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final centre = _SkyView._centre(c.task, size);
          void at(Offset local) {
            final v = local - centre;
            // The seasons orbit is a flattened ellipse: undo the squash.
            final dy = c.task == SkyTask.seasons
                ? v.dy / _SkyView._squash
                : v.dy;
            final a = (math.atan2(-dy, v.dx) * 180 / math.pi).round();
            view.dispatch(SetSkyAngle(a));
          }

          return GestureDetector(
            key: const ValueKey('sky-model'),
            onPanStart: open
                ? (d) {
                    final v = d.localPosition - centre;
                    _dragFrom = math.atan2(-v.dy, v.dx);
                    if (c.task != SkyTask.dayNight) at(d.localPosition);
                  }
                : null,
            onPanUpdate: open
                ? (d) {
                    if (c.task != SkyTask.dayNight) {
                      at(d.localPosition);
                      return;
                    }
                    // The Earth turns with the finger, by the angle swept.
                    final v = d.localPosition - centre;
                    final now = math.atan2(-v.dy, v.dx);
                    var swept = (now - _dragFrom) * 180 / math.pi;
                    // Crossing the left side jumps atan2 by a whole turn.
                    if (swept > 180) swept -= 360;
                    if (swept < -180) swept += 360;
                    if (swept.abs() >= 1) {
                      view.dispatch(SetSkyAngle(s.angle + swept.round()));
                      _dragFrom = now;
                    }
                  }
                : null,
            child: Semantics(
              label: SkyModelEngine.describe(c, s.angle, fr),
              liveRegion: true,
              excludeSemantics: true,
              child: CustomPaint(
                painter: _SkyPainter(c, s.angle, p, solved: s.solved),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );

    Widget turn(int delta, IconData icon, String tip, String key) =>
        IconButton.filledTonal(
          key: ValueKey(key),
          tooltip: tip,
          onPressed: open ? () => view.dispatch(NudgeSky(delta)) : null,
          icon: Icon(icon),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(borderRadius: Radii.cardMd, child: model),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Counter-clockwise is the way every body really turns.
                turn(
                  SkyModelEngine.step,
                  Icons.rotate_left_rounded,
                  fr
                      ? 'Tourner dans le sens des vrais mouvements'
                      : 'Turn the way it really turns',
                  'sky-forward',
                ),
                const SizedBox(width: 24),
                turn(
                  -SkyModelEngine.step,
                  Icons.rotate_right_rounded,
                  fr ? 'Revenir en arrière' : 'Turn back',
                  'sky-back',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.c, this.angle, this.p, {required this.solved});
  final SkyContent c;
  final int angle;
  final VillagePalette p;
  final bool solved;

  static const _space = Color(0xFF14204A);
  static const _sun = Color(0xFFF5C02B);
  static const _ocean = Color(0xFF2F6FDE);
  static const _land = Color(0xFF2FA35A);
  static const _moon = Color(0xFFD9D9D9);
  static const _night = Color(0xCC0A1030);

  static Offset _polar(
    Offset centre,
    double r,
    num degrees, [
    double squash = 1,
  ]) {
    final a = degrees * math.pi / 180;
    return centre + Offset(math.cos(a) * r, -math.sin(a) * r * squash);
  }

  /// A body lit from [sunDir] (degrees): the far half in shadow.
  void _lit(Canvas canvas, Offset at, double r, Color base, double sunDir) {
    canvas.drawCircle(at, r, Paint()..color = base);
    final rect = Rect.fromCircle(center: at, radius: r);
    final start = -(sunDir + 90) * math.pi / 180;
    canvas.drawArc(rect, start, -math.pi, true, Paint()..color = _night);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _space);
    final w = size.width;
    final h = size.height;
    final stars = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset((i * 97 % 100) / 100 * w, (i * 57 % 100) / 100 * h),
        (i % 3) * 0.5 + 0.6,
        stars,
      );
    }
    final rim = Paint()
      ..color = solved ? p.success : Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (c.task) {
      case SkyTask.dayNight:
        final sunAt = Offset(-w * 0.05, h / 2);
        canvas.drawCircle(sunAt, h * 0.42, Paint()..color = _sun);
        final rays = Paint()
          ..color = _sun.withValues(alpha: 0.5)
          ..strokeWidth = 3;
        for (final dy in [-0.3, -0.1, 0.1, 0.3]) {
          canvas.drawLine(
            Offset(w * 0.4, h * (0.5 + dy)),
            Offset(w * 0.6 - h * 0.36, h * (0.5 + dy)),
            rays,
          );
        }
        final at = Offset(w * 0.6, h / 2);
        final r = h * 0.34;
        canvas.drawCircle(at, r, Paint()..color = _ocean);
        // Land turns with the Earth, so the turning is visible.
        for (final (offset, size) in [(40, 0.32), (150, 0.26), (250, 0.3)]) {
          canvas.drawCircle(
            _polar(at, r * 0.55, angle + offset),
            r * size,
            Paint()..color = _land,
          );
        }
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)))
          // Night: the half away from the Sun (on the left).
          ..drawRect(
            Rect.fromLTRB(at.dx, at.dy - r, at.dx + r, at.dy + r),
            Paint()..color = _night,
          )
          ..restore()
          ..drawCircle(at, r, rim)
          ..drawCircle(at, 5, Paint()..color = Colors.white);
        final town = _polar(at, r, angle);
        canvas.drawCircle(town, 9, Paint()..color = const Color(0xFFE5484D));
        canvas.drawCircle(
          town,
          9,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        _label(canvas, c.town, _polar(at, r + 22, angle), Colors.white);
      case SkyTask.seasons:
        final sunAt = Offset(w / 2, h / 2);
        final a = w * 0.38;
        canvas.drawOval(
          Rect.fromCenter(
            center: sunAt,
            width: a * 2,
            height: a * 2 * _SkyView._squash,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final earth = _polar(sunAt, a, angle, _SkyView._squash);
        final behind = math.sin(angle * math.pi / 180) > 0;
        void drawEarth() {
          final r = h * 0.09;
          final toSun = sunAt - earth;
          _lit(
            canvas,
            earth,
            r,
            _ocean,
            math.atan2(-toSun.dy, toSun.dx) * 180 / math.pi,
          );
          canvas.drawCircle(earth, r, rim);
          // The axis leans right by 23°, always.
          final tilt = 23 * math.pi / 180;
          final dir = Offset(math.sin(tilt), -math.cos(tilt)) * (r * 1.6);
          canvas.drawLine(
            earth - dir,
            earth + dir,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 2.5,
          );
          _label(canvas, 'N', earth + dir * 1.25, Colors.white);
        }

        // Behind the Sun is drawn first, so the Sun hides it a little.
        if (behind) drawEarth();
        canvas.drawCircle(sunAt, h * 0.14, Paint()..color = _sun);
        if (!behind) drawEarth();
      case SkyTask.moon:
        final sunAt = Offset(-w * 0.12, h / 2);
        canvas.drawCircle(sunAt, h * 0.3, Paint()..color = _sun);
        final at = Offset(w * 0.58, h / 2);
        final orbit = h * 0.36;
        canvas.drawCircle(
          at,
          orbit,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _lit(canvas, at, h * 0.12, _ocean, 180);
        canvas.drawCircle(at, h * 0.12, rim);
        final moon = _polar(at, orbit, angle);
        _lit(canvas, moon, h * 0.06, _moon, 180);
        canvas.drawCircle(moon, h * 0.06, rim);
        // How it looks from the Earth, in the corner.
        final inset = Offset(w * 0.86, h * 0.17);
        final ir = h * 0.08;
        _phase(canvas, inset, ir, angle);
        _label(
          canvas,
          'Vue de la Terre',
          inset + Offset(0, ir + 14),
          Colors.white,
          size: 11,
        );
    }
  }

  /// The Moon as seen from the Earth: lit fraction and side from where
  /// it is on its orbit (the Sun on the left).
  void _phase(Canvas canvas, Offset at, double r, int moonAngle) {
    canvas.drawCircle(at, r, Paint()..color = const Color(0xFF3A3F55));
    // Elongation: 0 at new moon, 180 at full.
    final e = SkyAngles.distance(moonAngle, 180) * math.pi / 180;
    // Waxing (lit on the right) from new to full, the way it turns.
    final side = SkyAngles.norm(moonAngle) > 180 ? 1.0 : -1.0;
    final path = Path();
    const n = 24;
    for (var i = 0; i <= n; i++) {
      final t = -1 + 2 * i / n;
      final x = side * r * math.sqrt(1 - t * t);
      final pt = at + Offset(x, r * t);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    for (var i = n; i >= 0; i--) {
      final t = -1 + 2 * i / n;
      final x = side * r * math.cos(e) * math.sqrt(1 - t * t);
      path.lineTo(at.dx + x, at.dy + r * t);
    }
    canvas
      ..drawPath(path..close(), Paint()..color = _moon)
      ..drawCircle(
        at,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    double size = 13,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w800,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.angle != angle || old.solved != solved || old.c != c || old.p != p;
}

/// Grades the final angle against the target. A wrong angle that sits at
/// a declared near miss's target carries its diagnosis.
class SkyModelEvaluator implements Evaluator<SkyContent, BlanksAnswer> {
  const SkyModelEvaluator();

  @override
  String get engineKey => SkyModelEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    SkyContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final angle = int.tryParse(answer.blanks['angle'] ?? '');
    if (angle == null) throw ArgumentError('An answer is an angle.');
    final right = SkyAngles.inside(
      content.task,
      content.target,
      angle,
      content.tolerance,
    );
    ErrorClassification? miss;
    if (!right) {
      for (final m in content.nearMisses) {
        if (SkyAngles.inside(content.task, m.at, angle, content.tolerance)) {
          miss = m.diagnosis;
          break;
        }
      }
    }
    return EvaluationResult(
      outcome: right ? Outcome.correct : Outcome.incorrect,
      score: right ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: {'target': right},
      errors: right
          ? const []
          : [miss ?? const ErrorClassification.unclassified()],
    );
  }
}
