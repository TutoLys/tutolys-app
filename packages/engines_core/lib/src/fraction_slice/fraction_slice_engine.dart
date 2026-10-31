import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/pick_one.dart';

enum FractionShape { pizza, bar }

enum FractionMode { identify, shade }

class Fraction {
  const Fraction(this.num, this.den);
  final int num;
  final int den;

  bool sameValue(Fraction o) => num * o.den == o.num * den;

  String get symbols => '$num/$den';

  static const _frNum = [
    'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', //
  ];
  static const _enNum = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', //
  ];
  static const _frDen = {
    2: 'demi', 3: 'tiers', 4: 'quart', 5: 'cinquième', 6: 'sixième', //
    7: 'septième', 8: 'huitième',
  };
  static const _enDen = {
    2: 'half', 3: 'third', 4: 'quarter', 5: 'fifth', 6: 'sixth', //
    7: 'seventh', 8: 'eighth',
  };

  /// "trois huitièmes", "un demi", "two thirds", "one half".
  String words(Locale locale) {
    final fr = locale.languageCode == 'fr';
    final n = (fr ? _frNum : _enNum)[num];
    var d = (fr ? _frDen : _enDen)[den]!;
    if (num > 1) {
      d = switch (d) {
        'tiers' => d,
        'half' => 'halves',
        _ => '${d}s',
      };
    }
    return '$n $d';
  }
}

class FractionOption {
  const FractionOption({required this.id, required this.fraction});
  final String id;
  final Fraction fraction;
}

class FractionContent {
  const FractionContent({
    required this.shape,
    required this.parts,
    required this.mode,
    this.shaded = 0,
    this.target = const Fraction(0, 1),
    this.options = const [],
    this.correctId = '',
    this.words = false,
    this.shuffle = true,
  });

  final FractionShape shape;

  /// Equal parts the whole is cut into, 2–8.
  final int parts;
  final FractionMode mode;

  /// identify: how many parts are coloured (the first ones).
  final int shaded;

  /// shade: the fraction to colour.
  final Fraction target;
  final List<FractionOption> options;
  final String correctId;

  /// Options read "trois quarts" instead of "3/4".
  final bool words;
  final bool shuffle;

  List<String> get ids => [for (final o in options) o.id];

  FractionOption option(String id) => options.firstWhere((o) => o.id == id);

  /// shade: how many parts make the target.
  int get partsToShade => target.num * parts ~/ target.den;
}

class FractionState {
  const FractionState({
    required this.pick,
    this.shaded = const {},
    this.shadeSolved = false,
  });

  /// identify mode.
  final PickState pick;

  /// shade mode: the parts the child has coloured.
  final Set<int> shaded;
  final bool shadeSolved;

  FractionState copyWith({
    PickState? pick,
    Set<int>? shaded,
    bool? shadeSolved,
  }) => FractionState(
    pick: pick ?? this.pick,
    shaded: shaded ?? this.shaded,
    shadeSolved: shadeSolved ?? this.shadeSolved,
  );
}

sealed class FractionAction {
  const FractionAction();
}

class PickFraction extends FractionAction {
  const PickFraction(this.id);
  final String id;
}

class ToggleSlice extends FractionAction {
  const ToggleSlice(this.index);
  final int index;
}

/// "La découpe magique" — the `fraction_slice` engine (app ADR 0081;
/// Hafid's catalogue B10).
///
/// A pizza or a bar cut into 2–8 equal parts, drawn in code:
/// - `identify`: some parts are coloured; pick the fraction from 2–4
///   options. The right option is the one equal in value to coloured over
///   parts, so a lesson can't name a wrong key — and can't offer both 1/2
///   and 2/4.
/// - `shade`: colour the target fraction by tapping parts. Any parts will
///   do; only the count matters (2/4 of a pizza is any two slices).
///
/// Options read as symbols ("3/4") or words ("trois quarts").
class FractionSliceEngine
    implements
        LearningEngine<
          FractionContent,
          FractionState,
          FractionAction,
          AnswerValue
        > {
  const FractionSliceEngine();

  static const key = 'fraction_slice';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Every part is a focusable, spoken toggle; the drawing says how many
    // parts there are and how many are coloured.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static Fraction? _fraction(Object? raw) {
    if (raw is! Map) return null;
    final n = raw['num'];
    final d = raw['den'];
    if (n is! int || d is! int || d < 2 || d > 8 || n < 1 || n > d) {
      return null;
    }
    return Fraction(n, d);
  }

  @override
  ParseResult<FractionContent> parse(Map<String, Object?> config) {
    final shape = FractionShape.values.asNameMap()[config['shape'] ?? 'pizza'];
    final mode = FractionMode.values.asNameMap()[config['mode'] ?? 'identify'];
    final parts = config['parts'];
    if (shape == null || mode == null) {
      return const ParseResult.invalid(
        'shape is pizza or bar; mode is identify or shade.',
      );
    }
    if (parts is! int || parts < 2 || parts > 8) {
      return const ParseResult.invalid('parts is 2 to 8.');
    }
    final words = config['display'] == 'words';
    final shuffle = config['shuffle'] is bool
        ? config['shuffle']! as bool
        : true;

    if (mode == FractionMode.shade) {
      final target = _fraction(config['target']);
      if (target == null) {
        return const ParseResult.invalid(
          'target is {num, den}, den 2 to 8, num 1 to den.',
        );
      }
      if (parts % target.den != 0) {
        return const ParseResult.invalid(
          'parts must be a multiple of the target\'s den.',
        );
      }
      if (config.containsKey('options') || config.containsKey('shaded')) {
        return const ParseResult.invalid(
          'options and shaded are for identify.',
        );
      }
      return ParseResult.ok(
        FractionContent(
          shape: shape,
          parts: parts,
          mode: mode,
          target: target,
          words: words,
        ),
      );
    }

    final shaded = config['shaded'];
    if (shaded is! int || shaded < 1 || shaded > parts) {
      return const ParseResult.invalid('shaded is 1 to parts.');
    }
    final rawOptions = config['options'];
    if (rawOptions is! List || rawOptions.length < 2 || rawOptions.length > 4) {
      return const ParseResult.invalid('There are 2 to 4 options.');
    }
    final options = <FractionOption>[];
    for (final raw in rawOptions) {
      final id = raw is Map ? raw['id'] : null;
      final f = _fraction(raw);
      if (id is! String || id.isEmpty || f == null) {
        return const ParseResult.invalid(
          'Every option is {id, num, den}, den 2 to 8, num 1 to den.',
        );
      }
      if (options.any((o) => o.id == id)) {
        return const ParseResult.invalid('Option ids are unique.');
      }
      if (options.any((o) => o.fraction.sameValue(f))) {
        return const ParseResult.invalid(
          'Two options are the same fraction (like 1/2 and 2/4).',
        );
      }
      options.add(FractionOption(id: id, fraction: f));
    }
    final shown = Fraction(shaded, parts);
    final right = options.where((o) => o.fraction.sameValue(shown)).toList();
    if (right.length != 1) {
      return const ParseResult.invalid(
        'Exactly one option is the coloured fraction.',
      );
    }
    return ParseResult.ok(
      FractionContent(
        shape: shape,
        parts: parts,
        mode: mode,
        shaded: shaded,
        options: List.unmodifiable(options),
        correctId: right.single.id,
        words: words,
        shuffle: shuffle,
      ),
    );
  }

  @override
  FractionState initialize(FractionContent content, EngineSeed seed) =>
      FractionState(
        pick: content.mode == FractionMode.identify
            ? PickOne.initialize(content.ids, seed, shuffle: content.shuffle)
            : const PickState(order: []),
      );

  @override
  Transition<FractionState> reduce(FractionState s, FractionAction action) {
    switch (action) {
      case PickFraction(:final id):
        final t = PickOne.reduce(s.pick, PickChoice(id));
        return Transition(s.copyWith(pick: t.state), t.events);
      case ToggleSlice(:final index):
        // Identify mode always has options; only shade colours parts.
        if (s.pick.order.isNotEmpty ||
            s.shadeSolved ||
            index < 0 ||
            index >= 8) {
          return Transition(s);
        }
        final on = !s.shaded.contains(index);
        return Transition(
          s.copyWith(
            shaded: on ? {...s.shaded, index} : ({...s.shaded}..remove(index)),
          ),
          [
            InteractionEvent(on ? 'item_placed' : 'item_removed', {
              'item_id': 'part_$index',
            }),
          ],
        );
    }
  }

  @override
  AnswerValue? extractAnswer(FractionState s) {
    final pick = PickOne.extractAnswer(s.pick);
    if (pick != null) return pick;
    if (s.shaded.isEmpty || s.shadeSolved) return null;
    return MultiSelectAnswer([for (final i in s.shaded) 'part_$i']);
  }

  @override
  FractionState applyFeedback(FractionState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    if (s.pick.selected != null) {
      return s.copyWith(pick: PickOne.applyFeedback(s.pick, result));
    }
    // Shade: a wrong count stays on the board, so the child adds or
    // removes rather than starts over.
    return s.copyWith(shadeSolved: result.outcome == Outcome.correct);
  }

  @override
  Map<String, Object?> snapshot(FractionState s) => {
    'pick': PickOne.snapshot(s.pick),
    'shaded': (s.shaded.toList()..sort()),
    'shade_solved': s.shadeSolved,
  };

  @override
  FractionState? restore(FractionContent content, Map<String, Object?> snap) {
    try {
      final pick = content.mode == FractionMode.identify
          ? PickOne.restore(
              (snap['pick']! as Map).cast<String, Object?>(),
              ids: content.ids,
              correctId: content.correctId,
            )
          : const PickState(order: []);
      if (pick == null) return null;
      final shaded = ((snap['shaded'] as List?) ?? const [])
          .cast<int>()
          .toSet();
      final solved = snap['shade_solved'] == true;
      if (shaded.any((i) => i < 0 || i >= content.parts) ||
          (solved && shaded.length != content.partsToShade)) {
        return null;
      }
      return FractionState(pick: pick, shaded: shaded, shadeSolved: solved);
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<FractionContent, FractionState, FractionAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final shade = c.mode == FractionMode.shade;
    final coloured = shade ? s.shaded : {for (var i = 0; i < c.shaded; i++) i};
    final canTap = shade && view.enabled && !s.shadeSolved;
    final shapeName = switch (c.shape) {
      FractionShape.pizza => fr ? 'Une pizza' : 'A pizza',
      FractionShape.bar => fr ? 'Une barre' : 'A bar',
    };
    final describe = fr
        ? '$shapeName coupée en ${c.parts} parts égales, '
              '${coloured.length} colorée${coloured.length > 1 ? 's' : ''}.'
        : '$shapeName cut into ${c.parts} equal parts, '
              '${coloured.length} coloured.';

    final drawing = AspectRatio(
      aspectRatio: c.shape == FractionShape.pizza ? 1 : 3,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return Semantics(
            key: const ValueKey('fraction-shape'),
            label: describe,
            liveRegion: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: canTap
                        ? (d) {
                            final i = _partAt(c, size, d.localPosition);
                            if (i != null) view.dispatch(ToggleSlice(i));
                          }
                        : null,
                    child: CustomPaint(
                      painter: _FractionPainter(
                        c,
                        coloured,
                        VillagePalette.of(context),
                        solved: s.shadeSolved,
                      ),
                    ),
                  ),
                ),
                // A focusable, spoken target on each part, which is also a
                // finger-sized tap target at its centre.
                if (shade)
                  for (var i = 0; i < c.parts; i++)
                    _sliceTarget(
                      c,
                      size,
                      i,
                      on: s.shaded.contains(i),
                      fr: fr,
                      onTap: canTap
                          ? () => view.dispatch(ToggleSlice(i))
                          : null,
                    ),
              ],
            ),
          );
        },
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: c.shape == FractionShape.pizza ? 280 : 520,
                  ),
                  child: drawing,
                ),
              ),
              const SizedBox(height: 20),
              if (shade)
                Text(
                  '${s.shaded.length} / ${c.parts}',
                  key: const ValueKey('fraction-count'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: VillagePalette.of(context).ink,
                  ),
                )
              else
                PickOne.choices(
                  state: s.pick,
                  enabled: view.enabled,
                  fr: fr,
                  label: (id) {
                    final f = c.option(id).fraction;
                    return c.words ? f.words(view.locale) : f.symbols;
                  },
                  spoken: (id) => c.option(id).fraction.words(view.locale),
                  onPick: (id) => view.dispatch(PickFraction(id)),
                  keyPrefix: 'fraction-choice',
                  correctId: c.correctId,
                  width: c.words ? 160 : 96,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Offset _centre(FractionContent c, Size size, int i) {
    if (c.shape == FractionShape.bar) {
      final w = size.width / c.parts;
      return Offset((i + 0.5) * w, size.height / 2);
    }
    final r = math.min(size.width, size.height) / 2;
    final a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / c.parts;
    return size.center(Offset.zero) +
        Offset(math.cos(a), math.sin(a)) * r * 0.6;
  }

  static int? _partAt(FractionContent c, Size size, Offset p) {
    if (c.shape == FractionShape.bar) {
      if (p.dx < 0 || p.dx >= size.width) return null;
      return (p.dx / (size.width / c.parts)).floor();
    }
    final v = p - size.center(Offset.zero);
    if (v.distance > math.min(size.width, size.height) / 2) return null;
    var a = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    return (a / (2 * math.pi / c.parts)).floor() % c.parts;
  }

  static Widget _sliceTarget(
    FractionContent c,
    Size size,
    int i, {
    required bool on,
    required bool fr,
    required VoidCallback? onTap,
  }) {
    final at = _centre(c, size, i);
    const d = 44.0;
    return Positioned(
      left: at.dx - d / 2,
      top: at.dy - d / 2,
      width: d,
      height: d,
      child: Semantics(
        button: true,
        toggled: on,
        label: fr ? 'part ${i + 1}' : 'piece ${i + 1}',
        hint: on
            ? (fr ? 'coloriée' : 'coloured')
            : (fr ? 'pas coloriée' : 'not coloured'),
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            key: ValueKey('fraction-part-$i'),
            customBorder: const CircleBorder(),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _FractionPainter extends CustomPainter {
  _FractionPainter(this.c, this.coloured, this.p, {required this.solved});
  final FractionContent c;
  final Set<int> coloured;
  final VillagePalette p;
  final bool solved;

  static const _sauce = Color(0xFFF08A24);
  static const _crust = Color(0xFFE8B96A);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = solved
        ? p.success
        : (c.shape == FractionShape.pizza ? _sauce : p.quebecBlueBright);
    final blank = c.shape == FractionShape.pizza
        ? const Color(0xFFFFF3D6)
        : p.surface;
    final edge = Paint()
      ..color = p.ink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    if (c.shape == FractionShape.bar) {
      final w = size.width / c.parts;
      for (var i = 0; i < c.parts; i++) {
        final r = Rect.fromLTWH(i * w, 0, w, size.height).deflate(1.5);
        canvas
          ..drawRect(r, Paint()..color = coloured.contains(i) ? fill : blank)
          ..drawRect(r, edge);
      }
      return;
    }

    final centre = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 4;
    final sweep = 2 * math.pi / c.parts;
    canvas.drawCircle(centre, r, Paint()..color = _crust);
    final inner = Rect.fromCircle(center: centre, radius: r * 0.88);
    for (var i = 0; i < c.parts; i++) {
      canvas.drawArc(
        inner,
        -math.pi / 2 + i * sweep,
        sweep,
        true,
        Paint()..color = coloured.contains(i) ? fill : blank,
      );
    }
    canvas.drawCircle(centre, r, edge);
    for (var i = 0; i < c.parts; i++) {
      final a = -math.pi / 2 + i * sweep;
      canvas.drawLine(
        centre,
        centre + Offset(math.cos(a), math.sin(a)) * r,
        edge,
      );
    }
  }

  @override
  bool shouldRepaint(_FractionPainter old) =>
      old.c != c ||
      old.solved != solved ||
      old.p != p ||
      old.coloured.length != coloured.length ||
      !old.coloured.containsAll(coloured);
}

/// Grades a `fraction_slice` answer: the picked fraction (identify), or the
/// number of coloured parts (shade), whichever parts they are.
class FractionSliceEvaluator
    implements Evaluator<FractionContent, AnswerValue> {
  const FractionSliceEvaluator();

  @override
  String get engineKey => FractionSliceEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    FractionContent content,
    AnswerValue answer,
    EvaluationContext ctx,
  ) {
    switch (answer) {
      case SingleChoiceAnswer() when content.mode == FractionMode.identify:
        return PickOne.evaluate(
          engineKey: engineKey,
          ids: content.ids,
          correctId: content.correctId,
          answer: answer,
          ctx: ctx,
        );
      case MultiSelectAnswer(:final selectedOptionIds)
          when content.mode == FractionMode.shade:
        final want = content.partsToShade;
        final got = selectedOptionIds.length;
        final right = got == want;
        return EvaluationResult(
          outcome: right ? Outcome.correct : Outcome.incorrect,
          score: right ? 1 : 0,
          attemptNumber: ctx.attemptNumber,
          evaluator: '$engineKey.$policy@$version',
          skillNodeIds: ctx.skillNodeIds,
          itemResults: {'count': right},
          errors: right ? const [] : const [ErrorClassification.unclassified()],
        );
      default:
        throw ArgumentError('A ${answer.kind} answer does not fit this mode.');
    }
  }
}
