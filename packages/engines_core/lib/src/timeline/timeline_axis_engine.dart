import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

class AxisTick {
  const AxisTick({required this.id, required this.label});
  final String id;

  /// Drawn under the tick. May be empty: a number line labelled only at
  /// 0, 5 and 10 still has a tick at 7.
  final String label;
}

class AxisItem {
  const AxisItem({required this.id, required this.label, this.imageRef});
  final String id;
  final String label;
  final String? imageRef;
}

class AxisContent {
  const AxisContent({
    required this.ticks,
    required this.items,
    required this.answer,
    this.given = const {},
    this.distractors = const [],
    this.startLabel,
    this.endLabel,
  });

  /// In axis order, first to last.
  final List<AxisTick> ticks;
  final List<AxisItem> items;

  /// Items that belong on no tick. Left in the tray when the line is right;
  /// one put on a tick marks itself wrong.
  final List<AxisItem> distractors;

  /// How many items the child must put on the line: every item not given.
  int get toPlace => items.length - given.length;

  /// item id → the tick it belongs on. One item per tick at most.
  final Map<String, String> answer;

  /// Item ids shown already on their tick, fixed and never graded.
  final Set<String> given;

  final String? startLabel;
  final String? endLabel;

  AxisItem item(String id) =>
      items.followedBy(distractors).firstWhere((i) => i.id == id);
  AxisTick tick(String id) => ticks.firstWhere((t) => t.id == id);
  int tickIndex(String id) => ticks.indexWhere((t) => t.id == id);
}

class AxisState {
  const AxisState({
    required this.tray,
    required this.toPlace,
    this.held,
    this.placements = const {},
    this.locked = const {},
  });

  /// The items the child places, in tray order, distractors included.
  /// Given items aren't here.
  final List<String> tray;

  /// How many must be on the line before VALIDER. With distractors in the
  /// tray it is fewer than [tray]'s length, and the child is told the count.
  final int toPlace;

  /// The item picked up and waiting for a tick. Always an unplaced one.
  final String? held;

  /// item id → tick id, given items included.
  final Map<String, String> placements;

  /// Item ids fixed on their tick: given ones, and ones checked right.
  final Set<String> locked;

  int get placed => tray.where(placements.containsKey).length;
  bool get complete => placed == toPlace;

  String? itemOn(String tickId) {
    for (final e in placements.entries) {
      if (e.value == tickId) return e.key;
    }
    return null;
  }

  AxisState copyWith({
    String? held,
    bool clearHeld = false,
    Map<String, String>? placements,
    Set<String>? locked,
  }) => AxisState(
    tray: tray,
    toPlace: toPlace,
    held: clearHeld ? null : (held ?? this.held),
    placements: placements ?? this.placements,
    locked: locked ?? this.locked,
  );
}

sealed class AxisAction {
  const AxisAction();
}

/// Tap an item: pick it up, put it down, or take it off its tick.
class TapAxisItem extends AxisAction {
  const TapAxisItem(this.itemId);
  final String itemId;
}

/// Tap a tick: put the held item on it.
class TapTick extends AxisAction {
  const TapTick(this.tickId);
  final String tickId;
}

/// `timeline_calendar`'s axis mode (ADR 0030): put each item on its tick.
///
/// A life on a timeline ("bébé", "je marche", "je vais à l'école"), a
/// number on a number line. The ticks are the content's, in order, and may
/// be unlabelled. Tap an item, then a tick; tap a placed item to take it
/// off. A tick holds one item: putting another on it sends the first back.
/// VALIDER checks each item with partial credit, as `sort_buckets` does:
/// right ones lock, wrong ones go back to the tray.
class TimelineAxisEngine
    implements
        LearningEngine<AxisContent, AxisState, AxisAction, PlacementsAnswer> {
  const TimelineAxisEngine();

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: 'timeline_calendar',
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  /// 0-20 in steps of 1, the longest line grade 1 needs.
  static const _maxTicks = 21;

  static String? _image(Object? raw) {
    final v = raw is Map ? raw['image_ref'] : null;
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _optionalLabel(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  @override
  ParseResult<AxisContent> parse(Map<String, Object?> config) {
    final range = config['range'];
    final rawTicks = config['ticks'];
    if ((range == null) == (rawTicks == null)) {
      return const ParseResult.invalid(
        'An axis has either ticks or a range, not both.',
      );
    }
    final ticks = <AxisTick>[];
    // value → tick id, for a range: items say where they go with `at`.
    final byValue = <int, String>{};
    if (range != null) {
      final r = range is Map ? range : const {};
      final min = r['min'], max = r['max'], step = r['step'] ?? 1;
      final every = r['label_every'] ?? step;
      if (min is! int ||
          max is! int ||
          step is! int ||
          every is! int ||
          step < 1 ||
          max <= min ||
          (max - min) % step != 0 ||
          every % step != 0) {
        return const ParseResult.invalid(
          'range needs integer min < max, a step dividing max - min, and '
          'label_every a multiple of step.',
        );
      }
      final count = (max - min) ~/ step + 1;
      if (count > _maxTicks) {
        return const ParseResult.invalid(
          'A range makes at most $_maxTicks ticks.',
        );
      }
      for (var v = min; v <= max; v += step) {
        final id = 'v$v';
        byValue[v] = id;
        ticks.add(AxisTick(id: id, label: (v - min) % every == 0 ? '$v' : ''));
      }
    }
    final tickList = rawTicks ?? const [];
    if (range == null &&
        (tickList is! List ||
            tickList.length < 2 ||
            tickList.length > _maxTicks)) {
      return const ParseResult.invalid(
        'An axis needs between 2 and $_maxTicks ticks.',
      );
    }
    for (final t in range == null ? tickList as List : const []) {
      final id = t is Map ? t['id'] : null;
      final label = t is Map ? t['label'] : null;
      if (id is! String || id.isEmpty || label is! String) {
        return const ParseResult.invalid('Every tick needs an id and a label.');
      }
      if (ticks.any((x) => x.id == id)) {
        return const ParseResult.invalid('Tick ids must be unique.');
      }
      ticks.add(AxisTick(id: id, label: label));
    }
    final tickIds = {for (final t in ticks) t.id};

    final rawItems = config['items'];
    if (rawItems is! List || rawItems.length < 2 || rawItems.length > 8) {
      return const ParseResult.invalid('An axis needs between 2 and 8 items.');
    }
    final items = <AxisItem>[];
    final answer = <String, String>{};
    final given = <String>{};
    for (final i in rawItems) {
      final id = i is Map ? i['id'] : null;
      final label = i is Map ? i['label'] : null;
      final at = i is Map ? i['at'] : null;
      final tick = range != null && at is int
          ? byValue[at] ?? 'v$at'
          : (i is Map ? i['tick'] : null);
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.isEmpty ||
          tick is! String) {
        return const ParseResult.invalid(
          'Every axis item needs an id, a label and a tick (or at, on a '
          'range).',
        );
      }
      if (!tickIds.contains(tick)) {
        return ParseResult.invalid('Item $id goes on $tick, not a tick.');
      }
      if (answer.containsKey(id)) {
        return const ParseResult.invalid('Item ids must be unique.');
      }
      if (answer.containsValue(tick)) {
        return const ParseResult.invalid(
          'Two items share a tick: a tick holds one item.',
        );
      }
      final g = i['given'];
      if (g != null && g is! bool) {
        return const ParseResult.invalid('given must be true or false.');
      }
      if (g == true) given.add(id);
      items.add(AxisItem(id: id, label: label, imageRef: _image(i)));
      answer[id] = tick;
    }
    if (items.length - given.length < 2) {
      return const ParseResult.invalid(
        'At least two items must be left for the child to place.',
      );
    }
    final distractors = <AxisItem>[];
    final rawDistractors = config['distractors'];
    if (rawDistractors != null) {
      if (rawDistractors is! List || rawDistractors.length > 3) {
        return const ParseResult.invalid('distractors allows at most 3 items.');
      }
      for (final d in rawDistractors) {
        final id = d is Map ? d['id'] : null;
        final label = d is Map ? d['label'] : null;
        if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
          return const ParseResult.invalid(
            'Every distractor needs an id and a label.',
          );
        }
        if (answer.containsKey(id) || distractors.any((x) => x.id == id)) {
          return const ParseResult.invalid('Item ids must be unique.');
        }
        distractors.add(AxisItem(id: id, label: label, imageRef: _image(d)));
      }
    }
    return ParseResult.ok(
      AxisContent(
        ticks: List.unmodifiable(ticks),
        items: List.unmodifiable(items),
        answer: answer,
        given: given,
        distractors: List.unmodifiable(distractors),
        startLabel: _optionalLabel(config['start_label']),
        endLabel: _optionalLabel(config['end_label']),
      ),
    );
  }

  @override
  AxisState initialize(AxisContent content, EngineSeed seed) {
    final tray = [
      for (final i in content.items)
        if (!content.given.contains(i.id)) i.id,
      for (final d in content.distractors) d.id,
    ]..shuffle(seed.random());
    return AxisState(
      tray: List.unmodifiable(tray),
      toPlace: content.toPlace,
      placements: {for (final g in content.given) g: content.answer[g]!},
      locked: {...content.given},
    );
  }

  @override
  Transition<AxisState> reduce(AxisState s, AxisAction action) {
    switch (action) {
      case TapAxisItem(:final itemId):
        if (!s.tray.contains(itemId) || s.locked.contains(itemId)) {
          return Transition(s);
        }
        final tick = s.placements[itemId];
        if (tick != null && s.held != null) {
          // Holding another item: a tap on a placed one means "this tick".
          return reduce(s, TapTick(tick));
        }
        if (tick != null) {
          return Transition(
            s.copyWith(
              held: itemId,
              placements: Map.of(s.placements)..remove(itemId),
            ),
            [
              InteractionEvent('item_removed', {
                'item_id': itemId,
                'tick_id': tick,
              }),
            ],
          );
        }
        if (s.held == itemId) {
          return Transition(s.copyWith(clearHeld: true));
        }
        return Transition(s.copyWith(held: itemId));

      case TapTick(:final tickId):
        final item = s.held;
        if (item == null) return Transition(s);
        final occupant = s.itemOn(tickId);
        if (occupant != null && s.locked.contains(occupant)) {
          return Transition(s);
        }
        final placements = Map.of(s.placements);
        // One item per tick: whatever was there goes back to the tray.
        if (occupant != null) placements.remove(occupant);
        placements[item] = tickId;
        return Transition(s.copyWith(clearHeld: true, placements: placements), [
          if (occupant != null)
            InteractionEvent('item_removed', {
              'item_id': occupant,
              'tick_id': tickId,
            }),
          InteractionEvent('item_placed', {'item_id': item, 'tick_id': tickId}),
        ]);
    }
  }

  @override
  PlacementsAnswer? extractAnswer(AxisState s) =>
      !s.complete || s.tray.where(s.locked.contains).length == s.toPlace
      ? null
      : PlacementsAnswer(s.placements);

  @override
  AxisState applyFeedback(AxisState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {
      ...s.locked,
      for (final e in result.itemResults.entries)
        if (e.value) e.key,
    };
    return s.copyWith(
      clearHeld: true,
      locked: locked,
      placements: {
        for (final e in s.placements.entries)
          if (locked.contains(e.key)) e.key: e.value,
      },
    );
  }

  @override
  Map<String, Object?> snapshot(AxisState s) => {
    'mode': 'axis',
    'tray': s.tray,
    'held': s.held,
    'placements': s.placements,
    'locked': s.locked.toList(),
  };

  @override
  AxisState? restore(AxisContent content, Map<String, Object?> snap) {
    try {
      if (snap['mode'] != 'axis') return null;
      final tray = (snap['tray'] as List).cast<String>();
      final placeable = {
        for (final i in content.items)
          if (!content.given.contains(i.id)) i.id,
        for (final d in content.distractors) d.id,
      };
      if (tray.length != placeable.length || !tray.every(placeable.contains)) {
        return null;
      }
      final placements = (snap['placements'] as Map).cast<String, String>();
      final ticks = {for (final t in content.ticks) t.id};
      if (!placements.keys.every(
            (k) => content.answer.containsKey(k) || placeable.contains(k),
          ) ||
          !placements.values.every(ticks.contains) ||
          placements.values.toSet().length != placements.length) {
        return null;
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      if (!locked.containsAll(content.given) ||
          !locked.every(placements.containsKey)) {
        return null;
      }
      final held = snap['held'] as String?;
      if (held != null &&
          (!placeable.contains(held) || placements.containsKey(held))) {
        return null;
      }
      return AxisState(
        tray: List.unmodifiable(tray),
        toPlace: content.toPlace,
        held: held,
        placements: placements,
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  static const _minTick = 96.0;
  static const _tileWidth = 140.0;

  @override
  Widget buildView(
    BuildContext context,
    EngineView<AxisContent, AxisState, AxisAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final content = view.content;
    final p = VillagePalette.of(context);
    final holding = s.held != null && view.enabled;

    // A blank tick is named by how far it is from the last labelled one,
    // "repère 2 après 5": never by its position, which would collide with
    // a tick labelled with that number, and the way a child counts.
    String tickName(int i) {
      final label = content.ticks[i].label;
      if (label.isNotEmpty) return fr ? 'repère $label' : 'tick $label';
      for (var j = i - 1; j >= 0; j--) {
        final before = content.ticks[j].label;
        if (before.isNotEmpty) {
          return fr
              ? 'repère ${i - j} après $before'
              : 'tick ${i - j} after $before';
        }
      }
      return fr ? 'repère ${i + 1}' : 'tick ${i + 1}';
    }

    Widget slot(int i, {bool dense = false}) {
      final tick = content.ticks[i];
      final item = s.itemOn(tick.id);
      if (item != null) {
        final fixed = s.locked.contains(item);
        final given = content.given.contains(item);
        return AnswerTile(
          key: ValueKey('axis-placed-$item'),
          dense: dense,
          label: content.item(item).label,
          imageRef: content.item(item).imageRef,
          state: given
              ? AnswerTileState.idle
              : fixed
              ? AnswerTileState.correct
              : AnswerTileState.picked,
          semanticsState: given
              ? (fr ? 'déjà placé pour toi' : 'already placed for you')
              : fixed
              ? (fr ? 'bien placé' : 'in the right place')
              : (fr ? 'touche pour retirer' : 'tap to take it off'),
          onTap: view.enabled && !fixed
              ? () => view.dispatch(TapAxisItem(item))
              : null,
        );
      }
      return Semantics(
        key: ValueKey('axis-tick-${tick.id}'),
        button: true,
        enabled: holding,
        label: tickName(i),
        hint: holding
            ? (fr ? 'touche pour placer ici' : 'tap to put it here')
            : null,
        excludeSemantics: true,
        child: Material(
          color: holding ? p.navHoverFill : p.track.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: Radii.cardMd,
            side: BorderSide(
              color: holding ? p.quebecBlueBright : p.line,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: holding ? () => view.dispatch(TapTick(tick.id)) : null,
            borderRadius: Radii.cardMd,
            child: const SizedBox(height: 52, width: double.infinity),
          ),
        ),
      );
    }

    final labelStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: p.ink,
    );
    final endStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: p.inkMuted,
    );

    final axis = LayoutBuilder(
      builder: (context, constraints) {
        final n = content.ticks.length;
        // Short labels ("7") fit a narrow slot; "Je marche" doesn't.
        final longest = content.items.fold(
          0,
          (m, i) => i.label.length > m ? i.label.length : m,
        );
        // Numbers to 99 fit a 36px slot, so a 0-20 line stays one row.
        final minTick = longest <= 2
            ? 36.0
            : longest <= 3
            ? 52.0
            : _minTick;
        if (constraints.maxWidth / n >= minTick) {
          // Left to right: a slot over each tick, the label under it.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (content.startLabel != null || content.endLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (content.startLabel != null)
                        Text(content.startLabel!, style: endStyle),
                      const Spacer(),
                      if (content.endLabel != null)
                        Text(content.endLabel!, style: endStyle),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: minTick < 52 ? 1 : 4,
                        ),
                        child: slot(i, dense: minTick < _minTick),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // The line, with a mark under each slot.
              Row(
                key: const ValueKey('axis-line'),
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Container(height: 3, color: p.ink),
                          Container(width: 3, height: 10, color: p.ink),
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              content.ticks[i].label,
                              textAlign: TextAlign.center,
                              style: labelStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        }
        // Too many ticks for one row: the axis runs top to bottom.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (content.startLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(content.startLabel!, style: endStyle),
              ),
            for (var i = 0; i < n; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Text(
                            content.ticks[i].label,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ),
                    Container(width: 3, color: p.ink),
                    Center(
                      child: Container(width: 10, height: 3, color: p.ink),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: slot(i),
                      ),
                    ),
                  ],
                ),
              ),
            if (content.endLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(content.endLabel!, style: endStyle),
              ),
          ],
        );
      },
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  fr
                      ? 'Placés : ${s.placed} sur ${s.toPlace}'
                      : 'Placed: ${s.placed} of ${s.toPlace}',
                  key: const ValueKey('axis-count'),
                  textAlign: TextAlign.center,
                  style: endStyle,
                ),
              ),
              axis,
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.tray)
                    if (!s.placements.containsKey(id))
                      SizedBox(
                        width: _tileWidth,
                        child: AnswerTile(
                          key: ValueKey('axis-item-$id'),
                          label: content.item(id).label,
                          imageRef: content.item(id).imageRef,
                          state: s.held == id
                              ? AnswerTileState.picked
                              : AnswerTileState.idle,
                          semanticsState: s.held == id
                              ? (fr
                                    ? 'choisi, choisis son repère'
                                    : 'chosen, now pick its tick')
                              : null,
                          onTap: view.enabled
                              ? () => view.dispatch(TapAxisItem(id))
                              : null,
                        ),
                      )
                    else
                      const SizedBox(width: _tileWidth, height: 52),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades an axis item by item: each is right when it sits on its tick.
/// Given items are left out, as in order mode.
class TimelineAxisEvaluator
    implements Evaluator<AxisContent, PlacementsAnswer> {
  const TimelineAxisEvaluator();

  @override
  String get engineKey => 'timeline_calendar';

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    AxisContent content,
    PlacementsAnswer answer,
    EvaluationContext ctx,
  ) {
    final placed = answer.placements;
    final known = {
      ...content.answer.keys,
      for (final d in content.distractors) d.id,
    };
    if (!placed.keys.every(known.contains)) {
      throw ArgumentError('An answer can only place this axis\'s items.');
    }
    // One verdict per item to place (unplaced is wrong) and per distractor
    // put on the line (always wrong).
    final items = {
      for (final e in content.answer.entries)
        if (!content.given.contains(e.key)) e.key: placed[e.key] == e.value,
      for (final d in content.distractors)
        if (placed.containsKey(d.id)) d.id: false,
    };
    final right = items.values.where((v) => v).length;
    return EvaluationResult(
      outcome: right == items.length
          ? Outcome.correct
          : right == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: right / items.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: 'timeline_calendar.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: right == items.length
          ? const []
          : const [ErrorClassification.unclassified()],
    );
  }
}
