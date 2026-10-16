import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'outbox.dart';

/// Event types. Must match `play_event.v1.json` exactly.
enum PlayEventType {
  sessionStart('session_start'),
  exerciseStart('exercise_start'),
  attempt('attempt'),
  hintUsed('hint_used'),
  exerciseComplete('exercise_complete'),
  exerciseAbandon('exercise_abandon'),
  sessionEnd('session_end');

  const PlayEventType(this.wire);
  final String wire;
}

/// What the engine was asked to render, and where it sits in the curriculum.
class ExerciseIdentity {
  const ExerciseIdentity({
    required this.exerciseId,
    required this.exerciseVersion,
    required this.engineKey,
    required this.engineVersion,
    required this.skillNodeId,
    required this.subject,
    required this.grade,
    required this.rank,
  });

  final String exerciseId;
  final int exerciseVersion;
  final String engineKey;
  final int engineVersion;

  /// The curriculum leaf. Without it the play cannot appear in a report, which
  /// is why the server rejects exercise events that omit it.
  final String skillNodeId;

  final String subject;
  final int grade;
  final int rank;
}

/// Summary carried by `exercise_complete`.
class ExerciseSummary {
  const ExerciseSummary({
    required this.attempts,
    required this.correct,
    required this.totalMs,
    required this.distinctWrongAnswers,
    required this.maxRepeatOfSameWrongAnswer,
    this.hintsUsed = 0,
  });

  final int attempts;
  final int correct;
  final int totalMs;

  /// How many *different* wrong answers were tried.
  final int distinctWrongAnswers;

  /// How many times the single most-repeated wrong answer was given.
  ///
  /// The signal the plan cares about: repeating one wrong answer suggests a
  /// firm misconception, while trying several suggests guessing. A plain
  /// attempt count cannot tell those apart.
  final int maxRepeatOfSameWrongAnswer;

  final int hintsUsed;

  Map<String, Object?> toJson() => {
        'attempts': attempts,
        'correct': correct,
        'total_ms': totalMs,
        'distinct_wrong_answers': distinctWrongAnswers,
        'max_repeat_of_same_wrong_answer': maxRepeatOfSameWrongAnswer,
        'hints_used': hintsUsed,
      };
}

/// Stamps and writes play events.
///
/// Engines cannot write events any other way: they call `logAttempt`, and this
/// class supplies every id, timestamp, delta and hash. That is deliberate —
/// if each engine assembled its own events, the log shape would drift between
/// engines and the analytics would quietly stop comparing like with like. One
/// standard shape across all engines is a LOCKED decision in the plan.
class TelemetryClient {
  TelemetryClient({
    required this.outbox,
    required this.sessionId,
    required this.appVersion,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _uuid = uuid ?? const Uuid(),
        _now = clock ?? DateTime.now;

  /// The durable write target. Public only because Dart forbids private named
  /// parameters; nothing outside this class should write to it directly.
  final EventOutbox outbox;
  final Uuid _uuid;
  final DateTime Function() _now;

  final String sessionId;
  final String appVersion;

  static const schemaVersion = 1;

  // --- per-run state ----------------------------------------------------

  String? _runId;
  ExerciseIdentity? _identity;
  DateTime? _runStartedAt;
  DateTime? _previousEventAt;
  int _attemptIndex = 0;
  int _hintIndex = 0;

  /// Wrong-answer hashes seen in the current run, and how often.
  ///
  /// Tracked here rather than asked of the engine, so every engine reports the
  /// repeated-wrong-answer signal identically.
  final Map<String, int> _wrongAnswerCounts = {};

  int _correctCount = 0;

  String? get currentRunId => _runId;

  // --- session ----------------------------------------------------------

  Future<void> logSessionStart() => _write(PlayEventType.sessionStart);

  Future<void> logSessionEnd() => _write(PlayEventType.sessionEnd);

  // --- exercise run -----------------------------------------------------

  /// Begin a run. Resets all per-run counters.
  Future<void> startExercise(ExerciseIdentity identity) async {
    _runId = _uuid.v4();
    _identity = identity;
    _runStartedAt = _now();
    _attemptIndex = 0;
    _hintIndex = 0;
    _correctCount = 0;
    _wrongAnswerCounts.clear();

    await _write(PlayEventType.exerciseStart);
  }

  /// Record one attempt.
  ///
  /// [answer] is the normalized answer — ids, never display text — so that
  /// analysis never depends on wording or locale. The hash is computed here so
  /// it is stable across engines and across app versions.
  Future<void> logAttempt({
    required Map<String, Object?> answer,
    required bool isCorrect,
  }) async {
    _requireRun('logAttempt');

    _attemptIndex += 1;
    final hash = hashAnswer(answer);

    if (isCorrect) {
      _correctCount += 1;
    } else {
      _wrongAnswerCounts.update(hash, (n) => n + 1, ifAbsent: () => 1);
    }

    await _write(
      PlayEventType.attempt,
      attemptIndex: _attemptIndex,
      answerPayload: answer,
      answerHash: hash,
      isCorrect: isCorrect,
    );
  }

  Future<void> logHint() async {
    _requireRun('logHint');
    _hintIndex += 1;
    await _write(PlayEventType.hintUsed, hintIndex: _hintIndex);
  }

  /// Finish a run. The summary is derived from what this client observed, so
  /// an engine cannot under- or over-report its own difficulty.
  Future<void> logComplete() async {
    _requireRun('logComplete');

    final summary = ExerciseSummary(
      attempts: _attemptIndex,
      correct: _correctCount,
      totalMs: _elapsedMs(),
      distinctWrongAnswers: _wrongAnswerCounts.length,
      maxRepeatOfSameWrongAnswer: _wrongAnswerCounts.values.isEmpty
          ? 0
          : _wrongAnswerCounts.values.reduce((a, b) => a > b ? a : b),
      hintsUsed: _hintIndex,
    );

    await _write(PlayEventType.exerciseComplete, summary: summary);
    _endRun();
  }

  /// The kid left without finishing. Still a signal — abandon rate is one of
  /// the rule inputs — so it is logged rather than dropped.
  Future<void> logAbandon() async {
    _requireRun('logAbandon');
    await _write(PlayEventType.exerciseAbandon);
    _endRun();
  }

  void _endRun() {
    _runId = null;
    _identity = null;
    _runStartedAt = null;
  }

  void _requireRun(String method) {
    if (_runId == null) {
      // A programming error in an engine, not a runtime condition: calling
      // logAttempt outside a run would produce an event the server rejects.
      throw StateError('$method called outside an exercise run. '
          'Call startExercise first.');
    }
  }

  int _elapsedMs() {
    final start = _runStartedAt;
    if (start == null) return 0;
    return _now().difference(start).inMilliseconds;
  }

  /// Stable hash of a normalized answer.
  ///
  /// Keys are sorted so two equal answers hash equally regardless of the order
  /// an engine happened to build the map in. Truncated to 32 hex characters:
  /// enough to avoid collisions in a kid's run, short enough to index.
  static String hashAnswer(Map<String, Object?> answer) {
    final sortedKeys = answer.keys.toList()..sort();
    final canonical = {for (final key in sortedKeys) key: answer[key]};
    final digest = sha256.convert(utf8.encode(jsonEncode(canonical)));
    return digest.toString().substring(0, 32);
  }

  Future<void> _write(
    PlayEventType type, {
    int? attemptIndex,
    Map<String, Object?>? answerPayload,
    String? answerHash,
    bool? isCorrect,
    int? hintIndex,
    ExerciseSummary? summary,
  }) async {
    final now = _now();
    final identity = _identity;

    // Only keys present in play_event.v1.json: the schema sets
    // additionalProperties:false, so an extra field means a rejected event.
    final event = <String, Object?>{
      'schema_version': schemaVersion,
      'event_id': _uuid.v4(),
      'event_ts': now.toUtc().toIso8601String(),
      'session_id': sessionId,
      'event_type': type.wire,
      'app_version': appVersion,
      'exercise_run_id': _runId,
      'exercise_id': identity?.exerciseId,
      'exercise_version': identity?.exerciseVersion,
      'engine_key': identity?.engineKey,
      'engine_version': identity?.engineVersion,
      'skill_node_id': identity?.skillNodeId,
      'subject': identity?.subject,
      'grade': identity?.grade,
      'rank': identity?.rank,
      'attempt_index': attemptIndex,
      'answer_payload': answerPayload,
      'answer_hash': answerHash,
      'is_correct': isCorrect,
      'hint_index': hintIndex,
      'summary': summary?.toJson(),
      'ms_since_run_start': _runStartedAt == null
          ? null
          : now.difference(_runStartedAt!).inMilliseconds,
      'ms_since_prev_event': _previousEventAt == null
          ? null
          : now.difference(_previousEventAt!).inMilliseconds,
    };

    _previousEventAt = now;

    await outbox.add(event);
  }
}
