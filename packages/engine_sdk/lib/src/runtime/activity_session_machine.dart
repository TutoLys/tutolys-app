import '../contracts/answer.dart';
import '../contracts/evaluation.dart';
import 'runtime_event.dart';

/// The lifecycle of one activity session, as a pure reducer.
///
/// ```
/// created → loading → ready → presenting → awaitingInteraction
///   → evaluating → feedback ─┬─ retry ──────────► awaitingInteraction
///                            ├─ next question ──► presenting
///                            └─ last question ──► completed
/// presenting│awaiting│evaluating│feedback ─pause─► paused ─resume─► (same)
/// any live state ─interrupt─► interrupted ─resume─► (same)   [app died]
/// any live state ─abandon─► abandoned        created│loading│ready ─fail─► failed
/// ```
///
/// No I/O, no clock, no ids: the controller that drives it persists events
/// and snapshots. An input that makes no sense in the current phase — a
/// second submit while evaluating, a resume while playing — is *rejected*
/// (state unchanged, no events), never an exception. That is what makes a
/// double tap, or a duplicate input replayed after a crash, harmless.
enum SessionPhase {
  created,
  loading,
  ready,
  presenting,
  awaitingInteraction,
  evaluating,
  feedback,
  paused,
  interrupted,
  completed,
  failed,
  abandoned;

  bool get isTerminal => this == completed || this == failed || this == abandoned;

  /// Phases a learner can pause in.
  bool get isPlaying =>
      this == presenting || this == awaitingInteraction || this == evaluating || this == feedback;
}

class SessionState {
  const SessionState({
    this.phase = SessionPhase.created,
    this.questionIndex = 0,
    this.questionCount = 0,
    this.attempts = 0,
    this.maxAttempts,
    this.lastOutcome,
    this.pendingAnswer,
    this.resumeTo,
    this.questionsCompleted = 0,
    this.questionsSolved = 0,
    this.failureReason,
  });

  static const initial = SessionState();

  final SessionPhase phase;
  final int questionIndex;
  final int questionCount;

  /// Attempts made on the current question.
  final int attempts;

  /// Null = retry until correct.
  final int? maxAttempts;

  /// Verdict shown in [SessionPhase.feedback].
  final Outcome? lastOutcome;

  /// The answer being evaluated. Kept in state, and so in the snapshot, so a
  /// crash during evaluation resumes by re-evaluating the *same* attempt —
  /// same attempt number, same event id — rather than asking again.
  final AnswerValue? pendingAnswer;

  /// Where [SessionPhase.paused] / [SessionPhase.interrupted] return to.
  final SessionPhase? resumeTo;

  final int questionsCompleted;
  final int questionsSolved;
  final String? failureReason;

  bool get canRetry {
    final outcome = lastOutcome;
    if (outcome != Outcome.incorrect && outcome != Outcome.partial) return false;
    final max = maxAttempts;
    return max == null || attempts < max;
  }

  SessionState copyWith({
    SessionPhase? phase,
    int? questionIndex,
    int? questionCount,
    int? attempts,
    int? maxAttempts,
    Outcome? lastOutcome,
    bool clearLastOutcome = false,
    AnswerValue? pendingAnswer,
    bool clearPendingAnswer = false,
    SessionPhase? resumeTo,
    bool clearResumeTo = false,
    int? questionsCompleted,
    int? questionsSolved,
    String? failureReason,
  }) => SessionState(
    phase: phase ?? this.phase,
    questionIndex: questionIndex ?? this.questionIndex,
    questionCount: questionCount ?? this.questionCount,
    attempts: attempts ?? this.attempts,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    lastOutcome: clearLastOutcome ? null : (lastOutcome ?? this.lastOutcome),
    pendingAnswer: clearPendingAnswer ? null : (pendingAnswer ?? this.pendingAnswer),
    resumeTo: clearResumeTo ? null : (resumeTo ?? this.resumeTo),
    questionsCompleted: questionsCompleted ?? this.questionsCompleted,
    questionsSolved: questionsSolved ?? this.questionsSolved,
    failureReason: failureReason ?? this.failureReason,
  );

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'question_index': questionIndex,
    'question_count': questionCount,
    'attempts': attempts,
    'max_attempts': maxAttempts,
    'last_outcome': lastOutcome?.name,
    'pending_answer': pendingAnswer?.toJson(),
    'resume_to': resumeTo?.name,
    'questions_completed': questionsCompleted,
    'questions_solved': questionsSolved,
    'failure_reason': failureReason,
  };

  /// Null if the snapshot can't be trusted; the caller then abandons the
  /// stored session rather than resuming into a guessed state.
  static SessionState? fromJson(Map<String, Object?> json) {
    try {
      SessionPhase? phaseOf(Object? v) =>
          v == null ? null : SessionPhase.values.byName(v as String);
      final pending = json['pending_answer'] as Map?;
      final outcome = json['last_outcome'] as String?;
      final state = SessionState(
        phase: phaseOf(json['phase'])!,
        questionIndex: json['question_index'] as int,
        questionCount: json['question_count'] as int,
        attempts: json['attempts'] as int,
        maxAttempts: json['max_attempts'] as int?,
        lastOutcome: outcome == null ? null : Outcome.values.byName(outcome),
        pendingAnswer: pending == null
            ? null
            : AnswerValue.fromJson(pending.cast<String, Object?>()),
        resumeTo: phaseOf(json['resume_to']),
        questionsCompleted: json['questions_completed'] as int,
        questionsSolved: json['questions_solved'] as int,
        failureReason: json['failure_reason'] as String?,
      );
      if (pending != null && state.pendingAnswer == null) return null;
      if (state.questionIndex < 0 || state.questionIndex > state.questionCount) return null;
      return state;
    } on Object {
      return null;
    }
  }
}

sealed class SessionInput {
  const SessionInput();
}

class StartLoading extends SessionInput {
  const StartLoading();
}

class ContentLoaded extends SessionInput {
  const ContentLoaded({required this.questionCount, this.maxAttempts});
  final int questionCount;
  final int? maxAttempts;
}

class Begin extends SessionInput {
  const Begin();
}

/// The shell has shown the question (and its auto-read has been requested).
class QuestionShown extends SessionInput {
  const QuestionShown();
}

class Submit extends SessionInput {
  const Submit(this.answer);
  final AnswerValue answer;
}

class Evaluated extends SessionInput {
  const Evaluated(this.result);
  final EvaluationResult result;
}

class EvaluationFailed extends SessionInput {
  const EvaluationFailed({required this.reason, required this.evaluator, this.skillNodeIds = const []});
  final String reason;
  final String evaluator;
  final List<String> skillNodeIds;
}

/// Leave feedback: retry, next question, or finish — the machine decides.
class Continue extends SessionInput {
  const Continue();
}

class Pause extends SessionInput {
  const Pause();
}

class Resume extends SessionInput {
  const Resume();
}

/// Applied at launch to a stored, non-terminal snapshot: the app died.
class Interrupt extends SessionInput {
  const Interrupt();
}

class Abandon extends SessionInput {
  const Abandon([this.reason = AbandonReason.exited]);
  final AbandonReason reason;
}

class Fail extends SessionInput {
  const Fail(this.reason);
  final String reason;
}

class SessionStep {
  const SessionStep(this.state, this.events, {this.accepted = true});
  const SessionStep.rejected(this.state) : events = const [], accepted = false;

  final SessionState state;
  final List<RuntimeEvent> events;

  /// False when the input was meaningless in the current phase.
  final bool accepted;
}

abstract final class ActivitySessionMachine {
  static SessionStep reduce(SessionState s, SessionInput input) {
    if (s.phase.isTerminal) return SessionStep.rejected(s);

    return switch ((s.phase, input)) {
      (SessionPhase.created, StartLoading()) =>
        SessionStep(s.copyWith(phase: SessionPhase.loading), const []),

      (SessionPhase.loading, ContentLoaded(:final questionCount, :final maxAttempts)) =>
        questionCount < 1
            ? _fail(s, 'Activity has no questions.')
            : SessionStep(
                s.copyWith(
                  phase: SessionPhase.ready,
                  questionCount: questionCount,
                  maxAttempts: maxAttempts,
                ),
                const [],
              ),

      (SessionPhase.ready, Begin()) => SessionStep(
        s.copyWith(phase: SessionPhase.presenting, questionIndex: 0, attempts: 0),
        [QuestionPresented(questionIndex: 0, questionCount: s.questionCount)],
      ),

      (SessionPhase.presenting, QuestionShown()) =>
        SessionStep(s.copyWith(phase: SessionPhase.awaitingInteraction), const []),

      (SessionPhase.awaitingInteraction, Submit(:final answer)) => SessionStep(
        s.copyWith(
          phase: SessionPhase.evaluating,
          attempts: s.attempts + 1,
          pendingAnswer: answer,
        ),
        [
          AnswerSubmitted(
            questionIndex: s.questionIndex,
            attemptNumber: s.attempts + 1,
            answer: answer,
          ),
        ],
      ),

      (SessionPhase.evaluating, Evaluated(:final result)) =>
        // A verdict for a different attempt is stale (a slow evaluation
        // overtaken by a resume) and must not be recorded twice.
        result.attemptNumber != s.attempts
            ? SessionStep.rejected(s)
            : SessionStep(
                s.copyWith(
                  phase: SessionPhase.feedback,
                  lastOutcome: result.outcome,
                  clearPendingAnswer: true,
                ),
                [AnswerEvaluated(questionIndex: s.questionIndex, result: result)],
              ),

      (SessionPhase.evaluating, EvaluationFailed(:final reason, :final evaluator, :final skillNodeIds)) =>
        SessionStep(
          s.copyWith(
            phase: SessionPhase.feedback,
            lastOutcome: Outcome.ungraded,
            clearPendingAnswer: true,
          ),
          [
            AnswerEvaluated(
              questionIndex: s.questionIndex,
              result: EvaluationResult.failed(
                attemptNumber: s.attempts,
                evaluator: evaluator,
                skillNodeIds: skillNodeIds,
              ),
            ),
            EvaluationFailedDiagnostic(questionIndex: s.questionIndex, reason: reason),
          ],
        ),

      (SessionPhase.feedback, Continue()) => _continue(s),

      (final phase, Pause()) when phase.isPlaying => SessionStep(
        s.copyWith(phase: SessionPhase.paused, resumeTo: phase),
        const [SessionPaused()],
      ),

      (SessionPhase.paused, Resume()) => SessionStep(
        s.copyWith(phase: s.resumeTo, clearResumeTo: true),
        const [SessionResumed(afterInterruption: false)],
      ),

      (final phase, Interrupt()) when phase != SessionPhase.created && phase != SessionPhase.interrupted =>
        SessionStep(
          s.copyWith(
            phase: SessionPhase.interrupted,
            // A session that died while paused resumes into the phase the
            // pause was holding. The shell asks "continue?" after a crash
            // anyway, so a second pause screen would only be in the way.
            resumeTo: phase == SessionPhase.paused ? s.resumeTo : phase,
          ),
          const [],
        ),

      (SessionPhase.interrupted, Resume()) => SessionStep(
        s.copyWith(phase: s.resumeTo, clearResumeTo: true),
        const [SessionResumed(afterInterruption: true)],
      ),

      (_, Abandon(:final reason)) => SessionStep(
        s.copyWith(phase: SessionPhase.abandoned),
        [ActivityAbandoned(questionIndex: s.questionIndex, reason: reason)],
      ),

      (SessionPhase.created || SessionPhase.loading || SessionPhase.ready, Fail(:final reason)) =>
        _fail(s, reason),

      _ => SessionStep.rejected(s),
    };
  }

  static SessionStep _fail(SessionState s, String reason) => SessionStep(
    s.copyWith(phase: SessionPhase.failed, failureReason: reason),
    [SessionFailed(reason)],
  );

  static SessionStep _continue(SessionState s) {
    if (s.canRetry) {
      return SessionStep(
        s.copyWith(phase: SessionPhase.awaitingInteraction, clearLastOutcome: true),
        const [],
      );
    }

    final solved = s.lastOutcome == Outcome.correct;
    final completed = QuestionCompleted(
      questionIndex: s.questionIndex,
      attempts: s.attempts,
      solved: solved,
    );
    final done = s.questionsCompleted + 1;
    final solvedCount = s.questionsSolved + (solved ? 1 : 0);
    final next = s.questionIndex + 1;

    if (next >= s.questionCount) {
      return SessionStep(
        s.copyWith(
          phase: SessionPhase.completed,
          questionIndex: next,
          questionsCompleted: done,
          questionsSolved: solvedCount,
          clearLastOutcome: true,
        ),
        [
          completed,
          ActivityCompleted(questionsCompleted: done, questionsSolved: solvedCount),
        ],
      );
    }

    return SessionStep(
      s.copyWith(
        phase: SessionPhase.presenting,
        questionIndex: next,
        attempts: 0,
        questionsCompleted: done,
        questionsSolved: solvedCount,
        clearLastOutcome: true,
      ),
      [
        completed,
        QuestionPresented(questionIndex: next, questionCount: s.questionCount),
      ],
    );
  }
}
