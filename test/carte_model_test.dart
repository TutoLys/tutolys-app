import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/path/carte_model.dart';
import 'package:tutolys_app/features/path/learning_areas.dart';
import 'package:tutolys_app/features/path/skill_path.dart';

CachedSkillNode leaf(String id, String key, {String en = ''}) =>
    CachedSkillNode(
      id: id,
      labelFr: 'fr-$id',
      labelEn: en,
      stableKey: key,
      subject: 'MATH',
      grade: 1,
    );

SkillMasteryDto mastery(String id, double pct, {bool mastered = false}) =>
    SkillMasteryDto(skillNodeId: id, masteryPct: pct, isMastered: mastered);

List<PathSection> build(
  List<CachedSkillNode> leaves, {
  Set<String>? playable,
  List<SkillMasteryDto> masteries = const [],
  bool english = false,
  Set<String> completed = const {},
  String subject = 'MATH',
}) => buildCarteSections(
  subject: subject,
  leaves: leaves,
  playable: playable ?? leaves.map((l) => l.id).toSet(),
  masteries: masteries,
  appLocale: Locale(english ? 'en' : 'fr', 'CA'),
  completed: completed,
);

void main() {
  test('leaves group under their learning area, in the ministry order', () {
    final sections = build([
      leaf('g', 'mathematique/geometrie/b:A/o:1'),
      leaf('n', 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1'),
      leaf('o', 'mathematique/operations-sur-des-nombres/b:A/o:1'),
    ]);

    expect(sections.map((s) => s.title), ['Arithmétique', 'Géométrie']);
    // Two arithmetic strands share one title rather than splitting the path.
    expect(sections.first.nodes.map((n) => n.id).toSet(), {'n', 'o'});
  });

  test('titles follow the language', () {
    final sections = build([
      leaf('g', 'mathematique/geometrie/b:A/o:1', en: 'Shapes'),
    ], english: true);
    expect(sections.single.title, 'Geometry');
    expect(sections.single.nodes.single.label, 'Shapes');
  });

  test('a missing English label falls back to French, never to nothing', () {
    final sections = build([
      leaf('g', 'mathematique/geometrie/b:A/o:1'),
    ], english: true);
    expect(sections.single.nodes.single.label, 'fr-g');
  });

  test('a leaf no area claims goes last, untitled', () {
    final sections = build([
      leaf('x', 'mathematique/unknown-strand/b:A/o:1'),
      leaf('g', 'mathematique/geometrie/b:A/o:1'),
    ]);
    expect(sections.map((s) => s.title), ['Géométrie', null]);
  });

  test('objectives order numerically, so o:2 comes before o:10', () {
    final sections = build([
      leaf('ten', 'mathematique/mesure/b:A/o:10'),
      leaf('two', 'mathematique/mesure/b:A/o:2'),
    ]);
    expect(sections.single.nodes.map((n) => n.id), ['two', 'ten']);
  });

  test('states are real: mastered, one active frontier, then locked', () {
    final sections = build(
      [
        leaf('a', 'mathematique/mesure/b:A/o:1'),
        leaf('b', 'mathematique/mesure/b:A/o:2'),
        leaf('c', 'mathematique/mesure/b:A/o:3'),
        leaf('d', 'mathematique/mesure/b:A/o:4'),
      ],
      playable: {'a', 'b', 'c'},
      masteries: [mastery('a', 90, mastered: true), mastery('b', 60)],
    );

    final nodes = sections.single.nodes;
    expect(nodes.map((n) => n.state), [
      PathNodeState.mastered,
      PathNodeState.active,
      PathNodeState.locked,
      PathNodeState.soon,
    ]);
    expect(nodes[1].masteryPct, closeTo(0.6, 1e-9));
  });

  test('never-played is null, not zero — the card must not show a score', () {
    final sections = build([leaf('a', 'mathematique/mesure/b:A/o:1')]);
    expect(sections.single.nodes.single.masteryPct, isNull);
  });

  test('only one node is active across all sections', () {
    final sections = build([
      leaf('n', 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1'),
      leaf('g', 'mathematique/geometrie/b:A/o:1'),
    ]);
    final states = sections.expand((s) => s.nodes).map((n) => n.state);
    expect(states.where((s) => s == PathNodeState.active), hasLength(1));
  });

  test('a mastered leaf with nothing synced still shows as mastered', () {
    final sections = build(
      [leaf('a', 'mathematique/mesure/b:A/o:1')],
      playable: const {},
      masteries: [mastery('a', 85, mastered: true)],
    );
    expect(sections.single.nodes.single.state, PathNodeState.mastered);
  });

  test('strandOf reads both key grammars', () {
    expect(strandOf('mathematique/mesure/b:A/o:1/s:a'), 'mesure');
    expect(
      strandOf('mathematique/strand/geometrie/block/A/obj/1/leaf/000_A'),
      'geometrie',
    );
    expect(strandOf('math'), isNull);
  });

  group('completed on this device', () {
    final three = [
      leaf('a', 'mathematique/mesure/b:A/o:1'),
      leaf('b', 'mathematique/mesure/b:A/o:2'),
      leaf('c', 'mathematique/mesure/b:A/o:3'),
    ];

    test('a finished node is completed, and the fox moves past it', () {
      final nodes = build(three, completed: {'a'}).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.completed,
        PathNodeState.active,
        PathNodeState.locked,
      ]);
    });

    test('mastery outranks completion: gold stays the server\'s', () {
      final nodes = build(
        three,
        completed: {'a'},
        masteries: [mastery('a', 90, mastered: true)],
      ).single.nodes;
      expect(nodes.first.state, PathNodeState.mastered);
      expect(nodes[1].state, PathNodeState.active);
    });

    test('everything finished: no active node, nothing invented', () {
      final nodes = build(three, completed: {'a', 'b', 'c'}).single.nodes;
      expect(nodes.every((n) => n.state == PathNodeState.completed), isTrue);
    });

    test('nothing synced to play is "soon", even if once finished', () {
      final nodes = build(
        three,
        playable: {'b', 'c'},
        completed: {'a'},
      ).single.nodes;
      expect(
        nodes.first.state,
        PathNodeState.soon,
        reason: 'a completed node with no exercise could not be replayed',
      );
    });
  });

  group('skill names follow the subject\'s language', () {
    test('maths follows the app: English when the app is', () {
      final node = build([
        leaf('a', 'mathematique/mesure/b:A/o:1', en: 'Measure'),
      ], english: true).single.nodes.single;
      expect(node.label, 'Measure');
    });

    test('a missing English name falls back to French, never blank', () {
      final node = build([
        leaf('a', 'mathematique/mesure/b:A/o:1'),
      ], english: true).single.nodes.single;
      expect(node.label, 'fr-a');
    });

    test('Français stays French in an English app', () {
      final node = build(
        [leaf('a', 'francais-langue/lire/b:A/o:1', en: 'Read')],
        english: true,
        subject: 'FR',
      ).expand((s) => s.nodes).single;
      expect(node.label, 'fr-a');
    });

    test('English stays English in a French app', () {
      final node = build([
        leaf('a', 'english-language-arts/reading/b:A/o:1', en: 'Read'),
      ], subject: 'EN').expand((s) => s.nodes).single;
      expect(node.label, 'Read');
    });
  });

  test('a lesson count rides only on a node with more than one lesson', () {
    final nodes = buildCarteSections(
      subject: 'MATH',
      leaves: [
        leaf('a', 'mathematique/geometrie/b:A/o:1'),
        leaf('b', 'mathematique/geometrie/b:A/o:2'),
      ],
      playable: {'a', 'b'},
      masteries: const [],
      appLocale: const Locale('fr', 'CA'),
      lessonCounts: const {'a': (2, 4), 'b': (0, 1)},
      describeLessons: (d, t) => '$d/$t',
    ).single.nodes;

    expect(nodes[0].lessons, (2, 4));
    expect(nodes[0].lessonsLabel, '2/4');
    expect(nodes[0].state, PathNodeState.active, reason: 'not all done');
    expect(nodes[1].lessons, isNull);
  });

  group('unlocking is sequential (ADR 0032)', () {
    final four = [
      leaf('a', 'mathematique/mesure/b:A/o:1'),
      leaf('b', 'mathematique/mesure/b:A/o:2'),
      leaf('c', 'mathematique/mesure/b:A/o:3'),
      leaf('d', 'mathematique/mesure/b:A/o:4'),
    ];

    test('a node opens only once the playable one before it is done', () {
      final nodes = build(four).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.active,
        PathNodeState.locked,
        PathNodeState.locked,
        PathNodeState.locked,
      ]);
    });

    test('a node with no lesson is skipped, never what blocks the path', () {
      // Hafid's screenshot: 1 done, 2 had no lesson, 3 done, 4 next.
      final nodes = build(
        four,
        playable: {'a', 'c', 'd'},
        completed: {'a', 'c'},
      ).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.completed,
        PathNodeState.soon,
        PathNodeState.completed,
        PathNodeState.active,
      ]);
    });

    test('an unfinished node keeps everything after it locked', () {
      final nodes = build(
        four,
        playable: {'a', 'b', 'c', 'd'},
        completed: {'a', 'c'},
      ).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.completed,
        PathNodeState.active,
        PathNodeState.completed,
        PathNodeState.locked,
      ], reason: 'a node done earlier stays done and replayable');
    });

    test('server mastery counts as done for the sequence', () {
      final nodes = build(
        four,
        masteries: [mastery('a', 95, mastered: true)],
      ).single.nodes;
      expect(nodes[1].state, PathNodeState.active);
    });
  });
}
