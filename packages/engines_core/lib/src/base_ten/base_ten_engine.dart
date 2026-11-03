import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// A column of the tableau de numération, highest first.
enum BaseTenPlace {
  um('um', 3, 'unités de mille', 'thousands'),
  c('c', 2, 'centaines', 'hundreds'),
  d('d', 1, 'dizaines', 'tens'),
  u('u', 0, 'unités', 'ones'),
  di('di', -1, 'dixièmes', 'tenths'),
  ci('ci', -2, 'centièmes', 'hundredths');

  const BaseTenPlace(this.id, this.power, this.fr, this.en);
  final String id;

  /// 10^power is what one block is worth.
  final int power;
  final String fr;
  final String en;

  static BaseTenPlace? byId(Object? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class BaseTenContent {
  const BaseTenContent({
    required this.places,
    required this.start,
    this.supply = true,
    this.value,
    this.exact,
  });

  /// Consecutive places, highest first: [c, d, u].
  final List<BaseTenPlace> places;
  final Map<BaseTenPlace, int> start;

  /// Blocks can come from (and go back to) a reserve. Off: only the
  /// exchanges change the board.
  final bool supply;

  /// What the board must be worth, in hundredths (so 2,5 is 250). Any
  /// arrangement of that value is right.
  final int? value;

  /// The exact count per column, when the arrangement itself is asked for
  /// (the fewest blocks, or a given exchange).
  final Map<BaseTenPlace, int>? exact;

  static const cap = 19;

  /// The board's worth in hundredths.
  int worth(Map<BaseTenPlace, int> board) => board.entries.fold(
    0,
    (sum, e) => sum + e.value * _hundredths(e.key.power),
  );

  static int _hundredths(int power) => switch (power) {
    3 => 100000,
    2 => 10000,
    1 => 1000,
    0 => 100,
    -1 => 10,
    _ => 1,
  };
}

class BaseTenState {
  const BaseTenState({
    required this.places,
    required this.counts,
    this.supply = true,
    this.locked = const {},
    this.solved = false,
  });

  final List<BaseTenPlace> places;
  final Map<BaseTenPlace, int> counts;
  final bool supply;

  /// Items checked right.
  final Set<String> locked;
  final bool solved;

  int count(BaseTenPlace p) => counts[p] ?? 0;

  BaseTenState copyWith({
    Map<BaseTenPlace, int>? counts,
    Set<String>? locked,
    bool? solved,
  }) => BaseTenState(
    places: places,
    counts: counts ?? this.counts,
    supply: supply,
    locked: locked ?? this.locked,
    solved: solved ?? this.solved,
  );
}

sealed class BaseTenAction {
  const BaseTenAction();
}

class AddBlock extends BaseTenAction {
  const AddBlock(this.place);
  final BaseTenPlace place;
}

class TakeBlock extends BaseTenAction {
  const TakeBlock(this.place);
  final BaseTenPlace place;
}

/// One block of [place] becomes ten of the next place down.
class BreakBlock extends BaseTenAction {
  const BreakBlock(this.place);
  final BaseTenPlace place;
}

/// Ten blocks of [place] become one of the next place up.
class GroupBlocks extends BaseTenAction {
  const GroupBlocks(this.place);
  final BaseTenPlace place;
}

/// Le tableau de numération — the `base_ten` engine (plan
/// PLAN_GRADES_2_6_ENGINES §2.2, the place-value twin of column_calc;
/// app ADR 0122).
///
/// Columns of base-ten blocks, highest place first: unités de mille,
/// centaines, dizaines, unités, and for decimals dixièmes and centièmes.
/// The child adds and takes blocks, and makes the exchanges the PFEQ
/// calls « groupement » and « échange »: break one block into ten of the
/// next place down, or group ten into one of the next place up. The board
/// is graded on what it's worth (`value`: any arrangement), on exactly how
/// many blocks each column holds (`exact`), or both.
///
/// A column holds 19 at most, so 13 tens can sit on the board before the
/// child groups them, which is the point of an exchange.
class BaseTenEngine
    implements
        LearningEngine<
          BaseTenContent,
          BaseTenState,
          BaseTenAction,
          BlanksAnswer
        > {
  const BaseTenEngine();

  static const key = 'base_ten';
  static final _number = RegExp(r'^\d{1,4}(,\d{1,2})?$');

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<BaseTenContent> parse(Map<String, Object?> config) {
    final raw = config['places'];
    if (raw is! List || raw.length < 2 || raw.length > 4) {
      return const ParseResult.invalid('places is 2 to 4 place ids.');
    }
    final places = <BaseTenPlace>[];
    for (final id in raw) {
      final p = BaseTenPlace.byId(id);
      if (p == null) {
        return const ParseResult.invalid('A place is um, c, d, u, di or ci.');
      }
      places.add(p);
    }
    for (var i = 1; i < places.length; i++) {
      if (places[i].power != places[i - 1].power - 1) {
        return const ParseResult.invalid(
          'places are consecutive, highest first: [c, d, u].',
        );
      }
    }

    Map<BaseTenPlace, int>? counts(Object? v, String what) {
      if (v == null) return null;
      if (v is! Map) return null;
      final out = <BaseTenPlace, int>{};
      for (final e in v.entries) {
        final p = BaseTenPlace.byId(e.key);
        final n = e.value;
        if (p == null ||
            !places.contains(p) ||
            n is! int ||
            n < 0 ||
            n > BaseTenContent.cap) {
          return null;
        }
        out[p] = n;
      }
      return out;
    }

    final start = config['start'] == null
        ? <BaseTenPlace, int>{}
        : counts(config['start'], 'start');
    if (start == null) {
      return const ParseResult.invalid(
        'start is {place: count}, 0 to 19, for the board\'s places.',
      );
    }
    final rawTarget = config['target'];
    if (rawTarget is! Map ||
        (rawTarget['value'] == null && rawTarget['exact'] == null)) {
      return const ParseResult.invalid('target sets value, exact, or both.');
    }
    int? value;
    final rawValue = rawTarget['value'];
    if (rawValue != null) {
      if (rawValue is! String || !_number.hasMatch(rawValue)) {
        return const ParseResult.invalid('target value is a number: "234".');
      }
      final parts = rawValue.split(',');
      final frac = (parts.length == 2 ? parts[1] : '').padRight(2, '0');
      value = int.parse(parts[0]) * 100 + int.parse(frac);
    }
    final exact = counts(rawTarget['exact'], 'exact');
    if (rawTarget['exact'] != null && exact == null) {
      return const ParseResult.invalid(
        'target exact is {place: count} for the board\'s places.',
      );
    }
    final supply = config['supply'] is bool ? config['supply']! as bool : true;
    final content = BaseTenContent(
      places: List.unmodifiable(places),
      start: Map.unmodifiable(start),
      supply: supply,
      value: value,
      exact: exact == null
          ? null
          : Map.unmodifiable({for (final p in places) p: exact[p] ?? 0}),
    );

    // Targets the board can never show.
    final low = places.last.power;
    if (value != null && value % BaseTenContent._hundredths(low) != 0) {
      return const ParseResult.invalid(
        'The value needs a smaller place than the board has.',
      );
    }
    if (value != null &&
        content.exact != null &&
        content.worth(content.exact!) != value) {
      return const ParseResult.invalid('exact and value disagree.');
    }
    if (!supply && value != null && content.worth(start) != value) {
      return const ParseResult.invalid(
        'Without a supply only exchanges change the board, and they keep '
        'its value: start must already be worth the target.',
      );
    }
    final hint = config['hint'];
    if (hint != null && hint is! String) {
      return const ParseResult.invalid('hint is a string or null.');
    }
    return ParseResult.ok(content);
  }

  @override
  BaseTenState initialize(BaseTenContent content, EngineSeed seed) =>
      BaseTenState(
        places: content.places,
        counts: {for (final p in content.places) p: content.start[p] ?? 0},
        supply: content.supply,
      );

  BaseTenPlace? _below(BaseTenState s, BaseTenPlace p) {
    final i = s.places.indexOf(p);
    return i < 0 || i + 1 >= s.places.length ? null : s.places[i + 1];
  }

  BaseTenPlace? _above(BaseTenState s, BaseTenPlace p) {
    final i = s.places.indexOf(p);
    return i <= 0 ? null : s.places[i - 1];
  }

  @override
  Transition<BaseTenState> reduce(BaseTenState s, BaseTenAction action) {
    if (s.solved) return Transition(s);
    Map<BaseTenPlace, int> plus(BaseTenPlace p, int n) => {
      ...s.counts,
      p: s.count(p) + n,
    };
    switch (action) {
      case AddBlock(:final place):
        if (!s.supply ||
            !s.places.contains(place) ||
            s.count(place) >= BaseTenContent.cap) {
          return Transition(s);
        }
        return Transition(s.copyWith(counts: plus(place, 1)), [
          InteractionEvent('item_placed', {'item_id': place.id}),
        ]);
      case TakeBlock(:final place):
        if (!s.supply || s.count(place) == 0) return Transition(s);
        return Transition(s.copyWith(counts: plus(place, -1)), [
          InteractionEvent('item_removed', {'item_id': place.id}),
        ]);
      case BreakBlock(:final place):
        final below = _below(s, place);
        if (below == null ||
            s.count(place) == 0 ||
            s.count(below) + 10 > BaseTenContent.cap) {
          return Transition(s);
        }
        final counts = {...plus(place, -1), below: s.count(below) + 10};
        return Transition(s.copyWith(counts: counts), [
          InteractionEvent('item_placed', {
            'item_id': below.id,
            'from': place.id,
          }),
          // Ten smaller blocks appearing out of one is the moment.
          RevealEvent('exchange', itemId: '${place.id}>${below.id}'),
        ]);
      case GroupBlocks(:final place):
        final above = _above(s, place);
        if (above == null ||
            s.count(place) < 10 ||
            s.count(above) >= BaseTenContent.cap) {
          return Transition(s);
        }
        final counts = {...plus(place, -10), above: s.count(above) + 1};
        return Transition(s.copyWith(counts: counts), [
          InteractionEvent('item_placed', {
            'item_id': above.id,
            'from': place.id,
          }),
          RevealEvent('exchange', itemId: '${place.id}>${above.id}'),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(BaseTenState s) => s.solved
      ? null
      : BlanksAnswer({for (final p in s.places) p.id: '${s.count(p)}'});

  @override
  BaseTenState applyFeedback(BaseTenState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    // The board stays as it is: the child fixes it from there.
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
  Map<String, Object?> snapshot(BaseTenState s) => {
    'counts': {for (final p in s.places) p.id: s.count(p)},
    'locked': s.locked.toList(),
    'solved': s.solved,
  };

  @override
  BaseTenState? restore(BaseTenContent content, Map<String, Object?> snap) {
    try {
      final raw = snap['counts']! as Map;
      final counts = <BaseTenPlace, int>{};
      for (final p in content.places) {
        final n = raw[p.id] as int;
        if (n < 0 || n > BaseTenContent.cap) return null;
        counts[p] = n;
      }
      if (raw.length != content.places.length) return null;
      return BaseTenState(
        places: content.places,
        counts: counts,
        supply: content.supply,
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
    EngineView<BaseTenContent, BaseTenState, BaseTenAction> view,
  ) => _BaseTenBoard(view: view);
}

class _BaseTenBoard extends StatelessWidget {
  const _BaseTenBoard({required this.view});
  final EngineView<BaseTenContent, BaseTenState, BaseTenAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final s = view.state;
    final engine = const BaseTenEngine();
    final on = view.enabled && !s.solved;

    Widget block(BaseTenPlace place) {
      final (w, h) = switch (place) {
        BaseTenPlace.um => (30.0, 30.0),
        BaseTenPlace.c => (26.0, 26.0),
        BaseTenPlace.d => (8.0, 30.0),
        BaseTenPlace.u => (10.0, 10.0),
        BaseTenPlace.di => (8.0, 8.0),
        BaseTenPlace.ci => (6.0, 6.0),
      };
      final colour = place.power >= 0 ? p.quebecBlue : p.gold;
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.85),
          border: Border.all(color: colour, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    Widget step(String label, VoidCallback? onTap, String id) => SizedBox(
      width: 52,
      height: 48,
      child: AnswerTile(
        key: ValueKey(id),
        label: label,
        dense: true,
        state: AnswerTileState.idle,
        onTap: onTap,
      ),
    );

    Widget column(BaseTenPlace place) {
      final n = s.count(place);
      final i = s.places.indexOf(place);
      final hasBelow = i + 1 < s.places.length;
      final hasAbove = i > 0;
      final name = fr ? place.fr : place.en;
      return Semantics(
        container: true,
        label: '$name : $n',
        child: Container(
          key: ValueKey('base-ten-col-${place.id}'),
          width: 132,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: Radii.cardMd,
            border: Border.all(color: p.line, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.inkMuted,
                ),
              ),
              Text(
                '$n',
                key: ValueKey('base-ten-count-${place.id}'),
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: SizedBox(
                  height: 150,
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    alignment: WrapAlignment.center,
                    children: [for (var k = 0; k < n; k++) block(place)],
                  ),
                ),
              ),
              if (s.supply) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    step(
                      '−',
                      on && n > 0
                          ? () => view.dispatch(TakeBlock(place))
                          : null,
                      'base-ten-take-${place.id}',
                    ),
                    const SizedBox(width: 6),
                    step(
                      '+',
                      on && n < BaseTenContent.cap
                          ? () => view.dispatch(AddBlock(place))
                          : null,
                      'base-ten-add-${place.id}',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              if (hasBelow)
                SizedBox(
                  width: 116,
                  child: AnswerTile(
                    key: ValueKey('base-ten-break-${place.id}'),
                    label: fr ? '1 → 10 ▸' : '1 → 10 ▸',
                    dense: true,
                    semanticsState: fr
                        ? 'échanger un bloc contre dix'
                        : 'trade one block for ten',
                    state: AnswerTileState.idle,
                    onTap: on && engine.reduce(s, BreakBlock(place)).state != s
                        ? () => view.dispatch(BreakBlock(place))
                        : null,
                  ),
                ),
              if (hasAbove) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 116,
                  child: AnswerTile(
                    key: ValueKey('base-ten-group-${place.id}'),
                    label: fr ? '◂ 10 → 1' : '◂ 10 → 1',
                    dense: true,
                    semanticsState: fr
                        ? 'grouper dix blocs en un'
                        : 'group ten blocks into one',
                    state: AnswerTileState.idle,
                    onTap: on && engine.reduce(s, GroupBlocks(place)).state != s
                        ? () => view.dispatch(GroupBlocks(place))
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: FocusTraversalGroup(
          child: Row(
            key: const ValueKey('base-ten-board'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, place) in s.places.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                column(place),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades the board: `value` is right when the board is worth the target
/// in any arrangement; `exact` adds one item per column. A board worth the
/// target but not in the asked arrangement is a known slip, named
/// `math.place_value.not_exchanged`.
class BaseTenEvaluator implements Evaluator<BaseTenContent, BlanksAnswer> {
  const BaseTenEvaluator();

  @override
  String get engineKey => BaseTenEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    BaseTenContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final board = {
      for (final p in content.places)
        p: int.tryParse(answer.blanks[p.id] ?? '') ?? 0,
    };
    final items = <String, bool>{
      if (content.value != null) 'value': content.worth(board) == content.value,
      if (content.exact case final exact?)
        for (final p in content.places) 'col_${p.id}': board[p] == exact[p],
    };
    final hits = items.values.where((v) => v).length;
    final all = hits == items.length;
    final slip =
        !all &&
            content.exact != null &&
            content.worth(board) == content.worth(content.exact!)
        ? 'math.place_value.not_exchanged'
        : null;
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
}
