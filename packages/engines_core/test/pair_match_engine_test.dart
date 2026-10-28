import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_harness.dart';

/// Content taken verbatim from
/// `tutolys-backend/content/samples/fr_match_animals.json`'s `config`.
const _sampleConfig = {
  'pairs': [
    {
      'left': {'id': 'chat', 'label': 'chat'},
      'right': {'id': 'img_chat', 'label': '🐱'},
    },
    {
      'left': {'id': 'chien', 'label': 'chien'},
      'right': {'id': 'img_chien', 'label': '🐶'},
    },
    {
      'left': {'id': 'oiseau', 'label': 'oiseau'},
      'right': {'id': 'img_oiseau', 'label': '🐦'},
    },
  ],
  'distractors': [
    {'id': 'img_poisson', 'label': '🐟'},
  ],
  'hint': null,
};

void main() {
  const engine = PairMatchEngine();

  group('validate', () {
    test('accepts the real sample content', () {
      expect(engine.validate(_sampleConfig).isValid, isTrue);
    });

    test('rejects fewer than 2 pairs', () {
      final result = engine.validate({
        'pairs': [
          {
            'left': {'id': 'a', 'label': 'A'},
            'right': {'id': 'b', 'label': 'B'},
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('rejects a pair missing a side', () {
      final result = engine.validate({
        'pairs': [
          {
            'left': {'id': 'a', 'label': 'A'},
          },
          {
            'left': {'id': 'c', 'label': 'C'},
            'right': {'id': 'd', 'label': 'D'},
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('rejects more than 4 distractors', () {
      final result = engine.validate({
        'pairs': [
          {
            'left': {'id': 'a', 'label': 'A'},
            'right': {'id': 'b', 'label': 'B'},
          },
          {
            'left': {'id': 'c', 'label': 'C'},
            'right': {'id': 'd', 'label': 'D'},
          },
        ],
        'distractors': [
          for (var i = 0; i < 5; i++) {'id': 'x$i', 'label': 'X$i'},
        ],
      });
      expect(result.isValid, isFalse);
    });
  });

  group('play', () {
    Future<EngineHarness> pumpPairMatch(WidgetTester tester) async {
      final harness = await EngineHarness.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: engine.build(harness.context(), _sampleConfig)),
        ),
      );
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('matching all pairs completes the run', (tester) async {
      final harness = await pumpPairMatch(tester);

      await tester.tap(find.text('chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🐱'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('chien'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🐶'));
      await tester.pumpAndSettle();

      expect(harness.finished, isEmpty, reason: 'one pair still unmatched');

      await tester.tap(find.text('oiseau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🐦'));
      await tester.pumpAndSettle();

      expect(harness.finished, hasLength(1));
      final result = harness.finished.single;
      expect(result.outcome, ExerciseOutcome.completed);
      expect(result.correct, 3);
      expect(harness.feedback.calls.last, 'celebrate');
    });

    testWidgets(
      'a distractor can never be matched and counts as a wrong attempt',
      (tester) async {
        final harness = await pumpPairMatch(tester);

        await tester.tap(find.text('chat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('🐟')); // the distractor
        await tester.pumpAndSettle();

        expect(harness.feedback.calls, ['incorrect']);
        final attempt = harness.attempts.single;
        expect(attempt['is_correct'], isFalse);
        expect(attempt['answer_payload'], {
          'left': 'chat',
          'right': 'img_poisson',
        });
        expect(harness.finished, isEmpty);
      },
    );

    testWidgets('a wrong pair flashes amber, never red (the design)', (
      tester,
    ) async {
      await pumpPairMatch(tester);
      await tester.tap(find.text('chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🐶'));
      await tester.pump();
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('🐶'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(
        button.style!.side!.resolve(const {})!.color,
        VillagePalette.light.retry,
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a wrong guess reports both ids, never the emoji or label text',
      (tester) async {
        final harness = await pumpPairMatch(tester);

        await tester.tap(find.text('chat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('🐶')); // belongs to chien, not chat
        await tester.pumpAndSettle();

        final attempt = harness.attempts.single;
        expect(attempt['answer_payload'], {
          'left': 'chat',
          'right': 'img_chien',
        });
      },
    );

    testWidgets('tapping a right item with nothing selected does nothing', (
      tester,
    ) async {
      final harness = await pumpPairMatch(tester);

      await tester.tap(find.text('🐱'));
      await tester.pumpAndSettle();

      expect(harness.attempts, isEmpty);
    });
  });
}
