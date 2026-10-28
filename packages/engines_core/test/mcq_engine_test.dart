import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_harness.dart';

/// Content taken verbatim from
/// `tutolys-backend/content/samples/math_even_odd.json`'s `config`, so this
/// test exercises exactly what an authored exercise looks like.
const _sampleConfig = {
  'options': [
    {'id': 'a', 'label': '7'},
    {'id': 'b', 'label': '4'},
    {'id': 'c', 'label': '9'},
  ],
  'correct': 'b',
  'shuffle': true,
  'hint': 'Un nombre pair se termine par 0, 2, 4, 6 ou 8.',
};

void main() {
  const engine = McqEngine();

  group('validate', () {
    test('accepts the real sample content', () {
      expect(engine.validate(_sampleConfig).isValid, isTrue);
    });

    test('rejects fewer than 2 options', () {
      final result = engine.validate({
        'options': [
          {'id': 'a', 'label': '7'},
        ],
        'correct': 'a',
      });
      expect(result.isValid, isFalse);
    });

    test('rejects more than 6 options', () {
      final result = engine.validate({
        'options': [
          for (var i = 0; i < 7; i++) {'id': 'o$i', 'label': '$i'},
        ],
        'correct': 'o0',
      });
      expect(result.isValid, isFalse);
    });

    test('rejects an option missing a label', () {
      final result = engine.validate({
        'options': [
          {'id': 'a', 'label': '7'},
          {'id': 'b'},
        ],
        'correct': 'a',
      });
      expect(result.isValid, isFalse);
    });

    test('rejects duplicate option ids', () {
      final result = engine.validate({
        'options': [
          {'id': 'a', 'label': '7'},
          {'id': 'a', 'label': '4'},
        ],
        'correct': 'a',
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
      });
      expect(result.isValid, isFalse);
    });
  });

  group('play', () {
    // Shuffle off so the options render in authoring order and the test can
    // tap by label deterministically.
    final config = {..._sampleConfig, 'shuffle': false};

    Future<EngineHarness> pumpMcq(
      WidgetTester tester, {
      Map<String, Object?>? overrides,
    }) async {
      final harness = await EngineHarness.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: engine.build(
              harness.context(settingsOverrides: overrides ?? const {}),
              config,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('a wrong pick gives gentle feedback and stays open', (
      tester,
    ) async {
      final harness = await pumpMcq(tester);

      await tester.tap(find.text('7')); // id a, wrong
      await tester.pumpAndSettle();

      expect(harness.feedback.calls, ['incorrect']);
      expect(harness.finished, isEmpty);

      final attempt = harness.attempts.single;
      expect(attempt['answer_payload'], {'selected': 'a'});
      expect(attempt['is_correct'], isFalse);
    });

    testWidgets('a wrong pick then the right one completes the run', (
      tester,
    ) async {
      final harness = await pumpMcq(tester);

      await tester.tap(find.text('9')); // id c, wrong
      await tester.pumpAndSettle();
      await tester.tap(find.text('4')); // id b, correct
      await tester.pumpAndSettle();

      expect(harness.feedback.calls, ['incorrect', 'correct', 'celebrate']);
      expect(harness.finished, hasLength(1));

      final result = harness.finished.single;
      expect(result.outcome, ExerciseOutcome.completed);
      expect(result.attempts, 2);
      expect(result.correct, 1);

      final isCorrectFlags = harness.attempts
          .map((e) => e['is_correct'])
          .toList();
      expect(isCorrectFlags, [false, true]);
    });

    testWidgets('answers are reported by id, never by label', (tester) async {
      final harness = await pumpMcq(tester);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      final attempt = harness.attempts.single;
      expect(attempt['answer_payload'], {'selected': 'b'});
    });

    testWidgets('a hint is revealed on request and logged once', (
      tester,
    ) async {
      final harness = await pumpMcq(tester);

      expect(
        find.text('Un nombre pair se termine par 0, 2, 4, 6 ou 8.'),
        findsNothing,
      );
      await tester.tap(find.text('Indice'));
      await tester.pumpAndSettle();

      expect(
        find.text('Un nombre pair se termine par 0, 2, 4, 6 ou 8.'),
        findsOneWidget,
      );
      expect(harness.feedback.calls, ['hint']);
      expect(harness.hints, hasLength(1));
    });

    testWidgets('the hint control is hidden when the hints setting is off', (
      tester,
    ) async {
      await pumpMcq(tester, overrides: {'hints': false});

      expect(find.text('Indice'), findsNothing);
    });
  });
}
