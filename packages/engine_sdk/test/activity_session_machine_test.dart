import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

EvaluationResult _result(Outcome outcome, int attempt) => EvaluationResult(
  outcome: outcome,
  score: outcome == Outcome.correct ? 1 : 0,
  attemptNumber: attempt,
  evaluator: 'mcq.exact@1',
);

/// Drive the machine through [inputs], asserting each is accepted.
SessionStep _run(SessionState s, List<SessionInput> inputs) {
  late SessionStep step;
  for (final input in inputs) {
    step = ActivitySessionMachine.reduce(s, input);
    expect(step.accepted, isTrue, reason: '$input rejected in ${s.phase}');
    s = step.state;
  }
  return step;
}

SessionState _awaiting({int questions = 2, int? maxAttempts}) =>
    _run(SessionState.initial, [
      const StartLoading(),
      ContentLoaded(questionCount: questions, maxAttempts: maxAttempts),
      const Begin(),
      const QuestionShown(),
    ]).state;

const _a = SingleChoiceAnswer('a');
const _b = SingleChoiceAnswer('b');

void main() {
  group('happy path', () {
    test(
      'two questions, each right first time, emit the learning events in order',
      () {
        final events = <RuntimeEvent>[];
        var s = SessionState.initial;
        for (final input in <SessionInput>[
          const StartLoading(),
          const ContentLoaded(questionCount: 2),
          const Begin(),
          const QuestionShown(),
          const Submit(_a),
          Evaluated(_result(Outcome.correct, 1)),
          const Continue(),
          const QuestionShown(),
          const Submit(_b),
          Evaluated(_result(Outcome.correct, 1)),
          const Continue(),
        ]) {
          final step = ActivitySessionMachine.reduce(s, input);
          expect(step.accepted, isTrue, reason: '$input in ${s.phase}');
          events.addAll(step.events);
          s = step.state;
        }

        expect(s.phase, SessionPhase.completed);
        expect(s.questionsCompleted, 2);
        expect(s.questionsSolved, 2);
        expect(events.map((e) => e.type), [
          'question_presented',
          'answer_submitted',
          'attempt',
          'exercise_complete',
          'question_presented',
          'answer_submitted',
          'attempt',
          // Two first tries running: a combo, for the animation layer.
          'streak_advanced',
          'exercise_complete',
          'activity_completed',
        ]);
      },
    );

    test('an empty activity fails instead of completing', () {
      final step = _run(SessionState.initial, [const StartLoading()]);
      final failed = ActivitySessionMachine.reduce(
        step.state,
        const ContentLoaded(questionCount: 0),
      );
      expect(failed.state.phase, SessionPhase.failed);
      expect(failed.events.single, isA<SessionFailed>());
    });
  });

  group('retry', () {
    test(
      'a wrong answer returns to the same question with the attempt counted',
      () {
        var s = _run(_awaiting(), [
          const Submit(_b),
          Evaluated(_result(Outcome.incorrect, 1)),
        ]).state;
        expect(s.phase, SessionPhase.feedback);

        final step = ActivitySessionMachine.reduce(s, const Continue());
        s = step.state;
        expect(s.phase, SessionPhase.awaitingInteraction);
        expect(s.questionIndex, 0);
        expect(s.attempts, 1);
        expect(step.events, isEmpty, reason: 'a retry is not a completion');

        final second = ActivitySessionMachine.reduce(s, const Submit(_a));
        expect((second.events.single as AnswerSubmitted).attemptNumber, 2);
      },
    );

    test('partial credit also allows a retry', () {
      final s = _run(_awaiting(), [
        const Submit(_b),
        Evaluated(_result(Outcome.partial, 1)),
        const Continue(),
      ]).state;
      expect(s.phase, SessionPhase.awaitingInteraction);
    });

    test('an attempt cap completes the question unsolved and moves on', () {
      final step = _run(_awaiting(maxAttempts: 2), [
        const Submit(_b),
        Evaluated(_result(Outcome.incorrect, 1)),
        const Continue(),
        const Submit(_b),
        Evaluated(_result(Outcome.incorrect, 2)),
        const Continue(),
      ]);
      expect(step.state.phase, SessionPhase.presenting);
      expect(step.state.questionIndex, 1);
      expect(step.state.questionsSolved, 0);
      final completed = step.events.whereType<QuestionCompleted>().single;
      expect(completed.solved, isFalse);
      expect(completed.attempts, 2);
    });
  });

  group('duplicates and stale input', () {
    test('a second submit while evaluating is rejected and emits nothing', () {
      final s = _run(_awaiting(), [const Submit(_a)]).state;
      final dup = ActivitySessionMachine.reduce(s, const Submit(_a));
      expect(dup.accepted, isFalse);
      expect(dup.events, isEmpty);
      expect(dup.state.attempts, 1);
    });

    test('a verdict for another attempt number is rejected', () {
      final s = _run(_awaiting(), [const Submit(_a)]).state;
      final stale = ActivitySessionMachine.reduce(
        s,
        Evaluated(_result(Outcome.correct, 2)),
      );
      expect(stale.accepted, isFalse);
      expect(stale.state.phase, SessionPhase.evaluating);
    });

    test('submitting before the question is shown is rejected', () {
      final s = _run(SessionState.initial, [
        const StartLoading(),
        const ContentLoaded(questionCount: 1),
        const Begin(),
      ]).state;
      expect(
        ActivitySessionMachine.reduce(s, const Submit(_a)).accepted,
        isFalse,
      );
    });

    test('a terminal session rejects everything', () {
      final s = _run(_awaiting(), [const Abandon()]).state;
      for (final input in <SessionInput>[
        const Resume(),
        const Submit(_a),
        const Begin(),
        const Abandon(),
        const Interrupt(),
      ]) {
        expect(
          ActivitySessionMachine.reduce(s, input).accepted,
          isFalse,
          reason: '$input',
        );
      }
    });
  });

  group('evaluation failure', () {
    test('is recorded ungraded and flagged, and never counts as wrong', () {
      final step = _run(_awaiting(), [
        const Submit(_a),
        const EvaluationFailed(reason: 'boom', evaluator: 'mcq.exact@1'),
      ]);
      expect(step.state.phase, SessionPhase.feedback);
      expect(step.state.lastOutcome, Outcome.ungraded);
      final evaluated = step.events.whereType<AnswerEvaluated>().single;
      expect(evaluated.result.outcome, Outcome.ungraded);
      expect(evaluated.result.needsReview, isTrue);
      expect(step.events.whereType<EvaluationFailedDiagnostic>(), hasLength(1));
    });

    test(
      'moves on instead of retrying, so a broken evaluator cannot trap a child',
      () {
        final s = _run(_awaiting(), [
          const Submit(_a),
          const EvaluationFailed(reason: 'boom', evaluator: 'mcq.exact@1'),
          const Continue(),
        ]).state;
        expect(s.phase, SessionPhase.presenting);
        expect(s.questionIndex, 1);
      },
    );
  });

  group('pause and interruption', () {
    test('pause holds the phase and resume returns to it', () {
      final paused = _run(_awaiting(), [const Pause()]);
      expect(paused.state.phase, SessionPhase.paused);
      expect(paused.events.single, isA<SessionPaused>());

      final resumed = ActivitySessionMachine.reduce(
        paused.state,
        const Resume(),
      );
      expect(resumed.state.phase, SessionPhase.awaitingInteraction);
      expect(resumed.state.resumeTo, isNull);
      expect(
        (resumed.events.single as SessionResumed).afterInterruption,
        isFalse,
      );
    });

    test('cannot pause before play starts', () {
      final ready = _run(SessionState.initial, [
        const StartLoading(),
        const ContentLoaded(questionCount: 1),
      ]).state;
      expect(
        ActivitySessionMachine.reduce(ready, const Pause()).accepted,
        isFalse,
      );
    });

    test(
      'an interrupted evaluation resumes into evaluating with its answer kept',
      () {
        final s = _run(_awaiting(), [
          const Submit(_a),
          const Interrupt(),
        ]).state;
        expect(s.phase, SessionPhase.interrupted);

        final resumed = ActivitySessionMachine.reduce(s, const Resume());
        expect(resumed.state.phase, SessionPhase.evaluating);
        expect(resumed.state.pendingAnswer, isA<SingleChoiceAnswer>());
        expect(
          resumed.state.attempts,
          1,
          reason: 'same attempt, so same event id',
        );
        expect(
          (resumed.events.single as SessionResumed).afterInterruption,
          isTrue,
        );
      },
    );

    test(
      'a session that died while paused resumes into what the pause held',
      () {
        final s = _run(_awaiting(), [
          const Pause(),
          const Interrupt(),
          const Resume(),
        ]).state;
        expect(s.phase, SessionPhase.awaitingInteraction);
      },
    );

    test('an interrupted session can be abandoned', () {
      final step = _run(_awaiting(), [
        const Interrupt(),
        const Abandon(AbandonReason.staleResume),
      ]);
      expect(step.state.phase, SessionPhase.abandoned);
      expect(
        (step.events.single as ActivityAbandoned).reason,
        AbandonReason.staleResume,
      );
    });
  });

  group('combo', () {
    List<RuntimeEvent> play(List<List<Outcome>> questions) {
      var s = _awaiting(questions: questions.length);
      final events = <RuntimeEvent>[];
      for (final attempts in questions) {
        for (final (i, o) in attempts.indexed) {
          for (final input in [
            const Submit(_a),
            Evaluated(_result(o, i + 1)),
            const Continue(),
          ]) {
            final step = ActivitySessionMachine.reduce(s, input);
            expect(step.accepted, isTrue, reason: '$input in ${s.phase}');
            events.addAll(step.events);
            s = step.state;
          }
        }
        if (s.phase == SessionPhase.presenting) {
          s = ActivitySessionMachine.reduce(s, const QuestionShown()).state;
        }
      }
      return events;
    }

    List<int> combos(List<RuntimeEvent> events) => [
      for (final e in events)
        if (e is StreakAdvanced) e.count,
    ];

    test('counts first tries from the second one on', () {
      const ok = [Outcome.correct];
      expect(combos(play([ok, ok, ok])), [2, 3]);
    });

    test('a miss or a right answer after a retry starts it over', () {
      const ok = [Outcome.correct];
      const retried = [Outcome.incorrect, Outcome.correct];
      expect(combos(play([ok, retried, ok, ok])), [2]);
      expect(combos(play([ok, ok, retried, ok, ok])), [2, 2]);
    });

    test('is presentation only: never durable', () {
      const e = StreakAdvanced(questionIndex: 1, count: 2);
      expect(e.category, EventCategory.presentation);
      expect(e.category.isDurable, isFalse);
      expect(RevealEvent('outcome').category.isDurable, isFalse);
      expect(
        const IdlePrompted(questionIndex: 0, afterMs: 1).category.isDurable,
        isFalse,
      );
    });

    test('the count survives a snapshot, and old snapshots start at 0', () {
      var s = _awaiting(questions: 3);
      s = _run(s, [
        const Submit(_a),
        Evaluated(_result(Outcome.correct, 1)),
      ]).state;
      expect(s.firstTryStreak, 1);
      expect(SessionState.fromJson(s.toJson())!.firstTryStreak, 1);
      final old = s.toJson()..remove('first_try_streak');
      expect(SessionState.fromJson(old)!.firstTryStreak, 0);
    });
  });

  group('snapshot', () {
    test('every phase round-trips through JSON', () {
      final states = <SessionState>[
        SessionState.initial,
        _awaiting(),
        _run(_awaiting(), [const Submit(_a)]).state,
        _run(_awaiting(), [
          const Submit(_a),
          Evaluated(_result(Outcome.incorrect, 1)),
        ]).state,
        _run(_awaiting(), [const Pause()]).state,
        _run(_awaiting(), [const Submit(_a), const Interrupt()]).state,
      ];
      for (final s in states) {
        final back = SessionState.fromJson(s.toJson());
        expect(back, isNotNull, reason: '${s.phase}');
        expect(back!.toJson(), s.toJson(), reason: '${s.phase}');
      }
    });

    test('garbage is rejected rather than resumed', () {
      expect(SessionState.fromJson({'phase': 'nope'}), isNull);
      expect(SessionState.fromJson(const {}), isNull);
      final json = _run(_awaiting(), [const Submit(_a)]).state.toJson()
        ..['pending_answer'] = {'kind': 'from_the_future'};
      expect(SessionState.fromJson(json), isNull);
    });
  });
}
