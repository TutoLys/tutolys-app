import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

typedef Peg = (int row, int col);

enum GeoTask { build, copy }

/// What a `build` asks for.
enum GeoTarget { triangle, square, rectangle, rhombus, polygon }

/// Plane geometry on peg coordinates (integers, so every test is exact).
abstract final class GeoShape {
  static int _cross(Peg o, Peg a, Peg b) =>
      (a.$2 - o.$2) * (b.$1 - o.$1) - (a.$1 - o.$1) * (b.$2 - o.$2);

  static int _len2(Peg a, Peg b) =>
      (a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2);

  /// The corners of a closed band: drops a peg the band runs straight
  /// through, since a child sees no corner there.
  static List<Peg> corners(List<Peg> ring) {
    var pts = [...ring];
    var changed = true;
    while (changed && pts.length >= 3) {
      changed = false;
      for (var i = 0; i < pts.length; i++) {
        final prev = pts[(i - 1 + pts.length) % pts.length];
        final next = pts[(i + 1) % pts.length];
        if (_cross(prev, pts[i], next) == 0) {
          pts.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return pts;
  }

  static bool _segmentsCross(Peg a, Peg b, Peg c, Peg d) {
    int sign(int v) => v.sign;
    bool onSegment(Peg p, Peg q, Peg r) =>
        math.min(p.$1, r.$1) <= q.$1 &&
        q.$1 <= math.max(p.$1, r.$1) &&
        math.min(p.$2, r.$2) <= q.$2 &&
        q.$2 <= math.max(p.$2, r.$2);
    final d1 = sign(_cross(c, d, a));
    final d2 = sign(_cross(c, d, b));
    final d3 = sign(_cross(a, b, c));
    final d4 = sign(_cross(a, b, d));
    if (d1 != d2 && d3 != d4 && d1 != 0 && d2 != 0 && d3 != 0 && d4 != 0) {
      return true;
    }
    return (d1 == 0 && onSegment(c, a, d)) ||
        (d2 == 0 && onSegment(c, b, d)) ||
        (d3 == 0 && onSegment(a, c, b)) ||
        (d4 == 0 && onSegment(a, d, b));
  }

  /// No two non-adjacent sides touch, and the ring has an area.
  static bool simple(List<Peg> ring) {
    final n = ring.length;
    if (n < 3 || ring.toSet().length != n) return false;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if ((j - i).abs() == 1 || (i == 0 && j == n - 1)) continue;
        if (_segmentsCross(
          ring[i],
          ring[(i + 1) % n],
          ring[j],
          ring[(j + 1) % n],
        )) {
          return false;
        }
      }
    }
    return corners(ring).length >= 3;
  }

  static bool _rightAngles(List<Peg> c) {
    for (var i = 0; i < 4; i++) {
      final a = c[(i - 1 + 4) % 4];
      final o = c[i];
      final b = c[(i + 1) % 4];
      final dot = (a.$1 - o.$1) * (b.$1 - o.$1) + (a.$2 - o.$2) * (b.$2 - o.$2);
      if (dot != 0) return false;
    }
    return true;
  }

  static bool _equalSides(List<Peg> c) {
    final l = _len2(c[0], c[1]);
    for (var i = 1; i < c.length; i++) {
      if (_len2(c[i], c[(i + 1) % c.length]) != l) return false;
    }
    return true;
  }

  /// Whether a simple ring's corners make [target]. A square is a
  /// rectangle and a rhombus too, as in mathematics.
  static bool matches(List<Peg> corners, GeoTarget target, int sides) =>
      switch (target) {
        GeoTarget.triangle => corners.length == 3,
        GeoTarget.square =>
          corners.length == 4 && _rightAngles(corners) && _equalSides(corners),
        GeoTarget.rectangle => corners.length == 4 && _rightAngles(corners),
        GeoTarget.rhombus => corners.length == 4 && _equalSides(corners),
        GeoTarget.polygon => corners.length == sides,
      };

  /// The same figure, moved: equal corner sets after shifting each to its
  /// top-left, compared as a cycle in either direction.
  static bool sameFigure(List<Peg> a, List<Peg> b) {
    if (a.length != b.length) return false;
    List<Peg> norm(List<Peg> p) {
      final r = p.map((x) => x.$1).reduce(math.min);
      final c = p.map((x) => x.$2).reduce(math.min);
      return [for (final x in p) (x.$1 - r, x.$2 - c)];
    }

    final na = norm(a);
    final nb = norm(b);
    final n = na.length;
    for (final seq in [nb, nb.reversed.toList()]) {
      for (var shift = 0; shift < n; shift++) {
        var same = true;
        for (var i = 0; i < n && same; i++) {
          same = na[i] == seq[(i + shift) % n];
        }
        if (same) return true;
      }
    }
    return false;
  }
}

class GeoContent {
  const GeoContent({
    required this.pegs,
    required this.task,
    this.target = GeoTarget.triangle,
    this.sides = 0,
    this.model = const [],
  });

  /// The board is pegs × pegs.
  final int pegs;
  final GeoTask task;
  final GeoTarget target;

  /// build polygon: how many sides.
  final int sides;

  /// copy: the figure to reproduce, as its corners in order.
  final List<Peg> model;
}

class GeoState {
  const GeoState({
    required this.pegs,
    this.band = const [],
    this.closed = false,
    this.solved = false,
  });

  /// The board size, so the reducer can refuse a peg that isn't on it.
  final int pegs;

  /// The pegs the band goes round, in order.
  final List<Peg> band;

  /// The band is back at its first peg.
  final bool closed;
  final bool solved;

  GeoState copyWith({List<Peg>? band, bool? closed, bool? solved}) => GeoState(
    pegs: pegs,
    band: band ?? this.band,
    closed: closed ?? this.closed,
    solved: solved ?? this.solved,
  );
}

sealed class GeoAction {
  const GeoAction();
}

/// Tap a peg: stretch the band to it, close it on the first peg, or take
/// back the last one.
class TapPeg extends GeoAction {
  const TapPeg(this.peg);
  final Peg peg;
}

/// Take the band off the board.
class ClearBand extends GeoAction {
  const ClearBand();
}

/// "Atelier des formes" — the `geometry_lab` engine, geoboard form (app
/// ADR pending a number; Hafid's catalogue B9).
///
/// A board of pegs; the child stretches an elastic band peg to peg and
/// closes it on the first one.
/// - `build`: make a triangle, a square, a rectangle, a rhombus, or a
///   figure with N sides. Any one on the board is right: graded on the
///   geometry (exact, on integer pegs), never on a stored answer. A square
///   counts as a rectangle and a rhombus, as in mathematics.
/// - `copy`: reproduce a model figure anywhere on the board (the same
///   figure, moved).
///
/// A band crossing itself is never a figure. A peg the band runs straight
/// through isn't a corner.
class GeometryLabEngine
    implements LearningEngine<GeoContent, GeoState, GeoAction, OrderingAnswer> {
  const GeometryLabEngine();

  static const key = 'geometry_lab';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Every peg is a focusable, spoken button; the board says which pegs
    // the band goes round.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String pegId(Peg p) => '${p.$1},${p.$2}';

  static Peg? parsePeg(String id) {
    final parts = id.split(',');
    if (parts.length != 2) return null;
    final r = int.tryParse(parts[0]);
    final c = int.tryParse(parts[1]);
    return r == null || c == null ? null : (r, c);
  }

  @override
  ParseResult<GeoContent> parse(Map<String, Object?> config) {
    final pegs = config['pegs'] ?? 5;
    if (pegs is! int || pegs < 3 || pegs > 7) {
      return const ParseResult.invalid('pegs is 3 to 7.');
    }
    final task = GeoTask.values.asNameMap()[config['task'] ?? 'build'];
    if (task == null) {
      return const ParseResult.invalid('task is build or copy.');
    }

    if (task == GeoTask.copy) {
      final raw = config['model'];
      if (raw is! List || raw.length < 3 || raw.length > 8) {
        return const ParseResult.invalid('model is 3 to 8 corners.');
      }
      final model = <Peg>[];
      for (final m in raw) {
        final r = m is Map ? m['row'] : null;
        final c = m is Map ? m['col'] : null;
        if (r is! int ||
            c is! int ||
            r < 0 ||
            c < 0 ||
            r >= pegs ||
            c >= pegs) {
          return const ParseResult.invalid(
            'A model corner is {row, col} on the board.',
          );
        }
        model.add((r, c));
      }
      if (!GeoShape.simple(model) ||
          GeoShape.corners(model).length != model.length) {
        return const ParseResult.invalid(
          'model is a figure that does not cross itself, listed corner by '
          'corner.',
        );
      }
      if (config.containsKey('target')) {
        return const ParseResult.invalid('target is for build.');
      }
      return ParseResult.ok(
        GeoContent(pegs: pegs, task: task, model: List.unmodifiable(model)),
      );
    }

    final target = GeoTarget.values.asNameMap()[config['target']];
    if (target == null) {
      return const ParseResult.invalid(
        'target is triangle, square, rectangle, rhombus or polygon.',
      );
    }
    final sides = config['sides'];
    if (target == GeoTarget.polygon) {
      if (sides is! int || sides < 3 || sides > 8) {
        return const ParseResult.invalid('A polygon needs sides, 3 to 8.');
      }
    } else if (sides != null) {
      return const ParseResult.invalid('sides is for target polygon.');
    }
    if (config.containsKey('model')) {
      return const ParseResult.invalid('model is for copy.');
    }
    return ParseResult.ok(
      GeoContent(
        pegs: pegs,
        task: task,
        target: target,
        sides: sides is int ? sides : 0,
      ),
    );
  }

  @override
  GeoState initialize(GeoContent content, EngineSeed seed) =>
      GeoState(pegs: content.pegs);

  @override
  Transition<GeoState> reduce(GeoState s, GeoAction action) {
    if (s.solved) return Transition(s);
    switch (action) {
      case ClearBand():
        if (s.band.isEmpty) return Transition(s);
        return Transition(GeoState(pegs: s.pegs), [
          const InteractionEvent('item_removed', {'item_id': 'band'}),
        ]);
      case TapPeg(:final peg):
        if (peg.$1 < 0 || peg.$2 < 0 || peg.$1 >= s.pegs || peg.$2 >= s.pegs) {
          return Transition(s);
        }
        if (s.closed) {
          // A closed band opens again from its last peg.
          if (peg == s.band.last) {
            return Transition(s.copyWith(closed: false), [
              InteractionEvent('item_removed', {'item_id': pegId(peg)}),
            ]);
          }
          return Transition(s);
        }
        if (s.band.isNotEmpty && peg == s.band.last) {
          return Transition(s.copyWith(band: [...s.band]..removeLast()), [
            InteractionEvent('item_removed', {'item_id': pegId(peg)}),
          ]);
        }
        if (s.band.length >= 3 && peg == s.band.first) {
          return Transition(s.copyWith(closed: true), [
            InteractionEvent('item_placed', {'item_id': 'closed'}),
          ]);
        }
        if (s.band.contains(peg) || s.band.length >= 12) return Transition(s);
        return Transition(s.copyWith(band: [...s.band, peg]), [
          InteractionEvent('item_placed', {'item_id': pegId(peg)}),
        ]);
    }
  }

  @override
  OrderingAnswer? extractAnswer(GeoState s) => !s.closed || s.solved
      ? null
      : OrderingAnswer([for (final p in s.band) pegId(p)]);

  @override
  GeoState applyFeedback(GeoState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    // A wrong figure stays, so the child moves a corner rather than
    // starting over.
    return s.copyWith(solved: result.outcome == Outcome.correct);
  }

  @override
  Map<String, Object?> snapshot(GeoState s) => {
    'band': [for (final p in s.band) pegId(p)],
    'closed': s.closed,
    'solved': s.solved,
  };

  @override
  GeoState? restore(GeoContent content, Map<String, Object?> snap) {
    try {
      final band = [
        for (final id in (snap['band'] as List).cast<String>()) parsePeg(id)!,
      ];
      final closed = snap['closed'] == true;
      final solved = snap['solved'] == true;
      if (band.any(
            (p) =>
                p.$1 < 0 ||
                p.$2 < 0 ||
                p.$1 >= content.pegs ||
                p.$2 >= content.pegs,
          ) ||
          band.toSet().length != band.length ||
          (closed && band.length < 3) ||
          (solved && !closed)) {
        return null;
      }
      return GeoState(
        pegs: content.pegs,
        band: List.unmodifiable(band),
        closed: closed,
        solved: solved,
      );
    } on Object {
      return null;
    }
  }

  static String targetName(GeoContent c, bool fr) => switch (c.target) {
    GeoTarget.triangle => fr ? 'un triangle' : 'a triangle',
    GeoTarget.square => fr ? 'un carré' : 'a square',
    GeoTarget.rectangle => fr ? 'un rectangle' : 'a rectangle',
    GeoTarget.rhombus => fr ? 'un losange' : 'a rhombus',
    GeoTarget.polygon =>
      fr ? 'une figure à ${c.sides} côtés' : 'a figure with ${c.sides} sides',
  };

  @override
  Widget buildView(
    BuildContext context,
    EngineView<GeoContent, GeoState, GeoAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final p = VillagePalette.of(context);
    final copy = c.task == GeoTask.copy;

    final work = _Board(
      key: const ValueKey('geo-board'),
      pegs: c.pegs,
      band: s.band,
      closed: s.closed,
      color: s.solved ? p.success : p.quebecBlueBright,
      onPeg: view.enabled && !s.solved
          ? (peg) => view.dispatch(TapPeg(peg))
          : null,
      label: s.band.isEmpty
          ? (fr ? 'Planche à clous vide.' : 'Empty pegboard.')
          : fr
          ? 'L’élastique passe par ${s.band.length} clous'
                '${s.closed ? ', il est fermé' : ''}.'
          : 'The band goes round ${s.band.length} pegs'
                '${s.closed ? ' and is closed' : ''}.',
      fr: fr,
    );
    final model = copy
        ? _Board(
            key: const ValueKey('geo-model'),
            pegs: c.pegs,
            band: c.model,
            closed: true,
            // Not gold: it disappears on the wood.
            color: const Color(0xFF8E4EC6),
            label: fr
                ? 'Le modèle : une figure à ${c.model.length} côtés.'
                : 'The model: a figure with ${c.model.length} sides.',
            fr: fr,
          )
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final side = box.maxWidth >= 600;
                  if (model == null) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: work,
                      ),
                    );
                  }
                  Widget captioned(String caption, Widget board) => Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              caption,
                              style: TextStyle(
                                fontFamily: VillageType.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: p.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          board,
                        ],
                      ),
                    ),
                  );
                  final boards = [
                    captioned(fr ? 'Modèle' : 'Model', model),
                    const SizedBox(width: 16, height: 16),
                    captioned(fr ? 'Ta planche' : 'Your board', work),
                  ];
                  return side
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: boards,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: boards,
                        );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('geo-clear'),
                  onPressed: view.enabled && !s.solved && s.band.isNotEmpty
                      ? () => view.dispatch(const ClearBand())
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(fr ? 'Recommencer' : 'Start over'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.pegs,
    required this.band,
    required this.closed,
    required this.color,
    required this.label,
    required this.fr,
    this.onPeg,
    super.key,
  });

  final int pegs;
  final List<Peg> band;
  final bool closed;
  final Color color;
  final String label;
  final bool fr;
  final void Function(Peg)? onPeg;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Semantics(
        label: label,
        liveRegion: onPeg != null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE9C891),
            borderRadius: Radii.cardMd,
            border: Border.all(color: p.ink.withValues(alpha: 0.5), width: 2),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final step = box.maxWidth / pegs;
              Offset at(Peg x) =>
                  Offset((x.$2 + 0.5) * step, (x.$1 + 0.5) * step);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BandPainter(
                        [for (final x in band) at(x)],
                        closed: closed,
                        color: color,
                      ),
                    ),
                  ),
                  for (var r = 0; r < pegs; r++)
                    for (var col = 0; col < pegs; col++)
                      Positioned(
                        left: at((r, col)).dx - step / 2,
                        top: at((r, col)).dy - step / 2,
                        width: step,
                        height: step,
                        child: _PegView(
                          peg: (r, col),
                          index: band.indexOf((r, col)),
                          first: band.isNotEmpty && band.first == (r, col),
                          closable: !closed && band.length >= 3,
                          ink: p.ink,
                          color: color,
                          fr: fr,
                          onTap: onPeg == null ? null : () => onPeg!((r, col)),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PegView extends StatelessWidget {
  const _PegView({
    required this.peg,
    required this.index,
    required this.first,
    required this.closable,
    required this.ink,
    required this.color,
    required this.fr,
    required this.onTap,
  });

  final Peg peg;

  /// Where this peg is in the band, or -1.
  final int index;
  final bool first;

  /// Tapping the first peg now closes the band.
  final bool closable;
  final Color ink;
  final Color color;
  final bool fr;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final used = index >= 0;
    final dot = Container(
      width: used ? 16 : 10,
      height: used ? 16 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: used ? color : ink.withValues(alpha: 0.7),
        border: first && closable
            ? Border.all(color: Colors.white, width: 3)
            : null,
        boxShadow: first && closable
            ? [BoxShadow(color: color, spreadRadius: 4)]
            : null,
      ),
    );
    final where = fr
        ? 'clou ligne ${peg.$1 + 1}, colonne ${peg.$2 + 1}'
        : 'peg row ${peg.$1 + 1}, column ${peg.$2 + 1}';
    if (onTap == null) return ExcludeSemantics(child: Center(child: dot));
    return Semantics(
      button: true,
      label: where,
      hint: first && closable
          ? (fr ? 'touche pour fermer l’élastique' : 'tap to close the band')
          : used
          ? (fr ? 'dans l’élastique' : 'in the band')
          : null,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('geo-peg-${peg.$1}-${peg.$2}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: dot),
        ),
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter(this.points, {required this.closed, required this.color});
  final List<Offset> points;
  final bool closed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    if (closed) {
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.closed != closed ||
      old.color != color ||
      old.points.length != points.length ||
      !List.generate(
        points.length,
        (i) => old.points[i] == points[i],
      ).every((x) => x);
}

/// Grades a closed band on its geometry. Items: `simple` (it doesn't cross
/// itself) and `shape` (it is the asked-for figure, or the model moved).
class GeometryLabEvaluator implements Evaluator<GeoContent, OrderingAnswer> {
  const GeometryLabEvaluator();

  @override
  String get engineKey => GeometryLabEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    GeoContent content,
    OrderingAnswer answer,
    EvaluationContext ctx,
  ) {
    final ring = [
      for (final id in answer.orderedItemIds)
        GeometryLabEngine.parsePeg(id) ??
            (throw ArgumentError('Not a peg: $id')),
    ];
    final simple = GeoShape.simple(ring);
    final corners = simple ? GeoShape.corners(ring) : const <Peg>[];
    final shape =
        simple &&
        switch (content.task) {
          GeoTask.build => GeoShape.matches(
            corners,
            content.target,
            content.sides,
          ),
          GeoTask.copy => GeoShape.sameFigure(corners, content.model),
        };
    return EvaluationResult(
      outcome: shape ? Outcome.correct : Outcome.incorrect,
      score: shape ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: {'simple': simple, 'shape': shape},
      errors: shape ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
