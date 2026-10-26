import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../pattern_machine/pattern_machine_engine.dart';

enum CountersMode { free, plates, array }

/// What the final board must show. Every key that is set must hold; the
/// order of the child's moves never matters.
class CountersTarget {
  const CountersTarget({
    this.total,
    this.mat,
    this.perPlate,
    this.plates,
    this.removed,
    this.rows,
    this.cols,
    this.eitherWay = false,
    this.platesAnyOrder = false,
  });

  final int? total;

  /// Counters left loose on the mat.
  final int? mat;

  /// Every plate holds this many: equal groups, a fair share.
  final int? perPlate;

  /// Each plate, in order.
  final List<int>? plates;

  /// How many were taken off the board (start total − final total).
  final int? removed;
  final int? rows;
  final int? cols;

  /// rows × cols and cols × rows are both right.
  final bool eitherWay;

  /// [plates] compared as a multiset: 3 in frame 1 and 10 in frame 2 shows
  /// 13 as well as the other way round. The default on ten-frames.
  final bool platesAnyOrder;
}

/// A board state a lesson expects as a typical mistake, and what it means.
class CountersNearMiss {
  const CountersNearMiss({required this.when, required this.diagnosis});

  /// Metric → value, with the same keys as a target (`total`, `mat`,
  /// `per_plate`, `removed`, `rows`, `cols`).
  final Map<String, int> when;
  final ErrorClassification diagnosis;
}

class CountersContent {
  const CountersContent({
    required this.mode,
    required this.target,
    this.plates = 0,
    this.startMat = 0,
    this.startPlates = const [],
    this.supply = true,
    this.tenFrames = false,
    this.maxRows = 6,
    this.maxCols = 6,
    this.counter = const PatternPiece.shape(
      shape: PatternShape.circle,
      color: PatternColor.red,
    ),
    this.symbol,
    this.nearMisses = const [],
  });

  final CountersMode mode;
  final CountersTarget target;
  final int plates;
  final int startMat;
  final List<int> startPlates;

  /// A reserve the child can take counters from. Off for a take-away
  /// story: only what's on the board can be used.
  final bool supply;

  /// Plates are drawn as ten-frames (2 rows of 5) and hold 10 at most.
  final bool tenFrames;
  final int maxRows;
  final int maxCols;

  /// How a counter looks: a drawn piece, or [symbol] (an emoji, a letter)
  /// when the lesson gives one.
  final PatternPiece counter;
  final String? symbol;
  final List<CountersNearMiss> nearMisses;

  /// The loose mat is on the board in free mode, or when counters start
  /// there (a pile to share out).
  bool get hasMat => mode == CountersMode.free || startMat > 0;

  int get startTotal => startMat + startPlates.fold<int>(0, (a, b) => a + b);

  int get plateCap => tenFrames ? 10 : 20;

  static const maxTotal = 40;
}

class CountersState {
  const CountersState({
    required this.content,
    required this.mat,
    required this.plates,
    this.rows = 0,
    this.cols = 0,
    this.active = 0,
    this.solved = false,
  });

  /// The rules the reducer enforces (caps, the reserve).
  final CountersContent content;
  final int mat;
  final List<int> plates;
  final int rows;
  final int cols;

  /// The plate "+" on the mat's pile feeds (sharing out).
  final int active;
  final bool solved;

  int get total => content.mode == CountersMode.array
      ? rows * cols
      : mat + plates.fold<int>(0, (a, b) => a + b);

  CountersState copyWith({
    int? mat,
    List<int>? plates,
    int? rows,
    int? cols,
    int? active,
    bool? solved,
  }) => CountersState(
    content: content,
    mat: mat ?? this.mat,
    plates: plates ?? this.plates,
    rows: rows ?? this.rows,
    cols: cols ?? this.cols,
    active: active ?? this.active,
    solved: solved ?? this.solved,
  );
}

/// Where counters sit: the mat is [CountersArea.mat], plates are 0..n-1,
/// and the reserve is [CountersArea.reserve].
abstract final class CountersArea {
  static const mat = -1;
  static const reserve = -2;
}

sealed class CountersAction {
  const CountersAction();
}

/// One counter into [area]: from the mat's pile when filling a plate and
/// the pile has some, else from the reserve.
class AddCounter extends CountersAction {
  const AddCounter(this.area);
  final int area;
}

/// One counter out of [area]: a plate's goes back to the mat (when there
/// is one), the mat's goes away.
class TakeCounter extends CountersAction {
  const TakeCounter(this.area);
  final int area;
}

/// A dragged counter, from one area to another (the reserve included).
class MoveCounter extends CountersAction {
  const MoveCounter(this.from, this.to);
  final int from;
  final int to;
}

class SetRows extends CountersAction {
  const SetRows(this.rows);
  final int rows;
}

class SetCols extends CountersAction {
  const SetCols(this.cols);
  final int cols;
}

/// "Le plateau de jetons" — the `counters_board` engine (app ADR 0084;
/// requested by the Questions Maker for strand 2).
///
/// Manipulatives for a short story problem: counters on a mat, in N
/// plates, or laid out in rows and columns.
/// - `free`: add or take away on one mat ("Léa a 7 billes, elle en
///   donne 3").
/// - `plates`: put counters into plates — equal groups, sharing a pile
///   fairly, groups of ten on ten-frames.
/// - `array`: set rows × columns.
///
/// Graded on the final board against a `target` (total, mat, count per
/// plate, each plate, how many removed, rows and columns), never on the
/// moves. A wrong board that matches a declared `near_miss` (3 per plate
/// instead of 4, rows and columns swapped) carries that near miss's
/// diagnosis; any other wrong board is unclassified.
class CountersBoardEngine
    implements
        LearningEngine<
          CountersContent,
          CountersState,
          CountersAction,
          BlanksAnswer
        > {
  const CountersBoardEngine();

  static const key = 'counters_board';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Every area has + and − buttons and speaks its count; dragging is a
    // shortcut, never the only way.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static const _metricKeys = {
    'total',
    'mat',
    'per_plate',
    'removed',
    'rows',
    'cols',
  };

  static int? _count(Object? v, {int max = CountersContent.maxTotal}) =>
      v is int && v >= 0 && v <= max ? v : null;

  @override
  ParseResult<CountersContent> parse(Map<String, Object?> config) {
    final mode = CountersMode.values.asNameMap()[config['mode'] ?? 'free'];
    if (mode == null) {
      return const ParseResult.invalid('mode is free, plates or array.');
    }
    final tenFrames = config['ten_frames'] == true;
    final supply = config['supply'] is bool ? config['supply']! as bool : true;

    var plates = 0;
    if (mode == CountersMode.plates) {
      final p = config['plates'];
      if (p is! int || p < 1 || p > 6) {
        return const ParseResult.invalid('plates is 1 to 6.');
      }
      plates = p;
    } else if (config.containsKey('plates') || tenFrames) {
      return const ParseResult.invalid(
        'plates and ten_frames are for mode plates.',
      );
    }

    final start = config['start'] ?? const <String, Object?>{};
    if (start is! Map) return const ParseResult.invalid('start is an object.');
    final startMat = _count(start['mat'] ?? 0);
    final rawPlates = start['plates'] ?? List.filled(plates, 0);
    if (startMat == null ||
        rawPlates is! List ||
        rawPlates.length != plates ||
        rawPlates.any((n) => _count(n, max: tenFrames ? 10 : 20) == null)) {
      return const ParseResult.invalid(
        'start is {mat, plates}: whole counts, one per plate.',
      );
    }
    final startPlates = rawPlates.cast<int>();
    if (mode == CountersMode.array &&
        (startMat > 0 || startPlates.isNotEmpty)) {
      return const ParseResult.invalid('An array starts empty.');
    }
    final startTotal = startMat + startPlates.fold<int>(0, (a, b) => a + b);
    if (startTotal > CountersContent.maxTotal) {
      return const ParseResult.invalid('At most 40 counters.');
    }

    final maxRows = _count(config['max_rows'] ?? 6, max: 10);
    final maxCols = _count(config['max_cols'] ?? 6, max: 10);
    if (maxRows == null || maxCols == null || maxRows < 1 || maxCols < 1) {
      return const ParseResult.invalid('max_rows and max_cols are 1 to 10.');
    }

    final rawTarget = config['target'];
    if (rawTarget is! Map || rawTarget.isEmpty) {
      return const ParseResult.invalid('target sets at least one rule.');
    }
    int? t(String k, {int max = CountersContent.maxTotal}) =>
        rawTarget[k] == null ? null : _count(rawTarget[k], max: max);
    for (final k in rawTarget.keys) {
      if (!{
        ..._metricKeys,
        'plates',
        'either_way',
        'plates_any_order',
      }.contains(k)) {
        return ParseResult.invalid('target has an unknown rule: $k.');
      }
      if (!const {'plates', 'either_way', 'plates_any_order'}.contains(k) &&
          t(k as String) == null) {
        return ParseResult.invalid('target $k is a count, 0 to 40.');
      }
    }
    final targetPlates = rawTarget['plates'];
    if (targetPlates != null &&
        (targetPlates is! List ||
            targetPlates.length != plates ||
            targetPlates.any((n) => _count(n) == null))) {
      return const ParseResult.invalid(
        'target plates lists a count for every plate.',
      );
    }
    final target = CountersTarget(
      total: t('total'),
      mat: t('mat'),
      perPlate: t('per_plate'),
      plates: (targetPlates as List?)?.cast<int>(),
      removed: t('removed'),
      rows: t('rows', max: 10),
      cols: t('cols', max: 10),
      eitherWay: rawTarget['either_way'] == true,
      platesAnyOrder: rawTarget['plates_any_order'] is bool
          ? rawTarget['plates_any_order']! as bool
          : tenFrames,
    );

    // Rules that don't fit the mode can never be met.
    final arrayRules = target.rows != null || target.cols != null;
    final plateRules = target.perPlate != null || target.plates != null;
    if (mode == CountersMode.array &&
        (target.mat != null || plateRules || target.removed != null)) {
      return const ParseResult.invalid(
        'An array is graded on rows, cols and total only.',
      );
    }
    if (mode != CountersMode.array && arrayRules) {
      return const ParseResult.invalid('rows and cols are for mode array.');
    }
    if (mode != CountersMode.plates && plateRules) {
      return const ParseResult.invalid(
        'per_plate and plates are for mode plates.',
      );
    }
    if (target.mat != null && !(mode == CountersMode.free || startMat > 0)) {
      return const ParseResult.invalid(
        'target mat needs a mat (mode free, or counters starting on it).',
      );
    }

    var content = CountersContent(
      mode: mode,
      target: target,
      plates: plates,
      startMat: startMat,
      startPlates: List.unmodifiable(startPlates),
      supply: supply,
      tenFrames: tenFrames,
      maxRows: maxRows,
      maxCols: maxCols,
    );
    final reach = _reachable(content);
    if (reach != null) return ParseResult.invalid(reach);

    final rawCounter = config['counter'];
    final symbol = config['symbol'];
    if (rawCounter != null && symbol != null) {
      return const ParseResult.invalid('Give counter or symbol, not both.');
    }
    if (symbol != null &&
        (symbol is! String || symbol.isEmpty || symbol.length > 4)) {
      return const ParseResult.invalid('symbol is 1 to 4 characters.');
    }
    final counter = rawCounter == null
        ? content.counter
        : PatternPiece.fromJson(rawCounter);
    if (counter == null || counter.text != null) {
      return const ParseResult.invalid('counter is a {shape, color?}.');
    }

    final rawMisses = config['near_misses'] ?? const [];
    if (rawMisses is! List || rawMisses.length > 6) {
      return const ParseResult.invalid('There are at most 6 near_misses.');
    }
    final misses = <CountersNearMiss>[];
    for (final m in rawMisses) {
      final when = m is Map ? m['when'] : null;
      final diag = m is Map ? m['diagnosis'] : null;
      final code = diag is Map ? diag['code'] : null;
      final version = diag is Map ? diag['taxonomy_version'] : null;
      if (when is! Map ||
          when.isEmpty ||
          !when.keys.every(_metricKeys.contains) ||
          !when.values.every((v) => _count(v) != null) ||
          code is! String ||
          code.isEmpty ||
          version is! int) {
        return const ParseResult.invalid(
          'A near_miss is {when: {metric: count}, diagnosis: {code, '
          'taxonomy_version}}.',
        );
      }
      misses.add(
        CountersNearMiss(
          when: when.cast<String, int>(),
          diagnosis: ErrorClassification(code: code, taxonomyVersion: version),
        ),
      );
    }

    content = CountersContent(
      mode: mode,
      target: target,
      plates: plates,
      startMat: startMat,
      startPlates: content.startPlates,
      supply: supply,
      tenFrames: tenFrames,
      maxRows: maxRows,
      maxCols: maxCols,
      counter: counter,
      symbol: symbol as String?,
      nearMisses: List.unmodifiable(misses),
    );
    return ParseResult.ok(content);
  }

  /// Why the target can't be reached, or null. Checks the arithmetic a
  /// lesson most often gets wrong; the board's caps cover the rest.
  static String? _reachable(CountersContent c) {
    final t = c.target;
    if (c.mode == CountersMode.array) {
      final rows = t.rows;
      final cols = t.cols;
      if (rows != null && (rows < 1 || rows > c.maxRows)) {
        return 'target rows is outside 1 to max_rows.';
      }
      if (cols != null && (cols < 1 || cols > c.maxCols)) {
        return 'target cols is outside 1 to max_cols.';
      }
      if (t.eitherWay &&
          rows != null &&
          cols != null &&
          (cols > c.maxRows || rows > c.maxCols)) {
        return 'either_way needs room for cols × rows too.';
      }
      if (rows != null && cols != null && t.total != null) {
        if (rows * cols != t.total) return 'rows × cols is not total.';
      }
      return null;
    }
    final total = t.total;
    if (total != null && !c.supply && total > c.startTotal) {
      return 'With no supply, total can\'t exceed the counters at the start.';
    }
    if (t.removed != null) {
      if (t.removed! > c.startTotal) {
        return 'removed is more than the counters at the start.';
      }
      if (total != null && total != c.startTotal - t.removed!) {
        return 'total and removed disagree with the start.';
      }
    }
    if (t.perPlate != null && t.perPlate! > c.plateCap) {
      return 'per_plate is more than a plate holds.';
    }
    if (t.plates != null && t.plates!.any((n) => n > c.plateCap)) {
      return 'A target plate holds more than a plate can.';
    }
    if (t.perPlate != null &&
        t.plates != null &&
        t.plates!.any((n) => n != t.perPlate)) {
      return 'plates and per_plate disagree.';
    }
    final inPlates =
        t.plates?.fold<int>(0, (a, b) => a + b) ??
        (t.perPlate == null ? null : t.perPlate! * c.plates);
    if (inPlates != null && total != null) {
      final mat = t.mat ?? (c.hasMat ? null : 0);
      if (mat != null && inPlates + mat != total) {
        return 'The plates and the mat don\'t add up to total.';
      }
      if (mat == null && inPlates > total) {
        return 'The plates alone hold more than total.';
      }
    }
    if (inPlates != null && !c.supply && inPlates > c.startTotal) {
      return 'With no supply, the plates need more counters than there are.';
    }
    return null;
  }

  @override
  CountersState initialize(CountersContent content, EngineSeed seed) =>
      CountersState(
        content: content,
        mat: content.startMat,
        plates: content.mode == CountersMode.plates
            ? List.unmodifiable(content.startPlates)
            : const [],
      );

  static int _cap(CountersContent c, int area) =>
      area == CountersArea.mat ? CountersContent.maxTotal : c.plateCap;

  @override
  Transition<CountersState> reduce(CountersState s, CountersAction action) {
    final c = s.content;
    if (s.solved) return Transition(s);

    int count(int area) => area == CountersArea.mat ? s.mat : s.plates[area];
    bool valid(int area) =>
        (area == CountersArea.mat && c.hasMat) ||
        (area >= 0 && area < s.plates.length);
    CountersState put(CountersState st, int area, int delta) =>
        area == CountersArea.mat
        ? st.copyWith(mat: st.mat + delta)
        : st.copyWith(plates: [...st.plates]..[area] += delta);

    Transition<CountersState> move(int from, int to) {
      if (from == to) return Transition(s);
      final fromOk = from == CountersArea.reserve
          ? c.supply && s.total < CountersContent.maxTotal
          : valid(from) && count(from) > 0;
      final toOk =
          to == CountersArea.reserve || (valid(to) && count(to) < _cap(c, to));
      if (!fromOk || !toOk) return Transition(s);
      var next = s;
      if (from != CountersArea.reserve) next = put(next, from, -1);
      if (to != CountersArea.reserve) next = put(next, to, 1);
      if (to >= 0) next = next.copyWith(active: to);
      return Transition(next, [
        InteractionEvent(
          to == CountersArea.reserve ? 'item_removed' : 'item_placed',
          {'item_id': 'counter', 'from': '$from', 'bucket_id': '$to'},
        ),
      ]);
    }

    switch (action) {
      case MoveCounter(:final from, :final to):
        return move(from, to);
      case AddCounter(:final area):
        // Filling a plate takes from the mat's pile first, the way a
        // child shares out a heap.
        final from = area >= 0 && c.hasMat && s.mat > 0
            ? CountersArea.mat
            : CountersArea.reserve;
        return move(from, area);
      case TakeCounter(:final area):
        final to = area >= 0 && c.hasMat
            ? CountersArea.mat
            : CountersArea.reserve;
        return move(area, to);
      case SetRows(:final rows):
        if (c.mode != CountersMode.array || rows < 0 || rows > c.maxRows) {
          return Transition(s);
        }
        return Transition(s.copyWith(rows: rows), [
          InteractionEvent('item_placed', {'item_id': 'rows', 'value': rows}),
        ]);
      case SetCols(:final cols):
        if (c.mode != CountersMode.array || cols < 0 || cols > c.maxCols) {
          return Transition(s);
        }
        return Transition(s.copyWith(cols: cols), [
          InteractionEvent('item_placed', {'item_id': 'cols', 'value': cols}),
        ]);
    }
  }

  /// The board as the answer: one entry per area, or rows and cols.
  @override
  BlanksAnswer? extractAnswer(CountersState s) {
    if (s.solved) return null;
    if (s.content.mode == CountersMode.array) {
      return s.rows == 0 || s.cols == 0
          ? null
          : BlanksAnswer({'rows': '${s.rows}', 'cols': '${s.cols}'});
    }
    return BlanksAnswer({
      if (s.content.hasMat) 'mat': '${s.mat}',
      for (var i = 0; i < s.plates.length; i++) 'plate_$i': '${s.plates[i]}',
    });
  }

  @override
  CountersState applyFeedback(CountersState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    // A wrong board stays: the child fixes it, never starts over.
    return s.copyWith(solved: result.outcome == Outcome.correct);
  }

  @override
  Map<String, Object?> snapshot(CountersState s) => {
    'mat': s.mat,
    'plates': s.plates,
    'rows': s.rows,
    'cols': s.cols,
    'active': s.active,
    'solved': s.solved,
  };

  @override
  CountersState? restore(CountersContent content, Map<String, Object?> snap) {
    try {
      final plates = (snap['plates'] as List).cast<int>();
      final mat = snap['mat']! as int;
      final rows = snap['rows']! as int;
      final cols = snap['cols']! as int;
      final s = CountersState(
        content: content,
        mat: mat,
        plates: List.unmodifiable(plates),
        rows: rows,
        cols: cols,
        active: (snap['active'] as int?) ?? 0,
        solved: snap['solved'] == true,
      );
      if (plates.length !=
              (content.mode == CountersMode.plates ? content.plates : 0) ||
          mat < 0 ||
          (!content.hasMat && mat != 0) ||
          plates.any((n) => n < 0 || n > content.plateCap) ||
          rows < 0 ||
          rows > content.maxRows ||
          cols < 0 ||
          cols > content.maxCols ||
          s.total > CountersContent.maxTotal ||
          (!content.supply && s.total > content.startTotal)) {
        return null;
      }
      if (s.solved) {
        final answer = extractAnswer(s.copyWith(solved: false));
        if (answer == null ||
            measure(content, answer.blanks).values.contains(false)) {
          return null;
        }
      }
      return s;
    } on Object {
      return null;
    }
  }

  /// The final board's numbers, from an answer.
  static Map<String, int> metrics(
    CountersContent c,
    Map<String, String> board,
  ) {
    int n(String k) => int.tryParse(board[k] ?? '') ?? 0;
    if (c.mode == CountersMode.array) {
      final rows = n('rows');
      final cols = n('cols');
      return {'rows': rows, 'cols': cols, 'total': rows * cols};
    }
    final plates = [for (var i = 0; i < c.plates; i++) n('plate_$i')];
    final mat = n('mat');
    final total = mat + plates.fold<int>(0, (a, b) => a + b);
    return {
      'total': total,
      'mat': mat,
      'removed': c.startTotal - total,
      if (plates.isNotEmpty && plates.every((p) => p == plates.first))
        'per_plate': plates.first,
      for (var i = 0; i < plates.length; i++) 'plate_$i': plates[i],
    };
  }

  /// Each target rule → whether the board meets it.
  static Map<String, bool> measure(
    CountersContent c,
    Map<String, String> board,
  ) {
    final m = metrics(c, board);
    final t = c.target;
    final swapped = t.eitherWay && m['rows'] == t.cols && m['cols'] == t.rows;
    return {
      if (t.total != null) 'total': m['total'] == t.total,
      if (t.mat != null) 'mat': m['mat'] == t.mat,
      if (t.perPlate != null) 'per_plate': m['per_plate'] == t.perPlate,
      if (t.plates != null) 'plates': _samePlates(m, t),
      if (t.removed != null) 'removed': m['removed'] == t.removed,
      if (t.rows != null) 'rows': m['rows'] == t.rows || swapped,
      if (t.cols != null) 'cols': m['cols'] == t.cols || swapped,
    };
  }

  static bool _samePlates(Map<String, int> m, CountersTarget t) {
    final want = t.plates!;
    final got = [for (var i = 0; i < want.length; i++) m['plate_$i'] ?? 0];
    if (!t.platesAnyOrder) {
      return got.indexed.every((e) => e.$2 == want[e.$1]);
    }
    return _sorted(got).join(',') == _sorted(want).join(',');
  }

  static List<int> _sorted(List<int> xs) => [...xs]..sort();

  @override
  Widget buildView(
    BuildContext context,
    EngineView<CountersContent, CountersState, CountersAction> view,
  ) => _CountersView(view: view);
}

class _CountersView extends StatelessWidget {
  const _CountersView({required this.view});
  final EngineView<CountersContent, CountersState, CountersAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final c = view.content;
    final p = VillagePalette.of(context);
    final open = view.enabled && !s.solved;

    Widget counter(double size) => SizedBox.square(
      dimension: size,
      child: c.symbol != null
          ? Center(
              child: Text(c.symbol!, style: TextStyle(fontSize: size * 0.8)),
            )
          : Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: PatternPieceView(piece: c.counter),
            ),
    );

    String plural(int n, String fr1, String frN, String en1, String enN) =>
        fr ? (n == 1 ? fr1 : frN) : (n == 1 ? en1 : enN);

    if (c.mode == CountersMode.array) {
      Widget stepper(
        String label,
        int value,
        int max,
        void Function(int) set,
        String key,
      ) => Semantics(
        label: '$label : $value',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: p.ink,
              ),
            ),
            IconButton(
              key: ValueKey('$key-minus'),
              tooltip: fr ? 'Une de moins' : 'One fewer',
              onPressed: open && value > 0 ? () => set(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: p.ink,
                ),
              ),
            ),
            IconButton(
              key: ValueKey('$key-plus'),
              tooltip: fr ? 'Une de plus' : 'One more',
              onPressed: open && value < max ? () => set(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      );
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                key: const ValueKey('counters-array'),
                liveRegion: true,
                label: fr
                    ? '${s.rows} rangée${s.rows == 1 ? '' : 's'} de ${s.cols}, ${s.total} jetons.'
                    : '${s.rows} row${s.rows == 1 ? '' : 's'} of ${s.cols}, ${s.total} counters.',
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: Radii.cardMd,
                    border: Border.all(color: p.line, width: 2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final size = math.min(
                        40.0,
                        box.maxWidth / math.max(1, c.maxCols),
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var r = 0; r < s.rows; r++)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var k = 0; k < s.cols; k++) counter(size),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                children: [
                  stepper(
                    fr ? 'Rangées' : 'Rows',
                    s.rows,
                    c.maxRows,
                    (v) => view.dispatch(SetRows(v)),
                    'counters-rows',
                  ),
                  stepper(
                    fr ? 'Colonnes' : 'Columns',
                    s.cols,
                    c.maxCols,
                    (v) => view.dispatch(SetCols(v)),
                    'counters-cols',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget area(int id, String title, int count) {
      final isPlate = id >= 0;
      final cap = isPlate ? c.plateCap : CountersContent.maxTotal;
      final canAdd =
          open &&
          count < cap &&
          ((isPlate && c.hasMat && s.mat > 0) ||
              (c.supply && s.total < CountersContent.maxTotal));
      final canTake = open && count > 0;
      final spoken = fr
          ? '$title : $count ${plural(count, 'jeton', 'jetons', '', '')}'
          : '$title: $count ${plural(count, '', '', 'counter', 'counters')}';
      return DragTarget<int>(
        onWillAcceptWithDetails: (d) => open && d.data != id && count < cap,
        onAcceptWithDetails: (d) => view.dispatch(MoveCounter(d.data, id)),
        builder: (context, candidates, _) => Semantics(
          key: ValueKey('counters-area-$id'),
          label: spoken,
          liveRegion: true,
          child: Container(
            width: isPlate ? 170 : double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: candidates.isNotEmpty ? p.navHoverFill : p.surface,
              borderRadius: BorderRadius.circular(isPlate ? 60 : 16),
              border: Border.all(
                color: candidates.isNotEmpty ? p.quebecBlueBright : p.line,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    '$title · $count',
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: p.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: c.tenFrames && isPlate
                      ? _TenFrame(
                          count: count,
                          counter: counter(24),
                          line: p.line,
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            for (var i = 0; i < count; i++)
                              Draggable<int>(
                                data: id,
                                maxSimultaneousDrags: open ? 1 : 0,
                                feedback: Material(
                                  type: MaterialType.transparency,
                                  child: counter(34),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: counter(28),
                                ),
                                child: counter(28),
                              ),
                          ],
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: ValueKey('counters-take-$id'),
                      tooltip: fr ? 'Enlever un jeton' : 'Take one away',
                      onPressed: canTake
                          ? () => view.dispatch(TakeCounter(id))
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    IconButton(
                      key: ValueKey('counters-add-$id'),
                      tooltip: fr ? 'Ajouter un jeton' : 'Add one',
                      onPressed: canAdd
                          ? () => view.dispatch(AddCounter(id))
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final reserve = c.supply
        ? DragTarget<int>(
            onWillAcceptWithDetails: (d) =>
                open && d.data != CountersArea.reserve,
            onAcceptWithDetails: (d) =>
                view.dispatch(MoveCounter(d.data, CountersArea.reserve)),
            builder: (context, candidates, _) => Semantics(
              label: fr
                  ? 'Réserve de jetons. Glisse un jeton vers une assiette.'
                  : 'Counter reserve. Drag a counter to a plate.',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Draggable<int>(
                    data: CountersArea.reserve,
                    maxSimultaneousDrags: open ? 1 : 0,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: counter(34),
                    ),
                    child: counter(36),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Text(
                      fr ? 'Réserve' : 'Reserve',
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: candidates.isNotEmpty
                            ? p.quebecBlueBright
                            : p.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: reserve),
              if (c.supply) const SizedBox(height: 10),
              if (c.hasMat) area(CountersArea.mat, fr ? 'Tapis' : 'Mat', s.mat),
              if (c.hasMat && s.plates.isNotEmpty) const SizedBox(height: 12),
              if (s.plates.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < s.plates.length; i++)
                      area(
                        i,
                        c.tenFrames
                            ? (fr ? 'Cadre ${i + 1}' : 'Frame ${i + 1}')
                            : (fr ? 'Assiette ${i + 1}' : 'Plate ${i + 1}'),
                        s.plates[i],
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

/// A ten-frame: two rows of five cells, filled left to right.
class _TenFrame extends StatelessWidget {
  const _TenFrame({
    required this.count,
    required this.counter,
    required this.line,
  });
  final int count;
  final Widget counter;
  final Color line;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var r = 0; r < 2; r++)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 0; k < 5; k++)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: line, width: 1.5),
                ),
                child: r * 5 + k < count ? Center(child: counter) : null,
              ),
          ],
        ),
    ],
  );
}

/// Grades the final board against the target, rule by rule. A wrong board
/// matching a declared near miss carries its diagnosis.
class CountersBoardEvaluator
    implements Evaluator<CountersContent, BlanksAnswer> {
  const CountersBoardEvaluator();

  @override
  String get engineKey => CountersBoardEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    CountersContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final items = CountersBoardEngine.measure(content, answer.blanks);
    final right = !items.containsValue(false);
    ErrorClassification? miss;
    if (!right) {
      final m = CountersBoardEngine.metrics(content, answer.blanks);
      for (final nm in content.nearMisses) {
        if (nm.when.entries.every((e) => m[e.key] == e.value)) {
          miss = nm.diagnosis;
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
      itemResults: items,
      errors: right
          ? const []
          : [miss ?? const ErrorClassification.unclassified()],
    );
  }
}
