import 'dart:convert';
import 'dart:io';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:engine_sdk/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

/// The app half of telemetry ADR 0013's contract: everything the runtime
/// writes validates against `play_event.v2.json`, copied verbatim from
/// tutolys-telemetry (`docs/schemas/`), as is the shared batch fixture.
/// If telemetry changes the schema, re-copy both and this test says what
/// broke.
RuntimeEventRecorder v1Recorder(SessionIds ids, String appVersion) =>
    V1EventRecorder(ids: ids, appVersion: appVersion);

void main() {
  late JsonSchema schema;
  setUpAll(() {
    schema = JsonSchema.create(
      jsonDecode(File('test/fixtures/play_event.v2.json').readAsStringSync())
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
    RuntimeEventRecorder Function(SessionIds, String)? recorder,
    Map<String, Object?>? envelope,
    SessionIds? ids,
  }) => ActivitySessionController(
    ids: ids,
    envelope: QuestionEnvelope.parse(envelope ?? fakeEnvelope()).valueOrNull!,
    kidId: 'kid-lea',
    engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
    evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
    store: store,
    appVersion: '0.2.0',
    recorderFactory:
        recorder ??
        (ids, v) => V2EventRecorder(
          ids: ids,
          appVersion: v,
          sessionRunId: '989a4f01-acbf-5ce4-81f7-4329992d01a3',
        ),
    seed: 7,
    clock: ActiveClock(monotonic: () => mono),
    now: () => DateTime.utc(2026, 10, 25, 14).add(mono),
  );

  List<String> types() => [
    for (final e in outbox.all) e['event_type'] as String,
  ];

  Future<void> playTwoQuestions(ActivitySessionController c) async {
    await c.start();
    await c.recordAudioRequest(SpeechPart.prompt);
    await c.recordAudioRequest(SpeechPart.prompt); // a replay
    await c.requestHint();
    mono += const Duration(seconds: 3);
    await c.dispatch(const Pick('a'));
    await c.submit(); // wrong
    await c.proceed();
    await c.dispatch(const Pick('b'));
    await c.submit(); // right
    await c.proceed();
    await c.dispatch(const Pick('b'));
    await c.submit();
    await c.proceed();
  }

  test('the shared fixture is valid against the copied schema', () {
    final batch = jsonDecode(
      File('test/fixtures/play_event.v2.batch.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    var n = 0;
    for (final e in (batch['events'] as List).cast<Map<String, dynamic>>()) {
      final event = {
        ...e,
        'event_id':
            '00000000-0000-4000-8000-${(n++).toString().padLeft(12, '0')}',
      };
      final r = schema.validate(event);
      expect(r.isValid, isTrue, reason: '${e['event_type']}: ${r.errors}');
    }
  });

  test('a whole activity: every event valid, interactions kept', () async {
    final c = build();
    await playTwoQuestions(c);
    expect(types(), [
      'session_start',
      'exercise_start',
      'question_presented',
      'audio_requested',
      'audio_replayed',
      'hint_used',
      'option_selected',
      'attempt',
      'option_selected',
      'attempt',
      'exercise_complete',
      'exercise_start',
      'question_presented',
      'option_selected',
      'attempt',
      'exercise_complete',
      'session_end',
    ]);
    expectAllValid(outbox.all);
    expect(c.unrecordedEventCount, 0, reason: 'v2 has a type for everything');
  });

  test('sequence counts 0, 1, 2… across the whole activity', () async {
    await playTwoQuestions(build());
    expect([
      for (final e in outbox.all) e['sequence'],
    ], List.generate(outbox.all.length, (i) => i));
  });

  test('an attempt carries its verdict and the help the child had', () async {
    await playTwoQuestions(build());
    final first = outbox.all.firstWhere((e) => e['event_type'] == 'attempt');
    expect(first['is_correct'], isFalse);
    final evaluation = first['evaluation']! as Map;
    expect(evaluation['outcome'], 'incorrect');
    expect(evaluation['evaluator'], isNotEmpty);
    expect(evaluation['authority'], 'local');
    expect(first['assistance'], {'hints': 1, 'audio_replays': 1});
    final complete = outbox.all.lastWhere(
      (e) => e['event_type'] == 'exercise_complete',
    );
    expect(complete['assistance'], {
      'hints': 0,
      'audio_replays': 0,
    }, reason: 'tallies are per question');
  });

  test('in-question events carry their question and run', () async {
    await playTwoQuestions(build());
    final pick = outbox.all.firstWhere(
      (e) => e['event_type'] == 'option_selected',
    );
    expect(pick['payload'], {'option_id': 'a'});
    expect(pick['event_category'], 'interaction');
    expect(pick['question_instance_id'], isNotNull);
    expect(pick['exercise_run_id'], isNotNull);
    expect(pick['content_hash'], 'hash-1');
    final start = outbox.all.first;
    expect(start['question_instance_id'], isNull, reason: 'session-level');
  });

  test(
    'learning events keep v1\'s ids, so an upgrade double-counts nothing',
    () async {
      const fixed = '7a1e0c55-2b4d-4f3a-9c6e-1d2f3a4b5c6d';
      await playTwoQuestions(build(ids: SessionIds(fixed)));
      final v2 = {
        for (final e in outbox.all)
          if (e['event_type'] case final String t
              when PlayEventType.values.any((p) => p.wire == t))
            '$t#${e['attempt_index']}#${e['exercise_run_id']}': e['event_id'],
      };
      outbox = InMemoryEventOutbox();
      store = InMemoryActivitySessionStore(outbox);
      await playTwoQuestions(
        build(recorder: v1Recorder, ids: SessionIds(fixed)),
      );
      final v1 = {
        for (final e in outbox.all)
          '${e['event_type']}#${e['attempt_index']}#${e['exercise_run_id']}':
              e['event_id'],
      };
      expect(v2, v1);
    },
  );

  test('a resume continues the sequence with a new run id', () async {
    final first = build();
    await first.start();
    await first.dispatch(const Pick('a'));
    final before = outbox.all.length;
    final snap = await store.live(
      kidId: 'kid-lea',
      exerciseId: first.envelope.exerciseId,
    );

    final second = build(
      recorder: (ids, v) => V2EventRecorder(
        ids: ids,
        appVersion: v,
        sessionRunId: 'a1b2c3d4-0000-4000-8000-000000000002',
      ),
    );
    await second.start(resumeFrom: snap);
    await second.submit();
    final after = outbox.all.sublist(before);
    expect(after.first['sequence'], before, reason: 'no gap, no repeat');
    expect(after.map((e) => e['session_run_id']).toSet(), {
      'a1b2c3d4-0000-4000-8000-000000000002',
    });
    expect(types(), contains('session_resumed'));
    final ids = outbox.all.map((e) => e['event_id']).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expectAllValid(outbox.all);
  });

  test('pause and exit are recorded and valid', () async {
    final c = build();
    await c.start();
    await c.pause();
    await c.resume();
    await c.exit();
    expect(types(), [
      'session_start',
      'exercise_start',
      'question_presented',
      'session_paused',
      'session_resumed',
      'exercise_abandon',
      'session_end',
    ]);
    expectAllValid(outbox.all);
  });

  group('left between two questions', () {
    // The controller emits QuestionCompleted and the next QuestionPresented
    // together, so this can't be reached through it today; the recorder
    // still guarantees it (telemetry ADR 0017: a session_end on its own
    // reads as a finished lesson).
    final f = RecorderFrame(
      now: DateTime.utc(2026, 10, 26),
      activeMs: 4000,
      identity: const ExerciseIdentity(
        exerciseId: '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
        exerciseVersion: 1,
        engineKey: 'mcq',
        engineVersion: 1,
        skillNodeId: 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
        subject: 'MATH',
        grade: 1,
        rank: 0,
      ),
    );
    List<Map<String, Object?>> leaveAfterFirst(RuntimeEventRecorder r) => [
      ...r.record(const QuestionPresented(questionIndex: 0, questionCount: 2), f),
      ...r.record(
        const QuestionCompleted(questionIndex: 0, attempts: 1, solved: true),
        f,
      ),
      ...r.record(
        const ActivityAbandoned(questionIndex: 1, reason: AbandonReason.exited),
        f,
      ),
    ];

    for (final (name, make) in [
      ('v1', () => V1EventRecorder(ids: SessionIds.create(), appVersion: '0.2.0')),
      ('v2', () => V2EventRecorder(ids: SessionIds.create(), appVersion: '0.2.0')),
    ]) {
      test('$name still sends an abandon before session_end', () {
        final events = leaveAfterFirst(make());
        final types = [for (final e in events) e['event_type']];
        expect(types.sublist(types.length - 2), [
          'exercise_abandon',
          'session_end',
        ]);
        expect(types.where((t) => t == 'exercise_abandon'), hasLength(1));
        final abandon = events[types.indexOf('exercise_abandon')];
        final complete = events[types.indexOf('exercise_complete')];
        expect(abandon['exercise_run_id'], isNotNull);
        expect(
          abandon['exercise_run_id'],
          isNot(complete['exercise_run_id']),
          reason: 'the finished question stays finished',
        );
        if (name == 'v2') expectAllValid(events);
      });
    }

    test('an abandon before anything started sends nothing', () {
      final r = V1EventRecorder(ids: SessionIds.create(), appVersion: '0.2.0');
      expect(
        r.record(
          const ActivityAbandoned(questionIndex: 0, reason: AbandonReason.exited),
          f,
        ),
        isEmpty,
      );
    });
  });

  test('an unknown interaction type is counted, never sent', () {
    final r = V2EventRecorder(ids: SessionIds.create(), appVersion: '0.2.0');
    final f = RecorderFrame(
      now: DateTime.utc(2026),
      activeMs: 0,
      identity: const ExerciseIdentity(
        exerciseId: '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
        exerciseVersion: 1,
        engineKey: 'mcq',
        engineVersion: 1,
        skillNodeId: 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
        subject: 'MATH',
        grade: 1,
        rank: 0,
      ),
    );
    expect(r.record(const InteractionEvent('cell_wiggled'), f), isEmpty);
    expect(r.unrecordedCount, 1);
    final kept = r.record(
      const InteractionEvent('item_placed', {
        'item_id': 'n2',
        'label': 'deux',
        'nested': {'a': 1},
      }),
      f,
    );
    expect(kept.single['payload'], {'item_id': 'n2'}, reason: 'ids only');
  });

  test('a v1 snapshot resumes on v2 without losing its tallies', () {
    final ids = SessionIds.create();
    final v1 = V1EventRecorder(ids: ids, appVersion: '0.2.0');
    final v2 = V2EventRecorder(ids: ids, appVersion: '0.2.0')
      ..restore({...v1.state, 'question_index': 0, 'attempts': 2});
    expect((v2.state['v1']! as Map)['attempts'], 2);
    expect(v2.state['sequence'], 0);
  });
}
