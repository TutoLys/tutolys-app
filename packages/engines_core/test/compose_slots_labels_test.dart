import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter_test/flutter_test.dart';

const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

ComposeContent parsed(Map<String, Object?> config) =>
    const ComposeSlotsEngine().parse(config).valueOrNull!;

void main() {
  const evaluator = ComposeBuildEvaluator();

  // "3 + 3 + 3 = 9" built from three separate "3" tiles.
  final sum = parsed({
    'tiles': [
      {'id': 'a', 'label': '3'},
      {'id': 'b', 'label': '3'},
      {'id': 'c', 'label': '3'},
      {'id': 'd', 'label': '4'},
    ],
    'target': ['a', 'b', 'c'],
  });

  // "balle": two "l" tiles.
  final balle = parsed({
    'tiles': [
      {'id': 'b', 'label': 'b'},
      {'id': 'a', 'label': 'a'},
      {'id': 'l1', 'label': 'l'},
      {'id': 'l2', 'label': 'l'},
      {'id': 'e', 'label': 'e'},
      {'id': 'i', 'label': 'i'},
    ],
    'target': ['b', 'a', 'l1', 'l2', 'e'],
  });

  test('ordered: identical labels are interchangeable', () {
    final r = evaluator.evaluate(sum, OrderingAnswer(['c', 'a', 'b']), ctx);
    expect(r.outcome, Outcome.correct);
    final word = evaluator.evaluate(
      balle,
      OrderingAnswer(['b', 'a', 'l2', 'l1', 'e']),
      ctx,
    );
    expect(word.outcome, Outcome.correct);
  });

  test('ordered: a different label in a slot is still wrong', () {
    final r = evaluator.evaluate(sum, OrderingAnswer(['a', 'd', 'b']), ctx);
    expect(r.outcome, Outcome.partial);
    expect(r.itemResults, {'0': true, '1': false, '2': true});
    final word = evaluator.evaluate(
      balle,
      OrderingAnswer(['b', 'a', 'l1', 'i', 'e']),
      ctx,
    );
    expect(word.itemResults['3'], isFalse);
  });

  test('unordered: labels count as a multiset', () {
    final loose = parsed({
      'tiles': [
        {'id': 'a', 'label': '3'},
        {'id': 'b', 'label': '3'},
        {'id': 'c', 'label': '5'},
        {'id': 'd', 'label': '5'},
      ],
      'target': ['a', 'c'],
      'ordered': false,
    });
    // Either 3 and either 5, any order.
    expect(
      evaluator.evaluate(loose, OrderingAnswer(['d', 'b']), ctx).outcome,
      Outcome.correct,
    );
    // Two 3s: only one is owed.
    expect(
      evaluator.evaluate(loose, OrderingAnswer(['a', 'b']), ctx).itemResults,
      {'0': true, '1': false},
    );
  });
}
