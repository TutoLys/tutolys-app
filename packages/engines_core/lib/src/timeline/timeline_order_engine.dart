import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_slot.dart';
import '../widgets/answer_tile.dart';
import '../widgets/idle_hand_hint.dart';

class TimelineItem {
  const TimelineItem({
    required this.id,
    required this.label,
    this.imageRef,
    this.audioRef,
  });
  final String id;
  final String label;
  final String? imageRef;
  final String? audioRef;
}

class TimelineContent {
  const TimelineContent({
    required this.items,
    required this.answer,
    this.distractors = const [],
    this.given = const {},
    this.startLabel,
    this.endLabel,
  });

  /// The items that make the sequence.
  final List<TimelineItem> items;

  /// Items that belong nowhere in it — "the one that doesn't fit", the best
  /// diagnostic on a board. They stay in the tray when the order is right.
  final List<TimelineItem> distractors;

  /// Positions shown already filled and fixed — the season a cycle starts
  /// from, the week's "lundi". Never graded: the child didn't place them.
  final Set<int> given;

  /// Item ids in the right order, first to last.
  final List<String> answer;

  /// What the two ends of the sequence mean — "le matin" / "le soir",
  /// "le plus petit" / "le plus grand". Optional; drawn at the ends.
  final String? startLabel;
  final String? endLabel;

  TimelineItem item(String id) =>
      items.followedBy(distractors).firstWhere((i) => i.id == id);

  /// What the child places: every item not given, plus the distractors.
  Set<String> get trayIds => {
    for (var i = 0; i < answer.length; i++)
      if (!given.contains(i)) answer[i],
    for (final d in distractors) d.id,
  };
}

class TimelineState {
  const TimelineState({
    required this.tray,
    required this.slots,
    this.locked = const {},
  });

  /// Item ids in display order. A placed item keeps its place in the list,
  /// so the tray never reflows under a finger.
  final List<String> tray;

  /// One entry per position, first to last: the item placed there, or null.
  final List<String?> slots;

  /// Positions checked right — fixed for the rest of the question.
  final Set<int> locked;

  bool get full => slots.every((s) => s != null);
  bool isPlaced(String id) => slots.contains(id);

  TimelineState copyWith({List<String?>? slots, Set<int>? locked}) =>
      TimelineState(
        tray: tray,
        slots: slots ?? this.slots,
        locked: locked ?? this.locked,
      );
}

sealed class TimelineAction {
  const TimelineAction();
}

/// Put an item in the first empty position.
class PlaceInOrder extends TimelineAction {
  const PlaceInOrder(this.itemId);
  final String itemId;
}

/// Send a position's item back to the tray.
class ClearPosition extends TimelineAction {
  const ClearPosition(this.index);
  final int index;
}

/// Put every item in order, then VALIDER — the `timeline_calendar` engine
/// (ADR 0026; the old product's engine of the same name).
///
/// Days of the week, a morning routine, a life cycle, a story's events,
/// smallest to largest. Tap an item to put it in the next empty position;
/// tap a placed one to send it back. Content may add distractors (items
/// that belong nowhere, left in the tray when the order is right) and give
/// positions already filled, e.g. the season a cycle starts from.
///
/// Checked position by position, with **partial credit**: right positions
/// lock, wrong ones empty for the retry. The old engine revealed one slot
/// at a time through a multiple choice; building the whole order and
/// checking it once is the same evidence, without forcing the child to
/// commit to the first step before seeing the rest.
class TimelineOrderEngine
    implements
        LearningEngine<
          TimelineContent,
          TimelineState,
          TimelineAction,
          OrderingAnswer
        > {
  const TimelineOrderEngine();

  static const key = 'timeline_calendar';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String? _image(Object? raw) {
    final v = raw is Map ? raw['image_ref'] : null;
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _audio(Object? raw) {
    final v = raw is Map ? raw['audio_ref'] : null;
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _optionalLabel(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  @override
  ParseResult<TimelineContent> parse(Map<String, Object?> config) {
    final raw = config['items'];
    if (raw is! List || raw.length < 3 || raw.length > 8) {
      return const ParseResult.invalid(
        'timeline_calendar needs between 3 and 8 items.',
      );
    }
    final items = <TimelineItem>[];
    final byOrder = <int, String>{};
    final givenIds = <String>{};
    for (final i in raw) {
      final id = i is Map ? i['id'] : null;
      final label = i is Map ? i['label'] : null;
      final order = i is Map ? i['order'] : null;
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.isEmpty ||
          order is! int) {
        return const ParseResult.invalid(
          'Every item needs an id, a label and an integer order.',
        );
      }
      if (items.any((x) => x.id == id)) {
        return const ParseResult.invalid('Item ids must be unique.');
      }
      if (byOrder.containsKey(order)) {
        return const ParseResult.invalid(
          'Two items share an order: each position has one right item.',
        );
      }
      final given = i['given'];
      if (given != null && given is! bool) {
        return const ParseResult.invalid('given must be true or false.');
      }
      if (given == true) givenIds.add(id);
      items.add(
        TimelineItem(
          id: id,
          label: label,
          imageRef: _image(i),
          audioRef: _audio(i),
        ),
      );
      byOrder[order] = id;
    }
    if (items.length - givenIds.length < 2) {
      return const ParseResult.invalid(
        'At least two items must be left for the child to place.',
      );
    }
    final distractors = <TimelineItem>[];
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
        if (items.followedBy(distractors).any((x) => x.id == id)) {
          return const ParseResult.invalid('Item ids must be unique.');
        }
        distractors.add(
          TimelineItem(
            id: id,
            label: label,
            imageRef: _image(d),
            audioRef: _audio(d),
          ),
        );
      }
    }
    final orders = byOrder.keys.toList()..sort();
    if (orders.first != 0 || orders.last != items.length - 1) {
      return const ParseResult.invalid(
        'order must count 0, 1, 2… with no gaps.',
      );
    }
    final answer = [for (final o in orders) byOrder[o]!];
    return ParseResult.ok(
      TimelineContent(
        items: List.unmodifiable(items),
        answer: List.unmodifiable(answer),
        distractors: List.unmodifiable(distractors),
        given: {
          for (var i = 0; i < answer.length; i++)
            if (givenIds.contains(answer[i])) i,
        },
        startLabel: _optionalLabel(config['start_label']),
        endLabel: _optionalLabel(config['end_label']),
      ),
    );
  }

  @override
  TimelineState initialize(TimelineContent content, EngineSeed seed) {
    final tray = [
      for (final id in content.answer)
        if (content.trayIds.contains(id)) id,
      for (final d in content.distractors) d.id,
    ];
    final toPlace = [
      for (var i = 0; i < content.answer.length; i++)
        if (!content.given.contains(i)) content.answer[i],
    ];
    final random = seed.random();
    // A tray already in the right order would give the answer away.
    for (var tries = 0; tries < 8; tries++) {
      tray.shuffle(random);
      final order = [
        for (final id in tray)
          if (toPlace.contains(id)) id,
      ];
      if (!_sameOrder(order, toPlace)) break;
    }
    return TimelineState(
      tray: List.unmodifiable(tray),
      slots: [
        for (var i = 0; i < content.answer.length; i++)
          content.given.contains(i) ? content.answer[i] : null,
      ],
      locked: {...content.given},
    );
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Transition<TimelineState> reduce(TimelineState s, TimelineAction action) {
    switch (action) {
      case PlaceInOrder(:final itemId):
        final free = s.slots.indexOf(null);
        if (!s.tray.contains(itemId) || s.isPlaced(itemId) || free < 0) {
          return Transition(s);
        }
        final slots = List.of(s.slots)..[free] = itemId;
        return Transition(s.copyWith(slots: slots), [
          InteractionEvent('item_placed', {
            'item_id': itemId,
            'position': free,
          }),
        ]);
      case ClearPosition(:final index):
        if (index < 0 || index >= s.slots.length || s.locked.contains(index)) {
          return Transition(s);
        }
        final item = s.slots[index];
        if (item == null) return Transition(s);
        final slots = List.of(s.slots)..[index] = null;
        return Transition(s.copyWith(slots: slots), [
          InteractionEvent('item_removed', {
            'item_id': item,
            'position': index,
          }),
        ]);
    }
  }

  @override
  OrderingAnswer? extractAnswer(TimelineState s) =>
      !s.full || s.locked.length == s.slots.length
      ? null
      : OrderingAnswer(s.slots.cast<String>());

  @override
  TimelineState applyFeedback(TimelineState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {
      ...s.locked,
      for (final e in result.itemResults.entries)
        if (e.value) int.parse(e.key),
    };
    return s.copyWith(
      locked: locked,
      slots: [
        for (var i = 0; i < s.slots.length; i++)
          locked.contains(i) ? s.slots[i] : null,
      ],
    );
  }

  @override
  Map<String, Object?> snapshot(TimelineState s) => {
    'tray': s.tray,
    'slots': s.slots,
    'locked': s.locked.toList(),
  };

  @override
  TimelineState? restore(TimelineContent content, Map<String, Object?> snap) {
    try {
      final tray = (snap['tray'] as List).cast<String>();
      final known = content.trayIds;
      if (tray.length != known.length || !tray.every(known.contains)) {
        return null;
      }
      final slots = (snap['slots'] as List).cast<String?>();
      if (slots.length != content.answer.length ||
          !slots.indexed.every(
            (e) => content.given.contains(e.$1)
                ? e.$2 == content.answer[e.$1]
                : e.$2 == null || known.contains(e.$2),
          )) {
        return null;
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<int>()
          .toSet();
      if (!locked.every(
        (i) => i >= 0 && i < slots.length && slots[i] != null,
      )) {
        return null;
      }
      if (!locked.containsAll(content.given)) return null;
      return TimelineState(
        tray: List.unmodifiable(tray),
        slots: List.of(slots),
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  static const _slotWidth = 120.0;
  static const _gap = 12.0;

  @override
  Widget buildView(
    BuildContext context,
    EngineView<TimelineContent, TimelineState, TimelineAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final p = VillagePalette.of(context);
    final content = view.content;
    // The idle hand (G3) on the first card, until one is placed.
    final untouched = [
      for (var i = 0; i < s.slots.length; i++)
        if (!content.given.contains(i)) s.slots[i],
    ].every((x) => x == null);
    final handOn = view.enabled && s.locked.isEmpty && untouched
        ? s.tray.firstWhere((id) => !s.isPlaced(id), orElse: () => '')
        : null;

    Widget slot(int i) => AnswerSlot(
      key: ValueKey('timeline-slot-$i'),
      index: i + 1,
      label: s.slots[i] == null ? null : content.item(s.slots[i]!).label,
      imageRef: s.slots[i] == null ? null : content.item(s.slots[i]!).imageRef,
      audioRef: s.slots[i] == null ? null : content.item(s.slots[i]!).audioRef,
      // A given item is part of the question, not a verdict: neutral, not
      // green.
      state: content.given.contains(i)
          ? AnswerTileState.idle
          : s.locked.contains(i)
          ? AnswerTileState.correct
          : AnswerTileState.picked,
      emptyLabel: fr ? 'position ${i + 1}, vide' : 'position ${i + 1}, empty',
      semanticsState: content.given.contains(i)
          ? (fr ? 'déjà placé pour toi' : 'already placed for you')
          : s.locked.contains(i)
          ? (fr ? 'bien placé' : 'in the right place')
          : (fr ? 'touche pour retirer' : 'tap to take it out'),
      onTap: view.enabled && !s.locked.contains(i)
          ? () => view.dispatch(ClearPosition(i))
          : null,
    );

    Widget end(String text, {required bool start}) => Semantics(
      label: start
          ? (fr ? 'au début : $text' : 'first: $text')
          : (fr ? 'à la fin : $text' : 'last: $text'),
      excludeSemantics: true,
      child: Text(
        text,
        key: ValueKey(start ? 'timeline-start' : 'timeline-end'),
        style: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: p.inkMuted,
        ),
      ),
    );

    final startLabel = content.startLabel;
    final endLabel = content.endLabel;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final n = s.slots.length;
                  final oneRow =
                      n * _slotWidth + (n - 1) * _gap <= constraints.maxWidth;
                  if (oneRow) {
                    // Left to right, the way a number line or a week reads.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startLabel != null || endLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                if (startLabel != null)
                                  end(startLabel, start: true),
                                const Spacer(),
                                if (endLabel != null)
                                  end(endLabel, start: false),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            for (var i = 0; i < n; i++) ...[
                              if (i > 0) const SizedBox(width: _gap),
                              Expanded(child: slot(i)),
                            ],
                          ],
                        ),
                      ],
                    );
                  }
                  // Too many for one row: top to bottom, so "first" is
                  // never ambiguous across a line break.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (startLabel != null) ...[
                        end(startLabel, start: true),
                        const SizedBox(height: 8),
                      ],
                      for (var i = 0; i < n; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        slot(i),
                      ],
                      if (endLabel != null) ...[
                        const SizedBox(height: 8),
                        end(endLabel, start: false),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.tray)
                    if (!s.isPlaced(id))
                      SizedBox(
                        width: _slotWidth,
                        child: IdleHandHint(
                          show: handOn == id,
                          child: AnswerTile(
                            key: ValueKey('timeline-item-$id'),
                            label: content.item(id).label,
                            imageRef: content.item(id).imageRef,
                            audioRef: content.item(id).audioRef,
                            state: AnswerTileState.idle,
                            onTap: view.enabled && !s.full
                                ? () => view.dispatch(PlaceInOrder(id))
                                : null,
                          ),
                        ),
                      )
                    else
                      // Holds the item's place so the tray doesn't reflow.
                      const SizedBox(width: _slotWidth, height: 52),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a built order position by position.
///
/// A position is right when it holds the item that belongs there. Score is
/// the share of positions right; [EvaluationResult.itemResults] is keyed by
/// position index. Given positions are left out of both: the child didn't
/// place them, so they are no evidence either way.
class TimelineOrderEvaluator
    implements Evaluator<TimelineContent, OrderingAnswer> {
  const TimelineOrderEvaluator();

  @override
  String get engineKey => TimelineOrderEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    TimelineContent content,
    OrderingAnswer answer,
    EvaluationContext ctx,
  ) {
    final placed = answer.orderedItemIds;
    if (placed.length != content.answer.length) {
      throw ArgumentError('An answer must fill every position.');
    }
    final items = <String, bool>{
      for (var i = 0; i < placed.length; i++)
        if (!content.given.contains(i)) '$i': placed[i] == content.answer[i],
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
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: right == items.length
          ? const []
          : const [ErrorClassification.unclassified()],
    );
  }
}
