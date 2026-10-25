import 'dart:convert';
import 'dart:io';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

import 'package:engine_sdk/testing.dart';

void main() {
  late JsonSchema schema;
  setUpAll(() {
    schema = JsonSchema.create(
      jsonDecode(File('test/fixtures/play_event.v1.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  void expectAllValid(List<Map<String, Object?>> events) {
    for (final e in events) {
      final r = schema.validate(jsonDecode(jsonEncode(e)));
      expect(
        r.isValid,
        isTrue,
        reason: '${e['event_type']}: ${r.errors.join('; ')}\n${jsonEncode(e)}',
      );
    }
  }

  late InMemoryEventOutbox outbox;
  late InMemoryActivitySessionStore store;
  late Duration mono;

  setUp(() {
    outbox = InMemoryEventOutbox();
    store = InMemoryActivitySessionStore(outbox);
    mono = Duration.zero;
  });

  ActivitySessionController build({
    Map<String, Object?>? envelope,
    LearningEngineRegistry? engines,
    EvaluatorRegistry? evaluators,
    AppVersion? appVersion,
  }) => ActivitySessionController(
    envelope: QuestionEnvelope.parse(envelope ?? fakeEnvelope()).valueOrNull!,
    kidId: 'kid-lea',
    engines:
        engines ?? LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
    evaluators: evaluators ?? EvaluatorRegistry([FakeExactEvaluator()]),
    store: store,
    appVersion: '0.2.0',
    currentAppVersion: appVersion,
    seed: 7,
    clock: ActiveClock(monotonic: () => mono),
    now: () => DateTime.utc(2026, 10, 25, 14).add(mono),
  );

  List<String> types() => [
    for (final e in outbox.all) e['event_type'] as String,
  ];

  test(
    'a fresh start presents question 1, durably, and is interactive',
    () async {
      final c = build();
      await c.start();
      expect(c.state.phase, SessionPhase.awaitingInteraction);
      expect(c.isInteractive, isTrue);
      expect(types(), ['session_start', 'exercise_start']);
      expect(
        (await store.live(
          kidId: 'kid-lea',
          exerciseId: c.envelope.exerciseId,
        ))!.seed,
        7,
      );
      expect(c.current!.hintText, 'Compte sur tes doigts.');
    },
  );

  test(
    'wrong, retry, right, next, right: the full v1 record, every event valid',
    () async {
      final c = build();
      await c.start();

      await c.dispatch(const Pick('a'));
      expect(c.current!.answer, isA<SingleChoiceAnswer>());
      await c.submit();
      expect(c.state.phase, SessionPhase.feedback);
      expect(c.state.lastOutcome, Outcome.incorrect);
      expect((c.current!.state as FakeChoiceState).locked, {'a'});

      await c.proceed(); // retry
      expect(c.state.phase, SessionPhase.awaitingInteraction);
      await c.dispatch(const Pick('b'));
      await c.submit();
      expect(c.state.lastOutcome, Outcome.correct);
      await c.proceed(); // next question
      expect(c.state.questionIndex, 1);

      await c.dispatch(const Pick('b'));
      await c.submit();
      await c.proceed();
      expect(c.state.phase, SessionPhase.completed);

      expect(types(), [
        'session_start',
        'exercise_start',
        'attempt',
        'attempt',
        'exercise_complete',
        'exercise_start',
        'attempt',
        'exercise_complete',
        'session_end',
      ]);
      expectAllValid(outbox.all);

      final firstComplete = outbox.all.firstWhere(
        (e) => e['event_type'] == 'exercise_complete',
      );
      expect(firstComplete['summary'], containsPair('attempts', 2));
      expect(firstComplete['summary'], containsPair('correct', 1));
      expect(
        firstComplete['summary'],
        containsPair('distinct_wrong_answers', 1),
      );

      // One run id per question, attempt ids derived from the session.
      final runs = outbox.all
          .map((e) => e['exercise_run_id'])
          .whereType<String>()
          .toSet();
      expect(runs, hasLength(2));
      final ids = SessionIds(c.activitySessionId);
      expect(outbox.all[2]['event_id'], ids.attemptEventId(0, 1));
      expect(outbox.all[3]['event_id'], ids.attemptEventId(0, 2));

      // Terminal: nothing left to resume.
      expect(await store.allLive('kid-lea'), isEmpty);
    },
  );

  test('VALIDER with nothing selected does nothing', () async {
    final c = build();
    await c.start();
    await c.submit();
    expect(c.state.phase, SessionPhase.awaitingInteraction);
    expect(c.state.attempts, 0);
  });

  test('an immediate-mode engine is submitted on the tap itself', () async {
    final c = build(
      engines: LearningEngineRegistry([
        eraseEngine(FakeChoiceEngine(submitMode: SubmitMode.immediate)),
      ]),
    );
    await c.start();
    await c.dispatch(const Pick('b'));
    expect(c.state.phase, SessionPhase.feedback);
    expect(types().last, 'attempt');
  });

  test('a double tap of VALIDER is one attempt', () async {
    final c = build();
    await c.start();
    await c.dispatch(const Pick('a'));
    await Future.wait([c.submit(), c.submit()]);
    expect(types().where((t) => t == 'attempt'), hasLength(1));
  });

  group('resume', () {
    test('after a crash mid-question: same session, same engine state, whole-question summary', () async {
      final first = build();
      await first.start();
      await first.dispatch(const Pick('a'));
      await first.submit(); // wrong
      await first.proceed(); // back to awaiting, 'a' locked
      final sessionId = first.activitySessionId;
      // The app dies here: no exit(), no dispose().

      final snap = await store.live(
        kidId: 'kid-lea',
        exerciseId: first.envelope.exerciseId,
      );
      expect(snap, isNotNull);

      final second = build();
      await second.start(resumeFrom: snap);
      expect(second.activitySessionId, sessionId);
      expect(second.seed, 7);
      expect(second.state.phase, SessionPhase.awaitingInteraction);
      expect((second.current!.state as FakeChoiceState).locked, {'a'});

      await second.dispatch(const Pick('b'));
      await second.submit();
      await second.proceed();

      final complete = outbox.all.firstWhere(
        (e) => e['event_type'] == 'exercise_complete',
      );
      expect(
        complete['summary'],
        containsPair('attempts', 2),
        reason: 'tallies survived the crash',
      );
      expect(
        outbox.all.where((e) => e['event_type'] == 'session_start'),
        hasLength(1),
      );
      // Every id is still unique: the resume duplicated nothing.
      final eventIds = outbox.all.map((e) => e['event_id']).toList();
      expect(eventIds.toSet(), hasLength(eventIds.length));
      expectAllValid(outbox.all);
    });

    test(
      'a snapshot of different content is abandoned and a fresh session starts',
      () async {
        final first = build();
        await first.start();
        final oldId = first.activitySessionId;
        final snap = await store.live(
          kidId: 'kid-lea',
          exerciseId: first.envelope.exerciseId,
        );

        final second = build(
          envelope: fakeEnvelope(contentHash: 'hash-2', version: 2),
        );
        await second.start(resumeFrom: snap);

        expect(second.activitySessionId, isNot(oldId));
        final abandon = outbox.all.firstWhere(
          (e) => e['event_type'] == 'exercise_abandon',
        );
        expect(abandon['session_id'], oldId);
        expect(types().where((t) => t == 'session_end'), hasLength(1));
        expect(types().where((t) => t == 'session_start'), hasLength(2));
        expectAllValid(outbox.all);
      },
    );
  });

  group('failures', () {
    test('an unknown engine needs an update, and writes nothing', () async {
      final c = build(envelope: fakeEnvelope(engineKey: 'from_the_future'));
      await c.start();
      expect(c.state.phase, SessionPhase.failed);
      expect(c.failure, ActivityFailure.needsUpdate);
      expect(outbox.all, isEmpty);
    });

    test('content with no evaluator is invalid', () async {
      final c = build(evaluators: EvaluatorRegistry(const []));
      await c.start();
      expect(c.failure, ActivityFailure.invalidContent);
    });

    test('an app below the content floor needs an update', () async {
      final c = build(
        envelope: fakeEnvelope(minAppVersion: '2.0.0'),
        appVersion: AppVersion.tryParse('1.0.0'),
      );
      await c.start();
      expect(c.failure, ActivityFailure.needsUpdate);
    });

    test('an evaluator that throws records nothing as wrong and moves the child on', () async {
      final c = build(
        evaluators: EvaluatorRegistry([FakeExactEvaluator(throws: true)]),
      );
      final seen = <RuntimeEvent>[];
      c.events.listen(seen.add);
      await c.start();
      await c.dispatch(const Pick('b'));
      await c.submit();
      expect(c.state.lastOutcome, Outcome.ungraded);
      expect(types(), isNot(contains('attempt')));
      await c.proceed();
      expect(c.state.questionIndex, 1);
      await pumpEventQueue();
      expect(seen.whereType<EvaluationFailedDiagnostic>(), hasLength(1));
    });

    test(
      'a failed commit leaves the session where it was, publishes nothing',
      () async {
        final c = build();
        await c.start();
        await c.dispatch(const Pick('a'));
        final seen = <RuntimeEvent>[];
        c.events.listen(seen.add);

        store.failNextCommit = true;
        await c.submit();
        await pumpEventQueue();
        expect(c.failure, ActivityFailure.storage);
        expect(c.state.phase, SessionPhase.awaitingInteraction);
        expect(seen, isEmpty);
        expect(types(), isNot(contains('attempt')));

        await c.submit(); // the retry succeeds and clears the failure
        expect(c.failure, isNull);
        expect(types().where((t) => t == 'attempt'), hasLength(1));
        final summaryLater = outbox.all.last;
        expect(
          summaryLater['attempt_index'],
          1,
          reason: 'the failed try left no trace',
        );
      },
    );
  });

  test('events reach subscribers only after they are durable', () async {
    final c = build();
    final seenWhileDepth = <int>[];
    c.events.listen((_) async => seenWhileDepth.add(await outbox.depth()));
    await c.start();
    await pumpEventQueue();
    expect(seenWhileDepth, isNotEmpty);
    expect(seenWhileDepth.every((d) => d >= 2), isTrue);
  });

  test('paused time is not answer time', () async {
    final c = build(envelope: fakeEnvelope(questions: 1));
    await c.start();
    mono += const Duration(seconds: 3);
    await c.pause();
    mono += const Duration(minutes: 20);
    await c.resume();
    mono += const Duration(seconds: 2);
    await c.dispatch(const Pick('b'));
    await c.submit();
    await c.proceed();
    final complete = outbox.all.firstWhere(
      (e) => e['event_type'] == 'exercise_complete',
    );
    expect(complete['summary'], containsPair('total_ms', 5000));
  });

  test('an attempt cap completes the question unsolved', () async {
    final c = build(
      envelope: fakeEnvelope(questions: 1, evaluation: {'max_attempts': 1}),
    );
    await c.start();
    await c.dispatch(const Pick('a'));
    await c.submit();
    await c.proceed();
    expect(c.state.phase, SessionPhase.completed);
    expect(c.state.questionsSolved, 0);
  });

  test(
    'hints are v1 hint_used; audio requests are published but not yet storable',
    () async {
      final c = build();
      final seen = <RuntimeEvent>[];
      c.events.listen(seen.add);
      await c.start();
      await c.requestHint();
      await c.recordAudioRequest(SpeechPart.prompt);
      await c.recordAudioRequest(SpeechPart.prompt);
      await pumpEventQueue();
      expect(types().last, 'hint_used');
      expect(outbox.all.last['hint_index'], 1);
      final audio = seen.whereType<AudioRequested>().toList();
      expect(audio.map((a) => a.replay), [false, true]);
      expect(c.unrecordedEventCount, 2);
      expectAllValid(outbox.all);
    },
  );

  test('exit closes the open question and the session', () async {
    final c = build();
    await c.start();
    await c.exit();
    expect(c.state.phase, SessionPhase.abandoned);
    expect(types().sublist(2), ['exercise_abandon', 'session_end']);
    expect(await store.allLive('kid-lea'), isEmpty);
    expectAllValid(outbox.all);
  });

  test('the same seed gives the same option order', () async {
    final a = build();
    await a.start();
    final orderA = (a.current!.state as FakeChoiceState).order;
    final b = ActivitySessionController(
      envelope: a.envelope,
      kidId: 'kid-lea',
      engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
      evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
      store: InMemoryActivitySessionStore(),
      appVersion: '0.2.0',
      seed: 7,
    );
    await b.start();
    expect((b.current!.state as FakeChoiceState).order, orderA);
  });
}
