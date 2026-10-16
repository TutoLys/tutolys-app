import 'dart:convert';
import 'dart:io';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

/// A3 acceptance: every telemetry call yields an event valid against
/// `play_event.v1.json`.
///
/// This is the contract test that keeps the app and the telemetry service in
/// step. If it fails, the app would be posting events the server rejects — and
/// the failure would otherwise only show up as a rising "rejected" counter in
/// production, long after the release.
void main() {
  late JsonSchema schema;

  setUpAll(() {
    final file = File('test/fixtures/play_event.v1.json');
    schema = JsonSchema.create(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  /// Validate the way the server does: identity fields are stamped from the
  /// JWT, so the client's event is checked without them.
  void expectValid(Map<String, Object?> event, {String? because}) {
    final result = schema.validate(jsonDecode(jsonEncode(event)));
    expect(
      result.isValid,
      isTrue,
      reason: '${because ?? event['event_type']} produced an invalid event:\n'
          '${result.errors.join('\n')}\n'
          'event: ${jsonEncode(event)}',
    );
  }

  const identity = ExerciseIdentity(
    exerciseId: '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
    exerciseVersion: 3,
    engineKey: 'mcq',
    engineVersion: 1,
    skillNodeId: 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
    subject: 'MATH',
    grade: 1,
    rank: 2,
  );

  ({TelemetryClient client, InMemoryEventOutbox outbox}) build() {
    final outbox = InMemoryEventOutbox();
    var tick = DateTime.utc(2026, 10, 16, 12);
    final client = TelemetryClient(
      outbox: outbox,
      sessionId: 'b3968383-3c5f-4184-9642-2001de990e6f',
      appVersion: '0.1.0',
      // Advance the clock on every read so deltas are non-zero and ordering
      // is deterministic.
      clock: () => tick = tick.add(const Duration(milliseconds: 1200)),
    );
    return (client: client, outbox: outbox);
  }

  group('every event type validates', () {
    test('a full session, start to finish', () async {
      final (client: client, outbox: outbox) = build();

      await client.logSessionStart();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'option_id': 'b'}, isCorrect: false);
      await client.logHint();
      await client.logAttempt(answer: {'option_id': 'a'}, isCorrect: true);
      await client.logComplete();
      await client.logSessionEnd();

      expect(outbox.all, hasLength(7));
      for (final event in outbox.all) {
        expectValid(event);
      }
    });

    test('an abandoned run', () async {
      final (client: client, outbox: outbox) = build();

      await client.startExercise(identity);
      await client.logAttempt(answer: {'option_id': 'x'}, isCorrect: false);
      await client.logAbandon();

      for (final event in outbox.all) {
        expectValid(event);
      }
      expect(
        outbox.all.last['event_type'],
        'exercise_abandon',
        reason: 'abandon is a signal, not something to drop',
      );
    });

    test('a session with no exercise at all', () async {
      final (client: client, outbox: outbox) = build();

      await client.logSessionStart();
      await client.logSessionEnd();

      for (final event in outbox.all) {
        expectValid(event, because: 'session-level event');
      }
    });

    test('every event type the enum declares is covered', () async {
      final (client: client, outbox: outbox) = build();

      await client.logSessionStart();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: false);
      await client.logHint();
      await client.logComplete();
      await client.startExercise(identity);
      await client.logAbandon();
      await client.logSessionEnd();

      final produced =
          outbox.all.map((e) => e['event_type'] as String).toSet();
      final declared = PlayEventType.values.map((t) => t.wire).toSet();

      expect(
        produced,
        equals(declared),
        reason: 'a type the client can never emit is dead weight in the '
            'schema; a type it emits but the schema omits is a rejection',
      );
    });
  });

  group('the schema catches what it should', () {
    test('an extra field is rejected', () async {
      final (client: client, outbox: outbox) = build();
      await client.logSessionStart();

      final tampered = {...outbox.all.first, 'surprise': 'value'};

      expect(
        schema.validate(jsonDecode(jsonEncode(tampered))).isValid,
        isFalse,
        reason: 'additionalProperties:false must actually bite, otherwise the '
            'contract test proves nothing',
      );
    });

    test('an attempt missing is_correct is rejected', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: true);

      final attempt = outbox.all.firstWhere((e) => e['event_type'] == 'attempt');
      final broken = {...attempt}..remove('is_correct');

      expect(schema.validate(jsonDecode(jsonEncode(broken))).isValid, isFalse);
    });
  });

  group('stamping', () {
    test('the client supplies every id and timestamp', () async {
      final (client: client, outbox: outbox) = build();
      await client.logSessionStart();

      final event = outbox.all.single;
      expect(event['event_id'], isNotEmpty);
      expect(event['event_ts'], isNotEmpty);
      expect(event['session_id'], 'b3968383-3c5f-4184-9642-2001de990e6f');
      expect(event['schema_version'], 1);
      expect(event['app_version'], '0.1.0');
    });

    test('event ids are unique, so the outbox can retry safely', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      for (var i = 0; i < 20; i++) {
        await client.logAttempt(answer: {'n': i}, isCorrect: false);
      }

      final ids = outbox.all.map((e) => e['event_id']).toSet();
      expect(ids, hasLength(outbox.all.length));
    });

    test('attempt_index counts from one within a run', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: false);
      await client.logAttempt(answer: {'a': 2}, isCorrect: false);
      await client.logAttempt(answer: {'a': 3}, isCorrect: true);

      final indices = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .map((e) => e['attempt_index'])
          .toList();

      expect(indices, [1, 2, 3]);
    });

    test('a new run resets the attempt counter', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: true);
      await client.logComplete();

      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: true);

      final lastAttempt =
          outbox.all.lastWhere((e) => e['event_type'] == 'attempt');
      expect(lastAttempt['attempt_index'], 1);
    });

    test('each run gets its own exercise_run_id', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      final first = client.currentRunId;
      await client.logComplete();

      await client.startExercise(identity);
      final second = client.currentRunId;

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(second));
    });

    test('session-level events carry no exercise fields', () async {
      final (client: client, outbox: outbox) = build();
      await client.logSessionStart();

      final event = outbox.all.single;
      expect(event['exercise_run_id'], isNull);
      expect(event['exercise_id'], isNull);
      expect(event['skill_node_id'], isNull);
    });
  });

  group('answer hashing', () {
    test('equal answers hash equally regardless of key order', () {
      final a = TelemetryClient.hashAnswer({'x': 1, 'y': 2});
      final b = TelemetryClient.hashAnswer({'y': 2, 'x': 1});

      // Two engines might build the same answer map in different orders; the
      // repeated-wrong-answer signal would be wrong if that mattered.
      expect(a, b);
    });

    test('different answers hash differently', () {
      expect(
        TelemetryClient.hashAnswer({'option_id': 'a'}),
        isNot(TelemetryClient.hashAnswer({'option_id': 'b'})),
      );
    });

    test('the hash fits the schema length limit', () {
      final hash = TelemetryClient.hashAnswer({'option_id': 'a'});
      expect(hash.length, 32);
      expect(hash.length, lessThanOrEqualTo(64));
    });
  });

  group('the completion summary is derived, not reported', () {
    test('repeating one wrong answer differs from trying several', () async {
      // The distinction the plan cares about: a firm misconception looks
      // different from guessing, and an attempt count cannot tell them apart.
      final (client: repeater, outbox: repeaterBox) = build();
      await repeater.startExercise(identity);
      for (var i = 0; i < 3; i++) {
        await repeater.logAttempt(answer: {'option_id': 'b'}, isCorrect: false);
      }
      await repeater.logAttempt(answer: {'option_id': 'a'}, isCorrect: true);
      await repeater.logComplete();

      final (client: guesser, outbox: guesserBox) = build();
      await guesser.startExercise(identity);
      for (final option in ['b', 'c', 'd']) {
        await guesser.logAttempt(answer: {'option_id': option}, isCorrect: false);
      }
      await guesser.logAttempt(answer: {'option_id': 'a'}, isCorrect: true);
      await guesser.logComplete();

      Map<String, Object?> summaryOf(InMemoryEventOutbox box) =>
          (box.all.last['summary'] as Map).cast<String, Object?>();

      final repeated = summaryOf(repeaterBox);
      final guessed = summaryOf(guesserBox);

      expect(repeated['attempts'], 4);
      expect(guessed['attempts'], 4);

      expect(repeated['distinct_wrong_answers'], 1);
      expect(repeated['max_repeat_of_same_wrong_answer'], 3);

      expect(guessed['distinct_wrong_answers'], 3);
      expect(guessed['max_repeat_of_same_wrong_answer'], 1);
    });

    test('hints are counted', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      await client.logHint();
      await client.logHint();
      await client.logAttempt(answer: {'a': 1}, isCorrect: true);
      await client.logComplete();

      final summary = (outbox.all.last['summary'] as Map).cast<String, Object?>();
      expect(summary['hints_used'], 2);
      expect(summary['correct'], 1);
    });

    test('total_ms comes from the clock, not the engine', () async {
      final (client: client, outbox: outbox) = build();
      await client.startExercise(identity);
      await client.logAttempt(answer: {'a': 1}, isCorrect: true);
      await client.logComplete();

      final summary = (outbox.all.last['summary'] as Map).cast<String, Object?>();
      expect(summary['total_ms'], greaterThan(0));
    });
  });

  group('misuse is loud', () {
    test('logging an attempt outside a run throws', () async {
      final (client: client, outbox: _) = build();

      // Better a StateError in development than an event the server rejects
      // in production.
      expect(
        () => client.logAttempt(answer: {'a': 1}, isCorrect: true),
        throwsStateError,
      );
    });

    test('completing without a run throws', () async {
      final (client: client, outbox: _) = build();
      expect(client.logComplete, throwsStateError);
    });

    test('a run cannot be completed twice', () async {
      final (client: client, outbox: _) = build();
      await client.startExercise(identity);
      await client.logComplete();

      expect(client.logComplete, throwsStateError);
    });
  });

  group('the outbox is the only write path', () {
    test('events are durable before they are acknowledged', () async {
      final (client: client, outbox: outbox) = build();

      await client.logSessionStart();

      // Written straight through, not buffered: killing the app here must not
      // lose the event.
      expect(await outbox.depth(), 1);
    });

    test('the outbox is idempotent on event_id', () async {
      final outbox = InMemoryEventOutbox();
      const event = {'event_id': 'fixed-id', 'event_type': 'session_start'};

      await outbox.add(event);
      await outbox.add(event);

      expect(await outbox.depth(), 1);
    });

    test('delivered events leave the pending queue', () async {
      final (client: client, outbox: outbox) = build();
      await client.logSessionStart();
      await client.logSessionEnd();

      final pending = await outbox.pending();
      await outbox.markDelivered(
        pending.map((e) => e['event_id'] as String).toList(),
      );

      expect(await outbox.depth(), 0);
    });
  });
}
