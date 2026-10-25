import 'answer.dart';

/// What an answer demonstrated. Deliberately more than a boolean: a
/// three-of-four matching is real evidence, and collapsing it to "wrong"
/// throws that evidence away.
enum Outcome {
  correct,
  partial,
  incorrect,

  /// No verdict was possible — the evaluator failed, or the answer type
  /// needs a human (speaking). Never counted as wrong.
  ungraded;

  String get wire => name;
}

/// Who produced the verdict.
///
/// Every result today is [local]: answers ship to the device because offline
/// practice requires them (architecture doc §10 D6). Labelling it now means a
/// server re-evaluation path can be added later without anyone mistaking
/// today's client-graded data for authoritative assessment.
enum EvaluationAuthority { local, server }

/// One diagnostic observation about an answer.
///
/// An observation, never a diagnosis: one wrong answer that matches a known
/// misconception says only "this answer is consistent with X". Turning
/// repeated observations into a learner status is the backend rules
/// engine's job, with thresholds — not the evaluator's.
class ErrorClassification {
  const ErrorClassification({
    required this.code,
    required this.taxonomyVersion,
    this.confidence,
  });

  /// The code an evaluator emits when the answer is wrong but the content
  /// declared no meaning for that wrongness.
  static const unclassifiedCode = 'unclassified';

  const ErrorClassification.unclassified()
    : code = unclassifiedCode,
      taxonomyVersion = 0,
      confidence = null;

  /// Stable code from the backend's error taxonomy, e.g.
  /// `math.add.no_regroup`.
  final String code;
  final int taxonomyVersion;

  /// 0..1 when the evaluator can say how sure it is (speech recognition);
  /// null for a declared distractor, where the content itself is the claim.
  final double? confidence;

  bool get isUnclassified => code == unclassifiedCode;

  Map<String, Object?> toJson() => {
    'code': code,
    'taxonomy_version': taxonomyVersion,
    if (confidence != null) 'confidence': confidence,
  };
}

/// Everything an evaluator needs beyond the content and the answer.
class EvaluationContext {
  const EvaluationContext({
    required this.attemptNumber,
    required this.skillNodeIds,
  });

  /// 1-based.
  final int attemptNumber;

  /// Primary skill first.
  final List<String> skillNodeIds;
}

class EvaluationResult {
  const EvaluationResult({
    required this.outcome,
    required this.score,
    required this.attemptNumber,
    required this.evaluator,
    this.authority = EvaluationAuthority.local,
    this.feedbackCode,
    this.errors = const [],
    this.skillNodeIds = const [],
    this.needsReview = false,
    this.itemResults = const {},
  }) : assert(score >= 0 && score <= 1, 'score is 0..1');

  /// The result recorded when an evaluator throws. The kid did nothing wrong,
  /// so it is ungraded rather than incorrect, and flagged for review so the
  /// bad content gets found.
  const EvaluationResult.failed({
    required this.attemptNumber,
    required this.evaluator,
    this.skillNodeIds = const [],
  }) : outcome = Outcome.ungraded,
       score = 0,
       authority = EvaluationAuthority.local,
       feedbackCode = null,
       errors = const [],
       needsReview = true,
       itemResults = const {};

  final Outcome outcome;

  /// 0..1. Partial credit lives here; `outcome` stays the categorical verdict.
  final double score;
  final int attemptNumber;

  /// `<engine>.<policy>@<version>`, e.g. `mcq.exact@1`. Stored with every
  /// attempt so a scoring change never silently reinterprets old data.
  final String evaluator;
  final EvaluationAuthority authority;

  /// Selects the feedback copy the shell shows. Null means the generic
  /// right/wrong message.
  final String? feedbackCode;
  final List<ErrorClassification> errors;
  final List<String> skillNodeIds;
  final bool needsReview;

  /// Per-part verdicts for an answer with parts — a pair, a slot — keyed by
  /// the part's id. It's how partial credit becomes visible: the engine
  /// locks the parts that were right and clears the rest for the retry,
  /// without ever grading anything itself.
  final Map<String, bool> itemResults;

  bool get isCorrect => outcome == Outcome.correct;

  Map<String, Object?> toJson() => {
    'outcome': outcome.wire,
    'score': score,
    'attempt_number': attemptNumber,
    'evaluator': evaluator,
    'authority': authority.name,
    if (feedbackCode != null) 'feedback_code': feedbackCode,
    'errors': [for (final e in errors) e.toJson()],
    'skill_node_ids': skillNodeIds,
    if (needsReview) 'needs_review': true,
    if (itemResults.isNotEmpty) 'items': itemResults,
  };
}

/// Judges an answer against content. Pure: same inputs, same result.
///
/// Kept apart from engines on purpose. An engine knows how a child interacts
/// with a question; it must not know what a wrong answer *means* in
/// mathematics or French. Subject-specific diagnosis arrives as data on the
/// content (an option's declared `diagnosis`) and an evaluator copies it
/// through.
abstract interface class Evaluator<C, Ans extends AnswerValue> {
  /// Engine key this evaluator grades for.
  String get engineKey;

  /// The envelope's `evaluation.policy` it implements, e.g. `exact`.
  String get policy;
  int get version;

  EvaluationResult evaluate(C content, Ans answer, EvaluationContext context);
}

extension EvaluatorId on Evaluator<Object?, AnswerValue> {
  String get id => '$engineKey.$policy@$version';
}

/// Resolves an evaluator by engine key + policy.
class EvaluatorRegistry {
  EvaluatorRegistry(Iterable<Evaluator<Object?, AnswerValue>> evaluators)
    : _byKey = {} {
    for (final e in evaluators) {
      final k = _key(e.engineKey, e.policy);
      if (_byKey.containsKey(k)) {
        throw ArgumentError('Duplicate evaluator for $k');
      }
      _byKey[k] = e;
    }
  }

  final Map<String, Evaluator<Object?, AnswerValue>> _byKey;

  static String _key(String engineKey, String policy) => '$engineKey/$policy';

  Evaluator<Object?, AnswerValue>? lookup(String engineKey, String policy) =>
      _byKey[_key(engineKey, policy)];
}
