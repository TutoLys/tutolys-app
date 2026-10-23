import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_harness.dart';

/// Same content shape as mcq's sample, plus `time_limit_ms` — the one new
/// field this engine's content contract adds.
const _sampleConfig = {
  'options': [
    {'id': 'a', 'label': '5'},
    {'id': 'b', 'label': '7'},
    {'id': 'c', 'label': '9'},
  ],
  'correct': 'b',
  'time_limit_ms': 5000,
  'shuffle': false,
};

void main() {
  const engine = SpeedTapEngine();

  group('validate', () {
    test('accepts the real sample content', () {
      expect(engine.validate(_sampleConfig).isValid, isTrue);
    });

    test('rejects a missing time_limit_ms', () {
      final config = Map<String, Object?>.from(_sampleConfig)
        ..remove('time_limit_ms');
      expect(engine.validate(config).isValid, isFalse);
    });

    test('rejects a time_limit_ms outside 1000-60000', () {
      expect(
        engine.validate({..._sampleConfig, 'time_limit_ms': 500}).isValid,
        isFalse,
      );
      expect(
        engine.validate({..._sampleConfig, 'time_limit_ms': 70000}).isValid,
        isFalse,
      );
    });

    test('rejects fewer than 2 options', () {
      final result = engine.validate({
        'options': [
          {'id': 'a', 'label': '7'},
        ],
        'correct': 'a',
        'time_limit_ms': 5000,
      });
      expect(result.isValid, isFalse);
    });

    test('rejects a correct id that names no option', () {
      final result = engine.validate({
        'options': [
          {'id': 'a', 'label': '7'},
          {'id': 'b', 'label': '4'},
        ],
        'correct': 'z',
        'time_limit_ms': 5000,
      });
      expect(result.isValid, isFalse);
    });
  });

  group('play', () {
    Future<EngineHarness> pumpSpeedTap(
      WidgetTester tester, {
      Map<String, Object?>? overrides,
    }) async {
      final harness = await EngineHarness.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: engine.build(
              harness.context(settingsOverrides: overrides ?? const {}),
              _sampleConfig,
            ),
          ),
        ),
      );
      await tester.pump();
      return harness;
    }

    testWidgets('a correct tap completes the run before time runs out', (
      tester,
    ) async {
      final harness = await pumpSpeedTap(tester);

      await tester.tap(find.text('7')); // id b, correct
      await tester.pump();
      await tester.pump();

      expect(harness.feedback.calls, ['correct', 'celebrate']);
      expect(harness.finished, hasLength(1));
      expect(harness.finished.single.outcome, ExerciseOutcome.completed);
    });

    testWidgets('a wrong tap gives gentle feedback and restarts the clock', (
      tester,
    ) async {
      final harness = await pumpSpeedTap(tester);

      await tester.tap(find.text('5')); // id a, wrong
      await tester.pump();
      await tester.pump();

      expect(harness.feedback.calls, ['incorrect']);
      expect(harness.finished, isEmpty);
      final attempt = harness.attempts.single;
      expect(attempt['answer_payload'], {'selected': 'a'});
      expect(attempt['is_correct'], isFalse);

      // The clock restarted: a correct tap now still completes the run.
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.pump();
      expect(harness.finished, hasLength(1));
    });

    testWidgets(
      'running out the clock logs a wrong attempt and restarts, never an abandon',
      (tester) async {
        final harness = await pumpSpeedTap(tester);

        await tester.pump(const Duration(milliseconds: 5100));

        expect(harness.feedback.calls, ['incorrect']);
        expect(harness.finished, isEmpty);
        final attempt = harness.attempts.single;
        expect(attempt['answer_payload'], {
          'selected': null,
          'timed_out': true,
        });
        expect(attempt['is_correct'], isFalse);

        // Still playable after a timeout — the retry-until-correct contract
        // every engine shares.
        await tester.tap(find.text('7'));
        await tester.pump();
        await tester.pump();
        expect(harness.finished, hasLength(1));
      },
    );

    testWidgets('a hint is revealed on request and logged once', (
      tester,
    ) async {
      final harness = await EngineHarness.start();
      final configWithHint = {
        ..._sampleConfig,
        'hint': 'Compte sur tes doigts.',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: engine.build(harness.context(), configWithHint)),
        ),
      );
      await tester.pump();

      expect(find.text('Compte sur tes doigts.'), findsNothing);
      await tester.tap(find.text('Indice'));
      await tester.pump();

      expect(find.text('Compte sur tes doigts.'), findsOneWidget);
      expect(harness.feedback.calls, ['hint']);
      expect(harness.hints, hasLength(1));
    });
  });
}
