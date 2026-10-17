import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_harness.dart';

/// Content taken verbatim from
/// `tutolys-backend/content/samples/fr_syllables.json`'s `config`.
const _sampleConfig = {
  'tiles': [
    {'id': 'cha', 'label': 'cha'},
    {'id': 'peau', 'label': 'peau'},
    {'id': 'mi', 'label': 'mi'},
    {'id': 'ton', 'label': 'ton'},
  ],
  'target': ['cha', 'peau'],
  'ordered': true,
  'hint': 'Écoute les deux syllabes.',
};

void main() {
  const engine = ComposeBuildEngine();

  group('validate', () {
    test('accepts the real sample content', () {
      expect(engine.validate(_sampleConfig).isValid, isTrue);
    });

    test('rejects an empty target', () {
      final result = engine.validate({
        'tiles': [
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'B'},
        ],
        'target': <String>[],
      });
      expect(result.isValid, isFalse);
    });

    test('rejects a target id with no matching tile', () {
      final result = engine.validate({
        'tiles': [
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'B'},
        ],
        'target': ['a', 'z'],
      });
      expect(result.isValid, isFalse);
    });

    test('rejects fewer than 2 tiles', () {
      final result = engine.validate({
        'tiles': [
          {'id': 'a', 'label': 'A'},
        ],
        'target': ['a'],
      });
      expect(result.isValid, isFalse);
    });
  });

  group('play — ordered', () {
    Future<EngineHarness> pumpCompose(WidgetTester tester) async {
      final harness = await EngineHarness.start();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: engine.build(harness.context(), _sampleConfig),
        ),
      ));
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('assembling the target in order completes the run', (tester) async {
      final harness = await pumpCompose(tester);

      await tester.tap(find.text('cha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('peau'));
      await tester.pumpAndSettle();

      expect(harness.finished, hasLength(1));
      final result = harness.finished.single;
      expect(result.outcome, ExerciseOutcome.completed);

      final attempt = harness.attempts.single;
      expect(attempt['answer_payload'], {'sequence': ['cha', 'peau']});
      expect(attempt['is_correct'], isTrue);
    });

    testWidgets('the wrong order is wrong, and the bank resets for another try', (tester) async {
      final harness = await pumpCompose(tester);

      await tester.tap(find.text('peau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cha'));
      await tester.pump();
      // The bank reset is behind a short delay (so a kid sees the wrong
      // answer before it clears) — pumpAndSettle alone won't flush a bare
      // Future.delayed that isn't tied to a scheduled frame.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(harness.feedback.calls, ['incorrect']);
      expect(harness.finished, isEmpty);

      // The bank is whole again — both tiles can be tapped once more.
      await tester.tap(find.text('cha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('peau'));
      await tester.pumpAndSettle();

      expect(harness.finished, hasLength(1));
      expect(harness.attempts, hasLength(2));
    });

    testWidgets('tapping a placed tile returns it to the bank', (tester) async {
      final harness = await pumpCompose(tester);

      await tester.tap(find.text('cha'));
      await tester.pumpAndSettle();
      // Undo: the slot holding "cha" is tappable too.
      await tester.tap(find.text('cha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('peau'));
      await tester.pumpAndSettle();

      // Only one tile placed ("peau") — not yet at target length, so no
      // check has run.
      expect(harness.attempts, isEmpty);
    });
  });

  group('play — unordered', () {
    testWidgets('any arrangement of the right tiles is accepted when ordered is false', (tester) async {
      final harness = await EngineHarness.start();
      final config = {..._sampleConfig, 'ordered': false};

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: engine.build(harness.context(), config)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('peau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cha'));
      await tester.pumpAndSettle();

      expect(harness.finished, hasLength(1));
      expect(harness.finished.single.outcome, ExerciseOutcome.completed);
    });
  });
}
