import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

class SortBucket {
  const SortBucket({required this.id, required this.label});
  final String id;
  final String label;
}

class SortItem {
  const SortItem({required this.id, required this.label});
  final String id;
  final String label;
}

class SortContent {
  const SortContent({
    required this.buckets,
    required this.items,
    required this.answer,
    required this.shuffle,
  });

  /// In authored order: "pair / impair" reads in that order on purpose.
  final List<SortBucket> buckets;
  final List<SortItem> items;

  /// item id → the bucket id it belongs in.
  final Map<String, String> answer;

  /// Whether the tray's order is shuffled (it is unless content says not).
  final bool shuffle;

  SortBucket bucket(String id) => buckets.firstWhere((b) => b.id == id);
  SortItem item(String id) => items.firstWhere((i) => i.id == id);
}

class SortState {
  const SortState({
    required this.itemOrder,
    this.selected,
    this.placements = const {},
    this.locked = const {},
  });

  /// Item ids in tray order. A placed item keeps its place in the list, so
  /// the tray never reflows under a finger.
  final List<String> itemOrder;

  /// The item picked up and waiting for a bucket. Always an unplaced one.
  final String? selected;

  /// item id → bucket id, as the child has sorted them so far.
  final Map<String, String> placements;

  /// Item ids checked right — fixed for the rest of the question.
  final Set<String> locked;

  bool get complete => placements.length == itemOrder.length;

  SortState copyWith({
    String? selected,
    bool clearSelected = false,
    Map<String, String>? placements,
    Set<String>? locked,
  }) => SortState(
    itemOrder: itemOrder,
    selected: clearSelected ? null : (selected ?? this.selected),
    placements: placements ?? this.placements,
    locked: locked ?? this.locked,
  );
}

sealed class SortAction {
  const SortAction();
}

/// Tap an item: pick it up from the tray, put it down again, or — when it
/// is already in a bucket — take it back out. While another item is held,
/// tapping a sorted item drops the held one into that item's bucket.
class TapSortItem extends SortAction {
  const TapSortItem(this.itemId);
  final String itemId;
}

/// Tap a bucket: drop the picked-up item in it.
class TapBucket extends SortAction {
  const TapBucket(this.bucketId);
  final String bucketId;
}

/// Sort every item into its bucket, then VALIDER — the `sort_buckets`
/// engine (Phase 5, ADR 0025; the old product's `sort_classify`).
///
/// Tap an item, then the bucket it belongs in. Tap an item already in a
/// bucket to take it back out. Tap, never drag, like every other engine:
/// no drag physics to get wrong for a six-year-old.
///
/// The whole board is checked at once, with **partial credit**, exactly as
/// `pair_match` does: items sorted right lock in their bucket, wrong ones go
/// back to the tray for the retry. One attempt is one checked board.
class SortBucketsEngine
    implements
        LearningEngine<SortContent, SortState, SortAction, PlacementsAnswer> {
  const SortBucketsEngine();

  static const key = 'sort_buckets';

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
  ParseResult<SortContent> parse(Map<String, Object?> config) {
    final rawBuckets = config['buckets'];
    if (rawBuckets is! List || rawBuckets.length < 2 || rawBuckets.length > 4) {
      return const ParseResult.invalid(
        'sort_buckets needs between 2 and 4 buckets.',
      );
    }
    final rawItems = config['items'];
    if (rawItems is! List || rawItems.length < 2 || rawItems.length > 12) {
      return const ParseResult.invalid(
        'sort_buckets needs between 2 and 12 items.',
      );
    }
    final buckets = <SortBucket>[];
    for (final b in rawBuckets) {
      final e = _entry(b);
      if (e == null) {
        return const ParseResult.invalid(
          'Every bucket needs an id and a label.',
        );
      }
      buckets.add(SortBucket(id: e.$1, label: e.$2));
    }
    final bucketIds = {for (final b in buckets) b.id};
    if (bucketIds.length != buckets.length) {
      return const ParseResult.invalid('Bucket ids must be unique.');
    }
    final items = <SortItem>[];
    final answer = <String, String>{};
    for (final i in rawItems) {
      final e = _entry(i);
      final target = i is Map ? i['correct_bucket'] : null;
      if (e == null || target is! String) {
        return const ParseResult.invalid(
          'Every item needs an id, a label and a correct_bucket.',
        );
      }
      if (!bucketIds.contains(target)) {
        return ParseResult.invalid(
          'Item ${e.$1} belongs in $target, which is not a bucket.',
        );
      }
      items.add(SortItem(id: e.$1, label: e.$2));
      answer[e.$1] = target;
    }
    if (answer.length != items.length) {
      return const ParseResult.invalid('Item ids must be unique.');
    }
    final shuffle = config['shuffle'];
    return ParseResult.ok(
      SortContent(
        buckets: List.unmodifiable(buckets),
        items: List.unmodifiable(items),
        answer: answer,
        shuffle: shuffle is bool ? shuffle : true,
      ),
    );
  }

  @override
  SortState initialize(SortContent content, EngineSeed seed) {
    final order = [for (final i in content.items) i.id];
    if (content.shuffle) order.shuffle(seed.random());
    return SortState(itemOrder: List.unmodifiable(order));
  }

  @override
  Transition<SortState> reduce(SortState s, SortAction action) {
    switch (action) {
      case TapSortItem(:final itemId):
        if (!s.itemOrder.contains(itemId) || s.locked.contains(itemId)) {
          return Transition(s);
        }
        final bucket = s.placements[itemId];
        if (bucket != null && s.selected != null) {
          // Holding another item: a tap anywhere in a bucket means "here",
          // even when it lands on an item already sorted into it.
          return reduce(s, TapBucket(bucket));
        }
        if (bucket != null) {
          // Take it back out and hold it, ready for another bucket.
          return Transition(
            s.copyWith(
              selected: itemId,
              placements: Map.of(s.placements)..remove(itemId),
            ),
            [
              InteractionEvent('item_removed', {
                'item_id': itemId,
                'bucket_id': bucket,
              }),
            ],
          );
        }
        if (s.selected == itemId) {
          return Transition(s.copyWith(clearSelected: true));
        }
        return Transition(s.copyWith(selected: itemId));

      case TapBucket(:final bucketId):
        final item = s.selected;
        if (item == null) return Transition(s);
        return Transition(
          s.copyWith(
            clearSelected: true,
            placements: {...s.placements, item: bucketId},
          ),
          [
            InteractionEvent('item_placed', {
              'item_id': item,
              'bucket_id': bucketId,
            }),
          ],
        );
    }
  }

  @override
  PlacementsAnswer? extractAnswer(SortState s) =>
      !s.complete || s.locked.length == s.itemOrder.length
      ? null
      : PlacementsAnswer(s.placements);

  @override
  SortState applyFeedback(SortState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {
      ...s.locked,
      for (final e in result.itemResults.entries)
        if (e.value) e.key,
    };
    return s.copyWith(
      clearSelected: true,
      locked: locked,
      placements: {
        for (final e in s.placements.entries)
          if (locked.contains(e.key)) e.key: e.value,
      },
    );
  }

  @override
  Map<String, Object?> snapshot(SortState s) => {
    'item_order': s.itemOrder,
    'selected': s.selected,
    'placements': s.placements,
    'locked': s.locked.toList(),
  };

  @override
  SortState? restore(SortContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['item_order'] as List).cast<String>();
      final knownItems = {for (final i in content.items) i.id};
      final knownBuckets = {for (final b in content.buckets) b.id};
      if (order.length != knownItems.length ||
          !order.every(knownItems.contains)) {
        return null;
      }
      final placements = (snap['placements'] as Map).cast<String, String>();
      if (!placements.keys.every(knownItems.contains) ||
          !placements.values.every(knownBuckets.contains)) {
        return null;
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      if (!locked.every(placements.containsKey)) return null;
      final selected = snap['selected'] as String?;
      if (selected != null &&
          (!knownItems.contains(selected) ||
              placements.containsKey(selected))) {
        return null;
      }
      return SortState(
        itemOrder: List.unmodifiable(order),
        selected: selected,
        placements: placements,
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  static const _tileWidth = 140.0;

  @override
  Widget buildView(
    BuildContext context,
    EngineView<SortContent, SortState, SortAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final holding = s.selected != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.itemOrder)
                    if (!s.placements.containsKey(id))
                      SizedBox(
                        width: _tileWidth,
                        child: AnswerTile(
                          key: ValueKey('sort-item-$id'),
                          label: view.content.item(id).label,
                          state: s.selected == id
                              ? AnswerTileState.picked
                              : AnswerTileState.idle,
                          semanticsState: s.selected == id
                              ? (fr
                                    ? 'choisi, choisis son groupe'
                                    : 'chosen, now pick its group')
                              : null,
                          onTap: view.enabled
                              ? () => view.dispatch(TapSortItem(id))
                              : null,
                        ),
                      )
                    else
                      // Holds the item's place so the tray doesn't reflow.
                      const SizedBox(width: _tileWidth, height: 52),
                ],
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final n = view.content.buckets.length;
                  const gap = 12.0;
                  // Side by side when each bucket still fits a tile, two
                  // to a row otherwise (four buckets on a phone).
                  final perRow =
                      (constraints.maxWidth - gap * (n - 1)) / n >= _tileWidth
                      ? n
                      : 2;
                  final width =
                      (constraints.maxWidth - gap * (perRow - 1)) / perRow;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final b in view.content.buckets)
                        SizedBox(
                          width: width,
                          child: _BucketCard(
                            key: ValueKey('sort-bucket-${b.id}'),
                            label: b.label,
                            highlighted: holding && view.enabled,
                            dropHint: fr
                                ? 'touche pour déposer ici'
                                : 'tap to put it here',
                            onTap: view.enabled && holding
                                ? () => view.dispatch(TapBucket(b.id))
                                : null,
                            children: [
                              for (final id in s.itemOrder)
                                if (s.placements[id] == b.id)
                                  AnswerTile(
                                    key: ValueKey('sort-placed-$id'),
                                    label: view.content.item(id).label,
                                    state: s.locked.contains(id)
                                        ? AnswerTileState.correct
                                        : AnswerTileState.idle,
                                    semanticsState: s.locked.contains(id)
                                        ? (fr ? 'bien classé' : 'sorted right')
                                        : (fr
                                              ? 'touche pour retirer'
                                              : 'tap to take it out'),
                                    onTap:
                                        view.enabled && !s.locked.contains(id)
                                        ? () => view.dispatch(TapSortItem(id))
                                        : null,
                                  ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bucket: a labelled card the child taps to drop the item they hold,
/// with the items sorted into it so far inside.
///
/// While an item is held every bucket's border turns blue, so a child sees
/// at once where it can go. That is the only cue: no colour says whether a
/// bucket is the right one before VALIDER.
class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.label,
    required this.highlighted,
    required this.dropHint,
    required this.onTap,
    required this.children,
    super.key,
  });

  final String label;
  final bool highlighted;
  final String dropHint;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Material(
      color: highlighted ? p.navHoverFill : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardMd,
        side: BorderSide(
          color: highlighted ? p.quebecBlueBright : p.line,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardMd,
        child: ConstrainedBox(
          // Tall enough to read as a place to put things, even empty.
          constraints: const BoxConstraints(minHeight: 140),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  enabled: onTap != null,
                  label: label,
                  hint: onTap != null ? dropHint : null,
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: p.ink,
                      ),
                    ),
                  ),
                ),
                for (final c in children) ...[c, const SizedBox(height: 8)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grades a whole `sort_buckets` board, item by item.
///
/// Score is the share of items in their right bucket. The outcome is
/// `correct` only when every item is, `partial` when some are, `incorrect`
/// when none are, and [EvaluationResult.itemResults] says which — keyed by
/// item id — so the engine can lock the right ones without grading anything
/// itself.
class SortBucketsEvaluator implements Evaluator<SortContent, PlacementsAnswer> {
  const SortBucketsEvaluator();

  @override
  String get engineKey => SortBucketsEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    SortContent content,
    PlacementsAnswer answer,
    EvaluationContext ctx,
  ) {
    final placed = answer.placements;
    if (placed.length != content.answer.length ||
        !content.answer.keys.every(placed.containsKey)) {
      throw ArgumentError('A board answer must place every item.');
    }
    final items = {
      for (final e in content.answer.entries) e.key: placed[e.key] == e.value,
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
