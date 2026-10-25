import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// A place on the picture that takes one label.
class LabelPoint {
  const LabelPoint({required this.id, required this.x, required this.y});
  final String id;

  /// Fractions of the picture's width and height, `0, 0` top left.
  final double x;
  final double y;
}

class LabelChip {
  const LabelChip({required this.id, required this.label, this.point});
  final String id;
  final String label;

  /// The point it belongs on; null for a distractor that belongs nowhere.
  final String? point;
}

class LabelContent {
  const LabelContent({
    required this.imageRef,
    required this.aspectRatio,
    required this.points,
    required this.labels,
    this.shuffle = true,
  });

  final String imageRef;

  /// Width over height, so the picture is laid out (and its points placed)
  /// before it has synced.
  final double aspectRatio;
  final List<LabelPoint> points;
  final List<LabelChip> labels;
  final bool shuffle;

  LabelChip label(String id) => labels.firstWhere((l) => l.id == id);
  LabelPoint point(String id) => points.firstWhere((p) => p.id == id);

  /// Point id → the label that belongs there.
  Map<String, String> get answer => {
    for (final l in labels)
      if (l.point != null) l.point!: l.id,
  };
}

class LabelState {
  const LabelState({
    required this.trayOrder,
    required this.pointCount,
    this.held,
    this.placed = const {},
    this.locked = const {},
    this.tried = const {},
  });

  /// Label ids in tray order.
  final List<String> trayOrder;

  /// How many points the picture has: VALIDER waits until each has a label.
  final int pointCount;

  /// The label in the child's hand, waiting for a point.
  final String? held;

  /// Point id → label id.
  final Map<String, String> placed;

  /// Points checked right — fixed for the rest of the question.
  final Set<String> locked;

  /// `label|point` pairs checked wrong, so the same mistake can't be made
  /// twice (the same rule as a tried answer turning amber).
  final Set<String> tried;

  bool get complete => placed.length == pointCount;

  Set<String> get placedLabels => placed.values.toSet();

  LabelState copyWith({
    String? held,
    bool clearHeld = false,
    Map<String, String>? placed,
    Set<String>? locked,
    Set<String>? tried,
  }) => LabelState(
    trayOrder: trayOrder,
    pointCount: pointCount,
    held: clearHeld ? null : (held ?? this.held),
    placed: placed ?? this.placed,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
  );
}

sealed class LabelAction {
  const LabelAction();
}

/// Tap a label in the tray: pick it up (or put it down again).
class TapLabel extends LabelAction {
  const TapLabel(this.labelId);
  final String labelId;
}

/// Tap a point on the picture: drop the held label there, or take back the
/// label already on it.
class TapPoint extends LabelAction {
  const TapPoint(this.pointId);
  final String pointId;
}

/// Put the right name on each part of a picture — the `label_image` engine
/// (app ADR 0046; Hafid's catalogue #3, merging drag_drop, label_image,
/// map labels and missing_piece's picture form).
///
/// "Place les mots sur le plan de la classe", "Nomme les émotions de
/// Foxy", "Où sont le Nord et le Sud ?". Tap a label, then tap a numbered
/// point on the picture; tap a placed label to take it back. VALIDER checks
/// every point with partial credit: right ones lock green, wrong ones go
/// back to the tray, and that label can't go on that point again.
///
/// The picture carries no text: the app draws the labels, so one picture
/// serves both languages. Up to two distractor labels belong nowhere.
class LabelImageEngine
    implements
        LearningEngine<
          LabelContent,
          LabelState,
          LabelAction,
          PlacementsAnswer
        > {
  const LabelImageEngine();

  static const key = 'label_image';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<LabelContent> parse(Map<String, Object?> config) {
    final image = config['image_ref'];
    if (image is! String || image.isEmpty) {
      return const ParseResult.invalid('label_image needs an image_ref.');
    }
    final ratio = config['aspect_ratio'];
    if (ratio is! num || ratio < 0.25 || ratio > 4) {
      return const ParseResult.invalid(
        'aspect_ratio is the picture width over height, 0.25 to 4.',
      );
    }
    final rawPoints = config['points'];
    if (rawPoints is! List || rawPoints.length < 2 || rawPoints.length > 12) {
      return const ParseResult.invalid('A picture has 2 to 12 points.');
    }
    final points = <LabelPoint>[];
    for (final p in rawPoints) {
      final id = p is Map ? p['id'] : null;
      final x = p is Map ? p['x'] : null;
      final y = p is Map ? p['y'] : null;
      if (id is! String ||
          id.isEmpty ||
          x is! num ||
          y is! num ||
          x < 0 ||
          x > 1 ||
          y < 0 ||
          y > 1) {
        return const ParseResult.invalid(
          'Every point needs an id and x, y between 0 and 1.',
        );
      }
      if (points.any((q) => q.id == id)) {
        return const ParseResult.invalid('Point ids must be unique.');
      }
      points.add(LabelPoint(id: id, x: x.toDouble(), y: y.toDouble()));
    }
    final pointIds = {for (final p in points) p.id};
    final rawLabels = config['labels'];
    if (rawLabels is! List) {
      return const ParseResult.invalid('labels must be a list.');
    }
    final labels = <LabelChip>[];
    final claimed = <String>{};
    for (final l in rawLabels) {
      final id = l is Map ? l['id'] : null;
      final label = l is Map ? l['label'] : null;
      final point = l is Map ? l['point'] : null;
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.trim().isEmpty) {
        return const ParseResult.invalid('Every label needs an id and text.');
      }
      if (labels.any((x) => x.id == id)) {
        return const ParseResult.invalid('Label ids must be unique.');
      }
      if (point != null && (point is! String || !pointIds.contains(point))) {
        return const ParseResult.invalid(
          'A label\'s point must be one of the points.',
        );
      }
      if (point is String && !claimed.add(point)) {
        return const ParseResult.invalid('Each point takes one label.');
      }
      labels.add(LabelChip(id: id, label: label, point: point as String?));
    }
    if (claimed.length != points.length) {
      return const ParseResult.invalid('Every point needs its label.');
    }
    if (labels.length - points.length > 2) {
      return const ParseResult.invalid('At most 2 distractor labels.');
    }
    final shuffle = config['shuffle'];
    return ParseResult.ok(
      LabelContent(
        imageRef: image,
        aspectRatio: ratio.toDouble(),
        points: List.unmodifiable(points),
        labels: List.unmodifiable(labels),
        shuffle: shuffle is bool ? shuffle : true,
      ),
    );
  }

  @override
  LabelState initialize(LabelContent content, EngineSeed seed) {
    final order = [for (final l in content.labels) l.id];
    if (content.shuffle) order.shuffle(seed.random());
    return LabelState(
      trayOrder: List.unmodifiable(order),
      pointCount: content.points.length,
    );
  }

  static String _pair(String label, String point) => '$label|$point';

  @override
  Transition<LabelState> reduce(LabelState s, LabelAction action) {
    switch (action) {
      case TapLabel(:final labelId):
        if (!s.trayOrder.contains(labelId) ||
            s.placedLabels.contains(labelId)) {
          return Transition(s);
        }
        if (s.held == labelId) return Transition(s.copyWith(clearHeld: true));
        return Transition(s.copyWith(held: labelId));

      case TapPoint(:final pointId):
        if (s.locked.contains(pointId)) return Transition(s);
        final there = s.placed[pointId];
        final held = s.held;
        if (held == null) {
          if (there == null) return Transition(s);
          // Take it back into the hand, ready for another point.
          return Transition(
            s.copyWith(held: there, placed: Map.of(s.placed)..remove(pointId)),
            [
              InteractionEvent('item_removed', {
                'item_id': there,
                'bucket_id': pointId,
              }),
            ],
          );
        }
        if (s.tried.contains(_pair(held, pointId))) return Transition(s);
        // A label already there swaps back into the tray.
        return Transition(
          s.copyWith(clearHeld: true, placed: {...s.placed, pointId: held}),
          [
            InteractionEvent('item_placed', {
              'item_id': held,
              'bucket_id': pointId,
            }),
          ],
        );
    }
  }

  @override
  PlacementsAnswer? extractAnswer(LabelState s) =>
      !s.complete || s.placed.length == s.locked.length
      ? null
      : PlacementsAnswer({for (final e in s.placed.entries) e.value: e.key});

  @override
  LabelState applyFeedback(LabelState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {...s.locked};
    final tried = {...s.tried};
    final placed = <String, String>{};
    for (final e in s.placed.entries) {
      final right = result.itemResults[e.value];
      if (right == true || s.locked.contains(e.key)) {
        locked.add(e.key);
        placed[e.key] = e.value;
      } else if (right == false) {
        tried.add(_pair(e.value, e.key));
      }
    }
    return s.copyWith(
      clearHeld: true,
      placed: placed,
      locked: locked,
      tried: tried,
    );
  }

  @override
  Map<String, Object?> snapshot(LabelState s) => {
    'tray_order': s.trayOrder,
    'held': s.held,
    'placed': s.placed,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
  };

  @override
  LabelState? restore(LabelContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['tray_order'] as List).cast<String>();
      final labelIds = {for (final l in content.labels) l.id};
      final pointIds = {for (final p in content.points) p.id};
      if (order.length != labelIds.length || !order.every(labelIds.contains)) {
        return null;
      }
      final held = snap['held'] as String?;
      final placed = Map<String, String>.from(
        (snap['placed'] as Map?) ?? const {},
      );
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final tried = ((snap['tried'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final answer = content.answer;
      if (!placed.keys.every(pointIds.contains) ||
          !placed.values.every(labelIds.contains) ||
          placed.values.toSet().length != placed.length ||
          !locked.every((p) => placed[p] == answer[p]) ||
          (held != null &&
              (!labelIds.contains(held) || placed.containsValue(held)))) {
        return null;
      }
      return LabelState(
        trayOrder: List.unmodifiable(order),
        pointCount: content.points.length,
        held: held,
        placed: placed,
        locked: locked,
        tried: tried,
      );
    } on Object {
      return null;
    }
  }

  /// "en haut à gauche", from where a point sits, so a screen reader can
  /// tell the points apart without being told the answer.
  static String where(LabelPoint p, bool fr) {
    final v = p.y < 0.34
        ? (fr ? 'en haut' : 'top')
        : p.y > 0.66
        ? (fr ? 'en bas' : 'bottom')
        : (fr ? 'au milieu' : 'middle');
    final h = p.x < 0.34
        ? (fr ? 'à gauche' : 'left')
        : p.x > 0.66
        ? (fr ? 'à droite' : 'right')
        : (fr ? 'au centre' : 'centre');
    return '$v $h';
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<LabelContent, LabelState, LabelAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final c = view.content;
    final p = VillagePalette.of(context);
    final holding = s.held != null && view.enabled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                key: const ValueKey('label-tray'),
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.trayOrder)
                    if (!s.placedLabels.contains(id))
                      AnswerTile(
                        key: ValueKey('label-chip-$id'),
                        label: c.label(id).label,
                        state: s.held == id
                            ? AnswerTileState.picked
                            : AnswerTileState.idle,
                        semanticsState: s.held == id
                            ? (fr
                                  ? 'choisi, touche un repère sur l’image'
                                  : 'chosen, now tap a point on the picture')
                            : null,
                        onTap: view.enabled
                            ? () => view.dispatch(TapLabel(id))
                            : null,
                      ),
                ],
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: c.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, box) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: Radii.cardMd,
                              border: Border.all(color: p.line, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: Radii.cardMd,
                              child: ContentImage(
                                ref: c.imageRef,
                                fit: BoxFit.fill,
                                fallback: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                        for (final (i, point) in c.points.indexed)
                          _PointMarker(
                            key: ValueKey('label-point-${point.id}'),
                            number: i + 1,
                            center: Offset(
                              point.x * box.maxWidth,
                              point.y * box.maxHeight,
                            ),
                            bounds: box.biggest,
                            label: s.placed[point.id] == null
                                ? null
                                : c.label(s.placed[point.id]!).label,
                            locked: s.locked.contains(point.id),
                            highlighted:
                                holding &&
                                !s.locked.contains(point.id) &&
                                !s.tried.contains(_pair(s.held!, point.id)),
                            semanticsLabel: fr
                                ? 'repère ${i + 1}, ${where(point, fr)}'
                                : 'point ${i + 1}, ${where(point, fr)}',
                            hint: s.locked.contains(point.id)
                                ? (fr ? 'bien placé' : 'placed right')
                                : s.placed[point.id] != null
                                ? (fr
                                      ? 'touche pour retirer'
                                      : 'tap to take it back')
                                : holding
                                ? (fr
                                      ? 'touche pour déposer ici'
                                      : 'tap to put it here')
                                : null,
                            onTap: view.enabled && !s.locked.contains(point.id)
                                ? () => view.dispatch(TapPoint(point.id))
                                : null,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A numbered point on the picture, or — once a label is on it — the label
/// itself, centred on the point and kept inside the picture.
class _PointMarker extends StatelessWidget {
  const _PointMarker({
    required this.number,
    required this.center,
    required this.bounds,
    required this.label,
    required this.locked,
    required this.highlighted,
    required this.semanticsLabel,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final int number;
  final Offset center;
  final Size bounds;
  final String? label;
  final bool locked;
  final bool highlighted;
  final String semanticsLabel;
  final String? hint;
  final VoidCallback? onTap;

  static const _dot = 40.0;
  static const _chipHeight = 40.0;
  static const _chipMax = 150.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final text = label;
    final (border, fill) = locked
        ? (p.success, p.successPale)
        : highlighted
        ? (p.quebecBlueBright, p.navHoverFill)
        : (p.quebecBlue, p.surface);

    final width = text == null
        ? _dot
        : math.min(_chipMax, math.max(_dot, bounds.width * 0.4));
    final height = text == null ? _dot : _chipHeight;
    final left = (center.dx - width / 2).clamp(0.0, bounds.width - width);
    final top = (center.dy - height / 2).clamp(0.0, bounds.height - height);

    final face = text == null
        ? Text(
            '$number',
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: p.ink,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(Icons.check_rounded, size: 16, color: p.success),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
          );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: text == null ? semanticsLabel : '$semanticsLabel : $text',
        hint: hint,
        excludeSemantics: true,
        child: Material(
          color: fill,
          elevation: 2,
          shape: text == null
              ? CircleBorder(
                  side: BorderSide(color: border, width: highlighted ? 4 : 3),
                )
              : RoundedRectangleBorder(
                  borderRadius: Radii.cardSm,
                  side: BorderSide(color: border, width: 3),
                ),
          child: InkWell(
            onTap: onTap,
            customBorder: text == null ? const CircleBorder() : null,
            borderRadius: text == null ? null : Radii.cardSm,
            child: Center(child: face),
          ),
        ),
      ),
    );
  }
}

/// Grades a `label_image` board. [EvaluationResult.itemResults] has one
/// entry per placed label: true when it sits on its own point. A distractor
/// placed anywhere is wrong. Score is right labels over points.
class LabelImageEvaluator implements Evaluator<LabelContent, PlacementsAnswer> {
  const LabelImageEvaluator();

  @override
  String get engineKey => LabelImageEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    LabelContent content,
    PlacementsAnswer answer,
    EvaluationContext ctx,
  ) {
    final placements = answer.placements;
    if (placements.isEmpty) {
      throw ArgumentError('An answer must place something.');
    }
    final items = {
      for (final e in placements.entries)
        e.key: content.label(e.key).point == e.value,
    };
    final hits = items.values.where((v) => v).length;
    final all = hits == content.points.length && hits == items.length;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / content.points.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
