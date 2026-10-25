import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each reaction call becomes a runtime event and keeps its beat',
    () async {
      final bridge = LegacyFeedbackBridge(
        beat: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.dispose);
      final seen = <RuntimeEvent>[];
      bridge.events.listen(seen.add);

      final sw = Stopwatch()..start();
      await bridge.incorrect();
      await bridge.correct();
      await bridge.hint();
      expect(
        sw.elapsedMilliseconds,
        greaterThanOrEqualTo(60),
        reason: 'engines still get their pause',
      );

      final verdicts = seen.whereType<AnswerEvaluated>().toList();
      expect(verdicts.map((v) => v.result.outcome), [
        Outcome.incorrect,
        Outcome.correct,
      ]);
      expect(verdicts.map((v) => v.result.attemptNumber), [1, 2]);
      expect(verdicts.every((v) => v.result.evaluator == 'legacy'), isTrue);
      expect(seen.whereType<HintRequested>(), hasLength(1));
    },
  );

  test('celebrate adds a beat but no second verdict', () async {
    final bridge = LegacyFeedbackBridge(beat: Duration.zero);
    addTearDown(bridge.dispose);
    final seen = <RuntimeEvent>[];
    bridge.events.listen(seen.add);
    await bridge.correct();
    await bridge.celebrate();
    await pumpEventQueue();
    expect(seen, hasLength(1));
  });

  test('calls after dispose are harmless', () async {
    final bridge = LegacyFeedbackBridge(beat: Duration.zero)..dispose();
    await bridge.correct();
  });
}
