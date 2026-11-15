import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// What the child is asked to do with the calculator.
enum CalcTask {
  /// Key the given calculation and press =.
  key,

  /// The calculation is already keyed with one mistake: fix it, then =.
  repair,

  /// Reach the answer to a problem in the prompt, by any route.
  solve,
}

/// An exact number: the calculator never shows 0,30000000004.
class Rational {
  Rational(BigInt num, BigInt den) : this._norm(num, den);

  Rational._norm(BigInt n, BigInt d)
    : num = (d.isNegative ? -n : n) ~/ _gcd(n, d),
      den = d.abs() ~/ _gcd(n, d);

  static final zero = Rational(BigInt.zero, BigInt.one);

  final BigInt num;
  final BigInt den;

  static BigInt _gcd(BigInt a, BigInt b) {
    final g = a.gcd(b);
    return g == BigInt.zero ? BigInt.one : g;
  }

  /// "48", "4,5", "−3", "0," (a comma still waiting for digits).
  static Rational? parse(String s) {
    final m = RegExp(r'^(−?)(\d+)(?:,(\d*))?$').firstMatch(s);
    if (m == null) return null;
    final frac = m.group(3) ?? '';
    var n = BigInt.parse('${m.group(2)}$frac');
    if (m.group(1)!.isNotEmpty) n = -n;
    return Rational(n, BigInt.from(10).pow(frac.length));
  }

  Rational operator +(Rational o) =>
      Rational(num * o.den + o.num * den, den * o.den);
  Rational operator -(Rational o) =>
      Rational(num * o.den - o.num * den, den * o.den);
  Rational operator *(Rational o) => Rational(num * o.num, den * o.den);

  /// Null when [o] is zero: the calculator shows E.
  Rational? divide(Rational o) =>
      o.num == BigInt.zero ? null : Rational(num * o.den, den * o.num);

  Rational negate() => Rational(-num, den);

  @override
  bool operator ==(Object other) =>
      other is Rational && other.num == num && other.den == den;

  @override
  int get hashCode => Object.hash(num, den);
}

/// The display's form: a comma, a true minus, at most [_decimals] decimals,
/// rounded half away from zero, trailing zeros dropped. Null when the whole
/// part is longer than the screen.
String? formatNumber(Rational r) {
  const decimals = 8;
  final scale = BigInt.from(10).pow(decimals);
  final negative = r.num.isNegative;
  final abs = r.num.abs();
  // Round half away from zero at 8 decimals.
  final scaled = (abs * scale * BigInt.two + r.den) ~/ (r.den * BigInt.two);
  final whole = scaled ~/ scale;
  if (whole.toString().length > CalculatorContent.screenDigits) return null;
  var frac = (scaled % scale).toString().padLeft(decimals, '0');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final body = frac.isEmpty ? '$whole' : '$whole,$frac';
  return negative && scaled != BigInt.zero ? '−$body' : body;
}

const _ops = {'+', '−', '×', '÷'};
bool _isOp(String t) => _ops.contains(t);

/// Evaluates a keyed line, × and ÷ before + and −. Null for an unfinished
/// line; [divByZero] is set when it divides by zero.
Rational? evaluateLine(List<String> tokens, {List<bool>? divByZero}) {
  if (tokens.isEmpty || tokens.length.isEven) return null;
  final values = <Rational>[];
  final ops = <String>[];
  for (final (i, t) in tokens.indexed) {
    if (i.isEven) {
      final v = Rational.parse(t);
      if (v == null) return null;
      values.add(v);
    } else {
      if (!_isOp(t)) return null;
      ops.add(t);
    }
  }
  // × and ÷ first, left to right.
  final terms = [values.first];
  final adds = <String>[];
  for (final (i, op) in ops.indexed) {
    final v = values[i + 1];
    if (op == '×') {
      terms.last = terms.last * v;
    } else if (op == '÷') {
      final q = terms.last.divide(v);
      if (q == null) {
        divByZero?.add(true);
        return null;
      }
      terms.last = q;
    } else {
      adds.add(op);
      terms.add(v);
    }
  }
  var total = terms.first;
  for (final (i, op) in adds.indexed) {
    total = op == '+' ? total + terms[i + 1] : total - terms[i + 1];
  }
  return total;
}

class CalculatorContent {
  const CalculatorContent({
    required this.task,
    required this.answer,
    this.expression,
    this.start = const [],
    this.memory = false,
    this.sign = false,
    this.decimals = false,
    this.requireMemory = false,
  });

  final CalcTask task;

  /// key and repair: the calculation, as tokens (numbers and + − × ÷).
  final List<String>? expression;

  /// repair: what's already keyed when the question opens.
  final List<String> start;

  /// What the display must show, in its own form ("576", "2,5").
  final String answer;

  /// Keys shown beyond the digits, the four operations, =, C and ⌫.
  final bool memory;
  final bool sign;
  final bool decimals;

  /// solve: the problem is about the memory keys, so MR must be used.
  final bool requireMemory;

  /// Digits in one number, and on the screen's whole part.
  static const numberDigits = 8;
  static const screenDigits = 10;
}

class CalculatorState {
  const CalculatorState({
    required this.tokens,
    this.result,
    this.memory,
    this.recalled = false,
    this.last,
    this.locked = const {},
    this.solved = false,
  });

  /// The keyed line: numbers ("48", "4,5", "−3") and operations.
  final List<String> tokens;

  /// After =: the display's number, or "E" for an error.
  final String? result;

  /// The memory, in the display's form, or null when empty.
  final String? memory;

  /// MR was pressed at least once.
  final bool recalled;

  /// The line = last worked out.
  final List<String>? last;

  final Set<String> locked;
  final bool solved;

  CalculatorState copyWith({
    List<String>? tokens,
    String? Function()? result,
    String? Function()? memory,
    bool? recalled,
    List<String>? last,
    Set<String>? locked,
    bool? solved,
  }) => CalculatorState(
    tokens: tokens ?? this.tokens,
    result: result == null ? this.result : result(),
    memory: memory == null ? this.memory : memory(),
    recalled: recalled ?? this.recalled,
    last: last ?? this.last,
    locked: locked ?? this.locked,
    solved: solved ?? this.solved,
  );
}

/// One key of the calculator.
enum CalcKey {
  d0('0'),
  d1('1'),
  d2('2'),
  d3('3'),
  d4('4'),
  d5('5'),
  d6('6'),
  d7('7'),
  d8('8'),
  d9('9'),
  comma(','),
  add('+'),
  sub('−'),
  mul('×'),
  div('÷'),
  equals('='),
  clear('C'),
  back('⌫'),
  sign('+/−'),
  memoryPlus('M+'),
  memoryMinus('M−'),
  memoryRecall('MR'),
  memoryClear('MC');

  const CalcKey(this.label);
  final String label;

  String get id => name;
  bool get isDigit => index <= CalcKey.d9.index;
  bool get isOp => const {add, sub, mul, div}.contains(this);
  bool get isMemory =>
      const {memoryPlus, memoryMinus, memoryRecall, memoryClear}.contains(this);
}

class PressKey {
  const PressKey(this.key);
  final CalcKey key;
}

/// La calculatrice — the `calculator` engine (ENGINES_NEEDED_2026-11-08 §2
/// item 1; app ADR 0128).
///
/// A school calculator with a two-line screen: the keyed line on top, the
/// result below after =. × and ÷ come before + and −, and numbers are exact,
/// so 0,1 + 0,2 shows 0,3. Three tasks:
/// - `key`: key the given calculation and press =. Graded on the line the
///   child worked out, so typing the answer's digits isn't keying it.
/// - `repair`: the line opens with one mistake already keyed; the child fixes
///   it with ⌫ or C, then presses =.
/// - `solve`: a problem in the prompt, any route; graded on the display. With
///   `require_memory`, MR must have been used.
///
/// The memory keys (M+, M−, MR, MC) and +/− appear only when the content asks
/// for them, and the screen shows what the memory holds.
class CalculatorEngine
    implements
        LearningEngine<
          CalculatorContent,
          CalculatorState,
          PressKey,
          BlanksAnswer
        > {
  const CalculatorEngine();

  static const key = 'calculator';
  static final _number = RegExp(r'^[−-]?\d{1,8}(,\d{1,8})?$');

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  /// "48 × 12" into tokens, or null. Accepts - for −.
  static List<String>? tokensOf(Object? raw, {bool decimals = true}) {
    if (raw is! String) return null;
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.length.isEven) return null;
    final out = <String>[];
    for (final (i, p) in parts.indexed) {
      if (i.isEven) {
        if (!_number.hasMatch(p)) return null;
        if (!decimals && p.contains(',')) return null;
        out.add(p.replaceFirst('-', '−'));
      } else {
        final op = p == '-' ? '−' : p;
        if (!_isOp(op)) return null;
        out.add(op);
      }
    }
    return out;
  }

  @override
  ParseResult<CalculatorContent> parse(Map<String, Object?> config) {
    final task = switch (config['task']) {
      'key' => CalcTask.key,
      'repair' => CalcTask.repair,
      'solve' => CalcTask.solve,
      _ => null,
    };
    if (task == null) {
      return const ParseResult.invalid('task is key, repair or solve.');
    }
    bool flag(String k) => config[k] == true;
    for (final k in ['memory', 'sign', 'decimals', 'require_memory']) {
      if (config[k] != null && config[k] is! bool) {
        return ParseResult.invalid('$k is true or false.');
      }
    }
    final decimals = flag('decimals');
    final memory = flag('memory');
    final sign = flag('sign');
    final requireMemory = flag('require_memory');

    List<String>? expression;
    var start = const <String>[];
    String answer;
    if (task == CalcTask.solve) {
      if (config['expression'] != null || config['start'] != null) {
        return const ParseResult.invalid(
          'solve gives an answer, not an expression or a start.',
        );
      }
      final raw = config['answer'];
      if (raw is! String || !_number.hasMatch(raw)) {
        return const ParseResult.invalid('answer is a number: "576", "2,5".');
      }
      final value = Rational.parse(raw.replaceFirst('-', '−'));
      answer = formatNumber(value!)!;
      if (answer != raw.replaceFirst('-', '−')) {
        return const ParseResult.invalid(
          'answer is written as the screen shows it: no trailing zeros.',
        );
      }
      if (raw.contains(',') && !decimals) {
        return const ParseResult.invalid('A decimal answer needs decimals.');
      }
      if (requireMemory && !memory) {
        return const ParseResult.invalid('require_memory needs memory.');
      }
    } else {
      if (config['answer'] != null) {
        return const ParseResult.invalid(
          'key and repair work the answer out from the expression.',
        );
      }
      if (requireMemory) {
        return const ParseResult.invalid('require_memory is for solve.');
      }
      expression = tokensOf(config['expression'], decimals: decimals);
      if (expression == null || expression.length < 3) {
        return const ParseResult.invalid(
          'expression is a calculation with spaces: "48 × 12".',
        );
      }
      if (expression.any((t) => t.startsWith('−') && t.length > 1) && !sign) {
        return const ParseResult.invalid('A negative number needs sign.');
      }
      final errors = <bool>[];
      final value = evaluateLine(expression, divByZero: errors);
      if (value == null) {
        return const ParseResult.invalid('expression divides by zero.');
      }
      final shown = formatNumber(value);
      if (shown == null) {
        return const ParseResult.invalid('The answer is too long to show.');
      }
      answer = shown;
      if (task == CalcTask.repair) {
        final s = tokensOf(config['start'], decimals: decimals);
        if (s == null) {
          return const ParseResult.invalid(
            'start is the line already keyed, with its mistake: "48 + 12".',
          );
        }
        if (_sameLine(s, expression)) {
          return const ParseResult.invalid(
            'start has no mistake: it is the expression.',
          );
        }
        start = s;
      } else if (config['start'] != null) {
        return const ParseResult.invalid('start is for repair.');
      }
    }
    final hint = config['hint'];
    if (hint != null && hint is! String) {
      return const ParseResult.invalid('hint is a string or null.');
    }
    return ParseResult.ok(
      CalculatorContent(
        task: task,
        expression: expression == null ? null : List.unmodifiable(expression),
        start: List.unmodifiable(start),
        answer: answer,
        memory: memory,
        sign: sign,
        decimals: decimals,
        requireMemory: requireMemory,
      ),
    );
  }

  /// Same calculation: equal numbers and operations, or the two numbers of a
  /// single + or × swapped.
  static bool _sameLine(List<String> a, List<String> b) {
    String norm(String t) =>
        _isOp(t) ? t : formatNumber(Rational.parse(t) ?? Rational.zero)!;
    final x = a.map(norm).toList();
    final y = b.map(norm).toList();
    if (x.length != y.length) return false;
    if (_listEq(x, y)) return true;
    return x.length == 3 &&
        (x[1] == '+' || x[1] == '×') &&
        x[1] == y[1] &&
        x[0] == y[2] &&
        x[2] == y[0];
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  CalculatorState initialize(CalculatorContent content, EngineSeed seed) =>
      CalculatorState(tokens: content.start);

  /// Whether [key] is on this calculator.
  static bool shows(CalculatorContent c, CalcKey key) => switch (key) {
    CalcKey.comma => c.decimals,
    CalcKey.sign => c.sign,
    _ when key.isMemory => c.memory,
    _ => true,
  };

  @override
  Transition<CalculatorState> reduce(CalculatorState s, PressKey action) {
    if (s.solved) return Transition(s);
    final next = press(s, action.key);
    if (next == null) return Transition(s);
    return Transition(next, [
      InteractionEvent('item_placed', {'item_id': action.key.id}),
    ]);
  }

  /// The calculator's behaviour, or null when [key] does nothing here. The
  /// view only offers the keys this content shows.
  static CalculatorState? press(CalculatorState s, CalcKey key) {
    final t = s.tokens;
    final lastIsNumber = t.isNotEmpty && !_isOp(t.last);
    final shown = s.result != null && s.result != 'E' ? s.result : null;

    List<String> replaceLast(String v) => [...t.sublist(0, t.length - 1), v];

    if (key.isDigit) {
      final d = key.label;
      if (s.result != null) {
        return s.copyWith(tokens: [d], result: () => null);
      }
      if (!lastIsNumber) return s.copyWith(tokens: [...t, d]);
      final n = t.last;
      if (n.replaceAll(RegExp(r'\D'), '').length >=
          CalculatorContent.numberDigits) {
        return null;
      }
      if (n == '0') return s.copyWith(tokens: replaceLast(d));
      if (n == '−0') return s.copyWith(tokens: replaceLast('−$d'));
      return s.copyWith(tokens: replaceLast('$n$d'));
    }
    switch (key) {
      case CalcKey.comma:
        if (s.result != null) {
          return s.copyWith(tokens: ['0,'], result: () => null);
        }
        if (!lastIsNumber) return s.copyWith(tokens: [...t, '0,']);
        if (t.last.contains(',')) return null;
        return s.copyWith(tokens: replaceLast('${t.last},'));
      case CalcKey.add || CalcKey.sub || CalcKey.mul || CalcKey.div:
        final op = key.label;
        if (s.result != null) {
          if (shown == null) return null;
          return s.copyWith(tokens: [shown, op], result: () => null);
        }
        if (t.isEmpty) return null;
        if (!lastIsNumber) {
          if (t.last == op) return null;
          return s.copyWith(tokens: replaceLast(op));
        }
        return s.copyWith(tokens: [...t, op]);
      case CalcKey.equals:
        if (s.result != null || !lastIsNumber) return null;
        final value = evaluateLine(t);
        return s.copyWith(
          result: () => value == null ? 'E' : (formatNumber(value) ?? 'E'),
          last: t,
        );
      case CalcKey.back:
        if (s.result != null) return s.copyWith(result: () => null);
        if (t.isEmpty) return null;
        final cut = t.last.substring(0, t.last.length - 1);
        return s.copyWith(
          tokens: cut.isEmpty || cut == '−'
              ? t.sublist(0, t.length - 1)
              : replaceLast(cut),
        );
      case CalcKey.clear:
        if (t.isEmpty && s.result == null) return null;
        return s.copyWith(tokens: const [], result: () => null);
      case CalcKey.sign:
        String flip(String n) => n.startsWith('−') ? n.substring(1) : '−$n';
        if (s.result != null) {
          if (shown == null) return null;
          return s.copyWith(tokens: [flip(shown)], result: () => null);
        }
        if (!lastIsNumber) return null;
        return s.copyWith(tokens: replaceLast(flip(t.last)));
      case CalcKey.memoryPlus || CalcKey.memoryMinus:
        final value = shown != null
            ? Rational.parse(shown)
            : (lastIsNumber ? evaluateLine(t) : null);
        if (value == null) return null;
        final held = Rational.parse(s.memory ?? '0')!;
        final sum = key == CalcKey.memoryPlus ? held + value : held - value;
        final text = formatNumber(sum);
        if (text == null) return null;
        return s.copyWith(memory: () => text);
      case CalcKey.memoryRecall:
        final m = s.memory;
        if (m == null) return null;
        if (s.result != null) {
          return s.copyWith(tokens: [m], result: () => null, recalled: true);
        }
        return s.copyWith(
          tokens: lastIsNumber ? replaceLast(m) : [...t, m],
          recalled: true,
        );
      case CalcKey.memoryClear:
        if (s.memory == null) return null;
        return s.copyWith(memory: () => null);
      default:
        return null;
    }
  }

  @override
  BlanksAnswer? extractAnswer(CalculatorState s) => s.solved || s.result == null
      ? null
      : BlanksAnswer({
          'result': s.result!,
          'line': (s.last ?? const []).join(' '),
          'recalled': s.recalled ? '1' : '0',
        });

  @override
  CalculatorState applyFeedback(CalculatorState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    // The screen stays as it is: the child fixes it from there.
    return s.copyWith(
      locked: {
        ...s.locked,
        for (final e in result.itemResults.entries)
          if (e.value) e.key,
      },
      solved: result.outcome == Outcome.correct,
    );
  }

  @override
  Map<String, Object?> snapshot(CalculatorState s) => {
    'tokens': s.tokens,
    'result': s.result,
    'memory': s.memory,
    'recalled': s.recalled,
    'last': s.last,
    'locked': s.locked.toList(),
    'solved': s.solved,
  };

  @override
  CalculatorState? restore(
    CalculatorContent content,
    Map<String, Object?> snap,
  ) {
    try {
      final tokens = (snap['tokens']! as List).cast<String>();
      for (final (i, tok) in tokens.indexed) {
        final ok = i.isEven ? Rational.parse(tok) != null : _isOp(tok);
        if (!ok) return null;
      }
      final memory = snap['memory'] as String?;
      if (memory != null && Rational.parse(memory) == null) return null;
      return CalculatorState(
        tokens: List.unmodifiable(tokens),
        result: snap['result'] as String?,
        memory: memory,
        recalled: snap['recalled'] == true,
        last: (snap['last'] as List?)?.cast<String>(),
        locked: (snap['locked'] as List? ?? const []).cast<String>().toSet(),
        solved: snap['solved'] == true,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<CalculatorContent, CalculatorState, PressKey> view,
  ) => _CalculatorBoard(view: view);
}

class _CalculatorBoard extends StatelessWidget {
  const _CalculatorBoard({required this.view});
  final EngineView<CalculatorContent, CalculatorState, PressKey> view;

  static const _width = 312.0;

  static String _spoken(CalcKey k, bool fr) => switch (k) {
    CalcKey.comma => fr ? 'virgule' : 'decimal comma',
    CalcKey.add => fr ? 'plus' : 'plus',
    CalcKey.sub => fr ? 'moins' : 'minus',
    CalcKey.mul => fr ? 'multiplié par' : 'times',
    CalcKey.div => fr ? 'divisé par' : 'divided by',
    CalcKey.equals => fr ? 'égal' : 'equals',
    CalcKey.clear => fr ? 'tout effacer' : 'clear all',
    CalcKey.back => fr ? 'effacer un chiffre' : 'delete one',
    CalcKey.sign => fr ? 'changer le signe' : 'change the sign',
    CalcKey.memoryPlus => fr ? 'ajouter à la mémoire' : 'add to memory',
    CalcKey.memoryMinus =>
      fr ? 'enlever de la mémoire' : 'subtract from memory',
    CalcKey.memoryRecall => fr ? 'rappeler la mémoire' : 'recall memory',
    CalcKey.memoryClear => fr ? 'vider la mémoire' : 'clear memory',
    _ => k.label,
  };

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final s = view.state;
    final c = view.content;
    final on = view.enabled && !s.solved;

    Widget key(CalcKey k) => Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: 52,
        child: AnswerTile(
          key: ValueKey('calc-key-${k.id}'),
          label: k.label,
          dense: true,
          semanticsState: k.isDigit ? null : _spoken(k, fr),
          state: AnswerTileState.idle,
          onTap: on && CalculatorEngine.press(s, k) != null
              ? () => view.dispatch(PressKey(k))
              : null,
        ),
      ),
    );

    /// A row of keys; a key listed twice spans two columns.
    Widget row(List<CalcKey> keys) {
      final cells = <(CalcKey, int)>[];
      for (final k in keys) {
        if (cells.isNotEmpty && cells.last.$1 == k) {
          cells.last = (k, cells.last.$2 + 1);
        } else {
          cells.add((k, 1));
        }
      }
      return Row(
        children: [
          for (final (k, flex) in cells) Expanded(flex: flex, child: key(k)),
        ],
      );
    }

    final line = s.tokens.join(' ');
    final display = Semantics(
      container: true,
      liveRegion: true,
      label: [
        if (line.isNotEmpty) line,
        if (s.result != null) '= ${s.result}',
        if (s.memory != null) '${fr ? 'mémoire' : 'memory'} ${s.memory}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('calc-screen'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: Radii.cardMd,
            border: Border.all(color: p.line, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (s.memory != null)
                    Text(
                      'M = ${s.memory}',
                      key: const ValueKey('calc-memory'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.quebecBlue,
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      line,
                      key: const ValueKey('calc-line'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.result ?? (s.tokens.isEmpty ? '0' : ''),
                key: const ValueKey('calc-result'),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                  height: 1.1,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final back = c.sign
        ? [CalcKey.clear, CalcKey.back, CalcKey.sign, CalcKey.div]
        : [CalcKey.clear, CalcKey.back, CalcKey.back, CalcKey.div];
    final bottom = c.decimals
        ? [CalcKey.d0, CalcKey.comma, CalcKey.equals, CalcKey.equals]
        : [CalcKey.d0, CalcKey.d0, CalcKey.equals, CalcKey.equals];

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          key: const ValueKey('calc-board'),
          width: _width,
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                display,
                const SizedBox(height: 8),
                if (c.memory)
                  row(const [
                    CalcKey.memoryClear,
                    CalcKey.memoryRecall,
                    CalcKey.memoryMinus,
                    CalcKey.memoryPlus,
                  ]),
                row(back),
                row(const [CalcKey.d7, CalcKey.d8, CalcKey.d9, CalcKey.mul]),
                row(const [CalcKey.d4, CalcKey.d5, CalcKey.d6, CalcKey.sub]),
                row(const [CalcKey.d1, CalcKey.d2, CalcKey.d3, CalcKey.add]),
                row(bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grades the calculator.
///
/// key and repair: right when the line worked out is the asked calculation
/// (the two numbers of a single + or × may be swapped). A wrong digit or
/// operation names `math.calculator.key_misread`; the right keys in another
/// order name `math.calculator.key_order`.
///
/// solve: right when the screen shows the answer. With `require_memory`, a
/// right answer reached without MR is partial and names
/// `math.calculator.memory_not_used`.
class CalculatorEvaluator
    implements Evaluator<CalculatorContent, BlanksAnswer> {
  const CalculatorEvaluator();

  @override
  String get engineKey => CalculatorEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    CalculatorContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final shown = answer.blanks['result'] ?? '';
    final line =
        CalculatorEngine.tokensOf(answer.blanks['line'], decimals: true) ??
        const <String>[];
    final items = <String, bool>{};
    String? slip;
    if (content.task == CalcTask.solve) {
      items['result'] = shown == content.answer;
      if (content.requireMemory) {
        items['memory'] = answer.blanks['recalled'] == '1';
        if (items['result']! && !items['memory']!) {
          slip = 'math.calculator.memory_not_used';
        }
      }
    } else {
      final expected = content.expression!;
      final right =
          shown == content.answer && CalculatorEngine._sameLine(line, expected);
      items['result'] = right;
      if (!right && line.length == expected.length) {
        final mine = [...line]..sort();
        final theirs = [...expected]..sort();
        slip = CalculatorEngine._listEq(mine, theirs)
            ? 'math.calculator.key_order'
            : 'math.calculator.key_misread';
      }
    }
    final hits = items.values.where((v) => v).length;
    final all = hits == items.length;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / items.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      feedbackCode: all ? null : slip,
      errors: all
          ? const []
          : [
              slip == null
                  ? const ErrorClassification.unclassified()
                  : ErrorClassification(code: slip, taxonomyVersion: 1),
            ],
    );
  }
}
