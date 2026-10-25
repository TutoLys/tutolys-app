import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/features/progress/local_progress.dart';

Map<String, Object?> lesson(
  String id,
  String node, {
  String subject = 'SCI',
  int rank = 0,
  String locale = 'fr-CA',
  String? group,
}) => {
  'exercise_id': id,
  'skill_node_id': node,
  'subject': subject,
  'engine_key': 'mcq',
  'rank': rank,
  'locale': locale,
  'lesson_group': ?group,
};

NodeProgress done(String node, Set<String> ids) => NodeProgress(
  skillNodeId: node,
  plays: ids.length,
  lastCompletedAt: DateTime(2026, 10, 25),
  everPerfect: false,
  exerciseIds: ids,
);

void main() {
  const fr = Locale('fr', 'CA');

  test('a node is its finished lessons over its lessons', () {
    final fractions = localNodeFractions(
      cached: [
        lesson('l0', 'n1'),
        lesson('l1', 'n1', rank: 1),
        lesson('m0', 'n2'),
      ],
      progress: {
        'n1': done('n1', {'l0'}),
      },
      appLocale: fr,
    );
    expect(fractions, {'n1': 0.5, 'n2': 0.0});
  });

  test('a node with nothing cached has no local measure at all', () {
    final fractions = localNodeFractions(
      cached: const [],
      progress: {
        'n1': done('n1', {'l0'}),
      },
      appLocale: fr,
    );
    expect(fractions.containsKey('n1'), isFalse);
  });

  test('a lesson\'s other-language version is not a second lesson', () {
    final fractions = localNodeFractions(
      cached: [
        lesson('fr', 'n1', group: 'g'),
        lesson('en', 'n1', locale: 'en-CA', group: 'g'),
      ],
      progress: {
        'n1': done('n1', {'fr'}),
      },
      appLocale: fr,
    );
    expect(fractions['n1'], 1.0);
  });

  group('shownNodeProgress', () {
    test('the further of server mastery and local lessons', () {
      expect(shownNodeProgress(masteryPct: 30, local: 0.5), 0.5);
      expect(shownNodeProgress(masteryPct: 90, local: 0.5), 0.9);
    });

    test('either alone, and null when neither knows the node', () {
      expect(shownNodeProgress(masteryPct: 40), closeTo(0.4, 1e-9));
      expect(shownNodeProgress(local: 0.25), 0.25);
      expect(shownNodeProgress(), isNull);
    });
  });
}
