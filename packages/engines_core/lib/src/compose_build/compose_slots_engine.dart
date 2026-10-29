import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/creations.dart';
import '../widgets/answer_slot.dart';
import '../widgets/answer_tile.dart';
import '../widgets/idle_hand_hint.dart';

class ComposeTile {
  const ComposeTile({required this.id, required this.label, this.audioRef});
  final String id;
  final String label;

  /// The tile read aloud on request (a syllable, a sound).
  final String? audioRef;
}

class ComposeContent {
  const ComposeContent({
    required this.tiles,
    required this.target,
    required this.ordered,
    this.frame,
    this.creation = false,
  });

  final List<ComposeTile> tiles;

  /// Tile ids that make the answer, one per slot. Empty with a [frame].
  final List<String> target;

  /// Free mode (ADR 0094): per slot, the tiles any of which is right
  /// there, so every pick across the slots makes a sentence. Replaces
  /// [target]; slots are always ordered.
  final List<Set<String>>? frame;

  int get slotCount => frame?.length ?? target.length;

  /// Whether the slots' order matters (`7 = 5 + 2` vs `{5, 2}`).
  final bool ordered;

  /// The content marks this as the child's own work, so the shell offers
  /// to keep it. Off by default: a question with one right answer is not
  /// a creation (ADR 0093).
  final bool creation;

  ComposeTile tile(String id) => tiles.firstWhere((t) => t.id == id);
}

class ComposeState {
  const ComposeState({
    required this.tray,
    required this.slots,
    this.locked = const {},
    this.missed = const {},
  });

  /// Tile ids in display order. A placed tile stays in the list (so the
  /// tray never reflows under a finger) but is shown as used.
  final List<String> tray;

  /// One entry per target position: the tile placed there, or null.
  final List<String?> slots;

  /// Slot indexes checked right — fixed for the rest of the question.
  final Set<int> locked;

  /// The tiles the last check found wrong, by slot. They are back in the
  /// tray and show there in amber until the child's next tap, so the child
  /// sees which ones to change (UX review G7), each shown once (N5).
  final Map<int, String> missed;

  bool get full => slots.every((s) => s != null);
  bool isPlaced(String tileId) => slots.contains(tileId);

  ComposeState copyWith({
    List<String?>? slots,
    Set<int>? locked,
    Map<int, String>? missed,
  }) => ComposeState(
    tray: tray,
    slots: slots ?? this.slots,
    locked: locked ?? this.locked,
    missed: missed ?? this.missed,
  );
}

sealed class ComposeAction {
  const ComposeAction();
}

/// Put a tile in the first empty slot.
class PlaceTile extends ComposeAction {
  const PlaceTile(this.tileId);
  final String tileId;
}

/// Send a slot's tile back to the tray.
class ClearSlot extends ComposeAction {
  const ClearSlot(this.index);
  final int index;
}

/// Build the answer from tiles, then VALIDER — the `compose_build` engine on
/// the `LearningEngine` contract (Phase 4; the design's `.compose-slot`).
///
/// Tap a tile to fill the next empty slot; tap a filled slot to send its
/// tile back. Each tile places once. Checked with **partial credit**: slots
/// right lock in place, wrong ones empty for the retry.
class ComposeSlotsEngine
    implements
        LearningEngine<
          ComposeContent,
          ComposeState,
          ComposeAction,
          OrderingAnswer
        > {
  const ComposeSlotsEngine();

  static const key = 'compose_build';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<ComposeContent> parse(Map<String, Object?> config) {
    final rawTiles = config['tiles'];
    if (rawTiles is! List || rawTiles.length < 2 || rawTiles.length > 12) {
      return const ParseResult.invalid(
        'compose_build needs between 2 and 12 tiles.',
      );
    }
    final tiles = <ComposeTile>[];
    final ids = <String>{};
    for (final t in rawTiles) {
      final id = t is Map ? t['id'] : null;
      final label = t is Map ? t['label'] : null;
      if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
        return const ParseResult.invalid('Every tile needs an id and a label.');
      }
      if (!ids.add(id)) {
        return const ParseResult.invalid('Tile ids must be unique.');
      }
      final audio = t['audio_ref'];
      tiles.add(
        ComposeTile(
          id: id,
          label: label,
          audioRef: audio is String && audio.isNotEmpty ? audio : null,
        ),
      );
    }
    final creation = config['creation'];
    if (creation != null && creation is! bool) {
      return const ParseResult.invalid('creation must be true or false.');
    }
    final rawFrame = config['frame'];
    if (rawFrame != null) {
      if (config.containsKey('target') || config.containsKey('ordered')) {
        return const ParseResult.invalid('frame replaces target and ordered.');
      }
      if (rawFrame is! List || rawFrame.isEmpty || rawFrame.length > 8) {
        return const ParseResult.invalid('frame is 1 to 8 slots.');
      }
      final frame = <Set<String>>[];
      final used = <String>{};
      for (final slot in rawFrame) {
        if (slot is! List || slot.isEmpty) {
          return const ParseResult.invalid(
            'Every frame slot lists the tiles that fit there.',
          );
        }
        final accepted = <String>{};
        for (final id in slot) {
          if (id is! String || !ids.contains(id)) {
            return const ParseResult.invalid(
              'Every id in frame must exist in tiles.',
            );
          }
          // Disjoint slots: any pick fills every slot, since each tile
          // places once.
          if (!used.add(id)) {
            return const ParseResult.invalid(
              'A tile fits one frame slot only.',
            );
          }
          accepted.add(id);
        }
        frame.add(Set.unmodifiable(accepted));
      }
      return ParseResult.ok(
        ComposeContent(
          tiles: List.unmodifiable(tiles),
          target: const [],
          ordered: true,
          frame: List.unmodifiable(frame),
          creation: creation == true,
        ),
      );
    }
    final target = config['target'];
    if (target is! List || target.isEmpty) {
      return const ParseResult.invalid('target cannot be empty.');
    }
    final targetIds = <String>[];
    for (final id in target) {
      if (id is! String || !ids.contains(id)) {
        return const ParseResult.invalid(
          'Every id in target must exist in tiles.',
        );
      }
      targetIds.add(id);
    }
    if (targetIds.toSet().length != targetIds.length) {
      // Each tile places once, so a target using one twice can't be built.
      return const ParseResult.invalid('target uses a tile more than once.');
    }
    final ordered = config['ordered'];
    if (ordered != null && ordered is! bool) {
      return const ParseResult.invalid('ordered must be true or false.');
    }
    return ParseResult.ok(
      ComposeContent(
        tiles: List.unmodifiable(tiles),
        target: List.unmodifiable(targetIds),
        ordered: ordered != false,
        creation: creation == true,
      ),
    );
  }

  @override
  ComposeState initialize(ComposeContent content, EngineSeed seed) =>
      ComposeState(
        tray: List.unmodifiable(
          [for (final t in content.tiles) t.id]..shuffle(seed.random()),
        ),
        slots: List.filled(content.slotCount, null),
      );

  @override
  Transition<ComposeState> reduce(ComposeState s, ComposeAction action) {
    // Any tap starts the fix, so the last check's marks go.
    if (s.missed.isNotEmpty) s = s.copyWith(missed: const {});
    switch (action) {
      case PlaceTile(:final tileId):
        final free = s.slots.indexOf(null);
        if (!s.tray.contains(tileId) || s.isPlaced(tileId) || free < 0) {
          return Transition(s);
        }
        final slots = List.of(s.slots)..[free] = tileId;
        return Transition(s.copyWith(slots: slots), [
          InteractionEvent('tile_placed', {'tile_id': tileId, 'slot': free}),
        ]);
      case ClearSlot(:final index):
        if (index < 0 || index >= s.slots.length || s.locked.contains(index)) {
          return Transition(s);
        }
        final tile = s.slots[index];
        if (tile == null) return Transition(s);
        final slots = List.of(s.slots)..[index] = null;
        return Transition(s.copyWith(slots: slots), [
          InteractionEvent('tile_removed', {'tile_id': tile, 'slot': index}),
        ]);
    }
  }

  @override
  OrderingAnswer? extractAnswer(ComposeState s) =>
      !s.full || s.locked.length == s.slots.length
      ? null
      : OrderingAnswer(s.slots.cast<String>());

  @override
  ComposeState applyFeedback(ComposeState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final right = {
      for (final e in result.itemResults.entries)
        if (e.value) int.parse(e.key),
    };
    final locked = {...s.locked, ...right};
    return s.copyWith(
      locked: locked,
      slots: [
        for (var i = 0; i < s.slots.length; i++)
          locked.contains(i) ? s.slots[i] : null,
      ],
      missed: {
        for (var i = 0; i < s.slots.length; i++)
          if (!locked.contains(i) && s.slots[i] != null) i: s.slots[i]!,
      },
    );
  }

  @override
  Map<String, Object?> snapshot(ComposeState s) => {
    'tray': s.tray,
    'slots': s.slots,
    'locked': s.locked.toList(),
  };

  @override
  ComposeState? restore(ComposeContent content, Map<String, Object?> snap) {
    try {
      final tray = (snap['tray'] as List).cast<String>();
      final known = {for (final t in content.tiles) t.id};
      if (tray.length != known.length || !tray.every(known.contains)) {
        return null;
      }
      final slots = (snap['slots'] as List).cast<String?>();
      if (slots.length != content.slotCount ||
          !slots.every((t) => t == null || known.contains(t))) {
        return null;
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<int>()
          .toSet();
      return ComposeState(
        tray: List.unmodifiable(tray),
        slots: slots,
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<ComposeContent, ComposeState, ComposeAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    // The idle hand (G3) on the first tray tile, until a tile is placed.
    final handOn =
        view.enabled && s.locked.isEmpty && s.slots.every((t) => t == null)
        ? s.tray.first
        : null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                  for (var i = 0; i < s.slots.length; i++)
                    SizedBox(
                      width: 120,
                      child: AnswerSlot(
                        key: ValueKey('compose-slot-$i'),
                        large: true,
                        index: i + 1,
                        label: s.slots[i] == null
                            ? null
                            : view.content.tile(s.slots[i]!).label,
                        audioRef: s.slots[i] == null
                            ? null
                            : view.content.tile(s.slots[i]!).audioRef,
                        state: s.locked.contains(i)
                            ? AnswerTileState.correct
                            : AnswerTileState.picked,
                        emptyLabel: fr
                            ? 'case ${i + 1}, vide'
                            : 'slot ${i + 1}, empty',
                        semanticsState: s.locked.contains(i)
                            ? (fr ? 'bien placé' : 'right')
                            : (fr ? 'touche pour retirer' : 'tap to remove'),
                        onTap: view.enabled && !s.locked.contains(i)
                            ? () => view.dispatch(ClearSlot(i))
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.tray)
                    if (!s.isPlaced(id))
                      SizedBox(
                        width: 120,
                        child: IdleHandHint(
                          show: handOn == id,
                          child: AnswerTile(
                            key: ValueKey('compose-tile-$id'),
                            large: true,
                            label: view.content.tile(id).label,
                            audioRef: view.content.tile(id).audioRef,
                            // A tile the last check found wrong is back in
                            // the tray, amber until the next tap (G7). Shown
                            // once: not also as a ghost in its slot (N5).
                            state: s.missed.containsValue(id)
                                ? AnswerTileState.retry
                                : AnswerTileState.idle,
                            semanticsState: s.missed.containsValue(id)
                                ? (fr ? 'à changer' : 'to change')
                                : null,
                            onTap: view.enabled && !s.full
                                ? () => view.dispatch(PlaceTile(id))
                                : null,
                          ),
                        ),
                      )
                    else
                      // Holds the tile's place so the tray doesn't reflow.
                      const SizedBox(width: 120, height: 52),
                ],
              ),
              if (view.content.creation && s.locked.length == s.slots.length)
                KeepCreationButton(
                  locale: view.locale,
                  engineKey: ComposeSlotsEngine.key,
                  payload: {
                    'labels': [
                      for (final id in s.slots) view.content.tile(id!).label,
                    ],
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a built answer slot by slot.
///
/// Tiles are compared by label, not id: two tiles that read the same are
/// interchangeable, so "3 + 3 + 3" or "balle" grades on what the child
/// sees. Ordered: a slot is right when its label is the target's label for
/// that position. Unordered: when its label is still owed by the answer (a
/// multiset, so two "3"s need two "3"s). Score is the share of slots
/// right; [EvaluationResult.itemResults] is keyed by slot index. With a
/// frame, a slot is right when its label is one the frame accepts there.
class ComposeBuildEvaluator
    implements Evaluator<ComposeContent, OrderingAnswer> {
  const ComposeBuildEvaluator();

  @override
  String get engineKey => ComposeSlotsEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    ComposeContent content,
    OrderingAnswer answer,
    EvaluationContext ctx,
  ) {
    final placed = answer.orderedItemIds;
    if (placed.length != content.slotCount) {
      throw ArgumentError('An answer must fill every slot.');
    }
    String label(String id) => content.tile(id).label;
    final frame = content.frame;
    if (frame != null) {
      final fits = [
        for (final slot in frame) {for (final id in slot) label(id)},
      ];
      return _result(ctx, {
        for (var i = 0; i < placed.length; i++)
          '$i': fits[i].contains(label(placed[i])),
      });
    }
    final want = [for (final id in content.target) label(id)];
    final owed = <String, int>{};
    for (final l in want) {
      owed[l] = (owed[l] ?? 0) + 1;
    }
    final items = <String, bool>{};
    for (var i = 0; i < placed.length; i++) {
      final got = label(placed[i]);
      if (content.ordered) {
        items['$i'] = got == want[i];
      } else {
        final left = owed[got] ?? 0;
        items['$i'] = left > 0;
        if (left > 0) owed[got] = left - 1;
      }
    }
    return _result(ctx, items);
  }

  EvaluationResult _result(EvaluationContext ctx, Map<String, bool> items) {
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
