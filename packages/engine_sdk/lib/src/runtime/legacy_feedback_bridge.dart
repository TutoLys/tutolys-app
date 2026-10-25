import 'dart:async';

import '../contracts/evaluation.dart';
import '../engine.dart';
import 'runtime_event.dart';

/// Lets a `TutolysEngine` drive the new animation director.
///
/// The four engines built before `LearningEngine` call [EngineFeedback] and
/// `await` it — `correct()` then `celebrate()`, say — before they let the
/// child continue. This translates each call into a [RuntimeEvent] on
/// [events] and keeps the pause they always had ([beat], the old
/// `MascotEngineFeedback.hold`), so their pacing is unchanged.
///
/// **These events are for characters only, never for telemetry.** A legacy
/// engine already records its own play through `TelemetryClient`; the
/// question index here is always 0 and the evaluator is `legacy`, because a
/// legacy engine doesn't tell its host either. That is fine for a fox
/// deciding whether to celebrate, and wrong for anything that counts.
class LegacyFeedbackBridge implements EngineFeedback {
  LegacyFeedbackBridge({this.beat = const Duration(milliseconds: 900)});

  /// How long each reaction call holds the engine, as before.
  final Duration beat;

  final StreamController<RuntimeEvent> _events = StreamController.broadcast();
  int _attempt = 0;
  int _hints = 0;

  Stream<RuntimeEvent> get events => _events.stream;

  @override
  Future<void> correct() => _emit(_verdict(Outcome.correct));

  @override
  Future<void> incorrect() => _emit(_verdict(Outcome.incorrect));

  /// The run's own success moment. The director already celebrated on
  /// [correct]; this keeps the second beat the engines expect.
  @override
  Future<void> celebrate() => Future<void>.delayed(beat);

  @override
  Future<void> hint() =>
      _emit(HintRequested(questionIndex: 0, hintIndex: _hints++));

  AnswerEvaluated _verdict(Outcome o) => AnswerEvaluated(
    questionIndex: 0,
    result: EvaluationResult(
      outcome: o,
      score: o == Outcome.correct ? 1 : 0,
      attemptNumber: ++_attempt,
      evaluator: 'legacy',
    ),
  );

  Future<void> _emit(RuntimeEvent e) async {
    if (!_events.isClosed) _events.add(e);
    await Future<void>.delayed(beat);
  }

  void dispose() => unawaited(_events.close());
}
