import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';

/// A minimal single-choice [LearningEngine], just enough to drive the
/// runtime in tests. Not the real `mcq` port — that is Phase 3.
class FakeChoiceContent {
  const FakeChoiceContent(this.optionIds, this.correct);
  final List<String> optionIds;
  final String correct;
}

class FakeChoiceState {
  const FakeChoiceState({
    required this.order,
    this.selected,
    this.locked = const {},
  });
  final List<String> order;
  final String? selected;

  /// Options already tried and found wrong.
  final Set<String> locked;
}

class Pick {
  const Pick(this.id);
  final String id;
}

class FakeChoiceEngine
    implements
        LearningEngine<
          FakeChoiceContent,
          FakeChoiceState,
          Pick,
          SingleChoiceAnswer
        > {
  FakeChoiceEngine({
    this.key = 'fake_choice',
    this.submitMode = SubmitMode.explicit,
    this.version = 1,
  });

  final String key;
  final SubmitMode submitMode;
  final int version;

  @override
  EngineDescriptor get descriptor =>
      EngineDescriptor(key: key, version: version, submitMode: submitMode);

  @override
  ParseResult<FakeChoiceContent> parse(Map<String, Object?> config) {
    final options = config['options'];
    final correct = config['correct'];
    if (options is! List || options.length < 2 || correct is! String) {
      return const ParseResult.invalid('options[2+] and correct are required');
    }
    final ids = options.cast<String>();
    if (!ids.contains(correct)) {
      return const ParseResult.invalid('correct is not an option');
    }
    return ParseResult.ok(FakeChoiceContent(ids, correct));
  }

  @override
  FakeChoiceState initialize(FakeChoiceContent content, EngineSeed seed) =>
      FakeChoiceState(order: [...content.optionIds]..shuffle(seed.random()));

  @override
  Transition<FakeChoiceState> reduce(FakeChoiceState s, Pick a) {
    if (!s.order.contains(a.id) ||
        s.locked.contains(a.id) ||
        s.selected == a.id) {
      return Transition(s);
    }
    return Transition(
      FakeChoiceState(order: s.order, selected: a.id, locked: s.locked),
      [
        InteractionEvent('option_selected', {'option_id': a.id}),
      ],
    );
  }

  @override
  SingleChoiceAnswer? extractAnswer(FakeChoiceState s) =>
      s.selected == null ? null : SingleChoiceAnswer(s.selected!);

  @override
  FakeChoiceState applyFeedback(FakeChoiceState s, EvaluationResult r) =>
      r.isCorrect
      ? s
      : FakeChoiceState(
          order: s.order,
          locked: {...s.locked, if (s.selected != null) s.selected!},
        );

  @override
  Map<String, Object?> snapshot(FakeChoiceState s) => {
    'order': s.order,
    'selected': s.selected,
    'locked': s.locked.toList(),
  };

  @override
  FakeChoiceState? restore(
    FakeChoiceContent content,
    Map<String, Object?> snap,
  ) {
    final order = (snap['order'] as List?)?.cast<String>();
    if (order == null) return null;
    return FakeChoiceState(
      order: order,
      selected: snap['selected'] as String?,
      locked: ((snap['locked'] as List?) ?? const []).cast<String>().toSet(),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<FakeChoiceContent, FakeChoiceState, Pick> view,
  ) => Column(
    children: [
      for (final id in view.state.order)
        GestureDetector(
          key: ValueKey('option-$id'),
          onTap: view.enabled ? () => view.dispatch(Pick(id)) : null,
          child: Text(id, textDirection: TextDirection.ltr),
        ),
    ],
  );
}

class FakeExactEvaluator
    implements Evaluator<FakeChoiceContent, SingleChoiceAnswer> {
  FakeExactEvaluator({this.engineKey = 'fake_choice', this.throws = false});

  @override
  final String engineKey;
  final bool throws;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    FakeChoiceContent c,
    SingleChoiceAnswer a,
    EvaluationContext ctx,
  ) {
    if (throws) throw StateError('evaluator bug');
    final ok = a.selectedOptionId == c.correct;
    return EvaluationResult(
      outcome: ok ? Outcome.correct : Outcome.incorrect,
      score: ok ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: 'fake_choice.exact@1',
      skillNodeIds: ctx.skillNodeIds,
    );
  }
}

Map<String, Object?> fakeEnvelope({
  int questions = 2,
  String engineKey = 'fake_choice',
  String contentHash = 'hash-1',
  int version = 1,
  Map<String, Object?>? evaluation,
  String? minAppVersion,
}) => {
  'schema_version': 2,
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': version,
  'content_hash': contentHash,
  'engine_key': engineKey,
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'locale': 'fr-CA',
  'evaluation': ?evaluation,
  'min_app_version': ?minAppVersion,
  'config': {
    'questions': [
      for (var i = 0; i < questions; i++)
        {
          'prompt': {'text': 'Q$i'},
          'config': {
            'options': ['a', 'b', 'c'],
            'correct': 'b',
            'hint': 'Compte sur tes doigts.',
          },
        },
    ],
  },
};
