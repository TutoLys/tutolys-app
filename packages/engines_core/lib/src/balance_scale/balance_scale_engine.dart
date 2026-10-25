import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

enum BalanceMode {
  /// Both pans are known; pick <, > or =.
  compare,

  /// One term is missing; pick the value that makes the scale level.
  balance,
}

/// What sits on one pan: a number, `a + b` / `a − b`, or a pile of
/// counters. A null term is the gap a `balance` question asks for.
class BalanceSide {
  const BalanceSide({required this.terms, this.op = '+', this.symbol});

  /// 1 or 2 terms, each 0–100.
  final List<int?> terms;

  /// `+` or `-`, between the two terms. Grade 1: one operation per side.
  final String op;

  /// Counters mode: the single term is drawn as this many [symbol]s
  /// (at most 20, so a 6-year-old can still count them).
  final String? symbol;

  bool get hasGap => terms.contains(null);

  /// The side's value, with [gap] in place of the missing term.
  int value([int gap = 0]) {
    final a = terms[0] ?? gap;
    if (terms.length == 1) return a;
    final b = terms[1] ?? gap;
    return op == '+' ? a + b : a - b;
  }

  /// "3 + 2", "6 − 1", "4 + ?" — with [gap] shown in place of "?" once
  /// the child has placed a value.
  String text({String gap = '?'}) {
    String t(int? n) => n?.toString() ?? gap;
    if (terms.length == 1) return t(terms[0]);
    return '${t(terms[0])} ${op == '+' ? '+' : '−'} ${t(terms[1])}';
  }
}

class BalanceOption {
  const BalanceOption({required this.id, required this.value});
  final String id;
  final int value;
}

class BalanceContent {
  const BalanceContent({
    required this.mode,
    required this.left,
    required this.right,
    required this.choices,
    required this.correctId,
    this.options = const [],
  });

  final BalanceMode mode;
  final BalanceSide left;
  final BalanceSide right;

  /// `balance` only.
  final List<BalanceOption> options;

  /// What a tap can pick: sign ids (`lt`, `gt`, `eq`) or option ids.
  final List<String> choices;

  /// Derived from the values, never authored: the content can't disagree
  /// with its own arithmetic.
  final String correctId;

  BalanceOption option(String id) => options.firstWhere((o) => o.id == id);

  /// The side values with [pick] placed in the gap (balance) — what the
  /// scale weighs.
  (int, int) weigh([String? pick]) {
    final gap = pick == null || mode == BalanceMode.compare
        ? 0
        : option(pick).value;
    return (left.value(gap), right.value(gap));
  }
}

/// The three sign ids. Fixed, so a sidecar can say "chose gt: reversed
/// the symbol", grade 1's main error.
abstract final class BalanceSigns {
  static const lt = 'lt';
  static const gt = 'gt';
  static const eq = 'eq';
  static const all = [lt, gt, eq];

  static String glyph(String id) => switch (id) {
    lt => '<',
    gt => '>',
    _ => '=',
  };

  static String spoken(String id, bool fr) => switch (id) {
    lt => fr ? 'plus petit que' : 'less than',
    gt => fr ? 'plus grand que' : 'greater than',
    _ => fr ? 'égal à' : 'equal to',
  };

  static String of(int left, int right) => left < right
      ? lt
      : left > right
      ? gt
      : eq;
}

class BalanceState {
  const BalanceState({
    required this.order,
    this.selected,
    this.tried = const {},
    this.solved = false,
    this.lastWrong,
  });

  /// Choices in display order: signs keep < > =; options shuffle.
  final List<String> order;
  final String? selected;

  /// Checked wrong — amber, and no longer tappable.
  final Set<String> tried;
  final bool solved;

  /// The last wrong pick, so a `balance` scale can tip the way that value
  /// makes it tip: "too heavy on the left" is feedback a child can use.
  final String? lastWrong;

  BalanceState copyWith({
    String? selected,
    bool clearSelected = false,
    Set<String>? tried,
    bool? solved,
    String? lastWrong,
  }) => BalanceState(
    order: order,
    selected: clearSelected ? null : (selected ?? this.selected),
    tried: tried ?? this.tried,
    solved: solved ?? this.solved,
    lastWrong: lastWrong ?? this.lastWrong,
  );
}

sealed class BalanceAction {
  const BalanceAction();
}

class PickBalanceChoice extends BalanceAction {
  const PickBalanceChoice(this.id);
  final String id;
}

/// A two-pan scale — the `balance_scale` engine (app ADR 0045; Hafid's
/// catalogue B11, merging compare_choose's numeric form).
///
/// - `compare`: two numbers, two expressions (`3 + 2 ? 6 − 1`) or two piles
///   of counters; pick <, > or =. The scale stays level until the answer
///   is right, because a tilt *is* the answer.
/// - `balance`: one term is missing (`4 + ? = 7`); pick the value, from the
///   author's 2–4 options, that levels the scale. A wrong value tips the
///   scale the way that value would, which says "too much" or "too little"
///   without giving the answer away.
///
/// Grade 1's equality, equivalent expressions, missing term and comparing
/// numbers (math strand 1). Drawn in code: no art.
class BalanceScaleEngine
    implements
        LearningEngine<
          BalanceContent,
          BalanceState,
          BalanceAction,
          SingleChoiceAnswer
        > {
  const BalanceScaleEngine();

  static const key = 'balance_scale';
  static const maxTerm = 100;
  static const maxCounters = 20;

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static (BalanceSide?, String?) _side(Object? raw, String name) {
    if (raw is! Map) return (null, '$name must be an object.');
    final terms = raw['terms'];
    if (terms is! List || terms.isEmpty || terms.length > 2) {
      return (null, '$name needs 1 or 2 terms.');
    }
    final parsed = <int?>[];
    for (final t in terms) {
      if (t == null) {
        parsed.add(null);
      } else if (t is int && t >= 0 && t <= maxTerm) {
        parsed.add(t);
      } else {
        return (null, 'Every term is a whole number from 0 to $maxTerm.');
      }
    }
    final op = raw['op'] ?? '+';
    if (op != '+' && op != '-') return (null, 'op is + or -.');
    final symbol = raw['symbol'];
    if (symbol != null) {
      if (symbol is! String || symbol.isEmpty) {
        return (null, 'symbol must be a non-empty string.');
      }
      if (parsed.length != 1 || parsed.first == null) {
        return (null, 'Counters are one known number.');
      }
      if (parsed.first! > maxCounters) {
        return (null, 'At most $maxCounters counters on a pan.');
      }
    }
    return (
      BalanceSide(
        terms: List.unmodifiable(parsed),
        op: op as String,
        symbol: symbol as String?,
      ),
      null,
    );
  }

  @override
  ParseResult<BalanceContent> parse(Map<String, Object?> config) {
    final mode = switch (config['mode']) {
      null || 'compare' => BalanceMode.compare,
      'balance' => BalanceMode.balance,
      _ => null,
    };
    if (mode == null) {
      return const ParseResult.invalid('mode is compare or balance.');
    }
    final (left, leftError) = _side(config['left'], 'left');
    if (left == null) return ParseResult.invalid(leftError!);
    final (right, rightError) = _side(config['right'], 'right');
    if (right == null) return ParseResult.invalid(rightError!);
    final gaps = [...left.terms, ...right.terms].where((t) => t == null).length;

    if (mode == BalanceMode.compare) {
      if (gaps > 0) {
        return const ParseResult.invalid('A comparison has no missing term.');
      }
      if (config.containsKey('options')) {
        return const ParseResult.invalid('options belong to mode balance.');
      }
      if (left.value() < 0 || right.value() < 0) {
        return const ParseResult.invalid('A side never goes below zero.');
      }
      final rawSigns = config['signs'];
      final signs = rawSigns == null
          ? BalanceSigns.all
          : rawSigns is List &&
                rawSigns.length >= 2 &&
                rawSigns.every(BalanceSigns.all.contains) &&
                rawSigns.toSet().length == rawSigns.length
          ? [
              for (final s in BalanceSigns.all)
                if (rawSigns.contains(s)) s,
            ]
          : null;
      if (signs == null) {
        return const ParseResult.invalid(
          'signs lists 2 or 3 of lt, gt, eq, each once.',
        );
      }
      final correct = BalanceSigns.of(left.value(), right.value());
      if (!signs.contains(correct)) {
        return const ParseResult.invalid(
          'The right sign is not among the signs offered.',
        );
      }
      return ParseResult.ok(
        BalanceContent(
          mode: mode,
          left: left,
          right: right,
          choices: List.unmodifiable(signs),
          correctId: correct,
        ),
      );
    }

    if (gaps != 1) {
      return const ParseResult.invalid(
        'Balancing has exactly one missing term.',
      );
    }
    if (config.containsKey('signs')) {
      return const ParseResult.invalid('signs belong to mode compare.');
    }
    final rawOptions = config['options'];
    if (rawOptions is! List || rawOptions.length < 2 || rawOptions.length > 4) {
      return const ParseResult.invalid('Balancing needs 2 to 4 options.');
    }
    final options = <BalanceOption>[];
    for (final o in rawOptions) {
      final id = o is Map ? o['id'] : null;
      final value = o is Map ? o['value'] : null;
      if (id is! String ||
          id.isEmpty ||
          value is! int ||
          value < 0 ||
          value > maxTerm) {
        return const ParseResult.invalid(
          'Every option needs an id and a value from 0 to 100.',
        );
      }
      if (options.any((x) => x.id == id || x.value == value)) {
        return const ParseResult.invalid('Option ids and values are unique.');
      }
      options.add(BalanceOption(id: id, value: value));
    }
    final levels = [
      for (final o in options)
        if (left.value(o.value) == right.value(o.value)) o.id,
    ];
    if (levels.length != 1) {
      return const ParseResult.invalid(
        'Exactly one option must level the scale.',
      );
    }
    return ParseResult.ok(
      BalanceContent(
        mode: mode,
        left: left,
        right: right,
        options: List.unmodifiable(options),
        choices: [for (final o in options) o.id],
        correctId: levels.single,
      ),
    );
  }

  @override
  BalanceState initialize(BalanceContent content, EngineSeed seed) {
    final order = [...content.choices];
    // < > = always read in that order; numbers shuffle so the right one
    // isn't always in the same place.
    if (content.mode == BalanceMode.balance) order.shuffle(seed.random());
    return BalanceState(order: List.unmodifiable(order));
  }

  @override
  Transition<BalanceState> reduce(BalanceState s, BalanceAction action) {
    switch (action) {
      case PickBalanceChoice(:final id):
        if (s.solved ||
            !s.order.contains(id) ||
            s.tried.contains(id) ||
            s.selected == id) {
          return Transition(s);
        }
        return Transition(s.copyWith(selected: id), [
          InteractionEvent('option_selected', {'option_id': id}),
        ]);
    }
  }

  @override
  SingleChoiceAnswer? extractAnswer(BalanceState s) =>
      s.selected == null ? null : SingleChoiceAnswer(s.selected!);

  @override
  BalanceState applyFeedback(BalanceState s, EvaluationResult result) {
    final pick = s.selected;
    if (pick == null || result.outcome == Outcome.ungraded) return s;
    if (result.outcome == Outcome.correct) return s.copyWith(solved: true);
    return s.copyWith(
      clearSelected: true,
      tried: {...s.tried, pick},
      lastWrong: pick,
    );
  }

  @override
  Map<String, Object?> snapshot(BalanceState s) => {
    'order': s.order,
    'selected': s.selected,
    'tried': s.tried.toList(),
    'solved': s.solved,
    'last_wrong': s.lastWrong,
  };

  @override
  BalanceState? restore(BalanceContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final known = content.choices.toSet();
      if (order.length != known.length || !order.every(known.contains)) {
        return null;
      }
      if (content.mode == BalanceMode.compare) {
        for (var i = 0; i < order.length; i++) {
          if (order[i] != content.choices[i]) return null;
        }
      }
      final selected = snap['selected'] as String?;
      final tried = ((snap['tried'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final lastWrong = snap['last_wrong'] as String?;
      final solved = snap['solved'] == true;
      if ((selected != null && !known.contains(selected)) ||
          !tried.every(known.contains) ||
          tried.contains(content.correctId) ||
          (lastWrong != null && !tried.contains(lastWrong)) ||
          (solved && selected != content.correctId)) {
        return null;
      }
      return BalanceState(
        order: List.unmodifiable(order),
        selected: selected,
        tried: tried,
        solved: solved,
        lastWrong: lastWrong,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<BalanceContent, BalanceState, BalanceAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final c = view.content;
    final compare = c.mode == BalanceMode.compare;

    // How the scale tips. Level while the child is choosing; once solved
    // it shows the truth; in balance mode a wrong value tips it the way
    // that value would.
    var tilt = 0;
    if (s.solved) {
      final (l, r) = c.weigh(c.correctId);
      tilt = (r - l).sign;
    } else if (!compare && s.lastWrong != null && s.selected == null) {
      final (l, r) = c.weigh(s.lastWrong);
      tilt = (r - l).sign;
    }

    // The value shown in the gap: what's picked, else the last wrong try
    // (so the tilt has a reason on screen), else "?".
    final shownPick = compare ? null : (s.selected ?? s.lastWrong);
    String sideText(BalanceSide side) => side.text(
      gap: shownPick == null ? '?' : '${c.option(shownPick).value}',
    );

    final middle = compare
        ? (s.selected == null ? '?' : BalanceSigns.glyph(s.selected!))
        : '=';

    AnswerTileState stateOf(String id) => s.solved && id == s.selected
        ? AnswerTileState.correct
        : s.tried.contains(id)
        ? AnswerTileState.retry
        : s.selected == id
        ? AnswerTileState.picked
        : AnswerTileState.idle;

    String labelOf(String id) =>
        compare ? BalanceSigns.glyph(id) : '${c.option(id).value}';

    String spokenOf(String id) =>
        compare ? BalanceSigns.spoken(id, fr) : '${c.option(id).value}';

    String? hintOf(String id) => switch (stateOf(id)) {
      AnswerTileState.correct => fr ? 'bonne réponse' : 'right answer',
      AnswerTileState.retry => fr ? 'déjà essayé' : 'already tried',
      AnswerTileState.picked => fr ? 'choisi' : 'chosen',
      AnswerTileState.idle => null,
    };

    String describe(BalanceSide side) => side.symbol != null
        ? '${side.terms.first} ${side.symbol}'
        : sideText(side).replaceAll('−', fr ? 'moins' : 'minus');

    final tiltWords = switch (tilt) {
      -1 => fr ? 'La balance penche à gauche.' : 'The scale tips left.',
      1 => fr ? 'La balance penche à droite.' : 'The scale tips right.',
      _ => fr ? 'La balance est en équilibre.' : 'The scale is level.',
    };
    final scaleLabel = fr
        ? 'Plateau de gauche : ${describe(c.left)}. '
              'Plateau de droite : ${describe(c.right)}. $tiltWords'
        : 'Left pan: ${describe(c.left)}. '
              'Right pan: ${describe(c.right)}. $tiltWords';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                key: const ValueKey('balance-scale'),
                label: scaleLabel,
                liveRegion: true,
                excludeSemantics: true,
                child: _Scale(
                  tilt: tilt,
                  left: _PanContent(side: c.left, text: sideText(c.left)),
                  right: _PanContent(side: c.right, text: sideText(c.right)),
                  middle: middle,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.order)
                    SizedBox(
                      width: 96,
                      child: Semantics(
                        label: spokenOf(id),
                        hint: hintOf(id),
                        excludeSemantics: true,
                        button: true,
                        selected: s.selected == id,
                        child: AnswerTile(
                          key: ValueKey('balance-choice-$id'),
                          label: labelOf(id),
                          state: stateOf(id),
                          onTap:
                              view.enabled && !s.solved && !s.tried.contains(id)
                              ? () => view.dispatch(PickBalanceChoice(id))
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a pan shows: the number or expression, or the counters.
class _PanContent extends StatelessWidget {
  const _PanContent({required this.side, required this.text});
  final BalanceSide side;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final symbol = side.symbol;
    if (symbol != null) {
      return LayoutBuilder(
        builder: (context, box) {
          // Five to a row, sized to the pan, so 20 still fit on a phone.
          final size = math.min(28.0, (box.maxWidth - 8) / 5);
          return Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < side.terms.first!; i++)
                SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: Text(symbol, style: TextStyle(fontSize: size * 0.8)),
                  ),
                ),
            ],
          );
        },
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w800,
          fontSize: 34,
          color: p.ink,
        ),
      ),
    );
  }
}

/// The scale: a post, a beam that tips by [tilt] (−1 left down, 0 level,
/// 1 right down), and two pans hanging from its ends.
class _Scale extends StatelessWidget {
  const _Scale({
    required this.tilt,
    required this.left,
    required this.right,
    required this.middle,
  });

  final int tilt;
  final Widget left;
  final Widget right;
  final String middle;

  static const _angle = 0.14; // ~8°
  static const _beamY = 30.0;
  static const _hang = 16.0;
  static const _panHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final arm = w * 0.3;
        final panWidth = math.min(220.0, w * 0.4);
        final height = _beamY + _hang + _panHeight + arm * 0.15 + 34;
        return SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: tilt * _angle),
            duration: still ? Duration.zero : const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, angle, _) {
              final dy = math.sin(angle) * arm;
              Widget pan(Widget child, double cx, double offset, String key) =>
                  Positioned(
                    key: ValueKey(key),
                    left: cx - panWidth / 2,
                    top: _beamY + _hang + offset,
                    width: panWidth,
                    height: _panHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: Radii.cardMd,
                        border: Border.all(color: p.quebecBlue, width: 3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(child: child),
                      ),
                    ),
                  );
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BeamPainter(
                        angle: angle,
                        arm: arm,
                        beamY: _beamY,
                        hang: _hang,
                        color: p.quebecBlue,
                        post: p.inkMuted,
                      ),
                    ),
                  ),
                  pan(left, w / 2 - arm, -dy, 'balance-pan-left'),
                  pan(right, w / 2 + arm, dy, 'balance-pan-right'),
                  Positioned(
                    left: w / 2 - 26,
                    top: _beamY + _hang + _panHeight / 2 - 26,
                    width: 52,
                    height: 52,
                    child: DecoratedBox(
                      key: const ValueKey('balance-middle'),
                      decoration: BoxDecoration(
                        color: p.goldPale,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.gold, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          middle,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.angle,
    required this.arm,
    required this.beamY,
    required this.hang,
    required this.color,
    required this.post,
  });

  final double angle;
  final double arm;
  final double beamY;
  final double hang;
  final Color color;
  final Color post;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final postPaint = Paint()
      ..color = post
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    // Post and foot.
    canvas.drawLine(Offset(cx, beamY), Offset(cx, size.height - 8), postPaint);
    canvas.drawLine(
      Offset(cx - 40, size.height - 8),
      Offset(cx + 40, size.height - 8),
      postPaint,
    );
    // Beam.
    final dx = math.cos(angle) * arm;
    final dy = math.sin(angle) * arm;
    final beam = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final l = Offset(cx - dx, beamY - dy);
    final r = Offset(cx + dx, beamY + dy);
    canvas.drawLine(l, r, beam);
    // Strings down to the pans.
    final string = Paint()
      ..color = color
      ..strokeWidth = 3;
    canvas.drawLine(l, l.translate(0, hang), string);
    canvas.drawLine(r, r.translate(0, hang), string);
    canvas.drawCircle(Offset(cx, beamY), 9, Paint()..color = post);
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.angle != angle || old.arm != arm || old.color != color;
}

/// Grades a `balance_scale` pick. The right id is derived from the values
/// at parse time, so the content can't disagree with its arithmetic.
class BalanceScaleEvaluator
    implements Evaluator<BalanceContent, SingleChoiceAnswer> {
  const BalanceScaleEvaluator();

  @override
  String get engineKey => BalanceScaleEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    BalanceContent content,
    SingleChoiceAnswer answer,
    EvaluationContext ctx,
  ) {
    final pick = answer.selectedOptionId;
    if (!content.choices.contains(pick)) {
      throw ArgumentError('Unknown choice $pick.');
    }
    final right = pick == content.correctId;
    return EvaluationResult(
      outcome: right ? Outcome.correct : Outcome.incorrect,
      score: right ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: {pick: right},
      errors: right ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
