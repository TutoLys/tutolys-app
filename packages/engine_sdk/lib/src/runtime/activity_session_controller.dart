import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../contracts/answer.dart';
import '../contracts/envelope.dart';
import '../contracts/evaluation.dart';
import '../contracts/learning_engine.dart';
import '../contracts/learning_engine_registry.dart';
import '../telemetry.dart';
import 'active_clock.dart';
import 'activity_session_machine.dart';
import 'activity_session_store.dart';
import 'runtime_event.dart';
import 'session_ids.dart';
import 'v1_event_recorder.dart';
import 'v2_event_recorder.dart';

/// Why a session could not start.
enum ActivityFailure {
  /// An engine is unknown or too old, or the content is newer than this
  /// app — the kid needs an update, not an apology.
  needsUpdate,

  /// The content doesn't parse, or no evaluator grades it. A content bug.
  invalidContent,

  /// The device couldn't persist a step. Progress stops rather than
  /// continuing unrecorded: the product is the data.
  storage,
}

/// The current question, as a host renders it.
class ActivityQuestionView {
  const ActivityQuestionView({
    required this.spec,
    required this.engine,
    required this.content,
    required this.state,
    required this.answer,
  });

  final QuestionSpec spec;
  final ErasedEngine engine;
  final Object? content;
  final Object? state;

  /// What VALIDER would submit now; null = nothing to submit yet.
  final AnswerValue? answer;

  /// A plain-text hint, if the content carries one (`config.hint`).
  String? get hintText {
    final h = spec.config['hint'];
    return h is String && h.isNotEmpty ? h : null;
  }
}

/// Runs one activity session: the pure [ActivitySessionMachine], the
/// question's [LearningEngine], its [Evaluator], and durable persistence.
///
/// Every operation follows the same order, and the order is the design:
///
/// 1. compute the next machine state, engine state and events (pure);
/// 2. **commit** the events and the snapshot in one transaction;
/// 3. only then adopt the new state and publish the events.
///
/// So a subscriber — the animation director, the audio coordinator — never
/// sees an event that isn't already durable, and a failed commit leaves the
/// session exactly where it was. Operations are serialised: a second tap
/// while one is being committed waits its turn, then usually turns out to be
/// meaningless and is rejected by the machine.
class ActivitySessionController extends ChangeNotifier {
  ActivitySessionController({
    required this.envelope,
    required this.kidId,
    required this.engines,
    required this.evaluators,
    required this.store,
    required this.appVersion,
    this.currentAppVersion,
    this.recorderFactory = _v2,
    SessionIds? ids,
    int? seed,
    ActiveClock? clock,
    DateTime Function()? now,
    Random? random,
  }) : _ids = ids ?? SessionIds.create(),
       _seed = seed ?? (random ?? Random()).nextInt(1 << 31),
       _clock = clock ?? ActiveClock(),
       _now = now ?? DateTime.now;

  final QuestionEnvelope envelope;
  final String kidId;
  final LearningEngineRegistry engines;
  final EvaluatorRegistry evaluators;
  final ActivitySessionStore store;
  final String appVersion;
  final AppVersion? currentAppVersion;

  SessionIds _ids;
  int _seed;
  ActiveClock _clock;
  final DateTime Function() _now;
  late RuntimeEventRecorder _recorder = _newRecorder(_ids);

  /// Which wire format the outbox gets. `play_event.v2` since telemetry
  /// ADR 0013 (engine_sdk's V2EventRecorder); v1 stays for a host pointed at
  /// a telemetry that predates it.
  final RuntimeEventRecorder Function(SessionIds ids, String appVersion)
  recorderFactory;

  static RuntimeEventRecorder _v2(SessionIds ids, String appVersion) =>
      V2EventRecorder(ids: ids, appVersion: appVersion);

  RuntimeEventRecorder _newRecorder(SessionIds ids) =>
      recorderFactory(ids, appVersion);

  SessionState _state = SessionState.initial;
  final List<LearningEngineResolved> _questions = [];
  Object? _engineState;
  int _hintsShown = 0;
  final Set<String> _spokenParts = {};

  ActivityFailure? _failure;
  String? _failureReason;

  final StreamController<RuntimeEvent> _events = StreamController.broadcast();
  Future<void> _queue = Future.value();
  bool _disposed = false;

  /// Published only after the events are durable.
  Stream<RuntimeEvent> get events => _events.stream;

  SessionState get state => _state;
  String get activitySessionId => _ids.activitySessionId;
  int get seed => _seed;
  int get activeMs => _clock.activeMs;
  ActivityFailure? get failure => _failure;
  String? get failureReason => _failureReason;

  /// Durable events the recorder's format can't carry (see
  /// [RuntimeEventRecorder.unrecordedCount]).
  int get unrecordedEventCount => _recorder.unrecordedCount;

  int get hintsShown => _hintsShown;

  /// The verdict the feedback banner is about. In memory only: after a
  /// resume the banner falls back to its generic wording.
  EvaluationResult? get lastResult => _lastResult;
  EvaluationResult? _lastResult;

  ActivityQuestionView? get current {
    final i = _state.questionIndex;
    if (i >= _questions.length || _state.phase.isTerminal) return null;
    final q = _questions[i];
    return ActivityQuestionView(
      spec: envelope.questions[i],
      engine: q.engine,
      content: q.content,
      state: _engineState,
      answer: _engineState == null
          ? null
          : q.engine.extractAnswer(_engineState),
    );
  }

  /// Whether the learner can act on the question right now.
  bool get isInteractive => _state.phase == SessionPhase.awaitingInteraction;

  // ── lifecycle ──────────────────────────────────────────────────────────

  /// Start fresh, or resume [resumeFrom] if it was played against exactly
  /// this content. A snapshot of different content is abandoned (with its
  /// own ids, so its open question is closed in telemetry) and a fresh
  /// session starts instead.
  Future<void> start({SessionSnapshot? resumeFrom}) => _serial(() async {
    if (resumeFrom != null) {
      if (resumeFrom.matches(
            exerciseVersion: envelope.version,
            contentHash: envelope.contentHash,
          ) &&
          _resolveAll()) {
        await _resume(resumeFrom);
        return;
      }
      await _abandonStale(resumeFrom);
    }
    await _startFresh();
  });

  Future<void> _startFresh() async {
    var s = SessionState.initial;
    final events = <RuntimeEvent>[];
    SessionStep step(SessionInput input) {
      final r = ActivitySessionMachine.reduce(s, input);
      s = r.state;
      events.addAll(r.events);
      return r;
    }

    step(const StartLoading());
    final floor = envelope.minAppVersion;
    final current = currentAppVersion;
    final tooOld =
        floor != null &&
        current != null &&
        AppVersion.tryParse(floor) != null &&
        current < AppVersion.tryParse(floor)!;
    if (tooOld) {
      _failWith(
        ActivityFailure.needsUpdate,
        'App $current is older than the floor $floor.',
      );
    } else {
      _resolveAll();
    }
    if (_failure != null) {
      step(Fail(_failureReason!));
      _state = s; // nothing durable happened yet: a failed start writes nothing
      _publish(events);
      return;
    }

    step(
      ContentLoaded(
        questionCount: _questions.length,
        maxAttempts: envelope.evaluation.maxAttempts,
      ),
    );
    step(const Begin());
    step(const QuestionShown());
    _clock.start();
    final engineState = _initQuestion(0);
    await _commit(s, events, engineState: engineState);
  }

  /// Resolve every question's engine, content and evaluator up front, so a
  /// broken third question is found before the child starts the first.
  bool _resolveAll() {
    _questions.clear();
    for (final q in envelope.questions) {
      final r = engines.resolve(q, minimumVersion: envelope.engineMinVersion);
      switch (r) {
        case LearningEngineMissing(:final miss, :final reason):
          _failWith(
            miss == EngineMiss.needsUpdate
                ? ActivityFailure.needsUpdate
                : ActivityFailure.invalidContent,
            reason,
          );
          return false;
        case LearningEngineResolved():
          if (evaluators.lookup(q.engineKey, envelope.evaluation.policy) ==
              null) {
            _failWith(
              ActivityFailure.invalidContent,
              'No evaluator for ${q.engineKey}/${envelope.evaluation.policy}',
            );
            return false;
          }
          _questions.add(r);
      }
    }
    return true;
  }

  void _failWith(ActivityFailure f, String reason) {
    _failure = f;
    _failureReason = reason;
  }

  Future<void> _resume(SessionSnapshot snap) async {
    _ids = SessionIds(snap.activitySessionId);
    _seed = snap.seed;
    _clock = ActiveClock(initialActiveMs: snap.activeMs);
    _recorder = _newRecorder(_ids);
    final rs = snap.recorderState;
    _recorder.restore((rs?['recorder'] as Map?)?.cast<String, Object?>());
    _hintsShown = rs?['hints_shown'] as int? ?? 0;
    _spokenParts
      ..clear()
      ..addAll(((rs?['spoken_parts'] as List?) ?? const []).cast<String>());

    var s = snap.state;
    final events = <RuntimeEvent>[];
    if (s.phase != SessionPhase.interrupted) {
      s = ActivitySessionMachine.reduce(s, const Interrupt()).state;
    }
    final resumed = ActivitySessionMachine.reduce(s, const Resume());
    s = resumed.state;
    events.addAll(resumed.events);

    // Restore the question's engine state; an unusable snapshot restarts the
    // question rather than guessing.
    Object? engineState;
    final i = s.questionIndex;
    if (i < _questions.length) {
      final q = _questions[i];
      final saved = snap.engineState;
      engineState = saved == null ? null : q.engine.restore(q.content, saved);
      engineState ??= q.engine.initialize(q.content, _questionSeed(i));
    }

    if (s.phase != SessionPhase.paused) _clock.start();

    // A crash mid-evaluation: grade the same attempt again. Same attempt
    // number, so the same event id.
    if (s.phase == SessionPhase.evaluating &&
        s.pendingAnswer != null &&
        i < _questions.length) {
      final r = _evaluate(i, s.pendingAnswer!, s.attempts);
      final step = ActivitySessionMachine.reduce(s, r.input);
      s = step.state;
      events.addAll(step.events);
      if (r.result != null) {
        engineState = _questions[i].engine.applyFeedback(
          engineState,
          r.result!,
        );
      }
    }

    await _commit(s, events, engineState: engineState);
  }

  Future<void> _abandonStale(SessionSnapshot snap) async {
    final ids = SessionIds(snap.activitySessionId);
    final recorder = _newRecorder(ids)
      ..restore(
        (snap.recorderState?['recorder'] as Map?)?.cast<String, Object?>(),
      );
    final step = ActivitySessionMachine.reduce(
      snap.state.phase == SessionPhase.interrupted
          ? snap.state
          : ActivitySessionMachine.reduce(snap.state, const Interrupt()).state,
      const Abandon(AbandonReason.staleResume),
    );
    final identity = ExerciseIdentity(
      exerciseId: snap.exerciseId,
      exerciseVersion: snap.exerciseVersion,
      engineKey: envelope.engineKey,
      engineVersion: 0,
      skillNodeId: envelope.skillNodeId,
      subject: envelope.subject,
      grade: envelope.grade,
      rank: envelope.rank,
    );
    final wire = [
      for (final e in step.events)
        ...recorder.record(
          e,
          RecorderFrame(
            now: _now(),
            activeMs: snap.activeMs,
            identity: identity,
            contentHash: snap.contentHash,
          ),
        ),
    ];
    await store.commit(
      events: wire,
      snapshot: SessionSnapshot(
        activitySessionId: snap.activitySessionId,
        kidId: snap.kidId,
        exerciseId: snap.exerciseId,
        exerciseVersion: snap.exerciseVersion,
        contentHash: snap.contentHash,
        seed: snap.seed,
        state: step.state,
        activeMs: snap.activeMs,
        updatedAt: _now(),
      ),
    );
  }

  // ── learner actions ────────────────────────────────────────────────────

  /// An engine action. Engines with [SubmitMode.immediate] or
  /// [SubmitMode.onComplete] are submitted as soon as an answer exists.
  Future<void> dispatch(Object action) => _serial(() async {
    if (!isInteractive) return;
    final i = _state.questionIndex;
    final q = _questions[i];
    final t = q.engine.reduce(_engineState, action);
    final events = <RuntimeEvent>[...t.events];
    var s = _state;
    var engineState = t.state;

    final mode = q.engine.descriptor.submitMode;
    final answer = q.engine.extractAnswer(engineState);
    if (mode != SubmitMode.explicit && answer != null) {
      final r = _submitAndEvaluate(s, engineState, answer);
      s = r.state;
      engineState = r.engineState;
      events.addAll(r.events);
    }
    await _commit(s, events, engineState: engineState);
  });

  /// VALIDER.
  Future<void> submit() => _serial(() async {
    if (!isInteractive) return;
    final q = _questions[_state.questionIndex];
    final answer = q.engine.extractAnswer(_engineState);
    if (answer == null) return;
    final r = _submitAndEvaluate(_state, _engineState, answer);
    await _commit(r.state, r.events, engineState: r.engineState);
  });

  /// Leave feedback: the machine decides between retry, next and done.
  Future<void> proceed() => _serial(() async {
    if (_state.phase != SessionPhase.feedback) return;
    final step = ActivitySessionMachine.reduce(_state, const Continue());
    if (!step.accepted) return;
    var s = step.state;
    final events = [...step.events];
    var engineState = _engineState;
    if (s.phase == SessionPhase.presenting) {
      final shown = ActivitySessionMachine.reduce(s, const QuestionShown());
      s = shown.state;
      engineState = _initQuestion(s.questionIndex);
      _hintsShown = 0;
      _spokenParts.clear();
    }
    if (s.phase.isTerminal) {
      _clock.pause();
      engineState = null;
    }
    await _commit(s, events, engineState: engineState);
  });

  Future<void> requestHint() => _serial(() async {
    if (!isInteractive) return;
    final e = HintRequested(
      questionIndex: _state.questionIndex,
      hintIndex: _hintsShown,
    );
    _hintsShown++;
    await _commit(_state, [e], engineState: _engineState);
  });

  /// A speaker button or an auto-read. Recorded whether or not the audio
  /// then plays: the request is the learner's, the playback is ours.
  Future<void> recordAudioRequest(SpeechPart part, {String? partId}) =>
      _serial(() async {
        if (_state.phase.isTerminal ||
            _state.questionIndex >= _questions.length) {
          return;
        }
        final key = '${part.name}:${partId ?? ''}';
        final replay = !_spokenParts.add(key);
        final e = AudioRequested(
          questionIndex: _state.questionIndex,
          part: part,
          partId: partId,
          replay: replay,
        );
        await _commit(_state, [e], engineState: _engineState);
      });

  Future<void> pause() => _serial(() async {
    final step = ActivitySessionMachine.reduce(_state, const Pause());
    if (!step.accepted) return;
    _clock.pause();
    await _commit(step.state, step.events, engineState: _engineState);
  });

  Future<void> resume() => _serial(() async {
    final step = ActivitySessionMachine.reduce(_state, const Resume());
    if (!step.accepted) return;
    _clock.start();
    await _commit(step.state, step.events, engineState: _engineState);
  });

  /// The child left. Closes the open question in telemetry.
  Future<void> exit() => _serial(() async {
    final step = ActivitySessionMachine.reduce(_state, const Abandon());
    if (!step.accepted) return;
    _clock.pause();
    await _commit(step.state, step.events, engineState: null);
  });

  // ── internals ──────────────────────────────────────────────────────────

  ({SessionState state, Object? engineState, List<RuntimeEvent> events})
  _submitAndEvaluate(SessionState s, Object? engineState, AnswerValue answer) {
    final events = <RuntimeEvent>[];
    final submitted = ActivitySessionMachine.reduce(s, Submit(answer));
    if (!submitted.accepted) {
      return (state: s, engineState: engineState, events: events);
    }
    s = submitted.state;
    events.addAll(submitted.events);

    // Submit and verdict commit together, so no crash can separate them.
    final i = s.questionIndex;
    final r = _evaluate(i, answer, s.attempts);
    final evaluated = ActivitySessionMachine.reduce(s, r.input);
    s = evaluated.state;
    events.addAll(evaluated.events);
    if (r.result != null) {
      engineState = _questions[i].engine.applyFeedback(engineState, r.result!);
    }
    return (state: s, engineState: engineState, events: events);
  }

  ({SessionInput input, EvaluationResult? result}) _evaluate(
    int i,
    AnswerValue answer,
    int attempt,
  ) {
    final spec = envelope.questions[i];
    final evaluator = evaluators.lookup(
      spec.engineKey,
      envelope.evaluation.policy,
    )!;
    final id =
        '${evaluator.engineKey}.${evaluator.policy}@${evaluator.version}';
    try {
      final result = evaluator.evaluate(
        _questions[i].content,
        answer,
        EvaluationContext(
          attemptNumber: attempt,
          skillNodeIds: envelope.skillNodeIds,
        ),
      );
      return (input: Evaluated(result), result: result);
    } on Object catch (e) {
      return (
        input: EvaluationFailed(
          reason: '$e',
          evaluator: id,
          skillNodeIds: envelope.skillNodeIds,
        ),
        result: null,
      );
    }
  }

  Object? _initQuestion(int i) => i < _questions.length
      ? _questions[i].engine.initialize(_questions[i].content, _questionSeed(i))
      : null;

  /// One seed per question, derived from the session's: a resumed second
  /// question shuffles exactly as it did before.
  EngineSeed _questionSeed(int i) => EngineSeed((_seed * 31 + i) & 0x7fffffff);

  ExerciseIdentity _identityFor(int i) {
    final idx = i.clamp(0, envelope.questions.length - 1);
    final spec = envelope.questions[idx];
    return ExerciseIdentity(
      exerciseId: envelope.exerciseId,
      exerciseVersion: envelope.version,
      engineKey: spec.engineKey,
      engineVersion: idx < _questions.length
          ? _questions[idx].engine.descriptor.version
          : 0,
      skillNodeId: envelope.skillNodeId,
      subject: envelope.subject,
      grade: envelope.grade,
      rank: envelope.rank,
    );
  }

  int _questionIndexOf(RuntimeEvent e, int fallback) => switch (e) {
    QuestionPresented(:final questionIndex) ||
    AnswerSubmitted(:final questionIndex) ||
    AnswerEvaluated(:final questionIndex) ||
    QuestionCompleted(:final questionIndex) ||
    HintRequested(:final questionIndex) ||
    AudioRequested(:final questionIndex) ||
    ActivityAbandoned(:final questionIndex) => questionIndex,
    _ => fallback,
  };

  Future<void> _commit(
    SessionState next,
    List<RuntimeEvent> events, {
    required Object? engineState,
  }) async {
    final now = _now();
    final active = _clock.activeMs;
    final recorderBefore = _recorder.state;
    final wire = <Map<String, Object?>>[
      for (final e in events)
        ..._recorder.record(
          e,
          RecorderFrame(
            now: now,
            activeMs: active,
            identity: _identityFor(_questionIndexOf(e, next.questionIndex)),
            contentHash: envelope.contentHash,
          ),
        ),
    ];
    final i = next.questionIndex;
    final snapshot = SessionSnapshot(
      activitySessionId: _ids.activitySessionId,
      kidId: kidId,
      exerciseId: envelope.exerciseId,
      exerciseVersion: envelope.version,
      contentHash: envelope.contentHash,
      seed: _seed,
      state: next,
      engineState: engineState == null || i >= _questions.length
          ? null
          : _questions[i].engine.snapshot(engineState),
      recorderState: {
        'recorder': _recorder.state,
        'hints_shown': _hintsShown,
        'spoken_parts': _spokenParts.toList(),
      },
      activeMs: active,
      updatedAt: now,
    );

    try {
      await store.commit(events: wire, snapshot: snapshot);
    } on Object catch (e) {
      // Nothing was written; keep the session where it was. The recorder's
      // tallies already advanced, so put them back.
      _recorder.restore(recorderBefore);
      _failWith(ActivityFailure.storage, '$e');
      _notify();
      return;
    }

    if (_failure == ActivityFailure.storage) {
      _failure = null;
      _failureReason = null;
    }
    _state = next;
    for (final e in events) {
      if (e is AnswerEvaluated) _lastResult = e.result;
      if (e is QuestionPresented) _lastResult = null;
    }
    _engineState = engineState;
    _publish(events);
  }

  void _publish(List<RuntimeEvent> events) {
    if (_disposed) return;
    for (final e in events) {
      _events.add(e);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() op) {
    final next = _queue.then((_) => _disposed ? null : op());
    // A failure must not jam every later operation.
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  void dispose() {
    _disposed = true;
    _clock.pause();
    unawaited(_events.close());
    super.dispose();
  }
}
