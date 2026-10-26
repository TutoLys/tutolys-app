import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/answer_tile.dart';

typedef Cell = (int row, int col);

/// The four moves, by id. Stored the same whatever the buttons say.
const pathMoves = {
  'up': (-1, 0),
  'down': (1, 0),
  'left': (0, -1),
  'right': (0, 1),
};

class PathLandmark {
  const PathLandmark({
    required this.id,
    required this.cell,
    required this.label,
  });
  final String id;
  final Cell cell;
  final String label;
}

class PathContent {
  const PathContent({
    required this.rows,
    required this.cols,
    required this.start,
    required this.goal,
    this.walls = const {},
    this.landmarks = const [],
    this.mustVisit = const [],
    this.cardinal = false,
    this.maxMoves = 12,
    this.showPath = true,
    this.shortest = 0,
  });

  final int rows;
  final int cols;
  final Cell start;
  final Cell goal;
  final Set<Cell> walls;
  final List<PathLandmark> landmarks;

  /// Landmark ids the route must pass through, in any order.
  final List<String> mustVisit;

  /// Buttons read N E S O instead of arrows; north is up.
  final bool cardinal;
  final int maxMoves;

  /// Foxy walks each move as it's added. Off, the route is planned blind
  /// and only walked when it's checked.
  final bool showPath;

  /// The fewest moves that solve it (computed at parse).
  final int shortest;

  bool open(Cell c) =>
      c.$1 >= 0 &&
      c.$1 < rows &&
      c.$2 >= 0 &&
      c.$2 < cols &&
      !walls.contains(c);

  PathLandmark? landmarkAt(Cell c) {
    for (final l in landmarks) {
      if (l.cell == c) return l;
    }
    return null;
  }

  /// Follows [program] from the start. Stops at the first move into a wall
  /// or off the board, and says so.
  ({List<Cell> cells, bool bumped}) walk(List<String> program) {
    final cells = [start];
    for (final m in program) {
      final (dr, dc) = pathMoves[m]!;
      final next = (cells.last.$1 + dr, cells.last.$2 + dc);
      if (!open(next)) return (cells: cells, bumped: true);
      cells.add(next);
    }
    return (cells: cells, bumped: false);
  }

  /// What a route achieves, one entry per rule: `goal`, `moves`, and
  /// `visit:<id>` for each landmark that must be passed.
  Map<String, bool> judge(List<String> program) {
    final w = walk(program);
    final ids = {
      for (final c in w.cells)
        if (landmarkAt(c) case final l?) l.id,
    };
    return {
      'goal': !w.bumped && w.cells.last == goal,
      'moves': program.length <= maxMoves,
      for (final id in mustVisit) 'visit:$id': ids.contains(id),
    };
  }
}

class PathState {
  const PathState({
    required this.content,
    this.program = const [],
    this.revealed = false,
    this.solved = false,
  });

  /// The board the route is on, so the reducer can refuse a bump.
  final PathContent content;
  final List<String> program;

  /// The blind route has been checked: walk it on the board.
  final bool revealed;
  final bool solved;

  PathState copyWith({List<String>? program, bool? revealed, bool? solved}) =>
      PathState(
        content: content,
        program: program ?? this.program,
        revealed: revealed ?? this.revealed,
        solved: solved ?? this.solved,
      );
}

sealed class PathAction {
  const PathAction();
}

/// Add a move at the end of the route.
class AddPathMove extends PathAction {
  const AddPathMove(this.move);
  final String move;
}

/// Take one move out of the route; -1 is the last one.
class RemovePathMove extends PathAction {
  const RemovePathMove(this.index);
  final int index;
}

/// "Le chemin de Foxy" — the `path_planner` engine (app ADR 0050; Hafid's
/// catalogue B15, merged with code_robot B25 and map_navigator B13).
///
/// A small grid with a start, a goal, walls and named landmarks. The child
/// builds Foxy's route from four direction buttons — arrows, or N E S O
/// for the cardinal points — and Foxy walks it as it grows (or, with
/// `show_path: false`, only when it's checked: a planning task).
///
/// Any route that reaches the goal without bumping a wall, passes every
/// `must_visit` landmark and stays within `max_moves` is right, so there's
/// no single answer to author. Parse checks one exists.
class PathPlannerEngine
    implements
        LearningEngine<PathContent, PathState, PathAction, OrderingAnswer> {
  const PathPlannerEngine();

  static const key = 'path_planner';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Arrow keys add moves, Backspace removes the last. Every cell and the
    // route are spoken.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static Cell? _cell(Object? raw) {
    if (raw is! Map) return null;
    final r = raw['row'];
    final c = raw['col'];
    return r is int && c is int ? (r, c) : null;
  }

  @override
  ParseResult<PathContent> parse(Map<String, Object?> config) {
    final rows = config['rows'];
    final cols = config['cols'];
    if (rows is! int ||
        cols is! int ||
        rows < 2 ||
        rows > 7 ||
        cols < 2 ||
        cols > 7) {
      return const ParseResult.invalid('rows and cols are 2 to 7.');
    }
    final start = _cell(config['start']);
    final goal = _cell(config['goal']);
    final rawWalls = config['walls'] ?? const [];
    if (start == null || goal == null || rawWalls is! List) {
      return const ParseResult.invalid('start and goal are {row, col}.');
    }
    final walls = <Cell>{};
    for (final w in rawWalls) {
      final c = _cell(w);
      if (c == null) return const ParseResult.invalid('A wall is {row, col}.');
      walls.add(c);
    }
    bool inside(Cell c) => c.$1 >= 0 && c.$1 < rows && c.$2 >= 0 && c.$2 < cols;
    if (!inside(start) || !inside(goal) || !walls.every(inside)) {
      return const ParseResult.invalid('Every cell is inside the grid.');
    }
    if (start == goal || walls.contains(start) || walls.contains(goal)) {
      return const ParseResult.invalid(
        'start and goal are different open cells.',
      );
    }

    final rawLandmarks = config['landmarks'] ?? const [];
    if (rawLandmarks is! List || rawLandmarks.length > 6) {
      return const ParseResult.invalid('There are at most 6 landmarks.');
    }
    final landmarks = <PathLandmark>[];
    for (final raw in rawLandmarks) {
      final id = raw is Map ? raw['id'] : null;
      final label = raw is Map ? raw['label'] : null;
      final cell = _cell(raw);
      if (id is! String ||
          label is! String ||
          label.trim().isEmpty ||
          label.length > 14 ||
          cell == null) {
        return const ParseResult.invalid(
          'A landmark is {id, row, col, label} with a label of 1 to 14 '
          'characters.',
        );
      }
      if (!inside(cell) || walls.contains(cell) || cell == start) {
        return const ParseResult.invalid(
          'A landmark sits on an open cell other than the start.',
        );
      }
      if (landmarks.any((l) => l.id == id || l.cell == cell)) {
        return const ParseResult.invalid('Landmark ids and cells are unique.');
      }
      landmarks.add(PathLandmark(id: id, cell: cell, label: label));
    }

    final rawVisit = config['must_visit'] ?? const [];
    if (rawVisit is! List ||
        rawVisit.length > 3 ||
        !rawVisit.every((v) => landmarks.any((l) => l.id == v))) {
      return const ParseResult.invalid(
        'must_visit lists up to 3 landmark ids.',
      );
    }
    final mustVisit = rawVisit.cast<String>().toSet().toList();

    final maxMoves = config['max_moves'] ?? 12;
    if (maxMoves is! int || maxMoves < 2 || maxMoves > 12) {
      return const ParseResult.invalid('max_moves is 2 to 12.');
    }
    final directions = config['directions'] ?? 'arrows';
    if (directions != 'arrows' && directions != 'cardinal') {
      return const ParseResult.invalid('directions is arrows or cardinal.');
    }

    var content = PathContent(
      rows: rows,
      cols: cols,
      start: start,
      goal: goal,
      walls: Set.unmodifiable(walls),
      landmarks: List.unmodifiable(landmarks),
      mustVisit: List.unmodifiable(mustVisit),
      cardinal: directions == 'cardinal',
      maxMoves: maxMoves,
      showPath: config['show_path'] is bool
          ? config['show_path']! as bool
          : true,
    );
    final shortest = _shortest(content);
    if (shortest == null || shortest > maxMoves) {
      return ParseResult.invalid(
        shortest == null
            ? 'No route reaches the goal through every must_visit landmark.'
            : 'The shortest route takes $shortest moves, more than max_moves.',
      );
    }
    content = PathContent(
      rows: content.rows,
      cols: content.cols,
      start: content.start,
      goal: content.goal,
      walls: content.walls,
      landmarks: content.landmarks,
      mustVisit: content.mustVisit,
      cardinal: content.cardinal,
      maxMoves: content.maxMoves,
      showPath: content.showPath,
      shortest: shortest,
    );
    return ParseResult.ok(content);
  }

  /// Fewest moves from the start, through every must_visit landmark in the
  /// best order, to the goal; null if there is no such route.
  static int? _shortest(PathContent c) {
    int? dist(Cell from, Cell to) {
      final seen = {from};
      var frontier = [from];
      for (var d = 0; frontier.isNotEmpty; d++) {
        if (frontier.contains(to)) return d;
        final next = <Cell>[];
        for (final cell in frontier) {
          for (final (dr, dc) in pathMoves.values) {
            final n = (cell.$1 + dr, cell.$2 + dc);
            if (c.open(n) && seen.add(n)) next.add(n);
          }
        }
        frontier = next;
      }
      return null;
    }

    final stops = [
      for (final id in c.mustVisit)
        c.landmarks.firstWhere((l) => l.id == id).cell,
    ];
    int? best;
    void permute(List<Cell> rest, Cell at, int sofar) {
      if (rest.isEmpty) {
        final last = dist(at, c.goal);
        if (last != null && (best == null || sofar + last < best!)) {
          best = sofar + last;
        }
        return;
      }
      for (final s in rest) {
        final d = dist(at, s);
        if (d != null) permute([...rest]..remove(s), s, sofar + d);
      }
    }

    permute(stops, c.start, 0);
    return best;
  }

  @override
  PathState initialize(PathContent content, EngineSeed seed) =>
      PathState(content: content);

  @override
  Transition<PathState> reduce(PathState s, PathAction action) {
    if (s.solved) return Transition(s);
    switch (action) {
      case AddPathMove(:final move):
        if (!pathMoves.containsKey(move) || !canAdd(s.content, s, move)) {
          return Transition(s);
        }
        return Transition(
          s.copyWith(program: [...s.program, move], revealed: false),
          [
            InteractionEvent('move_added', {'move': move}),
          ],
        );
      case RemovePathMove(index: final raw):
        final index = raw == -1 ? s.program.length - 1 : raw;
        if (index < 0 || index >= s.program.length) return Transition(s);
        return Transition(
          s.copyWith(program: [...s.program]..removeAt(index), revealed: false),
          [
            InteractionEvent('move_removed', {'index': index}),
          ],
        );
    }
  }

  /// A live route refuses a move into a wall or past the limit: the board
  /// shows where Foxy is, so a bump is a slip, not a plan.
  static bool canAdd(PathContent c, PathState s, String move) {
    if (s.solved || s.program.length >= (c.showPath ? c.maxMoves : 12)) {
      return false;
    }
    if (!c.showPath) return true;
    return !c.walk([...s.program, move]).bumped;
  }

  @override
  OrderingAnswer? extractAnswer(PathState s) =>
      s.program.isEmpty || s.solved ? null : OrderingAnswer(s.program);

  @override
  PathState applyFeedback(PathState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    // The route stays, so the child can fix it rather than start over.
    return s.copyWith(
      revealed: true,
      solved: result.outcome == Outcome.correct,
    );
  }

  @override
  Map<String, Object?> snapshot(PathState s) => {
    'program': s.program,
    'revealed': s.revealed,
    'solved': s.solved,
  };

  @override
  PathState? restore(PathContent content, Map<String, Object?> snap) {
    try {
      final program = (snap['program'] as List).cast<String>();
      if (program.length > 12 || !program.every(pathMoves.containsKey)) {
        return null;
      }
      final solved = snap['solved'] == true;
      if (solved && content.judge(program).containsValue(false)) return null;
      return PathState(
        content: content,
        program: List.unmodifiable(program),
        revealed: snap['revealed'] == true,
        solved: solved,
      );
    } on Object {
      return null;
    }
  }

  static String moveLabel(String move, bool cardinal, bool fr) => cardinal
      ? switch (move) {
          'up' => 'N',
          'down' => 'S',
          'right' => 'E',
          _ => fr ? 'O' : 'W',
        }
      : switch (move) {
          'up' => '↑',
          'down' => '↓',
          'right' => '→',
          _ => '←',
        };

  static String moveSpoken(String move, bool cardinal, bool fr) => cardinal
      ? switch (move) {
          'up' => fr ? 'nord' : 'north',
          'down' => fr ? 'sud' : 'south',
          'right' => fr ? 'est' : 'east',
          _ => fr ? 'ouest' : 'west',
        }
      : switch (move) {
          'up' => fr ? 'en haut' : 'up',
          'down' => fr ? 'en bas' : 'down',
          'right' => fr ? 'à droite' : 'right',
          _ => fr ? 'à gauche' : 'left',
        };

  @override
  Widget buildView(
    BuildContext context,
    EngineView<PathContent, PathState, PathAction> view,
  ) => _PathView(view: view);
}

class _PathView extends StatelessWidget {
  const _PathView({required this.view});

  final EngineView<PathContent, PathState, PathAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final p = VillagePalette.of(context);
    final showWalk = c.showPath || s.revealed;
    final walk = c.walk(s.program);
    final trail = showWalk ? walk.cells : [c.start];
    final at = trail.last;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // The reducer re-checks both, so keys pressed faster than a rebuild
    // still can't bump a wall or remove the wrong step.
    void add(String m) {
      if (view.enabled) view.dispatch(AddPathMove(m));
    }

    void removeLast() {
      if (view.enabled) view.dispatch(const RemovePathMove(-1));
    }

    String cellName(Cell cell) {
      final name = cell == c.start
          ? (fr ? 'départ' : 'start')
          : cell == c.goal
          ? (fr ? 'arrivée' : 'goal')
          : c.walls.contains(cell)
          ? (fr ? 'mur' : 'wall')
          : c.landmarkAt(cell)?.label;
      return name ?? '';
    }

    final route = s.program
        .map((m) => PathPlannerEngine.moveSpoken(m, c.cardinal, fr))
        .join(', ');

    final board = LayoutBuilder(
      builder: (context, box) {
        final cell = math.min(64.0, (box.maxWidth - 8) / c.cols);
        final width = cell * c.cols;
        final height = cell * c.rows;
        Offset center(Cell x) =>
            Offset((x.$2 + 0.5) * cell, (x.$1 + 0.5) * cell);
        return Center(
          child: Semantics(
            key: const ValueKey('path-board'),
            label: fr
                ? 'Grille de ${c.rows} lignes et ${c.cols} colonnes. '
                      'Foxy est ${at == c.start ? 'au départ' : 'à la ligne ${at.$1 + 1}, colonne ${at.$2 + 1}'}.'
                : 'Grid of ${c.rows} rows and ${c.cols} columns. '
                      'Foxy is ${at == c.start ? 'at the start' : 'on row ${at.$1 + 1}, column ${at.$2 + 1}'}.',
            liveRegion: true,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  for (var r = 0; r < c.rows; r++)
                    for (var col = 0; col < c.cols; col++)
                      Positioned(
                        left: col * cell,
                        top: r * cell,
                        width: cell,
                        height: cell,
                        child: Semantics(
                          label: [
                            fr
                                ? 'ligne ${r + 1}, colonne ${col + 1}'
                                : 'row ${r + 1}, column ${col + 1}',
                            cellName((r, col)),
                          ].where((x) => x.isNotEmpty).join(', '),
                          child: _CellView(
                            c: c,
                            cell: (r, col),
                            size: cell,
                            visited: trail.contains((r, col)),
                          ),
                        ),
                      ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TrailPainter(
                          [for (final x in trail) center(x)],
                          s.revealed && !s.solved && !c.showPath
                              ? p.retry
                              : p.quebecBlueBright,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    left: at.$2 * cell + cell * 0.1,
                    top: at.$1 * cell + cell * 0.1,
                    width: cell * 0.8,
                    height: cell * 0.8,
                    child: ExcludeSemantics(
                      child: TutolysMascot(
                        key: const ValueKey('path-foxy'),
                        size: cell * 0.8,
                        mood: s.solved ? MascotMood.correct : MascotMood.idle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Widget pad(String m) => SizedBox(
      width: 64,
      child: Semantics(
        label: PathPlannerEngine.moveSpoken(m, c.cardinal, fr),
        button: true,
        excludeSemantics: true,
        child: AnswerTile(
          key: ValueKey('path-move-$m'),
          label: PathPlannerEngine.moveLabel(m, c.cardinal, fr),
          state: AnswerTileState.idle,
          dense: true,
          onTap: view.enabled && PathPlannerEngine.canAdd(c, s, m)
              ? () => add(m)
              : null,
        ),
      ),
    );

    final limit = c.showPath ? c.maxMoves : 12;
    final steps = Wrap(
      key: const ValueKey('path-program'),
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < s.program.length; i++)
          SizedBox(
            width: 44,
            child: Semantics(
              label:
                  '${fr ? 'pas' : 'step'} ${i + 1}, ${PathPlannerEngine.moveSpoken(s.program[i], c.cardinal, fr)}',
              hint: s.solved
                  ? null
                  : (fr ? 'touche pour retirer' : 'tap to remove'),
              button: true,
              excludeSemantics: true,
              child: AnswerTile(
                key: ValueKey('path-step-$i'),
                label: PathPlannerEngine.moveLabel(
                  s.program[i],
                  c.cardinal,
                  fr,
                ),
                state: s.solved
                    ? AnswerTileState.correct
                    : showWalk && walk.bumped && i >= walk.cells.length - 1
                    ? AnswerTileState.retry
                    : AnswerTileState.idle,
                dense: true,
                onTap: view.enabled && !s.solved
                    ? () => view.dispatch(RemovePathMove(i))
                    : null,
              ),
            ),
          ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => add('up'),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => add('down'),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => add('left'),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            add('right'),
        const SingleActivator(LogicalKeyboardKey.backspace): removeLast,
      },
      child: Focus(
        autofocus: true,
        // A tap anywhere on the board gives it the keyboard back (after
        // VALIDER took it), without competing with the buttons' taps.
        child: Builder(
          builder: (focusContext) => Listener(
            onPointerDown: (_) => Focus.of(focusContext).requestFocus(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.cardinal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          fr ? '↑ Nord' : '↑ North',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: p.inkMuted,
                          ),
                        ),
                      ),
                    board,
                    const SizedBox(height: 16),
                    Semantics(
                      label: s.program.isEmpty
                          ? (fr ? 'Le chemin est vide.' : 'The route is empty.')
                          : '${fr ? 'Chemin' : 'Route'} : $route.',
                      liveRegion: true,
                      child: Text(
                        '${s.program.length} / $limit ${fr ? 'pas' : 'steps'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: p.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: steps,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        pad('up'),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            pad('left'),
                            const SizedBox(width: 70),
                            pad('right'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        pad('down'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({
    required this.c,
    required this.cell,
    required this.size,
    required this.visited,
  });

  final PathContent c;
  final Cell cell;
  final double size;
  final bool visited;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final wall = c.walls.contains(cell);
    final landmark = c.landmarkAt(cell);
    final required = landmark != null && c.mustVisit.contains(landmark.id);
    final goal = cell == c.goal;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: wall
              ? p.ink.withValues(alpha: 0.75)
              : goal
              ? p.goldPale
              : landmark != null
              ? p.navHoverFill
              : p.surface,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(
            color: goal
                ? p.gold
                : required
                ? p.quebecBlueBright
                : p.line,
            width: goal || required ? 2.5 : 1.5,
          ),
        ),
        child: wall
            ? Icon(Icons.park_rounded, color: p.surface, size: size * 0.55)
            : goal
            ? Icon(Icons.flag_rounded, color: p.gold, size: size * 0.55)
            : landmark != null
            ? Padding(
                padding: const EdgeInsets.all(2),
                child: Stack(
                  children: [
                    Center(
                      child: FittedBox(
                        child: Text(
                          landmark.label,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ),
                    if (required && visited)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: size * 0.24,
                          color: p.success,
                        ),
                      ),
                  ],
                ),
              )
            : cell == c.start
            ? Icon(Icons.home_rounded, color: p.inkMuted, size: size * 0.4)
            : null,
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points, this.color);
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.color != color ||
      old.points.length != points.length ||
      !List.generate(
        points.length,
        (i) => points[i] == old.points[i],
      ).every((x) => x);
}

/// Grades a `path_planner` route against the rules, not a stored answer:
/// it must reach the goal without a bump, pass every must_visit landmark,
/// and fit in max_moves. Each rule is an item, so telemetry can say which
/// one failed.
class PathPlannerEvaluator implements Evaluator<PathContent, OrderingAnswer> {
  const PathPlannerEvaluator();

  @override
  String get engineKey => PathPlannerEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    PathContent content,
    OrderingAnswer answer,
    EvaluationContext ctx,
  ) {
    final program = answer.orderedItemIds;
    if (program.isEmpty || !program.every(pathMoves.containsKey)) {
      throw ArgumentError('A route is a list of moves.');
    }
    final items = content.judge(program);
    final right = !items.containsValue(false);
    return EvaluationResult(
      outcome: right ? Outcome.correct : Outcome.incorrect,
      score: right ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: right ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
