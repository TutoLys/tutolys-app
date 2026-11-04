import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// The four written operations the PFEQ asks for in grades 2-6.
enum ColumnOp {
  add('+'),
  sub('−'),
  mul('×'),
  div('÷');

  const ColumnOp(this.symbol);
  final String symbol;

  static ColumnOp? parse(Object? v) => switch (v) {
    'add' => add,
    'sub' => sub,
    'mul' => mul,
    'div' => div,
    _ => null,
  };
}

/// What a row of cells is for.
enum ColumnRowKind {
  /// Small boxes above the columns: carries, borrows. Never graded: a
  /// scaffold the child may use or not.
  scratch,

  /// A product of the multiplicand by one digit of the multiplier.
  partial,

  /// The answer: a sum, a difference, a product, a quotient.
  result,

  /// What's left after a division.
  remainder,
}

/// A row of cells to fill. Cell `i` counts from the right: 0 is the units
/// column (or the last decimal place, for a decimal sum).
class ColumnRow {
  const ColumnRow({
    required this.id,
    required this.kind,
    required this.expected,
    this.optionalLeading = 0,
  });

  final String id;
  final ColumnRowKind kind;

  /// The right digit of each cell, right to left. Empty for scratch rows.
  final List<String> expected;

  /// Leading cells a child may leave empty (they mean 0): a remainder row
  /// is as wide as the divisor, so its width never gives the answer away.
  final int optionalLeading;

  int get width => expected.length;

  bool optional(int i) => i >= width - optionalLeading;
  bool get graded => kind != ColumnRowKind.scratch;

  String cell(int i) => '${id}_$i';
}

class ColumnContent {
  const ColumnContent({
    required this.op,
    required this.operands,
    required this.decimals,
    required this.rows,
    required this.columns,
    this.scratchWidth = 0,
  });

  final ColumnOp op;

  /// The operands as written, without the decimal comma.
  final List<String> operands;

  /// Decimal places, for a sum or a difference of decimals; 0 otherwise.
  final int decimals;

  /// Graded rows, top to bottom.
  final List<ColumnRow> rows;

  /// How many digit columns the grid needs.
  final int columns;

  /// Scratch boxes above the operands (0: none).
  final int scratchWidth;

  /// Cells VALIDER waits for.
  Iterable<String> get requiredCells => [
    for (final r in rows)
      for (var i = 0; i < r.width; i++)
        if (!r.optional(i)) r.cell(i),
  ];

  Iterable<String> get gradedCells => [
    for (final r in rows)
      for (var i = 0; i < r.width; i++) r.cell(i),
  ];

  String? expectedFor(String cell) {
    for (final r in rows) {
      for (var i = 0; i < r.width; i++) {
        if (r.cell(i) == cell) return r.expected[i];
      }
    }
    return null;
  }

  BigInt get a => BigInt.parse(operands[0]);
  BigInt get b => BigInt.parse(operands[1]);
}

class ColumnState {
  const ColumnState({
    required this.order,
    this.required = const {},
    this.cells = const {},
    this.active,
    this.locked = const {},
  });

  /// Every cell a digit can go in, in filling order (right to left, row
  /// by row), scratch boxes last. The reducer refuses any other cell.
  final List<String> order;

  /// The graded cells VALIDER waits for (not a remainder's leading ones).
  final Set<String> required;

  /// Cell id → digit.
  final Map<String, String> cells;

  /// The cell the next digit goes in.
  final String? active;

  /// Cells checked right.
  final Set<String> locked;

  /// Where a digit goes when nothing is selected: the first empty graded
  /// cell in filling order.
  String? get next {
    for (final c in order) {
      if (!c.startsWith('s_') && !cells.containsKey(c)) return c;
    }
    return null;
  }

  ColumnState copyWith({
    Map<String, String>? cells,
    String? active,
    bool clearActive = false,
    Set<String>? locked,
  }) => ColumnState(
    order: order,
    required: required,
    cells: cells ?? this.cells,
    active: clearActive ? null : (active ?? this.active),
    locked: locked ?? this.locked,
  );
}

sealed class ColumnAction {
  const ColumnAction();
}

/// Select a cell.
class TapColumnCell extends ColumnAction {
  const TapColumnCell(this.cell);
  final String cell;
}

/// A digit from the keypad goes in the selected cell (or the next one).
class TapColumnDigit extends ColumnAction {
  const TapColumnDigit(this.digit);
  final String digit;
}

/// Empty the selected cell.
class EraseColumnCell extends ColumnAction {
  const EraseColumnCell();
}

/// Le calcul en colonnes — the `column_calc` engine (plan
/// PLAN_GRADES_2_6_ENGINES §2.2 #10, app ADR 0121).
///
/// A written operation, laid out the way a Québec classroom writes it:
/// addition and subtraction (naturals, or decimals aligned on the comma),
/// multiplication with one row per digit of a two-digit multiplier (the
/// shifted row's 0 included), and division with the divisor on the right
/// and the quotient under it. The child fills one digit at a time from a
/// 0-9 keypad (tapped, never typed), right to left. Small scratch boxes
/// above the columns take carries and borrows and are never graded.
///
/// There is no answer key: the expected digits are computed here, so a
/// lesson can't get them wrong. Every graded cell is an item. When a
/// wrong answer is a known slip (the carry forgotten, the smaller digit
/// taken from the larger, the second partial product not shifted, a
/// remainder too big) the verdict names it.
class ColumnCalcEngine
    implements
        LearningEngine<ColumnContent, ColumnState, ColumnAction, BlanksAnswer> {
  const ColumnCalcEngine();

  static const key = 'column_calc';
  static final _number = RegExp(r'^\d{1,6}(,\d{1,2})?$');
  static const _digits = '0123456789';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<ColumnContent> parse(Map<String, Object?> config) {
    final op = ColumnOp.parse(config['op']);
    if (op == null) {
      return const ParseResult.unsupported('op is add, sub, mul or div.');
    }
    final raw = config['operands'];
    if (raw is! List ||
        raw.length != 2 ||
        !raw.every((o) => o is String && _number.hasMatch(o))) {
      return const ParseResult.invalid(
        'operands are two numbers as strings: "503", or "12,5".',
      );
    }
    final texts = raw.cast<String>();
    final hint = config['hint'];
    if (hint != null && hint is! String) {
      return const ParseResult.invalid('hint is a string or null.');
    }
    final scratch = config['show_carries'] != false;
    final decimals = texts
        .map((t) => t.contains(',') ? t.split(',')[1].length : 0)
        .fold(0, (a, b) => a > b ? a : b);
    if (decimals > 0 && (op == ColumnOp.mul || op == ColumnOp.div)) {
      return const ParseResult.unsupported(
        'Decimal products and quotients come in a later version.',
      );
    }
    String scaled(String t) {
      final parts = t.split(',');
      final frac = parts.length == 2 ? parts[1] : '';
      return parts[0] + frac.padRight(decimals, '0');
    }

    final ops = [for (final t in texts) scaled(t)];
    final a = BigInt.parse(ops[0]);
    final b = BigInt.parse(ops[1]);
    List<String> digitsOf(BigInt n, {int min = 1}) {
      final s = n.toString().padLeft(min, '0');
      return [for (var i = s.length - 1; i >= 0; i--) s[i]];
    }

    final rows = <ColumnRow>[];
    var columns = 0;
    switch (op) {
      case ColumnOp.add:
        rows.add(
          ColumnRow(
            id: 'r',
            kind: ColumnRowKind.result,
            expected: digitsOf(a + b, min: decimals + 1),
          ),
        );
      case ColumnOp.sub:
        if (b > a) {
          return const ParseResult.invalid(
            'A subtraction takes the smaller number from the larger.',
          );
        }
        rows.add(
          ColumnRow(
            id: 'r',
            kind: ColumnRowKind.result,
            expected: digitsOf(a - b, min: decimals + 1),
          ),
        );
      case ColumnOp.mul:
        if (ops[1].length > 2 || ops[0].length > 4 || b == BigInt.zero) {
          return const ParseResult.invalid(
            'A product is up to 4 digits by 1 or 2 digits, not by 0.',
          );
        }
        if (ops[1].length == 2) {
          final units = BigInt.from(int.parse(ops[1][1]));
          final tens = BigInt.from(int.parse(ops[1][0]));
          rows
            ..add(
              ColumnRow(
                id: 'p0',
                kind: ColumnRowKind.partial,
                expected: digitsOf(a * units),
              ),
            )
            ..add(
              ColumnRow(
                id: 'p1',
                kind: ColumnRowKind.partial,
                // The shifted row, its 0 written.
                expected: digitsOf(a * tens * BigInt.from(10), min: 2),
              ),
            );
        }
        rows.add(
          ColumnRow(
            id: 'r',
            kind: ColumnRowKind.result,
            expected: digitsOf(a * b),
          ),
        );
      case ColumnOp.div:
        if (ops[0].length > 4 || ops[1].length > 2 || b == BigInt.zero) {
          return const ParseResult.invalid(
            'A division is up to 4 digits by 1 or 2 digits, not by 0.',
          );
        }
        if (a < b) {
          return const ParseResult.invalid(
            'The dividend is at least the divisor.',
          );
        }
        rows
          ..add(
            ColumnRow(
              id: 'q',
              kind: ColumnRowKind.result,
              expected: digitsOf(a ~/ b),
            ),
          )
          ..add(_remainderRow(a.remainder(b), ops[1].length));
    }
    for (final t in [...ops, for (final r in rows) r.expected.join()]) {
      if (t.length > columns) columns = t.length;
    }
    return ParseResult.ok(
      ColumnContent(
        op: op,
        operands: List.unmodifiable(ops),
        decimals: decimals,
        rows: List.unmodifiable(rows),
        columns: columns,
        scratchWidth: scratch && op != ColumnOp.div ? columns : 0,
      ),
    );
  }

  static ColumnRow _remainderRow(BigInt rem, int width) {
    final digits = rem.toString();
    final padded = digits.padLeft(width, '0');
    return ColumnRow(
      id: 'm',
      kind: ColumnRowKind.remainder,
      expected: [for (var i = padded.length - 1; i >= 0; i--) padded[i]],
      optionalLeading: padded.length - digits.length,
    );
  }

  @override
  ColumnState initialize(ColumnContent content, EngineSeed seed) =>
      ColumnState(order: _order(content), required: _required(content));

  static Set<String> _required(ColumnContent c) =>
      Set.unmodifiable(c.requiredCells);

  static List<String> _order(ColumnContent c) => List.unmodifiable([
    for (final r in c.rows)
      for (var i = 0; i < r.width; i++) r.cell(i),
    for (var i = 0; i < c.scratchWidth; i++) 's_$i',
  ]);

  @override
  Transition<ColumnState> reduce(ColumnState s, ColumnAction action) {
    switch (action) {
      case TapColumnCell(:final cell):
        if (!s.order.contains(cell) || s.locked.contains(cell)) {
          return Transition(s);
        }
        return Transition(s.copyWith(active: cell), [
          InteractionEvent('option_selected', {'option_id': cell}),
        ]);
      case TapColumnDigit(:final digit):
        final target = s.active ?? s.next;
        if (digit.length != 1 ||
            !_digits.contains(digit) ||
            target == null ||
            s.locked.contains(target)) {
          return Transition(s);
        }
        final cells = {...s.cells, target: digit};
        // Written right to left: the next cell along the row, else the
        // next empty one.
        final at = s.order.indexOf(target);
        String? next;
        if (!target.startsWith('s_') &&
            at + 1 < s.order.length &&
            s.order[at + 1].split('_').first == target.split('_').first &&
            !cells.containsKey(s.order[at + 1])) {
          next = s.order[at + 1];
        }
        return Transition(
          s.copyWith(cells: cells, active: next, clearActive: next == null),
          [
            InteractionEvent('item_placed', {
              'item_id': digit,
              'bucket_id': target,
            }),
          ],
        );
      case EraseColumnCell():
        final target = s.active;
        if (target == null ||
            s.locked.contains(target) ||
            !s.cells.containsKey(target)) {
          return Transition(s);
        }
        return Transition(s.copyWith(cells: Map.of(s.cells)..remove(target)), [
          InteractionEvent('item_removed', {'bucket_id': target}),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(ColumnState s) {
    if (!s.required.every(s.cells.containsKey)) return null;
    if (s.required.every(s.locked.contains)) return null;
    return BlanksAnswer({
      for (final e in s.cells.entries)
        if (!e.key.startsWith('s_')) e.key: e.value,
    });
  }

  @override
  ColumnState applyFeedback(ColumnState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {...s.locked};
    final cells = <String, String>{};
    for (final e in s.cells.entries) {
      final verdict = result.itemResults[e.key];
      if (locked.contains(e.key) || verdict == true) {
        locked.add(e.key);
        cells[e.key] = e.value;
      } else if (verdict == null) {
        // Scratch boxes stay: they're the child's working.
        cells[e.key] = e.value;
      }
    }
    return s.copyWith(cells: cells, locked: locked, clearActive: true);
  }

  @override
  Map<String, Object?> snapshot(ColumnState s) => {
    'cells': s.cells,
    'active': s.active,
    'locked': s.locked.toList(),
  };

  @override
  ColumnState? restore(ColumnContent content, Map<String, Object?> snap) {
    try {
      final order = _order(content);
      final cells = Map<String, String>.from(snap['cells'] as Map? ?? const {});
      final active = snap['active'] as String?;
      final locked = (snap['locked'] as List? ?? const [])
          .cast<String>()
          .toSet();
      if (!cells.keys.every(order.contains) ||
          !cells.values.every((d) => d.length == 1 && _digits.contains(d)) ||
          (active != null && !order.contains(active)) ||
          !locked.every((c) => cells[c] == content.expectedFor(c))) {
        return null;
      }
      return ColumnState(
        order: order,
        required: _required(content),
        cells: cells,
        active: active,
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<ColumnContent, ColumnState, ColumnAction> view,
  ) => _ColumnBoard(view: view);
}

class _ColumnBoard extends StatelessWidget {
  const _ColumnBoard({required this.view});
  final EngineView<ColumnContent, ColumnState, ColumnAction> view;

  static const _cell = 44.0;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final c = view.content;
    final s = view.state;
    final target = view.enabled ? (s.active ?? s.next) : null;
    final digitStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 28,
      color: p.ink,
    );

    /// One column position, right to left; [i] 0 is the units (or the last
    /// decimal place).
    Widget printed(String digit) => SizedBox(
      width: _cell,
      height: _cell,
      child: Center(child: Text(digit, style: digitStyle)),
    );

    Widget box(String id, {bool small = false, String? spoken}) {
      final digit = s.cells[id];
      final locked = s.locked.contains(id);
      final active = target == id;
      final size = small ? 30.0 : _cell - 4;
      return SizedBox(
        width: _cell,
        height: small ? 34 : _cell,
        child: Center(
          child: Semantics(
            button: !locked,
            selected: active,
            label: spoken ?? id,
            value: digit ?? (fr ? 'vide' : 'empty'),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('column-cell-$id'),
              borderRadius: BorderRadius.circular(8),
              onTap: view.enabled && !locked
                  ? () => view.dispatch(TapColumnCell(id))
                  : null,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: locked
                      ? p.successPale
                      : small
                      ? Colors.transparent
                      : p.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? p.quebecBlueBright
                        : locked
                        ? p.success
                        : p.line,
                    width: active ? 3 : (small ? 1 : 2),
                  ),
                ),
                child: Text(
                  digit ?? '',
                  style: small
                      ? digitStyle.copyWith(fontSize: 16, color: p.quebecBlue)
                      : digitStyle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Agrees with the prompt, so the lesson's language, not the app's. Config
    // always stores the comma.
    final separator = view.contentLocale.languageCode == 'fr' ? ',' : '.';

    /// A line of [width] columns, right-aligned, with the decimal separator.
    Widget line(List<Widget> rightToLeft, {Widget? lead}) {
      final cells = <Widget>[];
      for (var i = c.columns - 1; i >= 0; i--) {
        cells.add(
          i < rightToLeft.length
              ? rightToLeft[i]
              : const SizedBox(width: _cell),
        );
        if (c.decimals > 0 && i == c.decimals) {
          cells.add(
            SizedBox(
              width: 12,
              child: Text(
                separator,
                style: digitStyle,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _cell,
            child: Center(child: lead),
          ),
          ...cells,
        ],
      );
    }

    List<Widget> operandCells(String digits) => [
      for (var i = digits.length - 1; i >= 0; i--) printed(digits[i]),
    ];

    Widget rule() => Container(
      height: 3,
      width: _cell * (c.columns + 1) + (c.decimals > 0 ? 12 : 0),
      color: p.ink,
    );

    String spoken(ColumnRow r, int i) {
      final row = switch (r.kind) {
        ColumnRowKind.result =>
          c.op == ColumnOp.div
              ? (fr ? 'quotient' : 'quotient')
              : (fr ? 'résultat' : 'answer'),
        ColumnRowKind.partial =>
          r.id == 'p0'
              ? (fr ? 'premier produit' : 'first product')
              : (fr ? 'deuxième produit' : 'second product'),
        ColumnRowKind.remainder => fr ? 'reste' : 'remainder',
        ColumnRowKind.scratch => fr ? 'retenue' : 'carry',
      };
      return fr
          ? '$row, chiffre ${i + 1} depuis la droite'
          : '$row, digit ${i + 1} from the right';
    }

    List<Widget> rowBoxes(ColumnRow r) => [
      for (var i = 0; i < r.width; i++) box(r.cell(i), spoken: spoken(r, i)),
    ];

    final Widget board;
    if (c.op == ColumnOp.div) {
      final q = c.rows.firstWhere((r) => r.id == 'q');
      final m = c.rows.firstWhere((r) => r.id == 'm');
      Widget digits(String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final d in t.split('')) printed(d)],
      );
      Widget boxes(ColumnRow r) => Row(
        mainAxisSize: MainAxisSize.min,
        children: rowBoxes(r).reversed.toList(),
      );
      board = Row(
        key: const ValueKey('column-board'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              digits(c.operands[0]),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fr ? 'Reste ' : 'Left over ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: p.inkMuted,
                    ),
                  ),
                  boxes(m),
                ],
              ),
            ],
          ),
          Container(width: 3, height: _cell * 2 + 30, color: p.ink),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              digits(c.operands[1]),
              Container(
                height: 3,
                width:
                    _cell *
                    (q.width > c.operands[1].length
                        ? q.width
                        : c.operands[1].length),
                color: p.ink,
              ),
              const SizedBox(height: 4),
              boxes(q),
            ],
          ),
        ],
      );
    } else {
      final children = <Widget>[
        if (c.scratchWidth > 0)
          line([
            for (var i = 0; i < c.scratchWidth; i++)
              box(
                's_$i',
                small: true,
                spoken: spoken(
                  const ColumnRow(
                    id: 's',
                    kind: ColumnRowKind.scratch,
                    expected: [],
                  ),
                  i,
                ),
              ),
          ]),
        line(operandCells(c.operands[0])),
        line(
          operandCells(c.operands[1]),
          lead: Text(c.op.symbol, style: digitStyle),
        ),
        rule(),
      ];
      for (final r in c.rows) {
        children.add(line(rowBoxes(r)));
        if (r.id == 'p1') children.add(rule());
      }
      board = FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          key: const ValueKey('column-board'),
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    }

    Widget key(String label, VoidCallback? onTap, {String? id}) => SizedBox(
      width: 60,
      height: 56,
      child: AnswerTile(
        key: ValueKey('column-key-${id ?? label}'),
        label: label,
        dense: true,
        state: AnswerTileState.idle,
        onTap: onTap,
      ),
    );

    final canType =
        view.enabled && target != null && !s.locked.contains(target);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: board),
              const SizedBox(height: 20),
              Wrap(
                key: const ValueKey('column-keypad'),
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final d in '1234567890'.split(''))
                    key(
                      d,
                      canType ? () => view.dispatch(TapColumnDigit(d)) : null,
                    ),
                  key(
                    '⌫',
                    view.enabled &&
                            s.active != null &&
                            s.cells.containsKey(s.active) &&
                            !s.locked.contains(s.active)
                        ? () => view.dispatch(const EraseColumnCell())
                        : null,
                    id: 'erase',
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

/// Grades a written operation: one item per graded cell, the expected
/// digit computed from the operands. A whole wrong answer that matches a
/// known slip is named (`feedbackCode` and the error's code):
/// - `math.add.no_regroup`: every column added, no carry kept;
/// - `math.sub.smaller_from_larger`: each column's smaller digit taken from
///   its larger;
/// - `math.mul.partial_not_shifted`: the second product written without
///   its 0;
/// - `math.div.remainder_too_big`: a remainder at least the divisor.
class ColumnCalcEvaluator implements Evaluator<ColumnContent, BlanksAnswer> {
  const ColumnCalcEvaluator();

  /// The codes this evaluator can name (backend diagnosis taxonomy v1).
  static const codes = [
    'math.add.no_regroup',
    'math.sub.smaller_from_larger',
    'math.mul.partial_not_shifted',
    'math.div.remainder_too_big',
  ];

  @override
  String get engineKey => ColumnCalcEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    ColumnContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final given = answer.blanks;
    if (given.isEmpty) throw ArgumentError('An answer must fill something.');
    final cells = content.gradedCells.toList();
    final required = content.requiredCells.toSet();
    final items = {
      for (final cell in cells)
        if (given.containsKey(cell) || !required.contains(cell))
          cell: (given[cell] ?? '0') == content.expectedFor(cell),
    };
    final hits = items.values.where((v) => v).length;
    final all = hits == cells.length;
    final slip = all ? null : _slip(content, given);
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / cells.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      feedbackCode: slip,
      errors: all
          ? const []
          : [
              slip == null
                  ? const ErrorClassification.unclassified()
                  : ErrorClassification(code: slip, taxonomyVersion: 1),
            ],
    );
  }

  /// The number the child wrote in [row], or null if a cell is missing.
  static BigInt? _written(ColumnRow row, Map<String, String> given) {
    final digits = <String>[];
    for (var i = row.width - 1; i >= 0; i--) {
      final d = given[row.cell(i)] ?? (row.optional(i) ? '0' : null);
      if (d == null) return null;
      digits.add(d);
    }
    return BigInt.parse(digits.join());
  }

  static String? _slip(ColumnContent c, Map<String, String> given) {
    ColumnRow rowOf(String id) => c.rows.firstWhere((r) => r.id == id);
    String column(String n, int i) => i < n.length ? n[n.length - 1 - i] : '0';
    int d(String n, int i) => int.parse(column(n, i));
    final width = c.columns;
    switch (c.op) {
      case ColumnOp.add:
        final wrote = _written(rowOf('r'), given);
        if (wrote == null) return null;
        final noCarry = StringBuffer();
        for (var i = width - 1; i >= 0; i--) {
          noCarry.write((d(c.operands[0], i) + d(c.operands[1], i)) % 10);
        }
        return wrote == BigInt.parse(noCarry.toString())
            ? 'math.add.no_regroup'
            : null;
      case ColumnOp.sub:
        final wrote = _written(rowOf('r'), given);
        if (wrote == null) return null;
        final flipped = StringBuffer();
        for (var i = width - 1; i >= 0; i--) {
          flipped.write((d(c.operands[0], i) - d(c.operands[1], i)).abs());
        }
        return wrote == BigInt.parse(flipped.toString())
            ? 'math.sub.smaller_from_larger'
            : null;
      case ColumnOp.mul:
        if (!c.rows.any((r) => r.id == 'p1')) return null;
        final wrote = _written(rowOf('p1'), given);
        if (wrote == null) return null;
        final tens = BigInt.from(int.parse(c.operands[1][0]));
        return wrote == c.a * tens ? 'math.mul.partial_not_shifted' : null;
      case ColumnOp.div:
        final wrote = _written(rowOf('m'), given);
        return wrote != null && wrote >= c.b
            ? 'math.div.remainder_too_big'
            : null;
    }
  }
}
