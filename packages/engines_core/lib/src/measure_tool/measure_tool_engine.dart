import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/pick_one.dart';

enum MeasureInstrument { ruler, clock, thermometer }

class MeasureOption {
  const MeasureOption({required this.id, required this.value});
  final String id;

  /// A length or a temperature; for a clock, minutes after 12:00.
  final int value;
}

class MeasureContent {
  const MeasureContent({
    required this.instrument,
    required this.options,
    required this.correctId,
    this.start = 0,
    this.length = 0,
    this.max = 10,
    this.unit = 'cm',
    this.unitLabel = 'cm',
    this.minutes = 0,
    this.value = 0,
    this.min = 0,
    this.step = 1,
    this.shuffle = true,
  });

  final MeasureInstrument instrument;
  final List<MeasureOption> options;
  final String correctId;

  // ruler: an object from `start` to `start + length`, on a ruler of `max`.
  final int start;
  final int length;
  final String unit;
  final String unitLabel;

  /// Ruler: its last graduation. Thermometer: its top.
  final int max;

  // clock
  final int minutes;

  // thermometer
  final int value;
  final int min;
  final int step;
  final bool shuffle;

  List<String> get ids => [for (final o in options) o.id];

  MeasureOption option(String id) => options.firstWhere((o) => o.id == id);

  /// What the instrument shows: the right option's value.
  int get measured => switch (instrument) {
    MeasureInstrument.ruler => length,
    MeasureInstrument.clock => minutes,
    MeasureInstrument.thermometer => value,
  };

  String label(String id, Locale locale) {
    final v = option(id).value;
    return switch (instrument) {
      MeasureInstrument.ruler => '$v $unitLabel',
      MeasureInstrument.thermometer => '$v °C',
      MeasureInstrument.clock => clockLabel(v, locale),
    };
  }

  static String clockLabel(int minutes, Locale locale) {
    final h = minutes ~/ 60 == 0 ? 12 : minutes ~/ 60;
    final m = minutes % 60;
    if (locale.languageCode == 'fr') {
      return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
    }
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  /// "3:30" → 210 (minutes after 12:00); null when it isn't a clock time
  /// a grade-1 child can read (hours 1–12, minutes on a 5-minute mark).
  static int? parseTime(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h < 1 || h > 12 || min > 55 || min % 5 != 0) return null;
    return (h % 12) * 60 + min;
  }
}

/// "Mesure" — the `measure_tool` engine (app ADR 0049; Hafid's catalogue
/// A19 measure_estimate, merged with weather_station's instruments).
///
/// An instrument drawn in code, read, then answered from 2–4 values:
/// - `ruler`: an object laid on a ruler in cm, or along a row of cubes
///   (non-standard units). It may start past 0, which is the classic
///   grade-1 mistake ("it ends at 9, so it's 9").
/// - `clock`: an analog clock on a 5-minute mark (o'clock and half past
///   at grade 1).
/// - `thermometer`: a liquid column on a graduated scale, in °C.
///
/// The right option is the one whose value is what the instrument shows,
/// so a lesson can't name a wrong key. Reading only: setting the hands or
/// laying the ruler is a later mode.
class MeasureToolEngine
    implements
        LearningEngine<
          MeasureContent,
          PickState,
          PickChoice,
          SingleChoiceAnswer
        > {
  const MeasureToolEngine();

  static const key = 'measure_tool';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // A blind child can't read a drawn ruler; the instrument says what it
    // is, never its value.
    capabilities: EngineCapabilities(keyboard: true, screenReader: false),
  );

  static int? _int(Object? v) => v is int ? v : null;

  @override
  ParseResult<MeasureContent> parse(Map<String, Object?> config) {
    final instrument = MeasureInstrument.values
        .asNameMap()[config['instrument']];
    if (instrument == null) {
      return const ParseResult.invalid(
        'instrument is ruler, clock or thermometer.',
      );
    }

    final rawOptions = config['options'];
    if (rawOptions is! List || rawOptions.length < 2 || rawOptions.length > 4) {
      return const ParseResult.invalid('There are 2 to 4 options.');
    }
    final options = <MeasureOption>[];
    for (final raw in rawOptions) {
      final id = raw is Map ? raw['id'] : null;
      final rawValue = raw is Map ? raw['value'] : null;
      final value = instrument == MeasureInstrument.clock
          ? MeasureContent.parseTime(rawValue)
          : _int(rawValue);
      if (id is! String || id.isEmpty || value == null) {
        return ParseResult.invalid(
          instrument == MeasureInstrument.clock
              ? 'Every option needs an id and a time like "3:30".'
              : 'Every option needs an id and a whole-number value.',
        );
      }
      if (options.any((o) => o.id == id || o.value == value)) {
        return const ParseResult.invalid('Option ids and values are unique.');
      }
      options.add(MeasureOption(id: id, value: value));
    }

    var content = MeasureContent(
      instrument: instrument,
      options: options,
      correctId: '',
    );
    switch (instrument) {
      case MeasureInstrument.ruler:
        final unit = config['unit'] ?? 'cm';
        final start = _int(config['start'] ?? 0);
        final length = _int(config['length']);
        final max = _int(config['max']);
        final unitLabel = config['unit_label'] ?? unit;
        if (unit != 'cm' && unit != 'block') {
          return const ParseResult.invalid('unit is cm or block.');
        }
        if (max == null || max < 5 || max > 20) {
          return const ParseResult.invalid('max is 5 to 20.');
        }
        if (start == null || length == null || start < 0 || length < 1) {
          return const ParseResult.invalid(
            'start is 0 or more and length 1 or more.',
          );
        }
        if (start + length > max) {
          return const ParseResult.invalid('The object runs off the ruler.');
        }
        if (unitLabel is! String ||
            unitLabel.trim().isEmpty ||
            unitLabel.length > 16) {
          return const ParseResult.invalid('unit_label is 1 to 16 characters.');
        }
        content = MeasureContent(
          instrument: instrument,
          options: options,
          correctId: '',
          start: start,
          length: length,
          max: max,
          unit: unit as String,
          unitLabel: unitLabel,
        );
      case MeasureInstrument.clock:
        final minutes = MeasureContent.parseTime(config['time']);
        if (minutes == null) {
          return const ParseResult.invalid(
            'time is "H:MM", hours 1 to 12, minutes on a 5-minute mark.',
          );
        }
        content = MeasureContent(
          instrument: instrument,
          options: options,
          correctId: '',
          minutes: minutes,
        );
      case MeasureInstrument.thermometer:
        final value = _int(config['value']);
        final min = _int(config['min']);
        final max = _int(config['max']);
        final step = _int(config['step'] ?? 1);
        if (min == null || max == null || min >= max || max - min > 60) {
          return const ParseResult.invalid(
            'min is below max, at most 60 degrees apart.',
          );
        }
        if (!const {1, 2, 5, 10}.contains(step) || (max - min) % step! != 0) {
          return const ParseResult.invalid(
            'step is 1, 2, 5 or 10 and divides the scale.',
          );
        }
        if (value == null ||
            value < min ||
            value > max ||
            (value - min) % step != 0) {
          return const ParseResult.invalid(
            'value is on a graduation of the scale.',
          );
        }
        content = MeasureContent(
          instrument: instrument,
          options: options,
          correctId: '',
          value: value,
          min: min,
          max: max,
          step: step,
        );
    }

    final right = options.where((o) => o.value == content.measured).toList();
    if (right.length != 1) {
      return const ParseResult.invalid(
        'Exactly one option is what the instrument shows.',
      );
    }
    final shuffle = config['shuffle'];
    return ParseResult.ok(
      MeasureContent(
        instrument: content.instrument,
        options: List.unmodifiable(options),
        correctId: right.single.id,
        start: content.start,
        length: content.length,
        max: content.max,
        unit: content.unit,
        unitLabel: content.unitLabel,
        minutes: content.minutes,
        value: content.value,
        min: content.min,
        step: content.step,
        shuffle: shuffle is bool ? shuffle : true,
      ),
    );
  }

  @override
  PickState initialize(MeasureContent content, EngineSeed seed) =>
      PickOne.initialize(content.ids, seed, shuffle: content.shuffle);

  @override
  Transition<PickState> reduce(PickState s, PickChoice action) =>
      PickOne.reduce(s, action);

  @override
  SingleChoiceAnswer? extractAnswer(PickState s) => PickOne.extractAnswer(s);

  @override
  PickState applyFeedback(PickState s, EvaluationResult result) =>
      PickOne.applyFeedback(s, result);

  @override
  Map<String, Object?> snapshot(PickState s) => PickOne.snapshot(s);

  @override
  PickState? restore(MeasureContent content, Map<String, Object?> snap) =>
      PickOne.restore(snap, ids: content.ids, correctId: content.correctId);

  @override
  Widget buildView(
    BuildContext context,
    EngineView<MeasureContent, PickState, PickChoice> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final p = VillagePalette.of(context);
    final (drawing, height, describe) = switch (c.instrument) {
      MeasureInstrument.ruler => (
        _RulerPainter(c, p),
        150.0,
        c.unit == 'block'
            ? (fr
                  ? 'Un crayon, avec des ${c.unitLabel} alignés dessous.'
                  : 'A pencil, with ${c.unitLabel} lined up under it.')
            : (fr
                  ? 'Une règle de 0 à ${c.max} ${c.unitLabel}, avec un crayon posé dessus.'
                  : 'A ruler from 0 to ${c.max} ${c.unitLabel}, with a pencil on it.'),
      ),
      MeasureInstrument.clock => (
        _ClockPainter(c.minutes, p),
        240.0,
        fr ? 'Une horloge à aiguilles.' : 'A clock with hands.',
      ),
      MeasureInstrument.thermometer => (
        _ThermometerPainter(c, p),
        280.0,
        fr
            ? 'Un thermomètre gradué de ${c.min} à ${c.max} degrés.'
            : 'A thermometer marked from ${c.min} to ${c.max} degrees.',
      ),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                key: const ValueKey('measure-instrument'),
                label: describe,
                image: true,
                excludeSemantics: true,
                child: SizedBox(
                  height: height,
                  child: CustomPaint(painter: drawing),
                ),
              ),
              const SizedBox(height: 20),
              PickOne.choices(
                state: view.state,
                enabled: view.enabled,
                fr: fr,
                label: (id) => c.label(id, view.locale),
                onPick: (id) => view.dispatch(PickChoice(id)),
                keyPrefix: 'measure-choice',
                correctId: c.correctId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _text(
  Canvas canvas,
  String text,
  Offset center,
  Color color, {
  double size = 14,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

const _pencil = Color(0xFFF08A24);
const _liquid = Color(0xFFE5484D);

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.c, this.p);
  final MeasureContent c;
  final VillagePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 24.0;
    final unit = (size.width - 2 * pad) / c.max;
    double x(num u) => pad + u * unit;
    final edge = Paint()
      ..color = p.ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // The object: a pencil from start to start + length.
    final body = Rect.fromLTRB(x(c.start), 24, x(c.start + c.length), 56);
    final tip = math.min(body.width * 0.25, 22.0);
    final pencil = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.right - tip, body.top)
      ..lineTo(body.right, body.center.dy)
      ..lineTo(body.right - tip, body.bottom)
      ..lineTo(body.left, body.bottom)
      ..close();
    canvas
      ..drawPath(pencil, Paint()..color = _pencil)
      ..drawPath(pencil, edge);

    if (c.unit == 'block') {
      // Cubes laid end to end under the object: count them.
      for (var i = 0; i < c.length; i++) {
        final r = Rect.fromLTWH(
          x(c.start + i) + 1,
          70,
          unit - 2,
          unit - 2,
        ).intersect(Rect.fromLTWH(0, 70, size.width, 56));
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            Paint()..color = p.quebecBlueBright.withValues(alpha: 0.85),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            edge,
          );
      }
      return;
    }

    final ruler = RRect.fromRectAndRadius(
      Rect.fromLTRB(pad - 12, 66, size.width - pad + 12, 130),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(ruler, Paint()..color = const Color(0xFFF5D77A))
      ..drawRRect(ruler, edge);
    final tick = Paint()
      ..color = p.ink
      ..strokeWidth = 2;
    for (var i = 0; i <= c.max * 2; i++) {
      final at = x(i / 2);
      final long = i.isEven;
      canvas.drawLine(Offset(at, 66), Offset(at, long ? 88 : 78), tick);
      // Every number when there's room; on a phone, the even ones.
      if (long && (unit >= 24 || (i ~/ 2).isEven)) {
        _text(canvas, '${i ~/ 2}', Offset(at, 106), p.ink);
      }
    }
    // A dashed guide from each end of the object down to the ruler.
    final guide = Paint()
      ..color = p.ink.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (final at in [x(c.start), x(c.start + c.length)]) {
      for (var y = 58.0; y < 66; y += 4) {
        canvas.drawLine(Offset(at, y), Offset(at, y + 2), guide);
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.c != c || old.p != p;
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.minutes, this.p);
  final int minutes;
  final VillagePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 6;
    canvas
      ..drawCircle(center, r, Paint()..color = p.surface)
      ..drawCircle(
        center,
        r,
        Paint()
          ..color = p.quebecBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final big = i % 5 == 0;
      final from =
          center + Offset(math.cos(a), math.sin(a)) * (r - (big ? 14 : 8));
      final to = center + Offset(math.cos(a), math.sin(a)) * (r - 4);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = p.ink.withValues(alpha: big ? 0.9 : 0.4)
          ..strokeWidth = big ? 3 : 1.5,
      );
    }
    for (var h = 1; h <= 12; h++) {
      final a = h * math.pi / 6 - math.pi / 2;
      _text(
        canvas,
        '$h',
        center + Offset(math.cos(a), math.sin(a)) * (r - 32),
        p.ink,
        size: r / 6,
      );
    }
    void hand(double turns, double length, double width, Color color) {
      final a = turns * 2 * math.pi - math.pi / 2;
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * length,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    // Short and thick for the hours, long and thin for the minutes.
    hand((minutes / 60) / 12, r * 0.5, 9, p.quebecBlue);
    hand((minutes % 60) / 60, r * 0.78, 5, p.quebecBlueBright);
    canvas.drawCircle(center, 8, Paint()..color = p.quebecBlue);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.minutes != minutes || old.p != p;
}

class _ThermometerPainter extends CustomPainter {
  _ThermometerPainter(this.c, this.p);
  final MeasureContent c;
  final VillagePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const top = 16.0;
    final bottom = size.height - 56;
    final bulb = Offset(cx, size.height - 30);
    double y(int v) => bottom - (v - c.min) / (c.max - c.min) * (bottom - top);
    final tube = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - 12, top - 8, cx + 12, bulb.dy),
      const Radius.circular(12),
    );
    final edge = Paint()
      ..color = p.ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawRRect(tube, Paint()..color = p.surface)
      ..drawCircle(bulb, 24, Paint()..color = _liquid)
      ..drawRRect(tube, edge)
      ..drawCircle(bulb, 24, edge)
      ..drawRect(
        Rect.fromLTRB(cx - 6, y(c.value), cx + 6, bulb.dy),
        Paint()..color = _liquid,
      );
    final labelEvery = c.step <= 1 ? 5 : 10;
    for (var v = c.min; v <= c.max; v += c.step) {
      final big = v % labelEvery == 0 || v == c.min || v == c.max;
      canvas.drawLine(
        Offset(cx + 16, y(v)),
        Offset(cx + (big ? 34 : 26), y(v)),
        Paint()
          ..color = p.ink
          ..strokeWidth = big ? 2.5 : 1.5,
      );
      if (big) _text(canvas, '$v', Offset(cx + 54, y(v)), p.ink);
    }
    _text(canvas, '°C', Offset(cx - 40, top + 4), p.inkMuted);
  }

  @override
  bool shouldRepaint(_ThermometerPainter old) => old.c != c || old.p != p;
}

/// Grades a `measure_tool` pick against the value the instrument shows.
class MeasureToolEvaluator
    implements Evaluator<MeasureContent, SingleChoiceAnswer> {
  const MeasureToolEvaluator();

  @override
  String get engineKey => MeasureToolEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    MeasureContent content,
    SingleChoiceAnswer answer,
    EvaluationContext ctx,
  ) => PickOne.evaluate(
    engineKey: engineKey,
    ids: content.ids,
    correctId: content.correctId,
    answer: answer,
    ctx: ctx,
  );
}
