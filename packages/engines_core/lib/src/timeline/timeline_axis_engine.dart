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
    this.startLabel,
    this.endLabel,
  });

  /// In axis order, first to last.
  final List<AxisTick> ticks;
  final List<AxisItem> items;

  /// item id → the tick it belongs on. One item per tick at most.
  final Map<String, String> answer;

  /// Item ids shown already on their tick, fixed and never graded.
  final Set<String> given;

  final String? startLabel;
  final String? endLabel;

  AxisItem item(String id) => items.firstWhere((i) => i.id == id);
  AxisTick tick(String id) => ticks.firstWhere((t) => t.id == id);
  int tickIndex(String id) => ticks.indexWhere((t) => t.id == id);
}

class AxisState {
  const AxisState({
    required this.tray,
    this.held,
    this.placements = const {},
    this.locked = const {},
  });

  /// The items the child places, in tray order. Given items aren't here.
  final List<String> tray;

  /// The item picked up and waiting for a tick. Always an unplaced one.
  final String? held;

  /// item id → tick id, given items included.
  final Map<String, String> placements;

  /// Item ids fixed on their tick: given ones, and ones checked right.
  final Set<String> locked;

  bool get complete => tray.every(placements.containsKey);

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

  static String? _image(Object? raw) {
    final v = raw is Map ? raw['image_ref'] : null;
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _optionalLabel(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  @override
  ParseResult<AxisContent> parse(Map<String, Object?> config) {
    if (config['distractors'] != null) {
      return const ParseResult.invalid(
        'An axis has no distractors: every item has a tick.',
      );
    }
    final rawTicks = config['ticks'];
    if (rawTicks is! List || rawTicks.length < 2 || rawTicks.length > 11) {
      return const ParseResult.invalid('An axis needs between 2 and 11 ticks.');
    }
    final ticks = <AxisTick>[];
    for (final t in rawTicks) {
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
      final tick = i is Map ? i['tick'] : null;
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.isEmpty ||
          tick is! String) {
        return const ParseResult.invalid(
          'Every axis item needs an id, a label and a tick.',
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
    return ParseResult.ok(
      AxisContent(
        ticks: List.unmodifiable(ticks),
        items: List.unmodifiable(items),
        answer: answer,
        given: given,
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
    ]..shuffle(seed.random());
    return AxisState(
      tray: List.unmodifiable(tray),
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
      !s.complete || s.tray.every(s.locked.contains)
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
      };
      if (tray.length != placeable.length || !tray.every(placeable.contains)) {
        return null;
      }
      final placements = (snap['placements'] as Map).cast<String, String>();
      final ticks = {for (final t in content.ticks) t.id};
      if (!placements.keys.every(content.answer.containsKey) ||
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
        final minTick = longest <= 3 ? 52.0 : _minTick;
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
    if (!content.answer.keys.every(placed.containsKey)) {
      throw ArgumentError('An answer must place every item.');
    }
    final items = {
      for (final e in content.answer.entries)
        if (!content.given.contains(e.key)) e.key: placed[e.key] == e.value,
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
