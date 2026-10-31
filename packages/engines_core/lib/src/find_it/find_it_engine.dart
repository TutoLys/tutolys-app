import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/swatch_text.dart';

/// How the scene is laid out. The content decides; the engine never
/// reorders a sentence or a plan.
enum FindItLayout {
  /// Separate things, shuffled into a wrapping row (the old engine).
  items,

  /// A sentence: words and marks in reading order, as tappable chips.
  words,

  /// One word, letter by letter, with no gap between them: "Touche la
  /// lettre muette dans « vert »".
  letters,

  /// Rows × columns, row-major: a plan, a map, a Cartesian grid.
  grid,
}

class FindItCell {
  const FindItCell({
    required this.id,
    required this.label,
    this.join = false,
    this.imageRef,
  });
  final String id;

  /// `items` and `grid` only: a picture in place of (grid) or beside
  /// (items) the label. Sentences and words stay text.
  final String? imageRef;

  /// What the cell shows. May be empty in a grid (an empty square on a
  /// plan is still a place you can point at).
  final String label;

  /// `words` only: no space before this cell, so "dort." reads as written
  /// while "." stays tappable on its own.
  final bool join;

  /// Marks that never take a space before them, in either language. French
  /// puts one before « ? ! : ; », so those are the content's call (`join`).
  static const joinsByDefault = {'.', ',', ')', '»', '…'};
}

/// Text drawn on the four sides of a grid: the compass of a plan.
class EdgeLabels {
  const EdgeLabels({this.top, this.right, this.bottom, this.left});
  final String? top;
  final String? right;
  final String? bottom;
  final String? left;

  bool get isEmpty =>
      top == null && right == null && bottom == null && left == null;
}

class LegendEntry {
  const LegendEntry({required this.symbol, required this.label});
  final String symbol;
  final String label;
}

class FindItContent {
  const FindItContent({
    required this.layout,
    required this.cells,
    required this.correct,
    this.columns = 0,
    this.rowLabels = const [],
    this.columnLabels = const [],
    this.legend = const [],
    this.edges = const EdgeLabels(),
    this.bottomOrigin = false,
    this.shuffle = true,
  });

  final FindItLayout layout;
  final List<FindItCell> cells;
  final Set<String> correct;

  /// Grid only.
  final int columns;

  /// Grid only, optional: drawn left of each row and under each column.
  /// Both, like [cells], are held in **display order**, top row first —
  /// parse turns a bottom-left-origin grid around once, so nothing after it
  /// has to know.
  final List<String> rowLabels;
  final List<String> columnLabels;

  /// Optional: what the symbols on a plan mean ("🏫 l'école").
  final List<LegendEntry> legend;

  /// Grid only, optional: "Nord" above, "Sud" below…
  final EdgeLabels edges;

  /// Grid only: the content listed its rows from the bottom up (a Cartesian
  /// grid, where (2, 3) is 2 right and 3 up). Only changes how an unlabelled
  /// row is counted for a screen reader; the cells are already turned.
  final bool bottomOrigin;

  /// `items` layout only.
  final bool shuffle;

  bool get multiple => correct.length > 1;
  int get rows => columns == 0 ? 0 : cells.length ~/ columns;
  FindItCell cell(String id) => cells.firstWhere((c) => c.id == id);
}

class FindItState {
  const FindItState({
    required this.order,
    this.single = false,
    this.selected = const {},
    this.found = const {},
    this.tried = const {},
  });

  /// Cell ids in display order.
  final List<String> order;

  /// One right answer: a new pick replaces the last, like choosing.
  final bool single;

  /// Picked and not yet checked.
  final Set<String> selected;

  /// Checked right — fixed for the rest of the question.
  final Set<String> found;

  /// Checked wrong — amber, and no longer tappable.
  final Set<String> tried;

  FindItState copyWith({
    Set<String>? selected,
    Set<String>? found,
    Set<String>? tried,
  }) => FindItState(
    order: order,
    single: single,
    selected: selected ?? this.selected,
    found: found ?? this.found,
    tried: tried ?? this.tried,
  );
}

sealed class FindItAction {
  const FindItAction();
}

class TapCell extends FindItAction {
  const TapCell(this.cellId);
  final String cellId;
}

/// Find the thing that matches — the `find_it` engine (ADR 0028; the old
/// product's engine of the same name).
///
/// "Touche le nom", "Où est l'école ?", "Touche la case (2, 3)", "Touche
/// tous les nombres pairs". Tap to pick; with one right answer a new tap
/// replaces the pick, with several each tap toggles. VALIDER checks the
/// picks with **partial credit**: right ones lock, wrong ones turn amber
/// and can't be picked again — the old engine's "a wrong guess costs
/// nothing", without letting a child tap every cell to win.
///
/// Text and emoji only for now. A picture background with tappable regions
/// is a later, additive mode once images render (ADR 0025).
class FindItEngine
    implements
        LearningEngine<
          FindItContent,
          FindItState,
          FindItAction,
          MultiSelectAnswer
        > {
  const FindItEngine();

  static const key = 'find_it';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static List<String>? _strings(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.any((x) => x is! String)) return null;
    return raw.cast<String>();
  }

  @override
  ParseResult<FindItContent> parse(Map<String, Object?> config) {
    final layout = switch (config['layout']) {
      null || 'items' => FindItLayout.items,
      'words' => FindItLayout.words,
      'letters' => FindItLayout.letters,
      'grid' => FindItLayout.grid,
      _ => null,
    };
    if (layout == null) {
      return const ParseResult.invalid(
        'layout is items, words, letters or grid.',
      );
    }
    final raw = config['scene_items'];
    final (min, max) = switch (layout) {
      FindItLayout.items => (3, 12),
      FindItLayout.words => (2, 24),
      FindItLayout.letters => (2, 16),
      FindItLayout.grid => (4, 64),
    };
    if (raw is! List || raw.length < min || raw.length > max) {
      return ParseResult.invalid(
        'A $layout scene needs between $min and $max scene_items.',
      );
    }
    final cells = <FindItCell>[];
    for (final c in raw) {
      final id = c is Map ? c['id'] : null;
      final label = c is Map ? c['label'] : null;
      // Only a grid may have blank cells.
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          (label.isEmpty && layout != FindItLayout.grid)) {
        return const ParseResult.invalid(
          'Every scene item needs an id and a label.',
        );
      }
      if (cells.any((x) => x.id == id)) {
        return const ParseResult.invalid('Scene item ids must be unique.');
      }
      final join = c['join'];
      if (join != null && join is! bool) {
        return const ParseResult.invalid('join must be true or false.');
      }
      final image = c['image_ref'];
      cells.add(
        FindItCell(
          id: id,
          label: label,
          imageRef: image is String && image.isNotEmpty ? image : null,
          join: join is bool
              ? join
              : FindItCell.joinsByDefault.contains(label.trim()),
        ),
      );
    }
    final ids = {for (final c in cells) c.id};
    final correct = _strings(config['correct_ids']);
    if (correct == null ||
        correct.isEmpty ||
        correct.toSet().length != correct.length ||
        !correct.every(ids.contains)) {
      return const ParseResult.invalid(
        'correct_ids must name one or more scene items, each once.',
      );
    }
    if (correct.length == cells.length) {
      return const ParseResult.invalid(
        'If every item is right, there is nothing to find.',
      );
    }

    var columns = 0;
    var rowLabels = const <String>[];
    var columnLabels = const <String>[];
    var edges = const EdgeLabels();
    var bottomOrigin = false;
    var displayCells = cells;
    if (layout == FindItLayout.grid) {
      final c = config['columns'];
      if (c is! int || c < 2 || c > 8 || cells.length % c != 0) {
        return const ParseResult.invalid(
          'A grid needs 2 to 8 columns that divide its scene_items evenly.',
        );
      }
      columns = c;
      final rows = cells.length ~/ c;
      if (rows < 2 || rows > 8) {
        return const ParseResult.invalid('A grid has 2 to 8 rows.');
      }
      final rl = _strings(config['row_labels']);
      final cl = _strings(config['column_labels']);
      if (rl == null || (rl.isNotEmpty && rl.length != rows)) {
        return const ParseResult.invalid('row_labels needs one per row.');
      }
      if (cl == null || (cl.isNotEmpty && cl.length != c)) {
        return const ParseResult.invalid('column_labels needs one per column.');
      }
      final origin = config['origin'];
      if (origin != null && origin != 'top_left' && origin != 'bottom_left') {
        return const ParseResult.invalid('origin is top_left or bottom_left.');
      }
      bottomOrigin = origin == 'bottom_left';
      columnLabels = cl;
      if (bottomOrigin) {
        // Listed bottom row first: turn rows (and their labels) into
        // display order once, here.
        displayCells = [
          for (var r = rows - 1; r >= 0; r--)
            ...cells.sublist(r * c, (r + 1) * c),
        ];
        rowLabels = rl.reversed.toList();
      } else {
        rowLabels = rl;
      }
      final rawEdges = config['edge_labels'];
      if (rawEdges != null) {
        if (rawEdges is! Map) {
          return const ParseResult.invalid('edge_labels must be an object.');
        }
        String? side(String k) {
          final v = rawEdges[k];
          return v is String && v.isNotEmpty ? v : null;
        }

        edges = EdgeLabels(
          top: side('top'),
          right: side('right'),
          bottom: side('bottom'),
          left: side('left'),
        );
      }
    }

    final legend = <LegendEntry>[];
    final rawLegend = config['legend'];
    if (rawLegend != null) {
      if (rawLegend is! List || rawLegend.length > 8) {
        return const ParseResult.invalid('legend allows at most 8 entries.');
      }
      for (final e in rawLegend) {
        final symbol = e is Map ? e['symbol'] : null;
        final label = e is Map ? e['label'] : null;
        if (symbol is! String ||
            symbol.isEmpty ||
            label is! String ||
            label.isEmpty) {
          return const ParseResult.invalid(
            'Every legend entry needs a symbol and a label.',
          );
        }
        legend.add(LegendEntry(symbol: symbol, label: label));
      }
    }

    final shuffle = config['shuffle'];
    return ParseResult.ok(
      FindItContent(
        layout: layout,
        cells: List.unmodifiable(displayCells),
        correct: correct.toSet(),
        columns: columns,
        edges: edges,
        bottomOrigin: bottomOrigin,
        rowLabels: List.unmodifiable(rowLabels),
        columnLabels: List.unmodifiable(columnLabels),
        legend: List.unmodifiable(legend),
        shuffle: shuffle is bool ? shuffle : true,
      ),
    );
  }

  @override
  FindItState initialize(FindItContent content, EngineSeed seed) {
    final order = [for (final c in content.cells) c.id];
    // A sentence or a plan has its own order; only loose items shuffle.
    if (content.layout == FindItLayout.items && content.shuffle) {
      order.shuffle(seed.random());
    }
    return FindItState(
      order: List.unmodifiable(order),
      single: !content.multiple,
    );
  }

  @override
  Transition<FindItState> reduce(FindItState s, FindItAction action) {
    switch (action) {
      case TapCell(:final cellId):
        if (!s.order.contains(cellId) ||
            s.found.contains(cellId) ||
            s.tried.contains(cellId)) {
          return Transition(s);
        }
        if (s.selected.contains(cellId)) {
          return Transition(
            s.copyWith(selected: {...s.selected}..remove(cellId)),
            [
              InteractionEvent('option_deselected', {'option_id': cellId}),
            ],
          );
        }
        return Transition(
          s.copyWith(selected: s.single ? {cellId} : {...s.selected, cellId}),
          [
            InteractionEvent('option_selected', {'option_id': cellId}),
          ],
        );
    }
  }

  @override
  MultiSelectAnswer? extractAnswer(FindItState s) => s.selected.isEmpty
      ? null
      : MultiSelectAnswer({...s.found, ...s.selected});

  @override
  FindItState applyFeedback(FindItState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final right = {
      for (final e in result.itemResults.entries)
        if (e.value) e.key,
    };
    final wrong = {
      for (final e in result.itemResults.entries)
        if (!e.value) e.key,
    };
    return s.copyWith(
      selected: const {},
      found: {...s.found, ...right},
      tried: {...s.tried, ...wrong},
    );
  }

  @override
  Map<String, Object?> snapshot(FindItState s) => {
    'order': s.order,
    'selected': s.selected.toList(),
    'found': s.found.toList(),
    'tried': s.tried.toList(),
  };

  @override
  FindItState? restore(FindItContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final known = {for (final c in content.cells) c.id};
      if (order.length != known.length || !order.every(known.contains)) {
        return null;
      }
      Set<String> set(String k) =>
          ((snap[k] as List?) ?? const []).cast<String>().toSet();
      final selected = set('selected');
      final found = set('found');
      final tried = set('tried');
      if (!selected.followedBy(found).followedBy(tried).every(known.contains)) {
        return null;
      }
      if (!content.correct.containsAll(found) ||
          tried.any(content.correct.contains)) {
        return null;
      }
      if (content.layout != FindItLayout.items) {
        // A sentence or a plan is never reordered.
        final authored = [for (final c in content.cells) c.id];
        for (var i = 0; i < order.length; i++) {
          if (order[i] != authored[i]) return null;
        }
      }
      if (!content.multiple && selected.length > 1) return null;
      return FindItState(
        order: List.unmodifiable(order),
        single: !content.multiple,
        selected: selected,
        found: found,
        tried: tried,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<FindItContent, FindItState, FindItAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final content = view.content;
    final p = VillagePalette.of(context);

    AnswerTileState stateOf(String id) => s.found.contains(id)
        ? AnswerTileState.correct
        : s.tried.contains(id)
        ? AnswerTileState.retry
        : s.selected.contains(id)
        ? AnswerTileState.picked
        : AnswerTileState.idle;

    String? hintOf(String id) => s.found.contains(id)
        ? (fr ? 'trouvé' : 'found')
        : s.tried.contains(id)
        ? (fr ? 'déjà essayé' : 'already tried')
        : s.selected.contains(id)
        ? (fr ? 'choisi' : 'chosen')
        : null;

    VoidCallback? tapOf(String id) =>
        view.enabled && !s.found.contains(id) && !s.tried.contains(id)
        ? () => view.dispatch(TapCell(id))
        : null;

    final scene = switch (content.layout) {
      FindItLayout.items => Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final id in s.order)
            SizedBox(
              width: 140,
              child: AnswerTile(
                key: ValueKey('find-cell-$id'),
                label: content.cell(id).label,
                imageRef: content.cell(id).imageRef,
                state: stateOf(id),
                semanticsState: hintOf(id),
                onTap: tapOf(id),
              ),
            ),
        ],
      ),
      FindItLayout.words => Wrap(
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, id) in s.order.indexed)
            Padding(
              // A word gets a space before it; a joined mark doesn't.
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : (content.cell(id).join ? 2 : 8),
              ),
              child: _FindCell(
                key: ValueKey('find-cell-$id'),
                label: content.cell(id).label,
                semanticsLabel: content.cell(id).label,
                state: stateOf(id),
                hint: hintOf(id),
                onTap: tapOf(id),
                shape: _CellShape.word,
              ),
            ),
        ],
      ),
      FindItLayout.letters => Wrap(
        spacing: 2,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, id) in s.order.indexed)
            _FindCell(
              key: ValueKey('find-cell-$id'),
              label: content.cell(id).label,
              // "lettre 3 : r" — a letter alone is ambiguous when repeated.
              semanticsLabel: fr
                  ? 'lettre ${i + 1} : ${content.cell(id).label}'
                  : 'letter ${i + 1}: ${content.cell(id).label}',
              state: stateOf(id),
              hint: hintOf(id),
              onTap: tapOf(id),
              shape: _CellShape.letter,
            ),
        ],
      ),
      FindItLayout.grid => _Grid(
        content: content,
        cellBuilder: (id, row, column, size) {
          final label = content.cell(id).label;
          final where = _place(content, row, column, fr);
          return _FindCell(
            key: ValueKey('find-cell-$id'),
            label: label,
            semanticsLabel: label.isEmpty ? where : '$label, $where',
            state: stateOf(id),
            hint: hintOf(id),
            onTap: tapOf(id),
            shape: _CellShape.square,
            size: size,
            imageRef: content.cell(id).imageRef,
          );
        },
      ),
    };

    final toFind = content.correct.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (content.multiple)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    fr
                        ? 'Trouvés : ${s.found.length} sur $toFind'
                        : 'Found: ${s.found.length} of $toFind',
                    key: const ValueKey('find-count'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.inkMuted,
                    ),
                  ),
                ),
              scene,
              if (content.legend.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  key: const ValueKey('find-legend'),
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final e in content.legend)
                      SwatchText(
                        '${e.symbol}  ${e.label}',
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: p.ink,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Where a grid cell is, for a screen reader: by its labels when the
  /// content has them ("colonne 2, rangée 3"), by position otherwise.
  static String _place(FindItContent c, int row, int column, bool fr) {
    final col = c.columnLabels.isNotEmpty
        ? c.columnLabels[column]
        : '${column + 1}';
    final r = c.rowLabels.isNotEmpty
        ? c.rowLabels[row]
        : '${c.bottomOrigin ? c.rows - row : row + 1}';
    return fr ? 'colonne $col, rangée $r' : 'column $col, row $r';
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.content, required this.cellBuilder});

  final FindItContent content;
  final Widget Function(String id, int row, int column, double size)
  cellBuilder;

  static const _gap = 6.0;
  static const _axis = 28.0;
  static const _edge = 22.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final hasRows = content.rowLabels.isNotEmpty;
    final hasColumns = content.columnLabels.isNotEmpty;
    final axisStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: p.inkMuted,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = content.columns;
        final edges = content.edges;
        final sides =
            (edges.left != null ? _edge + _gap : 0) +
            (edges.right != null ? _edge + _gap : 0);
        final room =
            constraints.maxWidth -
            sides -
            (hasRows ? _axis + _gap : 0) -
            _gap * (n - 1);
        // Never so big a 2×2 fills the screen. As big as fits otherwise: a
        // full 8×8 plan on a phone gets ~34px squares, below the 48px
        // target, which content keeps to big screens or fewer columns.
        final size = (room / n).clamp(0.0, 76.0);
        Widget axisLabel(String text, {double? width, double? height}) =>
            SizedBox(
              width: width,
              height: height,
              child: Center(
                child: ExcludeSemantics(child: Text(text, style: axisStyle)),
              ),
            );
        Widget edge(String text, {int turns = 0}) => Semantics(
          label: text,
          child: ExcludeSemantics(
            child: RotatedBox(
              quarterTurns: turns,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: axisStyle.copyWith(color: p.quebecBlue),
              ),
            ),
          ),
        );
        final grid = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < content.rows; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRows) ...[
                    axisLabel(content.rowLabels[r], width: _axis),
                    const SizedBox(width: _gap),
                  ],
                  for (var c = 0; c < n; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    cellBuilder(content.cells[r * n + c].id, r, c, size),
                  ],
                ],
              ),
            ],
            // Column labels sit under the grid, like a graph's x axis.
            if (hasColumns) ...[
              const SizedBox(height: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRows) const SizedBox(width: _axis + _gap),
                  for (var c = 0; c < n; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    axisLabel(
                      content.columnLabels[c],
                      width: size,
                      height: _axis,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
        if (edges.isEmpty) return Center(child: grid);
        return Center(
          child: Column(
            key: const ValueKey('find-edges'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (edges.top != null) ...[
                edge(edges.top!),
                const SizedBox(height: _gap),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (edges.left != null) ...[
                    SizedBox(width: _edge, child: edge(edges.left!, turns: 3)),
                    const SizedBox(width: _gap),
                  ],
                  grid,
                  if (edges.right != null) ...[
                    const SizedBox(width: _gap),
                    SizedBox(width: _edge, child: edge(edges.right!, turns: 1)),
                  ],
                ],
              ),
              if (edges.bottom != null) ...[
                const SizedBox(height: _gap),
                edge(edges.bottom!),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _CellShape { word, letter, square }

/// One tappable square of a plan or word of a sentence. Same four states as
/// [AnswerTile], and like it each state reads without colour: picked has a
/// thick border and is announced "selected", found carries a check, tried
/// carries the amber target icon.
class _FindCell extends StatelessWidget {
  const _FindCell({
    required this.label,
    required this.semanticsLabel,
    required this.state,
    required this.hint,
    required this.onTap,
    required this.shape,
    this.size = 0,
    this.imageRef,
    super.key,
  });

  final String label;
  final String semanticsLabel;
  final AnswerTileState state;
  final String? hint;
  final VoidCallback? onTap;
  final _CellShape shape;
  final double size;

  /// Square cells only: the picture fills the square, and the label is what
  /// shows until it has synced.
  final String? imageRef;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final (border, fill, icon) = switch (state) {
      AnswerTileState.idle => (p.line, p.surface, null),
      AnswerTileState.picked => (p.quebecBlueBright, p.navHoverFill, null),
      AnswerTileState.retry => (
        p.retry,
        p.retryPale,
        Icons.track_changes_rounded,
      ),
      AnswerTileState.correct => (
        p.success,
        p.successPale,
        Icons.check_rounded,
      ),
    };
    final square = shape == _CellShape.square;
    final text = SwatchText(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w700,
        // Emoji on a plan read better big; words stay text-sized.
        fontSize: square
            ? size * 0.42
            : shape == _CellShape.letter
            ? 28
            : 20,
        color: p.ink,
      ),
    );
    final body = square
        ? SizedBox(
            width: size,
            height: size,
            child: imageRef == null
                ? Center(child: text)
                : Padding(
                    padding: EdgeInsets.all(size * 0.1),
                    child: ContentImage(
                      ref: imageRef!,
                      fallback: Center(child: text),
                    ),
                  ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 40),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: shape == _CellShape.letter ? 6 : 12,
                vertical: 8,
              ),
              child: Center(widthFactor: 1, child: text),
            ),
          );
    return Semantics(
      button: true,
      selected: state == AnswerTileState.picked,
      enabled: onTap != null,
      label: semanticsLabel,
      hint: hint,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: square ? Radii.cardSm : Radii.cardMd,
          side: BorderSide(
            color: border,
            width: state == AnswerTileState.picked ? 3 : 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: square ? Radii.cardSm : Radii.cardMd,
          child: Stack(
            children: [
              body,
              if (icon != null)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Icon(icon, size: 14, color: border),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades the picks of a `find_it` scene.
///
/// [EvaluationResult.itemResults] has one entry per pick, keyed by cell id:
/// true for a right one, false for a wrong one. Right cells not picked yet
/// aren't listed — they are simply still to find. Score is right picks over
/// (right cells + wrong picks), so picking everything never scores well.
class FindItEvaluator implements Evaluator<FindItContent, MultiSelectAnswer> {
  const FindItEvaluator();

  @override
  String get engineKey => FindItEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    FindItContent content,
    MultiSelectAnswer answer,
    EvaluationContext ctx,
  ) {
    final picks = answer.selectedOptionIds;
    if (picks.isEmpty) throw ArgumentError('An answer must pick something.');
    final items = {for (final id in picks) id: content.correct.contains(id)};
    final hits = items.values.where((v) => v).length;
    final misses = items.length - hits;
    final all = hits == content.correct.length && misses == 0;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / (content.correct.length + misses),
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
