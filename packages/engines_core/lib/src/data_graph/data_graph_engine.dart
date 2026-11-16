import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../shell/activity_assist.dart';
import '../widgets/answer_tile.dart';
import '../widgets/choice_layout.dart';
import '../widgets/swatch_text.dart';

enum DataGraphMode {
  /// Read the chart, answer a question about it (the old engine).
  read,

  /// Make the chart: raise each bar to its count.
  build,
}

enum ChartType { bar, pictograph }

class GraphCategory {
  const GraphCategory({
    required this.id,
    required this.label,
    required this.value,
    this.symbol,
  });
  final String id;
  final String label;

  /// The count: drawn in read mode, the target in build mode.
  final int value;

  /// What a pictograph stacks ("🍎"). Bars ignore it.
  final String? symbol;
}

class GraphOption {
  const GraphOption({required this.id, required this.label});
  final String id;
  final String label;
}

class DataGraphContent {
  const DataGraphContent({
    required this.mode,
    required this.chartType,
    required this.categories,
    required this.max,
    this.options = const [],
    this.correct,
    this.source = const [],
    this.shuffleOptions = true,
  });

  final DataGraphMode mode;
  final ChartType chartType;
  final List<GraphCategory> categories;

  /// Top of the value axis.
  final int max;

  /// Read mode: the choices and the right one.
  final List<GraphOption> options;
  final String? correct;

  /// Build mode, optional: the things to count ("🍎 🍌 🍎 …"), drawn above
  /// the chart. Without it the prompt carries the counts.
  final List<String> source;

  final bool shuffleOptions;

  GraphCategory category(String id) => categories.firstWhere((c) => c.id == id);
  GraphOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class DataGraphState {
  const DataGraphState({
    this.optionOrder = const [],
    this.selected,
    this.tried = const {},
    this.values = const {},
    this.locked = const {},
    this.wrong = const {},
    this.touched = false,
  });

  // Read mode.
  final List<String> optionOrder;
  final String? selected;

  /// Options checked wrong: amber, not choosable again.
  final Set<String> tried;

  // Build mode.
  /// category id → the height the child has set.
  final Map<String, int> values;

  /// Categories checked right — fixed for the rest of the question.
  final Set<String> locked;

  /// Categories checked wrong and not changed since: drawn amber.
  final Set<String> wrong;

  /// A bar was moved at least once, so there is something to check — a
  /// target of 0 is legal, so an untouched chart can't be an answer.
  final bool touched;

  DataGraphState copyWith({
    String? selected,
    bool clearSelected = false,
    Set<String>? tried,
    Map<String, int>? values,
    Set<String>? locked,
    Set<String>? wrong,
    bool? touched,
  }) => DataGraphState(
    optionOrder: optionOrder,
    selected: clearSelected ? null : (selected ?? this.selected),
    tried: tried ?? this.tried,
    values: values ?? this.values,
    locked: locked ?? this.locked,
    wrong: wrong ?? this.wrong,
    touched: touched ?? this.touched,
  );
}

sealed class DataGraphAction {
  const DataGraphAction();
}

class PickGraphOption extends DataGraphAction {
  const PickGraphOption(this.optionId);
  final String optionId;
}

/// Raise (+1) or lower (−1) a bar.
class StepBar extends DataGraphAction {
  const StepBar(this.categoryId, this.delta);
  final String categoryId;
  final int delta;
}

/// Read or make a bar chart or a pictograph — the `data_graph` engine
/// (ADR 0041; the old product's engine of the same name).
///
/// **Read** is the old engine: a chart drawn from the content, and a
/// multiple-choice question about it ("Quel fruit est le plus aimé ?").
/// **Build** is new: the child raises each bar (or stacks each symbol) to
/// its count with − / + buttons, from a list to count or from the prompt,
/// and VALIDER checks each bar with partial credit — right bars lock, wrong
/// ones keep their height, amber, for the child to fix. Reading can be
/// faked with `mcq` and a picture; building can't, which is why this
/// engine exists.
///
/// Everything is drawn natively, so no picture assets are needed.
class DataGraphEngine
    implements
        LearningEngine<
          DataGraphContent,
          DataGraphState,
          DataGraphAction,
          AnswerValue
        > {
  const DataGraphEngine();

  static const key = 'data_graph';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static (String, String)? _entry(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
      return null;
    }
    return (id, label);
  }

  @override
  ParseResult<DataGraphContent> parse(Map<String, Object?> config) {
    final mode = switch (config['mode']) {
      null || 'read' => DataGraphMode.read,
      'build' => DataGraphMode.build,
      _ => null,
    };
    if (mode == null) {
      return const ParseResult.invalid('mode is read or build.');
    }
    final chart = switch (config['chart_type']) {
      null || 'bar' => ChartType.bar,
      'pictograph' => ChartType.pictograph,
      _ => null,
    };
    if (chart == null) {
      return const ParseResult.invalid('chart_type is bar or pictograph.');
    }

    final rawCats = config['categories'];
    if (rawCats is! List || rawCats.length < 2 || rawCats.length > 6) {
      return const ParseResult.invalid('A chart has 2 to 6 categories.');
    }
    final categories = <GraphCategory>[];
    for (final c in rawCats) {
      final e = _entry(c);
      final value = c is Map ? c['value'] : null;
      if (e == null || value is! int || value < 0) {
        return const ParseResult.invalid(
          'Every category needs an id, a label and a value of 0 or more.',
        );
      }
      if (categories.any((x) => x.id == e.$1)) {
        return const ParseResult.invalid('Category ids must be unique.');
      }
      final symbol = (c as Map)['symbol'];
      if (chart == ChartType.pictograph &&
          (symbol is! String || symbol.isEmpty)) {
        return const ParseResult.invalid(
          'A pictograph needs a symbol on every category.',
        );
      }
      categories.add(
        GraphCategory(
          id: e.$1,
          label: e.$2,
          value: value,
          symbol: symbol is String && symbol.isNotEmpty ? symbol : null,
        ),
      );
    }

    final top = categories.map((c) => c.value).reduce((a, b) => a > b ? a : b);
    final rawMax = config['max'];
    if (rawMax != null && (rawMax is! int || rawMax < 1 || rawMax > 20)) {
      return const ParseResult.invalid('max is a whole number from 1 to 20.');
    }
    final max = rawMax is int ? rawMax : (top < 5 ? 5 : (top <= 10 ? 10 : 20));
    if (top > max) {
      return const ParseResult.invalid('A value is above the chart\'s max.');
    }

    var options = <GraphOption>[];
    String? correct;
    var source = const <String>[];
    if (mode == DataGraphMode.read) {
      final rawOptions = config['options'];
      if (rawOptions is! List ||
          rawOptions.length < 2 ||
          rawOptions.length > 4) {
        return const ParseResult.invalid('Reading needs 2 to 4 options.');
      }
      for (final o in rawOptions) {
        final e = _entry(o);
        if (e == null) {
          return const ParseResult.invalid(
            'Every option needs an id and a label.',
          );
        }
        if (options.any((x) => x.id == e.$1)) {
          return const ParseResult.invalid('Option ids must be unique.');
        }
        options.add(GraphOption(id: e.$1, label: e.$2));
      }
      final c = config['correct'];
      if (c is! String || !options.any((o) => o.id == c)) {
        return const ParseResult.invalid('correct must name an option.');
      }
      correct = c;
    } else {
      if (config['options'] != null || config['correct'] != null) {
        return const ParseResult.invalid(
          'Building has no options: the bars are the answer.',
        );
      }
      final rawSource = config['source'];
      if (rawSource != null) {
        if (rawSource is! List ||
            rawSource.length > 40 ||
            rawSource.any((s) => s is! String || s.isEmpty)) {
          return const ParseResult.invalid(
            'source is a list of at most 40 things to count.',
          );
        }
        source = List.unmodifiable(rawSource.cast<String>());
      }
    }
    final shuffle = config['shuffle'];
    return ParseResult.ok(
      DataGraphContent(
        mode: mode,
        chartType: chart,
        categories: List.unmodifiable(categories),
        max: max,
        options: List.unmodifiable(options),
        correct: correct,
        source: source,
        shuffleOptions: shuffle is bool ? shuffle : true,
      ),
    );
  }

  @override
  DataGraphState initialize(DataGraphContent content, EngineSeed seed) {
    if (content.mode == DataGraphMode.build) {
      return DataGraphState(
        values: {for (final c in content.categories) c.id: 0},
      );
    }
    final order = [for (final o in content.options) o.id];
    if (content.shuffleOptions) order.shuffle(seed.random());
    return DataGraphState(optionOrder: List.unmodifiable(order));
  }

  @override
  Transition<DataGraphState> reduce(DataGraphState s, DataGraphAction action) {
    switch (action) {
      case PickGraphOption(:final optionId):
        if (!s.optionOrder.contains(optionId) ||
            s.tried.contains(optionId) ||
            s.selected == optionId) {
          return Transition(s);
        }
        return Transition(s.copyWith(selected: optionId), [
          InteractionEvent('option_selected', {'option_id': optionId}),
        ]);
      case StepBar(:final categoryId, :final delta):
        final now = s.values[categoryId];
        if (now == null || s.locked.contains(categoryId) || delta == 0) {
          return Transition(s);
        }
        final next = now + (delta > 0 ? 1 : -1);
        // The engine doesn't know max (content isn't in reduce); the view
        // disables + at the top, and a value below 0 is meaningless.
        if (next < 0) return Transition(s);
        return Transition(
          s.copyWith(
            values: {...s.values, categoryId: next},
            wrong: {...s.wrong}..remove(categoryId),
            touched: true,
          ),
          [
            InteractionEvent('tile_moved', {
              'category_id': categoryId,
              'count': next,
            }),
          ],
        );
    }
  }

  @override
  AnswerValue? extractAnswer(DataGraphState s) {
    if (s.optionOrder.isNotEmpty) {
      return s.selected == null ? null : SingleChoiceAnswer(s.selected!);
    }
    if (!s.touched || s.locked.length == s.values.length) return null;
    return BlanksAnswer({
      for (final e in s.values.entries) e.key: '${e.value}',
    });
  }

  @override
  DataGraphState applyFeedback(DataGraphState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    if (s.optionOrder.isNotEmpty) {
      return result.outcome == Outcome.correct || s.selected == null
          ? s
          : s.copyWith(tried: {...s.tried, s.selected!}, clearSelected: true);
    }
    final right = {
      for (final e in result.itemResults.entries)
        if (e.value) e.key,
    };
    return s.copyWith(
      locked: {...s.locked, ...right},
      wrong: {
        for (final e in result.itemResults.entries)
          if (!e.value) e.key,
      },
      // Fixing one bar is a new answer to check.
      touched: false,
    );
  }

  @override
  Map<String, Object?> snapshot(DataGraphState s) => {
    'option_order': s.optionOrder,
    'selected': s.selected,
    'tried': s.tried.toList(),
    'values': s.values,
    'locked': s.locked.toList(),
    'wrong': s.wrong.toList(),
    'touched': s.touched,
  };

  @override
  DataGraphState? restore(DataGraphContent content, Map<String, Object?> snap) {
    try {
      Set<String> set(String k) =>
          ((snap[k] as List?) ?? const []).cast<String>().toSet();
      final order = ((snap['option_order'] as List?) ?? const [])
          .cast<String>();
      final values = ((snap['values'] as Map?) ?? const {}).cast<String, int>();
      if (content.mode == DataGraphMode.read) {
        final known = {for (final o in content.options) o.id};
        if (order.length != known.length || !order.every(known.contains)) {
          return null;
        }
        final selected = snap['selected'] as String?;
        if (selected != null && !known.contains(selected)) return null;
        if (!set('tried').every(known.contains)) return null;
        return DataGraphState(
          optionOrder: List.unmodifiable(order),
          selected: selected,
          tried: set('tried'),
        );
      }
      final cats = {for (final c in content.categories) c.id};
      if (values.length != cats.length ||
          !values.keys.every(cats.contains) ||
          values.values.any((v) => v < 0 || v > content.max)) {
        return null;
      }
      return DataGraphState(
        values: values,
        locked: set('locked'),
        wrong: set('wrong'),
        touched: snap['touched'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<DataGraphContent, DataGraphState, DataGraphAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final content = view.content;
    final p = VillagePalette.of(context);
    final build = content.mode == DataGraphMode.build;

    final chart = _Chart(
      content: content,
      values: build
          ? s.values
          : {for (final c in content.categories) c.id: c.value},
      locked: s.locked,
      wrong: s.wrong,
      fr: fr,
      stepper: build
          ? (c) => _Stepper(
              key: ValueKey('graph-step-${c.id}'),
              id: c.id,
              label: c.label,
              value: s.values[c.id]!,
              max: content.max,
              fr: fr,
              onStep: view.enabled && !s.locked.contains(c.id)
                  ? (d) => view.dispatch(StepBar(c.id, d))
                  : null,
            )
          : null,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (content.source.isNotEmpty) ...[
                Semantics(
                  label: fr
                      ? 'À compter : ${content.source.join(', ')}'
                      : 'To count: ${content.source.join(', ')}',
                  excludeSemantics: true,
                  child: Container(
                    key: const ValueKey('graph-source'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: Radii.cardMd,
                      border: Border.all(color: p.line, width: 2),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final t in content.source)
                          SwatchText(t, style: const TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              chart,
              if (!build) ...[
                const SizedBox(height: 24),
                // Big centred answers, numbers as square tiles (UX review
                // AM3).
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: ChoiceLayout(
                    ids: s.optionOrder,
                    labelOf: (id) => content.option(id)!.label,
                    tile: (id, {required square}) => AnswerTile(
                      key: ValueKey('graph-option-$id'),
                      label: content.option(id)!.label,
                      prominent: true,
                      labelSize: AnswerTile.sharedLabelSize(
                        content.options.map((o) => o.label),
                        prominent: true,
                      ),
                      square: square,
                      // Three misses: one wrong answer is set aside (G8).
                      dimmed:
                          content.correct != null &&
                          ActivityAssist.narrowOf(context) &&
                          id ==
                              answerToDim(
                                order: s.optionOrder,
                                right: {content.correct!},
                                tried: s.tried,
                              ),
                      state: s.tried.contains(id)
                          ? AnswerTileState.retry
                          : s.selected == id
                          ? AnswerTileState.picked
                          : AnswerTileState.idle,
                      semanticsState: s.tried.contains(id)
                          ? (fr ? 'déjà essayé' : 'already tried')
                          : null,
                      onTap: view.enabled && !s.tried.contains(id)
                          ? () => view.dispatch(PickGraphOption(id))
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The chart itself: a value axis, a bar or a stack of symbols per
/// category, and the category's label under it. Purely drawn from data, so
/// the same widget shows the content's chart (read) and the child's (build).
class _Chart extends StatelessWidget {
  const _Chart({
    required this.content,
    required this.values,
    required this.locked,
    required this.wrong,
    required this.fr,
    this.stepper,
  });

  final DataGraphContent content;
  final Map<String, int> values;
  final Set<String> locked;
  final Set<String> wrong;
  final bool fr;
  final Widget Function(GraphCategory c)? stepper;

  // Tall enough that a pictograph's faces are ~26 px and the axis reads at
  // 15 px on a phone (UX review AM26: 14 px faces, 8 px numbers).
  static const _height = 260.0;
  static const _axis = 40.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final max = content.max;
    final unit = _height / max;
    // Label every value up to 10, every other one above.
    final every = max <= 10 ? 1 : 2;
    final axisStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: p.inkMuted,
    );
    final labelStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: p.ink,
    );

    Color fillOf(String id) => locked.contains(id)
        ? p.success
        : wrong.contains(id)
        ? p.retry
        : p.quebecBlueBright;

    Widget column(GraphCategory c) {
      final v = values[c.id] ?? 0;
      final name = fr ? '${c.label} : $v' : '${c.label}: $v';
      final mark = locked.contains(c.id)
          ? Icons.check_rounded
          : wrong.contains(c.id)
          ? Icons.track_changes_rounded
          : null;
      final body = content.chartType == ChartType.bar
          ? Container(
              key: ValueKey('graph-bar-${c.id}'),
              height: v * unit,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: fillOf(c.id),
                borderRadius: const BorderRadius.vertical(top: Radii.sm),
              ),
            )
          : Column(
              key: ValueKey('graph-bar-${c.id}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < v; i++)
                  SizedBox(
                    height: unit,
                    child: FittedBox(child: SwatchText(c.symbol ?? '■')),
                  ),
              ],
            );
      return Expanded(
        child: Semantics(
          label: name,
          excludeSemantics: stepper == null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _height + 20,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (mark != null) Icon(mark, size: 16, color: fillOf(c.id)),
                    body,
                  ],
                ),
              ),
              Container(height: 2, color: p.ink),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: SwatchText(
                  content.chartType == ChartType.pictograph
                      ? '${c.symbol} ${c.label}'
                      : c.label,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
              if (stepper != null) ...[const SizedBox(height: 8), stepper!(c)],
            ],
          ),
        ),
      );
    }

    return Row(
      key: const ValueKey('graph-chart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The value axis, aligned with the bars' baseline.
        ExcludeSemantics(
          child: SizedBox(
            width: _axis,
            height: _height + 20,
            child: Stack(
              // « 0 » sits half below the baseline; don't cut it.
              clipBehavior: Clip.none,
              children: [
                for (var v = 0; v <= max; v += every)
                  Positioned(
                    right: 6,
                    bottom: v * unit - 9,
                    child: Text('$v', style: axisStyle),
                  ),
              ],
            ),
          ),
        ),
        for (final c in content.categories) column(c),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.label,
    required this.value,
    required this.max,
    required this.fr,
    required this.onStep,
    super.key,
  });

  final String id;
  final String label;
  final int value;
  final int max;
  final bool fr;
  final void Function(int delta)? onStep;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    Widget button(int delta, IconData icon, String name) {
      final enabled = onStep != null && (delta < 0 ? value > 0 : value < max);
      return Semantics(
        button: true,
        enabled: enabled,
        label: name,
        excludeSemantics: true,
        child: Material(
          color: enabled ? p.surface : p.track.withValues(alpha: 0.35),
          shape: CircleBorder(side: BorderSide(color: p.line, width: 2)),
          child: InkWell(
            key: ValueKey('graph-$id-${delta > 0 ? 'plus' : 'minus'}'),
            customBorder: const CircleBorder(),
            onTap: enabled ? () => onStep!(delta) : null,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 20, color: p.ink),
            ),
          ),
        ),
      );
    }

    final minus = button(
      -1,
      Icons.remove_rounded,
      fr ? 'moins de $label' : 'fewer $label',
    );
    final plus = button(
      1,
      Icons.add_rounded,
      fr ? 'plus de $label' : 'more $label',
    );
    // Side by side when the column has room; stacked (+ on top, as a bar
    // grows up) when six categories share a phone.
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 100
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [minus, const SizedBox(width: 4), plus],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [plus, const SizedBox(height: 4), minus],
            ),
    );
  }
}

/// Grades either mode.
///
/// Read: the picked option against `correct`, like `mcq`. Build: each bar
/// against its count, with partial credit; [EvaluationResult.itemResults]
/// is keyed by category id.
class DataGraphEvaluator implements Evaluator<DataGraphContent, AnswerValue> {
  const DataGraphEvaluator();

  @override
  String get engineKey => DataGraphEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    DataGraphContent content,
    AnswerValue answer,
    EvaluationContext ctx,
  ) {
    final Map<String, bool> items;
    if (content.mode == DataGraphMode.read) {
      final picked = (answer as SingleChoiceAnswer).selectedOptionId;
      if (content.option(picked) == null) {
        throw ArgumentError('Answer names an option this chart lacks.');
      }
      items = const {};
      final right = picked == content.correct;
      return _result(right ? 1 : 0, 1, items, ctx);
    }
    final built = (answer as BlanksAnswer).blanks;
    items = {
      for (final c in content.categories) c.id: built[c.id] == '${c.value}',
    };
    final right = items.values.where((v) => v).length;
    return _result(right, items.length, items, ctx);
  }

  EvaluationResult _result(
    int right,
    int of,
    Map<String, bool> items,
    EvaluationContext ctx,
  ) => EvaluationResult(
    outcome: right == of
        ? Outcome.correct
        : right == 0
        ? Outcome.incorrect
        : Outcome.partial,
    score: right / of,
    attemptNumber: ctx.attemptNumber,
    evaluator: '$engineKey.$policy@$version',
    skillNodeIds: ctx.skillNodeIds,
    itemResults: items,
    errors: right == of ? const [] : const [ErrorClassification.unclassified()],
  );
}
