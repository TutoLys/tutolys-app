import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import 'answer_tile.dart';

/// Where a "pick one value" question stands: the engines that draw
/// something to read (a ruler, a clock, a cut pizza) and then offer the
/// values to choose from. Same rules as `balance_scale`: a wrong pick goes
/// amber and can't be picked again; a right one ends the question.
class PickState {
  const PickState({
    required this.order,
    this.selected,
    this.tried = const {},
    this.solved = false,
  });

  final List<String> order;
  final String? selected;
  final Set<String> tried;
  final bool solved;

  PickState copyWith({
    String? selected,
    bool clearSelected = false,
    Set<String>? tried,
    bool? solved,
  }) => PickState(
    order: order,
    selected: clearSelected ? null : (selected ?? this.selected),
    tried: tried ?? this.tried,
    solved: solved ?? this.solved,
  );
}

class PickChoice {
  const PickChoice(this.id);
  final String id;
}

/// The shared reducer, feedback, snapshot and grading for [PickState].
/// An engine keeps its own content and drawing and delegates the rest.
abstract final class PickOne {
  static PickState initialize(
    List<String> ids,
    EngineSeed seed, {
    bool shuffle = true,
  }) {
    final order = [...ids];
    if (shuffle) order.shuffle(seed.random());
    return PickState(order: List.unmodifiable(order));
  }

  static Transition<PickState> reduce(PickState s, PickChoice action) {
    final id = action.id;
    if (s.solved ||
        !s.order.contains(id) ||
        s.tried.contains(id) ||
        s.selected == id) {
      return Transition(s);
    }
    return Transition(s.copyWith(selected: id), [
      InteractionEvent('option_selected', {'option_id': id}),
    ]);
  }

  static SingleChoiceAnswer? extractAnswer(PickState s) =>
      s.selected == null || s.solved ? null : SingleChoiceAnswer(s.selected!);

  static PickState applyFeedback(PickState s, EvaluationResult result) {
    final pick = s.selected;
    if (pick == null || result.outcome == Outcome.ungraded) return s;
    if (result.outcome == Outcome.correct) return s.copyWith(solved: true);
    return s.copyWith(clearSelected: true, tried: {...s.tried, pick});
  }

  static Map<String, Object?> snapshot(PickState s) => {
    'order': s.order,
    'selected': s.selected,
    'tried': s.tried.toList(),
    'solved': s.solved,
  };

  static PickState? restore(
    Map<String, Object?> snap, {
    required List<String> ids,
    required String correctId,
  }) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final known = ids.toSet();
      if (order.length != known.length || !order.every(known.contains)) {
        return null;
      }
      final selected = snap['selected'] as String?;
      final tried = ((snap['tried'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final solved = snap['solved'] == true;
      if ((selected != null && !known.contains(selected)) ||
          !tried.every(known.contains) ||
          tried.contains(correctId) ||
          (solved && selected != correctId)) {
        return null;
      }
      return PickState(
        order: List.unmodifiable(order),
        selected: selected,
        tried: tried,
        solved: solved,
      );
    } on Object {
      return null;
    }
  }

  static EvaluationResult evaluate({
    required String engineKey,
    required List<String> ids,
    required String correctId,
    required SingleChoiceAnswer answer,
    required EvaluationContext ctx,
  }) {
    final pick = answer.selectedOptionId;
    if (!ids.contains(pick)) throw ArgumentError('Unknown choice $pick.');
    final right = pick == correctId;
    return EvaluationResult(
      outcome: right ? Outcome.correct : Outcome.incorrect,
      score: right ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.exact@1',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: {pick: right},
      errors: right ? const [] : const [ErrorClassification.unclassified()],
    );
  }

  /// The row of choice tiles under the drawing.
  static Widget choices({
    required PickState state,
    required bool enabled,
    required bool fr,
    required String Function(String id) label,
    String Function(String id)? spoken,
    required void Function(String id) onPick,
    required String keyPrefix,
    double width = 120,
  }) {
    AnswerTileState stateOf(String id) => state.solved && id == state.selected
        ? AnswerTileState.correct
        : state.tried.contains(id)
        ? AnswerTileState.retry
        : state.selected == id
        ? AnswerTileState.picked
        : AnswerTileState.idle;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final id in state.order)
          SizedBox(
            width: width,
            // Narrow slots hold short answers (« 20 °C »): big square-ish
            // tiles (UX review AM3). Wide ones hold sentences.
            height: width <= 160 ? 96 : null,
            child: Semantics(
              label: (spoken ?? label)(id),
              hint: switch (stateOf(id)) {
                AnswerTileState.correct =>
                  fr ? 'bonne réponse' : 'right answer',
                AnswerTileState.retry => fr ? 'déjà essayé' : 'already tried',
                AnswerTileState.picked => fr ? 'choisi' : 'chosen',
                AnswerTileState.idle => null,
              },
              excludeSemantics: true,
              button: true,
              selected: state.selected == id,
              child: AnswerTile(
                key: ValueKey('$keyPrefix-$id'),
                label: label(id),
                square: width <= 160,
                state: stateOf(id),
                onTap: enabled && !state.solved && !state.tried.contains(id)
                    ? () => onPick(id)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
