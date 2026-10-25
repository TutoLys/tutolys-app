import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A6 acceptance: a backend-only change to `engine_key` swaps which engine
/// renders a question, with no app code touched. These tests exercise that
/// through [ExerciseRunner] directly, plus the fallback and telemetry
/// lifecycle it owns on every engine's behalf.
void main() {
  Map<String, Object?> envelope({
    String engineKey = 'fake-a',
    int engineMinVersion = 1,
    String exerciseId = '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
    int version = 3,
    String skillNodeId = 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
    Map<String, Object?> config = const {},
  }) {
    return {
      'exercise_id': exerciseId,
      'version': version,
      'engine_key': engineKey,
      'engine_min_version': engineMinVersion,
      'skill_node_id': skillNodeId,
      'subject': 'MATH',
      'grade': 1,
      'rank': 2,
      'locale': 'fr-CA',
      'prompt': {'text': 'Quel nombre ?', 'audio_ref': null, 'image_ref': null},
      'config': config,
      'assets': const [],
    };
  }

  ({TelemetryClient client, InMemoryEventOutbox outbox}) buildTelemetry() {
    final outbox = InMemoryEventOutbox();
    var tick = DateTime.utc(2026, 10, 17, 9);
    final client = TelemetryClient(
      outbox: outbox,
      sessionId: 'b3968383-3c5f-4184-9642-2001de990e6f',
      appVersion: '0.1.0',
      clock: () => tick = tick.add(const Duration(milliseconds: 500)),
    );
    return (client: client, outbox: outbox);
  }

  Widget host({
    required Map<String, Object?> envelope,
    required EngineRegistry registry,
    required TelemetryClient telemetry,
    ValueChanged<ExerciseResult>? onFinished,
    Map<String, Object?> settingsOverrides = const {},
    AudioResolver? audio,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ExerciseRunner(
          envelope: envelope,
          registry: registry,
          telemetry: telemetry,
          feedback: _RecordingFeedback(),
          audio: audio ?? InMemoryAudioResolver(),
          locale: const Locale('fr', 'CA'),
          settingsOverrides: settingsOverrides,
          onFinished: onFinished ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders the engine the envelope names, nothing else', (
    tester,
  ) async {
    final registry = EngineRegistry([
      _FakeEngine(
        engineKey: 'fake-a',
        buildImpl: (_, _) => const Text('ENGINE A'),
      ),
      _FakeEngine(
        engineKey: 'fake-b',
        buildImpl: (_, _) => const Text('ENGINE B'),
      ),
    ]);
    final (client: telemetry, outbox: _) = buildTelemetry();

    await tester.pumpWidget(
      host(
        envelope: envelope(engineKey: 'fake-a'),
        registry: registry,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ENGINE A'), findsOneWidget);
    expect(find.text('ENGINE B'), findsNothing);
  });

  testWidgets(
    'swapping only engine_key swaps the rendered engine — a content change, not a code change',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
        _FakeEngine(
          engineKey: 'fake-b',
          buildImpl: (_, _) => const Text('ENGINE B'),
        ),
      ]);
      final (client: telemetryA, outbox: _) = buildTelemetry();
      final (client: telemetryB, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        host(
          envelope: envelope(engineKey: 'fake-a'),
          registry: registry,
          telemetry: telemetryA,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ENGINE A'), findsOneWidget);

      // Same registry, same runner code — only the envelope's engine_key
      // changed, exactly as a backend content edit would.
      await tester.pumpWidget(
        host(
          envelope: envelope(engineKey: 'fake-b'),
          registry: registry,
          telemetry: telemetryB,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ENGINE B'), findsOneWidget);
      expect(find.text('ENGINE A'), findsNothing);
    },
  );

  testWidgets(
    'shows a friendly fallback for an engine the app has never heard of',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseRunner(
              envelope: envelope(engineKey: 'does-not-exist'),
              registry: registry,
              telemetry: telemetry,
              feedback: _RecordingFeedback(),
              audio: InMemoryAudioResolver(),
              locale: const Locale('fr', 'CA'),
              onFinished: (_) {},
              unsupportedBuilder: (context, reason) =>
                  Text('FALLBACK: $reason'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('FALLBACK:'), findsOneWidget);
      expect(find.text('ENGINE A'), findsNothing);
    },
  );

  testWidgets(
    'shows a friendly fallback when the installed engine is older than required',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          version: 1,
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseRunner(
              envelope: envelope(engineKey: 'fake-a', engineMinVersion: 2),
              registry: registry,
              telemetry: telemetry,
              feedback: _RecordingFeedback(),
              audio: InMemoryAudioResolver(),
              locale: const Locale('fr', 'CA'),
              onFinished: (_) {},
              unsupportedBuilder: (context, reason) =>
                  Text('FALLBACK: $reason'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('FALLBACK:'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a friendly fallback rather than crashing on invalid content',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          validateImpl: (_) => const EngineValidation.invalid('bad content'),
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseRunner(
              envelope: envelope(engineKey: 'fake-a'),
              registry: registry,
              telemetry: telemetry,
              feedback: _RecordingFeedback(),
              audio: InMemoryAudioResolver(),
              locale: const Locale('fr', 'CA'),
              onFinished: (_) {},
              unsupportedBuilder: (context, reason) =>
                  Text('FALLBACK: $reason'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FALLBACK: bad content'), findsOneWidget);
      expect(find.text('ENGINE A'), findsNothing);
    },
  );

  testWidgets(
    'starts telemetry with the resolved identity before the engine builds',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          version: 7,
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: outbox) = buildTelemetry();

      await tester.pumpWidget(
        host(
          envelope: envelope(engineKey: 'fake-a', engineMinVersion: 1),
          registry: registry,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();

      final start = outbox.all.single;
      expect(start['event_type'], 'exercise_start');
      expect(start['exercise_id'], '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e');
      expect(start['exercise_version'], 3);
      expect(start['engine_key'], 'fake-a');
      // The engine that actually rendered, not the backend's minimum.
      expect(start['engine_version'], 7);
      expect(start['skill_node_id'], 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53');
      expect(start['subject'], 'MATH');
      expect(start['grade'], 1);
      expect(start['rank'], 2);
    },
  );

  testWidgets('logs completion and forwards the result exactly once', (
    tester,
  ) async {
    late EngineContext captured;
    final registry = EngineRegistry([
      _FakeEngine(
        engineKey: 'fake-a',
        buildImpl: (context, _) {
          captured = context;
          return const Text('ENGINE A');
        },
      ),
    ]);
    final (client: telemetry, outbox: outbox) = buildTelemetry();

    final finishedResults = <ExerciseResult>[];

    await tester.pumpWidget(
      host(
        envelope: envelope(engineKey: 'fake-a'),
        registry: registry,
        telemetry: telemetry,
        onFinished: finishedResults.add,
      ),
    );
    await tester.pumpAndSettle();

    const result = ExerciseResult(
      outcome: ExerciseOutcome.completed,
      attempts: 2,
      correct: 1,
      elapsedMs: 4000,
    );

    captured.onFinished(result);
    // A buggy engine calling onFinished twice must not double-log or
    // double-notify the host.
    captured.onFinished(result);
    await tester.pumpAndSettle();

    expect(
      outbox.all.map((e) => e['event_type']),
      containsOnce('exercise_complete'),
    );
    expect(finishedResults, [result]);
  });

  testWidgets(
    'logs abandonment when disposed mid-run, without calling onFinished',
    (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: outbox) = buildTelemetry();
      var finishedCalls = 0;

      await tester.pumpWidget(
        host(
          envelope: envelope(engineKey: 'fake-a'),
          registry: registry,
          telemetry: telemetry,
          onFinished: (_) => finishedCalls++,
        ),
      );
      await tester.pumpAndSettle();

      // The host navigates away on its own — e.g. the kid pressed the device
      // back button — without the engine ever reporting a result.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        outbox.all.map((e) => e['event_type']),
        containsOnce('exercise_abandon'),
      );
      expect(finishedCalls, 0);
    },
  );

  testWidgets(
    'merges common settings with the engine manifest, with overrides applied',
    (tester) async {
      late EngineContext captured;
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          settingsManifest: const SettingsManifest(
            engineKey: 'fake-a',
            definitions: [
              SettingDefinition(
                key: 'wobble',
                type: SettingType.toggle,
                defaultValue: false,
                labelFr: 'Wobble',
                labelEn: 'Wobble',
              ),
            ],
          ),
          buildImpl: (context, _) {
            captured = context;
            return const Text('ENGINE A');
          },
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        host(
          envelope: envelope(engineKey: 'fake-a'),
          registry: registry,
          telemetry: telemetry,
          settingsOverrides: const {'wobble': true, 'hints': false},
        ),
      );
      await tester.pumpAndSettle();

      // A common setting (declared nowhere in this engine's own manifest)...
      expect(captured.settings.toggle('hints', fallback: true), isFalse);
      // ...alongside the engine's own setting, both from one merged manifest.
      expect(captured.settings.toggle('wobble'), isTrue);
    },
  );

  group('read-aloud audio', () {
    testWidgets('no audio_ref means no speaker button', (tester) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();

      await tester.pumpWidget(
        host(
          envelope: envelope(
            engineKey: 'fake-a',
          ), // default prompt has audio_ref: null
          registry: registry,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets(
      'an audio_ref shows a speaker button, disabled until the resolver answers',
      (tester) async {
        final registry = EngineRegistry([
          _FakeEngine(
            engineKey: 'fake-a',
            buildImpl: (_, _) => const Text('ENGINE A'),
          ),
        ]);
        final (client: telemetry, outbox: _) = buildTelemetry();
        final resolver = InMemoryAudioResolver();
        final envelopeWithAudio = {
          ...envelope(engineKey: 'fake-a'),
          'prompt': {
            'text': 'Quel nombre ?',
            'audio_ref': 'audio',
            'image_ref': null,
          },
        };

        await tester.pumpWidget(
          host(
            envelope: envelopeWithAudio,
            registry: registry,
            telemetry: telemetry,
            audio: resolver,
          ),
        );
        await tester.pump();

        // The speaker sits to the left of the question (Hafid, 2026-10-25).
        expect(
          tester.getCenter(find.byIcon(Icons.volume_up)).dx,
          lessThan(tester.getCenter(find.text('Quel nombre ?')).dx),
        );

        final buttonBefore = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.volume_up),
        );
        expect(buttonBefore.onPressed, isNull, reason: 'not resolved yet');

        resolver.put(
          '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          'audio',
          Uint8List.fromList([1, 2, 3]),
        );
        // Resolution only happens once per exerciseId/audioRef — a second
        // pump re-triggers the microtask queue, not a fresh resolve.
        await tester.pumpWidget(
          host(
            envelope: envelopeWithAudio,
            registry: registry,
            telemetry: telemetry,
            audio: resolver,
          ),
        );
        await tester.pumpAndSettle();

        final buttonAfter = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.volume_up),
        );
        expect(
          buttonAfter.onPressed,
          isNotNull,
          reason: 'resolved now, so tappable',
        );
      },
    );

    testWidgets('tapping the button while enabled does not throw', (
      tester,
    ) async {
      final registry = EngineRegistry([
        _FakeEngine(
          engineKey: 'fake-a',
          buildImpl: (_, _) => const Text('ENGINE A'),
        ),
      ]);
      final (client: telemetry, outbox: _) = buildTelemetry();
      final resolver = InMemoryAudioResolver()
        ..put(
          '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          'audio',
          Uint8List.fromList([1, 2, 3]),
        );
      final envelopeWithAudio = {
        ...envelope(engineKey: 'fake-a'),
        'prompt': {
          'text': 'Quel nombre ?',
          'audio_ref': 'audio',
          'image_ref': null,
        },
      };

      await tester.pumpWidget(
        host(
          envelope: envelopeWithAudio,
          registry: registry,
          telemetry: telemetry,
          audio: resolver,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.volume_up));
      await tester.pumpAndSettle();
      // No assertion beyond "didn't throw" — real playback needs a real
      // platform audio channel this test environment doesn't have;
      // ExercisePromptAudio.play() is deliberately failure-swallowing
      // (see its own docstring), which this exercises.
    });
  });

  group('multi-question exercises', () {
    Map<String, Object?> multiQuestionEnvelope({
      required List<Map<String, Object?>> questions,
    }) {
      return envelope(engineKey: 'fake-a', config: {'questions': questions});
    }

    testWidgets(
      'renders the first question, not the second, until it finishes',
      (tester) async {
        late EngineContext captured;
        var buildCount = 0;
        final registry = EngineRegistry([
          _FakeEngine(
            engineKey: 'fake-a',
            buildImpl: (context, config) {
              buildCount += 1;
              captured = context;
              return Text('Q: ${config['correct']}');
            },
          ),
        ]);
        final (client: telemetry, outbox: outbox) = buildTelemetry();

        await tester.pumpWidget(
          host(
            envelope: multiQuestionEnvelope(
              questions: [
                {
                  'prompt': {'text': 'Un ?'},
                  'config': {'correct': 'a'},
                },
                {
                  'prompt': {'text': 'Deux ?'},
                  'config': {'correct': 'b'},
                },
              ],
            ),
            registry: registry,
            telemetry: telemetry,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Q: a'), findsOneWidget);
        expect(find.text('Un ?'), findsOneWidget);
        expect(buildCount, 1);
        // The first question's own real exercise_start, same as a
        // single-question run gets.
        expect(
          outbox.all.map((e) => e['event_type']),
          containsOnce('exercise_start'),
        );

        captured.onFinished(
          const ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: 1,
            correct: 1,
            elapsedMs: 100,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Q: b'), findsOneWidget);
        expect(find.text('Deux ?'), findsOneWidget);
        expect(buildCount, 2);
        // A second, independent exercise_start/exercise_complete pair for
        // question two, with its own exercise_run_id — not a continuation
        // of question one's run.
        expect(
          outbox.all.where((e) => e['event_type'] == 'exercise_start').length,
          2,
        );
        expect(
          outbox.all
              .where((e) => e['event_type'] == 'exercise_complete')
              .length,
          1,
        );
        final runIds = outbox.all.map((e) => e['exercise_run_id']).toSet();
        expect(runIds.length, 2, reason: 'each question gets its own run id');
      },
    );

    testWidgets(
      'calls the host onFinished exactly once, with aggregated totals, after the last question',
      (tester) async {
        EngineContext? captured;
        final registry = EngineRegistry([
          _FakeEngine(
            engineKey: 'fake-a',
            buildImpl: (context, config) {
              captured = context;
              return Text('Q: ${config['correct']}');
            },
          ),
        ]);
        final (client: telemetry, outbox: _) = buildTelemetry();
        final finished = <ExerciseResult>[];

        await tester.pumpWidget(
          host(
            envelope: multiQuestionEnvelope(
              questions: [
                {
                  'prompt': {'text': 'Un ?'},
                  'config': {'correct': 'a'},
                },
                {
                  'prompt': {'text': 'Deux ?'},
                  'config': {'correct': 'b'},
                },
              ],
            ),
            registry: registry,
            telemetry: telemetry,
            onFinished: finished.add,
          ),
        );
        await tester.pumpAndSettle();

        captured!.onFinished(
          const ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: 1,
            correct: 1,
            elapsedMs: 100,
          ),
        );
        await tester.pumpAndSettle();
        expect(finished, isEmpty, reason: 'one question down, one to go');

        captured!.onFinished(
          const ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: 2,
            correct: 1,
            elapsedMs: 300,
          ),
        );
        await tester.pumpAndSettle();

        expect(finished, hasLength(1));
        final aggregate = finished.single;
        expect(aggregate.outcome, ExerciseOutcome.completed);
        expect(aggregate.attempts, 3); // 1 + 2
        expect(aggregate.correct, 2); // 1 + 1
        expect(aggregate.elapsedMs, 400); // 100 + 300
        expect(aggregate.questionResults, hasLength(2));
        expect(aggregate.questionResults[0].isFirstTryPerfect, isTrue);
        expect(aggregate.questionResults[1].isFirstTryPerfect, isFalse);
      },
    );

    testWidgets(
      'a single-question exercise still has an empty questionResults',
      (tester) async {
        late EngineContext captured;
        final registry = EngineRegistry([
          _FakeEngine(
            engineKey: 'fake-a',
            buildImpl: (context, _) {
              captured = context;
              return const Text('ENGINE A');
            },
          ),
        ]);
        final (client: telemetry, outbox: _) = buildTelemetry();
        final finished = <ExerciseResult>[];

        await tester.pumpWidget(
          host(
            envelope: envelope(engineKey: 'fake-a'),
            registry: registry,
            telemetry: telemetry,
            onFinished: finished.add,
          ),
        );
        await tester.pumpAndSettle();

        captured.onFinished(
          const ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: 1,
            correct: 1,
            elapsedMs: 100,
          ),
        );
        await tester.pumpAndSettle();

        expect(finished.single.questionResults, isEmpty);
      },
    );
  });
}

class _FakeEngine extends TutolysEngine {
  _FakeEngine({
    required this.engineKey,
    this.version = 1,
    this.settingsManifest = const SettingsManifest(
      engineKey: 'fake',
      definitions: [],
    ),
    EngineValidation Function(Map<String, Object?>)? validateImpl,
    required this.buildImpl,
  }) : _validateImpl = validateImpl ?? ((_) => const EngineValidation.valid());

  final String engineKey;
  @override
  final int version;
  @override
  final SettingsManifest settingsManifest;
  final EngineValidation Function(Map<String, Object?>) _validateImpl;
  final Widget Function(EngineContext, Map<String, Object?>) buildImpl;

  @override
  String get key => engineKey;

  @override
  String get category => 'general';

  @override
  EngineValidation validate(Map<String, Object?> config) =>
      _validateImpl(config);

  @override
  Widget build(EngineContext context, Map<String, Object?> config) =>
      buildImpl(context, config);
}

class _RecordingFeedback implements EngineFeedback {
  final calls = <String>[];

  @override
  Future<void> correct() async => calls.add('correct');

  @override
  Future<void> incorrect() async => calls.add('incorrect');

  @override
  Future<void> celebrate() async => calls.add('celebrate');

  @override
  Future<void> hint() async => calls.add('hint');
}

/// `containsOnce(x)` — a plain `contains` would also pass if `x` appeared
/// twice, which is exactly the double-logging bug this guards against.
Matcher containsOnce(Object? value) => predicate<Iterable<Object?>>(
  (iterable) => iterable.where((e) => e == value).length == 1,
  'contains "$value" exactly once',
);
