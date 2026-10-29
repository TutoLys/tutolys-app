import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/idle_hand_hint.dart';

class MatchItem {
  const MatchItem({
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

class PairMatchContent {
  const PairMatchContent({
    required this.lefts,
    required this.rights,
    required this.answer,
  });

  final List<MatchItem> lefts;

  /// Every right-hand item, distractors included.
  final List<MatchItem> rights;

  /// left id → the right id it belongs with.
  final Map<String, String> answer;

  MatchItem left(String id) => lefts.firstWhere((i) => i.id == id);
  MatchItem right(String id) => rights.firstWhere((i) => i.id == id);
}

class PairMatchState {
  const PairMatchState({
    required this.leftOrder,
    required this.rightOrder,
    this.selectedLeft,
    this.selectedRight,
    this.links = const {},
    this.locked = const {},
    this.missed = const {},
  });

  final List<String> leftOrder;
  final List<String> rightOrder;

  /// The left item waiting for its partner.
  final String? selectedLeft;

  /// A right item picked first, waiting for its left partner. Many children
  /// start on the picture side (UX review G4). At most one of the two is
  /// set.
  final String? selectedRight;

  /// left id → right id, as the child has paired them so far.
  final Map<String, String> links;

  /// Left ids whose pair was checked right — fixed for the rest of the
  /// question.
  final Set<String> locked;

  /// The pairs the last check found wrong, left id → right id. They have
  /// come apart, but stay marked amber until the child's next tap, so the
  /// child can see which ones to fix (UX review G7).
  final Map<String, String> missed;

  bool get complete => links.length == leftOrder.length;

  PairMatchState copyWith({
    String? selectedLeft,
    String? selectedRight,
    bool clearSelected = false,
    Map<String, String>? links,
    Set<String>? locked,
    Map<String, String>? missed,
  }) => PairMatchState(
    leftOrder: leftOrder,
    rightOrder: rightOrder,
    selectedLeft: clearSelected ? null : (selectedLeft ?? this.selectedLeft),
    selectedRight: clearSelected ? null : (selectedRight ?? this.selectedRight),
    links: links ?? this.links,
    locked: locked ?? this.locked,
    missed: missed ?? this.missed,
  );
}

sealed class PairMatchAction {
  const PairMatchAction();
}

class TapLeft extends PairMatchAction {
  const TapLeft(this.leftId);
  final String leftId;
}

class TapRight extends PairMatchAction {
  const TapRight(this.rightId);
  final String rightId;
}

/// Pair every left item with its right partner, then VALIDER — the
/// `pair_match` engine on the `LearningEngine` contract (Phase 4).
///
/// Tap a left item, then a right one, to pair them, or the other way
/// round. Tap a paired item again to undo its pair. The whole board is checked at once, with
/// **partial credit**: pairs checked right lock in place, wrong ones come
/// apart for the retry. The design's "wrong pairs flash and clear, right
/// pairs lock in", but as one answer — the brief's point that three right
/// out of four is evidence a single "wrong" would throw away.
///
/// This changes what one attempt means for this engine: the legacy engine
/// logged one attempt per pair, this one logs one per checked board (ADR
/// 0022).
class PairMatchBoardEngine
    implements
        LearningEngine<
          PairMatchContent,
          PairMatchState,
          PairMatchAction,
          PairsAnswer
        > {
  const PairMatchBoardEngine();

  static const key = 'pair_match';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static MatchItem? _item(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
      return null;
    }
    final image = raw['image_ref'];
    final audio = raw['audio_ref'];
    return MatchItem(
      id: id,
      label: label,
      imageRef: image is String && image.isNotEmpty ? image : null,
      audioRef: audio is String && audio.isNotEmpty ? audio : null,
    );
  }

  @override
  ParseResult<PairMatchContent> parse(Map<String, Object?> config) {
    final pairs = config['pairs'];
    if (pairs is! List || pairs.length < 2 || pairs.length > 8) {
      return const ParseResult.invalid(
        'pair_match needs between 2 and 8 pairs.',
      );
    }
    final lefts = <MatchItem>[];
    final rights = <MatchItem>[];
    final answer = <String, String>{};
    for (final p in pairs) {
      final l = p is Map ? _item(p['left']) : null;
      final r = p is Map ? _item(p['right']) : null;
      if (l == null || r == null) {
        return const ParseResult.invalid(
          'Every pair needs a left and a right item with an id and a label.',
        );
      }
      lefts.add(l);
      rights.add(r);
      answer[l.id] = r.id;
    }
    final distractors = config['distractors'];
    if (distractors != null) {
      if (distractors is! List || distractors.length > 4) {
        return const ParseResult.invalid('distractors allows at most 4 items.');
      }
      for (final d in distractors) {
        final item = _item(d);
        if (item == null) {
          return const ParseResult.invalid(
            'Every distractor needs an id and a label.',
          );
        }
        rights.add(item);
      }
    }
    if (lefts.map((i) => i.id).toSet().length != lefts.length ||
        rights.map((i) => i.id).toSet().length != rights.length) {
      return const ParseResult.invalid('Item ids must be unique on each side.');
    }
    return ParseResult.ok(
      PairMatchContent(
        lefts: List.unmodifiable(lefts),
        rights: List.unmodifiable(rights),
        answer: answer,
      ),
    );
  }

  @override
  PairMatchState initialize(PairMatchContent content, EngineSeed seed) {
    final random = seed.random();
    final lefts = [for (final i in content.lefts) i.id]..shuffle(random);
    final rights = [for (final i in content.rights) i.id]..shuffle(random);
    return PairMatchState(
      leftOrder: List.unmodifiable(lefts),
      rightOrder: List.unmodifiable(rights),
    );
  }

  @override
  Transition<PairMatchState> reduce(PairMatchState s, PairMatchAction action) {
    // Any tap starts the fix, so the last check's marks go.
    if (s.missed.isNotEmpty) s = s.copyWith(missed: const {});
    switch (action) {
      case TapLeft(:final leftId):
        if (!s.leftOrder.contains(leftId) || s.locked.contains(leftId)) {
          return Transition(s);
        }
        final waiting = s.selectedRight;
        if (waiting != null) return _link(s, leftId, waiting);
        final linked = s.links[leftId];
        if (linked != null) {
          // Undo this pair and pick the left item up again.
          return Transition(
            s.copyWith(
              selectedLeft: leftId,
              links: Map.of(s.links)..remove(leftId),
            ),
            [
              InteractionEvent('pair_disconnected', {
                'left_id': leftId,
                'right_id': linked,
              }),
            ],
          );
        }
        if (s.selectedLeft == leftId) {
          return Transition(s.copyWith(clearSelected: true));
        }
        return Transition(s.copyWith(selectedLeft: leftId));

      case TapRight(:final rightId):
        if (!s.rightOrder.contains(rightId)) return Transition(s);
        final lockedRight = s.locked.any((l) => s.links[l] == rightId);
        if (lockedRight) return Transition(s);
        final left = s.selectedLeft;
        if (left != null) return _link(s, left, rightId);
        // Right first: pick it up (undoing its pair), or put it down again.
        final pairedWith = s.links.entries
            .where((e) => e.value == rightId)
            .map((e) => e.key)
            .firstOrNull;
        if (pairedWith != null) {
          return Transition(
            s.copyWith(
              selectedRight: rightId,
              links: Map.of(s.links)..remove(pairedWith),
            ),
            [
              InteractionEvent('pair_disconnected', {
                'left_id': pairedWith,
                'right_id': rightId,
              }),
            ],
          );
        }
        if (s.selectedRight == rightId) {
          return Transition(s.copyWith(clearSelected: true));
        }
        return Transition(s.copyWith(selectedRight: rightId));
    }
  }

  /// Pair [left] with [right]. A right item belongs to one pair at a time,
  /// so taking it moves it; a left item's old pair is replaced.
  Transition<PairMatchState> _link(
    PairMatchState s,
    String left,
    String right,
  ) {
    final links = Map.of(s.links)..removeWhere((_, r) => r == right);
    links[left] = right;
    return Transition(s.copyWith(clearSelected: true, links: links), [
      InteractionEvent('pair_connected', {'left_id': left, 'right_id': right}),
    ]);
  }

  @override
  PairsAnswer? extractAnswer(PairMatchState s) =>
      !s.complete || s.locked.length == s.leftOrder.length
      ? null
      : PairsAnswer([
          for (final e in s.links.entries) (left: e.key, right: e.value),
        ]);

  @override
  PairMatchState applyFeedback(PairMatchState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final right = {
      for (final e in result.itemResults.entries)
        if (e.value) e.key,
    };
    final locked = {...s.locked, ...right};
    return s.copyWith(
      clearSelected: true,
      locked: locked,
      links: {
        for (final e in s.links.entries)
          if (locked.contains(e.key)) e.key: e.value,
      },
      missed: {
        for (final e in s.links.entries)
          if (!locked.contains(e.key)) e.key: e.value,
      },
    );
  }

  @override
  Map<String, Object?> snapshot(PairMatchState s) => {
    'left_order': s.leftOrder,
    'right_order': s.rightOrder,
    'selected_left': s.selectedLeft,
    'selected_right': s.selectedRight,
    'links': s.links,
    'locked': s.locked.toList(),
  };

  @override
  PairMatchState? restore(PairMatchContent content, Map<String, Object?> snap) {
    try {
      final lefts = (snap['left_order'] as List).cast<String>();
      final rights = (snap['right_order'] as List).cast<String>();
      final knownL = {for (final i in content.lefts) i.id};
      final knownR = {for (final i in content.rights) i.id};
      if (lefts.length != knownL.length || !lefts.every(knownL.contains)) {
        return null;
      }
      if (rights.length != knownR.length || !rights.every(knownR.contains)) {
        return null;
      }
      final links = (snap['links'] as Map).cast<String, String>();
      if (!links.keys.every(knownL.contains) ||
          !links.values.every(knownR.contains)) {
        return null;
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      return PairMatchState(
        leftOrder: List.unmodifiable(lefts),
        rightOrder: List.unmodifiable(rights),
        selectedLeft: snap['selected_left'] as String?,
        selectedRight: snap['selected_right'] as String?,
        links: links,
        locked: locked,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<PairMatchContent, PairMatchState, PairMatchAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    // Number the pairs in left-column order, so a pair's two tiles share a
    // badge the child can match by eye.
    final badgeOf = <String, int>{};
    for (final l in s.leftOrder) {
      if (s.links.containsKey(l)) badgeOf[l] = badgeOf.length + 1;
    }
    int? rightBadge(String r) {
      for (final e in s.links.entries) {
        if (e.value == r) return badgeOf[e.key];
      }
      return null;
    }

    // The idle hand (G3): on the first left tile while nothing is touched,
    // then on the first right tile once a left one waits for its partner
    // (or the other way round, when a right tile was picked first).
    final untouched = view.enabled && s.links.isEmpty && s.locked.isEmpty;
    final handLeft = untouched && s.selectedLeft == null
        ? s.leftOrder.first
        : null;
    final handRight = untouched && s.selectedLeft != null
        ? s.rightOrder.first
        : null;

    AnswerTileState stateOf(bool locked, bool picked, {bool missed = false}) =>
        locked
        ? AnswerTileState.correct
        : picked
        ? AnswerTileState.picked
        : missed
        ? AnswerTileState.retry
        : AnswerTileState.idle;
    final toFix = fr ? 'à corriger' : 'to fix';

    Widget column(List<Widget> tiles) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tiles) ...[t, const SizedBox(height: 12)],
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FocusTraversalGroup(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column([
                for (final l in s.leftOrder)
                  IdleHandHint(
                    show: handLeft == l,
                    child: AnswerTile(
                      key: ValueKey('pair-left-$l'),
                      large: true,
                      label: view.content.left(l).label,
                      imageRef: view.content.left(l).imageRef,
                      audioRef: view.content.left(l).audioRef,
                      state: stateOf(
                        s.locked.contains(l),
                        s.selectedLeft == l || s.links.containsKey(l),
                        missed: s.missed.containsKey(l),
                      ),
                      badge: s.locked.contains(l) ? null : badgeOf[l],
                      semanticsState: s.locked.contains(l)
                          ? (fr ? 'bien associé' : 'matched')
                          : s.selectedLeft == l
                          ? (fr
                                ? 'choisi, choisis son partenaire'
                                : 'chosen, now pick its partner')
                          : s.missed.containsKey(l)
                          ? toFix
                          : null,
                      onTap: view.enabled && !s.locked.contains(l)
                          ? () => view.dispatch(TapLeft(l))
                          : null,
                    ),
                  ),
              ]),
              const SizedBox(width: 16),
              column([
                for (final r in s.rightOrder)
                  Builder(
                    builder: (context) {
                      final lockedRight = s.locked.any((l) => s.links[l] == r);
                      final badge = rightBadge(r);
                      return IdleHandHint(
                        show: handRight == r,
                        child: AnswerTile(
                          key: ValueKey('pair-right-$r'),
                          large: true,
                          label: view.content.right(r).label,
                          imageRef: view.content.right(r).imageRef,
                          audioRef: view.content.right(r).audioRef,
                          state: stateOf(
                            lockedRight,
                            badge != null || s.selectedRight == r,
                            missed: s.missed.containsValue(r),
                          ),
                          badge: lockedRight ? null : badge,
                          semanticsState: lockedRight
                              ? (fr ? 'bien associé' : 'matched')
                              : s.selectedRight == r
                              ? (fr
                                    ? 'choisi, choisis son partenaire'
                                    : 'chosen, now pick its partner')
                              : s.missed.containsValue(r)
                              ? toFix
                              : null,
                          // Live from the start: a right tile can be picked
                          // first (G4).
                          onTap: view.enabled && !lockedRight
                              ? () => view.dispatch(TapRight(r))
                              : null,
                        ),
                      );
                    },
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a whole `pair_match` board, pair by pair.
///
/// Score is the share of pairs right. The outcome is `correct` only when
/// every pair is, `partial` when some are, `incorrect` when none are, and
/// [EvaluationResult.itemResults] says which — keyed by left id — so the
/// engine can lock the right ones without grading anything itself.
class PairMatchEvaluator implements Evaluator<PairMatchContent, PairsAnswer> {
  const PairMatchEvaluator();

  @override
  String get engineKey => PairMatchBoardEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    PairMatchContent content,
    PairsAnswer answer,
    EvaluationContext ctx,
  ) {
    final items = {
      for (final p in answer.pairs) p.left: content.answer[p.left] == p.right,
    };
    if (items.length != content.answer.length) {
      throw ArgumentError('A board answer must pair every left item.');
    }
    final right = items.values.where((v) => v).length;
    final score = right / items.length;
    return EvaluationResult(
      outcome: right == items.length
          ? Outcome.correct
          : right == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: score,
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
