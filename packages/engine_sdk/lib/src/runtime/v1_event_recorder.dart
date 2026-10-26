import 'package:uuid/uuid.dart';

import '../contracts/evaluation.dart';
import '../telemetry.dart';
import 'runtime_event.dart';
import 'session_ids.dart';

/// Turns runtime events into wire events for the outbox.
///
/// Stateful (per-question tallies), but the state is plain data that rides
/// in the session snapshot — so the summary written after a resume still
/// covers the whole question.
abstract interface class RuntimeEventRecorder {
  /// Wire events for [event]; empty when this format has nowhere to put it.
  List<Map<String, Object?>> record(RuntimeEvent event, RecorderFrame frame);

  Map<String, Object?> get state;

  void restore(Map<String, Object?>? state);

  /// Durable events this format could not carry, since construction. A
  /// health counter, so the gap stays visible until telemetry v2 lands.
  int get unrecordedCount;
}

/// Everything about "now" the recorder needs, supplied by the controller.
class RecorderFrame {
  const RecorderFrame({
    required this.now,
    required this.activeMs,
    required this.identity,
    this.contentHash,
  });

  /// Wall clock, for `event_ts` only.
  final DateTime now;

  /// Pause-excluded active time since the session began. Every duration the
  /// recorder writes is derived from this, never from wall-clock deltas, so
  /// time spent paused or backgrounded is not reported as answer time.
  final int activeMs;

  /// The current question's identity.
  final ExerciseIdentity identity;

  /// The envelope's content hash, for v2's `content_hash`. v1 has no field
  /// for it and ignores it.
  final String? contentHash;
}

/// Records against `play_event.v1` — what telemetry accepts today.
///
/// v1 has seven event types, so this keeps exactly the subset the existing
/// aggregates, mastery, XP and streaks read, with their v1 meaning:
///
/// | runtime event | v1 event |
/// |---|---|
/// | first `QuestionPresented` | `session_start` + `exercise_start` |
/// | later `QuestionPresented` | `exercise_start` |
/// | `AnswerEvaluated` (graded) | `attempt` |
/// | `HintRequested` | `hint_used` |
/// | `QuestionCompleted` | `exercise_complete` (summary from the tallies) |
/// | `ActivityAbandoned` | `exercise_abandon` (always, once started) + `session_end` |
/// | `ActivityCompleted` | `session_end` |
///
/// Everything else durable — selections, audio requests, pauses — has no v1
/// type and is counted in [unrecordedCount] instead. It is still published
/// in-process (the director and audio see it); it just isn't stored until
/// telemetry's v2 schema lands (architecture doc §6, LE-T1).
///
/// An **ungraded** attempt (the evaluator failed) is not written as an
/// `attempt`: v1 requires `is_correct`, and recording a system failure as a
/// wrong answer would lower the child's mastery for our bug.
///
/// Every `event_id` is derived from [SessionIds], so the same step always
/// yields the same ids.
class V1EventRecorder implements RuntimeEventRecorder {
  V1EventRecorder({required this.ids, required this.appVersion});

  final SessionIds ids;
  final String appVersion;

  static const _uuid = Uuid();

  // Per-question tallies, reset by each QuestionPresented.
  int? _questionIndex;
  int _runStartActiveMs = 0;
  int? _prevEventActiveMs;
  int _attempts = 0;
  int _correct = 0;
  int _hints = 0;
  final Map<String, int> _wrongCounts = {};
  Map<String, Object?>? _lastAnswer;
  bool _sessionStarted = false;
  int _unrecorded = 0;

  /// The identity the open run started with. Every later event of that run
  /// reuses it, so a run closed from a stale snapshot — when the engine or
  /// exercise version may have changed since — still describes the run that
  /// actually happened.
  ExerciseIdentity? _runIdentity;

  @override
  int get unrecordedCount => _unrecorded;

  String get _sessionId => ids.activitySessionId;

  String? get _runId =>
      _questionIndex == null ? null : ids.exerciseRunId(_questionIndex!);

  @override
  List<Map<String, Object?>> record(RuntimeEvent event, RecorderFrame f) {
    switch (event) {
      case QuestionPresented(:final questionIndex):
        final out = <Map<String, Object?>>[];
        if (!_sessionStarted) {
          _sessionStarted = true;
          out.add(_sessionEvent(PlayEventType.sessionStart, f));
        }
        _questionIndex = questionIndex;
        _runIdentity = f.identity;
        _runStartActiveMs = f.activeMs;
        _prevEventActiveMs = null;
        _attempts = 0;
        _correct = 0;
        _hints = 0;
        _wrongCounts.clear();
        _lastAnswer = null;
        out.add(_runEvent(PlayEventType.exerciseStart, f, idName: 'start'));
        return out;

      case AnswerSubmitted(:final answer):
        // No v1 type of its own; its answer rides on the `attempt` that the
        // verdict produces.
        _lastAnswer = answer.toJson();
        _unrecorded++;
        return const [];

      case AnswerEvaluated(:final questionIndex, :final result):
        if (result.outcome == Outcome.ungraded || _runId == null) {
          return const [];
        }
        final answer = _lastAnswer ?? const <String, Object?>{};
        final hash = TelemetryClient.hashAnswer(answer);
        _attempts += 1;
        if (result.isCorrect) {
          _correct += 1;
        } else {
          _wrongCounts.update(hash, (n) => n + 1, ifAbsent: () => 1);
        }
        return [
          _runEvent(
            PlayEventType.attempt,
            f,
            eventId: ids.attemptEventId(questionIndex, result.attemptNumber),
            attemptIndex: result.attemptNumber,
            answerPayload: answer,
            answerHash: hash,
            isCorrect: result.isCorrect,
          ),
        ];

      case HintRequested(:final hintIndex):
        if (_runId == null) return const [];
        _hints += 1;
        return [
          _runEvent(
            PlayEventType.hintUsed,
            f,
            idName: 'hint:$hintIndex',
            hintIndex: hintIndex + 1,
          ),
        ];

      case QuestionCompleted():
        if (_runId == null) return const [];
        final summary = ExerciseSummary(
          attempts: _attempts,
          correct: _correct,
          totalMs: f.activeMs - _runStartActiveMs,
          distinctWrongAnswers: _wrongCounts.length,
          maxRepeatOfSameWrongAnswer: _wrongCounts.values.isEmpty
              ? 0
              : _wrongCounts.values.reduce((a, b) => a > b ? a : b),
          hintsUsed: _hints,
        );
        final out = [
          _runEvent(
            PlayEventType.exerciseComplete,
            f,
            idName: 'complete',
            summary: summary,
          ),
        ];
        _questionIndex = null;
        _runIdentity = null;
        return out;

      case ActivityAbandoned(:final questionIndex):
        final out = <Map<String, Object?>>[];
        if (_runId == null && _sessionStarted) {
          // No question open (left between two): the abandon still goes
          // out, on the question the kid would have seen next. Alone, a
          // session_end reads as a finished lesson (telemetry ADR 0017).
          _questionIndex = questionIndex;
          _runIdentity = f.identity;
          _runStartActiveMs = f.activeMs;
          _prevEventActiveMs = null;
        }
        if (_runId != null) {
          out.add(
            _runEvent(PlayEventType.exerciseAbandon, f, idName: 'abandon'),
          );
          _questionIndex = null;
          _runIdentity = null;
        }
        if (_sessionStarted) {
          out.add(_sessionEvent(PlayEventType.sessionEnd, f));
        }
        return out;

      case ActivityCompleted():
        return [_sessionEvent(PlayEventType.sessionEnd, f)];

      case _:
        if (event.category.isDurable) _unrecorded++;
        return const [];
    }
  }

  Map<String, Object?> _sessionEvent(PlayEventType type, RecorderFrame f) =>
      buildV1Event(
        eventId: _uuid.v5(_sessionId, type.wire),
        eventTs: f.now,
        sessionId: _sessionId,
        type: type,
        appVersion: appVersion,
      );

  Map<String, Object?> _runEvent(
    PlayEventType type,
    RecorderFrame f, {
    String? idName,
    String? eventId,
    int? attemptIndex,
    Map<String, Object?>? answerPayload,
    String? answerHash,
    bool? isCorrect,
    int? hintIndex,
    ExerciseSummary? summary,
  }) {
    final runId = _runId!;
    final sincePrev = _prevEventActiveMs == null
        ? null
        : f.activeMs - _prevEventActiveMs!;
    _prevEventActiveMs = f.activeMs;
    return buildV1Event(
      eventId: eventId ?? _uuid.v5(runId, idName!),
      eventTs: f.now,
      sessionId: _sessionId,
      type: type,
      appVersion: appVersion,
      runId: runId,
      identity: _runIdentity ?? f.identity,
      attemptIndex: attemptIndex,
      answerPayload: answerPayload,
      answerHash: answerHash,
      isCorrect: isCorrect,
      hintIndex: hintIndex,
      summary: summary,
      msSinceRunStart: f.activeMs - _runStartActiveMs,
      msSincePrevEvent: sincePrev,
    );
  }

  @override
  Map<String, Object?> get state => {
    'question_index': _questionIndex,
    'run_start_active_ms': _runStartActiveMs,
    'prev_event_active_ms': _prevEventActiveMs,
    'attempts': _attempts,
    'correct': _correct,
    'hints': _hints,
    'wrong_counts': Map<String, int>.of(_wrongCounts),
    'last_answer': _lastAnswer,
    'session_started': _sessionStarted,
    'run_identity': _runIdentity == null
        ? null
        : _identityToJson(_runIdentity!),
  };

  static Map<String, Object?> _identityToJson(ExerciseIdentity i) => {
    'exercise_id': i.exerciseId,
    'exercise_version': i.exerciseVersion,
    'engine_key': i.engineKey,
    'engine_version': i.engineVersion,
    'skill_node_id': i.skillNodeId,
    'subject': i.subject,
    'grade': i.grade,
    'rank': i.rank,
  };

  static ExerciseIdentity? _identityFromJson(Map<String, Object?>? j) =>
      j == null
      ? null
      : ExerciseIdentity(
          exerciseId: j['exercise_id'] as String,
          exerciseVersion: j['exercise_version'] as int,
          engineKey: j['engine_key'] as String,
          engineVersion: j['engine_version'] as int,
          skillNodeId: j['skill_node_id'] as String,
          subject: j['subject'] as String,
          grade: j['grade'] as int,
          rank: j['rank'] as int,
        );

  @override
  void restore(Map<String, Object?>? s) {
    if (s == null) return;
    try {
      _questionIndex = s['question_index'] as int?;
      _runStartActiveMs = s['run_start_active_ms'] as int;
      _prevEventActiveMs = s['prev_event_active_ms'] as int?;
      _attempts = s['attempts'] as int;
      _correct = s['correct'] as int;
      _hints = s['hints'] as int;
      _wrongCounts
        ..clear()
        ..addAll((s['wrong_counts'] as Map).cast<String, int>());
      final last = s['last_answer'] as Map?;
      _lastAnswer = last?.cast<String, Object?>();
      _sessionStarted = s['session_started'] as bool;
      _runIdentity = _identityFromJson(
        (s['run_identity'] as Map?)?.cast<String, Object?>(),
      );
    } on Object {
      // A tally we can't read only costs summary accuracy, never an event:
      // start the tallies fresh rather than refusing to resume.
      _wrongCounts.clear();
    }
  }
}
