import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// One answer option.
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    this.imageRef,
    this.audioRef,
    this.diagnosis,
  });

  final String id;
  final String label;
  final String? imageRef;
  final String? audioRef;

  /// What choosing this option suggests, when the content declares it
  /// (`{"code": …, "taxonomy_version": …}`). Read by the evaluator, never
  /// by the engine: the engine doesn't know what a wrong answer means.
  final ErrorClassification? diagnosis;
}

class SingleChoiceContent {
  const SingleChoiceContent({
    required this.options,
    required this.correct,
    this.shuffle = true,
  });

  final List<ChoiceOption> options;
  final String correct;
  final bool shuffle;

  ChoiceOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class SingleChoiceState {
  const SingleChoiceState({
    required this.order,
    this.selected,
    this.tried = const {},
    this.solved = false,
  });

  /// Option ids in display order — the seeded shuffle, fixed for the
  /// question so a resume shows the same order.
  final List<String> order;
  final String? selected;

  /// Options already submitted and found not right.
  final Set<String> tried;
  final bool solved;

  SingleChoiceState copyWith({
    String? selected,
    bool clearSelected = false,
    Set<String>? tried,
    bool? solved,
  }) => SingleChoiceState(
    order: order,
    selected: clearSelected ? null : (selected ?? this.selected),
    tried: tried ?? this.tried,
    solved: solved ?? this.solved,
  );
}

sealed class SingleChoiceAction {
  const SingleChoiceAction();
}

class SelectOption extends SingleChoiceAction {
  const SelectOption(this.optionId);
  final String optionId;
}

/// Pick one answer, then VALIDER — the `mcq` engine on the `LearningEngine`
/// contract (Phase 3, architecture doc §8).
///
/// The key stays `mcq` (doc §10 D1): it is the brief's "single choice",
/// and renaming it would orphan every exercise, attempt and mastery row
/// already tagged with it. The content is exactly the backend's
/// `mcq.content.schema.json`, so no content changes.
///
/// What changed from the legacy `McqEngine`, deliberately:
/// - **Select, then VALIDER** (doc §10 D3), instead of every tap being an
///   answer. A child can change their mind before committing, and an
///   accidental tap is not a wrong attempt.
/// - **It doesn't grade.** `McqExactEvaluator` does; this engine only knows
///   which option is selected and which were already tried.
/// - **No hint, prompt or audio of its own.** The shell draws all three.
/// - A tried option stays visible and marked rather than being cleared, so
///   the child doesn't try it again.
class SingleChoiceEngine
    implements
        LearningEngine<
          SingleChoiceContent,
          SingleChoiceState,
          SingleChoiceAction,
          SingleChoiceAnswer
        > {
  const SingleChoiceEngine();

  static const key = 'mcq';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<SingleChoiceContent> parse(Map<String, Object?> config) {
    final rawOptions = config['options'];
    if (rawOptions is! List || rawOptions.length < 2 || rawOptions.length > 6) {
      return const ParseResult.invalid('mcq needs between 2 and 6 options.');
    }
    final options = <ChoiceOption>[];
    final ids = <String>{};
    for (final o in rawOptions) {
      if (o is! Map) {
        return const ParseResult.invalid(
          'Every option needs an id and a label.',
        );
      }
      final id = o['id'];
      final label = o['label'];
      if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
        return const ParseResult.invalid(
          'Every option needs an id and a label.',
        );
      }
      if (!ids.add(id)) {
        return const ParseResult.invalid('Option ids must be unique.');
      }
      options.add(
        ChoiceOption(
          id: id,
          label: label,
          imageRef: o['image_ref'] is String ? o['image_ref'] as String : null,
          audioRef: o['audio_ref'] is String ? o['audio_ref'] as String : null,
          diagnosis: _diagnosis(o['diagnosis']),
        ),
      );
    }
    final correct = config['correct'];
    if (correct is! String || !ids.contains(correct)) {
      return const ParseResult.invalid('correct must name one of the options.');
    }
    final shuffle = config['shuffle'];
    if (shuffle != null && shuffle is! bool) {
      return const ParseResult.invalid('shuffle must be true or false.');
    }
    return ParseResult.ok(
      SingleChoiceContent(
        options: List.unmodifiable(options),
        correct: correct,
        shuffle: shuffle != false,
      ),
    );
  }

  static ErrorClassification? _diagnosis(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code'];
    final version = raw['taxonomy_version'];
    if (code is! String || code.isEmpty || version is! int) return null;
    return ErrorClassification(code: code, taxonomyVersion: version);
  }

  @override
  SingleChoiceState initialize(SingleChoiceContent content, EngineSeed seed) {
    final order = [for (final o in content.options) o.id];
    if (content.shuffle) order.shuffle(seed.random());
    return SingleChoiceState(order: List.unmodifiable(order));
  }

  @override
  Transition<SingleChoiceState> reduce(
    SingleChoiceState s,
    SingleChoiceAction action,
  ) {
    switch (action) {
      case SelectOption(:final optionId):
        if (s.solved ||
            !s.order.contains(optionId) ||
            s.tried.contains(optionId) ||
            s.selected == optionId) {
          return Transition(s);
        }
        return Transition(s.copyWith(selected: optionId), [
          InteractionEvent('option_selected', {
            'option_id': optionId,
            if (s.selected != null) 'replaced_option_id': s.selected,
          }),
        ]);
    }
  }

  @override
  SingleChoiceAnswer? extractAnswer(SingleChoiceState s) =>
      s.selected == null || s.solved ? null : SingleChoiceAnswer(s.selected!);

  @override
  SingleChoiceState applyFeedback(
    SingleChoiceState s,
    EvaluationResult result,
  ) {
    final picked = s.selected;
    if (picked == null) return s;
    if (result.isCorrect) return s.copyWith(solved: true);
    // Ungraded is our failure, not the child's: don't mark their choice.
    if (result.outcome == Outcome.ungraded) {
      return s.copyWith(clearSelected: true);
    }
    return s.copyWith(clearSelected: true, tried: {...s.tried, picked});
  }

  @override
  Map<String, Object?> snapshot(SingleChoiceState s) => {
    'order': s.order,
    'selected': s.selected,
    'tried': s.tried.toList(),
    'solved': s.solved,
  };

  @override
  SingleChoiceState? restore(
    SingleChoiceContent content,
    Map<String, Object?> snap,
  ) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final known = {for (final o in content.options) o.id};
      // A snapshot that names options this content doesn't have is from
      // other content: start fresh rather than guess.
      if (order.length != known.length || !order.every(known.contains)) {
        return null;
      }
      final selected = snap['selected'] as String?;
      final tried = ((snap['tried'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      if ((selected != null && !known.contains(selected)) ||
          !tried.every(known.contains)) {
        return null;
      }
      return SingleChoiceState(
        order: List.unmodifiable(order),
        selected: selected,
        tried: tried,
        solved: snap['solved'] == true,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<SingleChoiceContent, SingleChoiceState, SingleChoiceAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in s.order) ...[
                Builder(
                  builder: (context) {
                    final option = view.content.option(id)!;
                    final tried = s.tried.contains(id);
                    final state = switch (id) {
                      _ when tried => AnswerTileState.retry,
                      _ when s.selected == id && s.solved =>
                        AnswerTileState.correct,
                      _ when s.selected == id => AnswerTileState.picked,
                      _ => AnswerTileState.idle,
                    };
                    return AnswerTile(
                      key: ValueKey('mcq-option-$id'),
                      label: option.label,
                      state: state,
                      semanticsState: switch (state) {
                        AnswerTileState.retry =>
                          fr ? 'déjà essayé' : 'already tried',
                        AnswerTileState.correct =>
                          fr ? 'bonne réponse' : 'right answer',
                        AnswerTileState.picked => fr ? 'choisi' : 'chosen',
                        AnswerTileState.idle => null,
                      },
                      onTap: !view.enabled || tried || s.solved
                          ? null
                          : () => view.dispatch(SelectOption(id)),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades an `mcq` answer: right is the one `correct` option.
///
/// A wrong choice carries its option's declared `diagnosis` when the
/// content has one, and is otherwise `unclassified`. One wrong answer is an
/// observation, never a diagnosis: the backend's rules engine decides what
/// repeated observations mean.
class McqExactEvaluator
    implements Evaluator<SingleChoiceContent, SingleChoiceAnswer> {
  const McqExactEvaluator();

  @override
  String get engineKey => SingleChoiceEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    SingleChoiceContent content,
    SingleChoiceAnswer answer,
    EvaluationContext ctx,
  ) {
    final option = content.option(answer.selectedOptionId);
    if (option == null) {
      throw ArgumentError(
        'Answer names an option this question does not have: ${answer.selectedOptionId}',
      );
    }
    final right = option.id == content.correct;
    return EvaluationResult(
      outcome: right ? Outcome.correct : Outcome.incorrect,
      score: right ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      errors: right
          ? const []
          : [option.diagnosis ?? const ErrorClassification.unclassified()],
    );
  }
}
