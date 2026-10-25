import '../contracts/answer.dart';
import '../contracts/evaluation.dart';

/// Which stream an event belongs to, and therefore how durable it must be.
///
/// The split exists so one event can feed analytics, animation and audio
/// without technical noise reaching the learning record (brief §16):
/// `learning` and `interaction` go to the durable outbox; the diagnostic
/// categories never do.
enum EventCategory {
  learning,
  interaction,
  accessibility,
  runtimeDiagnostic,
  animationDiagnostic,
  syncDiagnostic;

  /// Whether events in this category must reach telemetry. A failed
  /// animation must never cost a learning event, and an animation event
  /// must never pollute the learning record.
  bool get isDurable => switch (this) {
    learning || interaction || accessibility => true,
    runtimeDiagnostic || animationDiagnostic || syncDiagnostic => false,
  };

  String get wire => switch (this) {
    learning => 'learning',
    interaction => 'interaction',
    accessibility => 'accessibility',
    runtimeDiagnostic => 'runtime_diagnostic',
    animationDiagnostic => 'animation_diagnostic',
    syncDiagnostic => 'sync_diagnostic',
  };
}

/// A semantic fact about an activity session.
///
/// Carries no event id, timestamp or elapsed time: those are stamped by the
/// recorder that persists it, which keeps the session machine and every
/// engine pure. Subscribers — telemetry, the animation director, the audio
/// coordinator — all see the same instance.
sealed class RuntimeEvent {
  const RuntimeEvent();

  EventCategory get category;

  /// Wire name. Learning events reuse the v1 telemetry names where one
  /// exists (`attempt`, `exercise_complete`) so every existing aggregate
  /// keeps its meaning (doc §6).
  String get type;

  /// Ids and numbers only — never stems or labels.
  Map<String, Object?> get payload;
}

// ── learning ────────────────────────────────────────────────────────────────

class QuestionPresented extends RuntimeEvent {
  const QuestionPresented({
    required this.questionIndex,
    required this.questionCount,
  });
  final int questionIndex;
  final int questionCount;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'question_presented';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'question_count': questionCount,
  };
}

class AnswerSubmitted extends RuntimeEvent {
  const AnswerSubmitted({
    required this.questionIndex,
    required this.attemptNumber,
    required this.answer,
  });
  final int questionIndex;
  final int attemptNumber;
  final AnswerValue answer;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'answer_submitted';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'attempt_number': attemptNumber,
    'answer': answer.toJson(),
  };
}

/// The verdict on an attempt. Persisted as v1's `attempt` event, which is
/// what `kid_skill_daily`, mastery and XP already read.
class AnswerEvaluated extends RuntimeEvent {
  const AnswerEvaluated({required this.questionIndex, required this.result});
  final int questionIndex;
  final EvaluationResult result;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'attempt';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'evaluation': result.toJson(),
  };
}

class QuestionCompleted extends RuntimeEvent {
  const QuestionCompleted({
    required this.questionIndex,
    required this.attempts,
    required this.solved,
  });
  final int questionIndex;
  final int attempts;

  /// False when the attempt cap ran out, or evaluation failed.
  final bool solved;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'exercise_complete';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'attempts': attempts,
    'solved': solved,
  };
}

class ActivityCompleted extends RuntimeEvent {
  const ActivityCompleted({
    required this.questionsCompleted,
    required this.questionsSolved,
  });
  final int questionsCompleted;
  final int questionsSolved;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'activity_completed';
  @override
  Map<String, Object?> get payload => {
    'questions_completed': questionsCompleted,
    'questions_solved': questionsSolved,
  };
}

class ActivityAbandoned extends RuntimeEvent {
  const ActivityAbandoned({required this.questionIndex, required this.reason});
  final int questionIndex;
  final AbandonReason reason;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'exercise_abandon';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'reason': reason.name,
  };
}

enum AbandonReason { exited, staleResume, declinedResume }

class SessionPaused extends RuntimeEvent {
  const SessionPaused();
  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'session_paused';
  @override
  Map<String, Object?> get payload => const {};
}

class SessionResumed extends RuntimeEvent {
  const SessionResumed({required this.afterInterruption});

  /// True when resuming a session the app died in, not a user pause.
  final bool afterInterruption;

  @override
  EventCategory get category => EventCategory.learning;
  @override
  String get type => 'session_resumed';
  @override
  Map<String, Object?> get payload => {'after_interruption': afterInterruption};
}

// ── interaction ─────────────────────────────────────────────────────────────

/// An engine-reported state change: `option_selected`, `pair_connected`,
/// `tile_moved`… Engines choose the type from a documented vocabulary; the
/// payload is ids and indexes only.
class InteractionEvent extends RuntimeEvent {
  const InteractionEvent(this.type, [this.payload = const {}]);

  @override
  final String type;
  @override
  final Map<String, Object?> payload;

  @override
  EventCategory get category => EventCategory.interaction;
}

class HintRequested extends RuntimeEvent {
  const HintRequested({required this.questionIndex, required this.hintIndex});
  final int questionIndex;
  final int hintIndex;

  @override
  EventCategory get category => EventCategory.interaction;
  @override
  String get type => 'hint_used';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'hint_index': hintIndex,
  };
}

/// Which part of a question a speaker button belongs to.
enum SpeechPart { prompt, option, feedback }

class AudioRequested extends RuntimeEvent {
  const AudioRequested({
    required this.questionIndex,
    required this.part,
    required this.replay,
    this.partId,
  });
  final int questionIndex;
  final SpeechPart part;

  /// Option id when [part] is an option.
  final String? partId;

  /// Not the first play of this part in this question. Replays are an
  /// assistance signal, never a penalty (brief §20).
  final bool replay;

  @override
  EventCategory get category => EventCategory.interaction;
  @override
  String get type => replay ? 'audio_replayed' : 'audio_requested';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'part': part.name,
    if (partId != null) 'part_id': partId,
  };
}

// ── diagnostics (never persisted to telemetry) ──────────────────────────────

class SessionFailed extends RuntimeEvent {
  const SessionFailed(this.reason);
  final String reason;

  @override
  EventCategory get category => EventCategory.runtimeDiagnostic;
  @override
  String get type => 'session_failed';
  @override
  Map<String, Object?> get payload => {'reason': reason};
}

class EvaluationFailedDiagnostic extends RuntimeEvent {
  const EvaluationFailedDiagnostic({
    required this.questionIndex,
    required this.reason,
  });
  final int questionIndex;
  final String reason;

  @override
  EventCategory get category => EventCategory.runtimeDiagnostic;
  @override
  String get type => 'evaluation_failed';
  @override
  Map<String, Object?> get payload => {
    'question_index': questionIndex,
    'reason': reason,
  };
}

/// Emitted by renderers and the animation director. Lives here, not in the
/// motion package, so a single stream type serves every subscriber.
class AnimationDiagnostic extends RuntimeEvent {
  const AnimationDiagnostic(this.type, [this.payload = const {}]);

  @override
  final String type;
  @override
  final Map<String, Object?> payload;

  @override
  EventCategory get category => EventCategory.animationDiagnostic;
}
