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

  test('inside an area, strands keep the ministry order, not the alphabet', () {
    // Hafid, 2026-10-25: math opened on "opérations" and français on
    // "accords", because the whole area was sorted by stable_key.
    final math = build([
      leaf('op', 'mathematique/operations-sur-des-nombres/b:A/o:1'),
      leaf('so2', 'mathematique/sens-des-operations-sur-des-nombres/b:A/o:1'),
      leaf('se10', 'mathematique/sens-et-ecriture-des-nombres/b:A/o:10'),
      leaf('se2', 'mathematique/sens-et-ecriture-des-nombres/b:A/o:2'),
    ]);
    expect(math.single.title, 'Arithmétique');
    expect(math.single.nodes.map((n) => n.id), ['se2', 'se10', 'so2', 'op']);
    expect(math.single.nodes.first.state, PathNodeState.active);

    const ecrire =
        'francais-langue/competence-ecrire-des-textes-varies-section';
    final fr = build([
      leaf('acc', '$ecrire-accords-connaissances/b:A/o:1'),
      leaf('conj', '$ecrire-conjugaison-connaissances/b:A/o:1'),
      leaf('lex', '$ecrire-lexique-connaissances/b:A/o:1'),
    ], subject: 'FR');
    expect(fr.first.nodes.map((n) => n.id), ['lex', 'conj', 'acc']);
  });

  group('document order and areas from the backend (ADR 0044)', () {
    CachedSkillNode placed(
      String id,
      int order, {
      String? area,
      String? areaEn,
      int? ordinal,
    }) => CachedSkillNode(
      id: id,
      labelFr: 'fr-$id',
      labelEn: '',
      // Keys that would sort the other way: order must come from doc_order.
      stableKey: 'francais-langue/zz-$id/b:A/o:${100 - order}',
      subject: 'FR',
      grade: 1,
      docOrder: order,
      areaLabelFr: area,
      areaLabelEn: areaEn,
      areaOrdinal: ordinal,
    );

    test('areas and leaves follow the document, titled with its labels', () {
      final sections = build([
        placed('lire2', 30, area: 'Lire des textes variés', ordinal: 1),
        placed('ecr1', 10, area: 'Écrire des textes variés', ordinal: 0),
        placed('lire1', 20, area: 'Lire des textes variés', ordinal: 1),
        placed('ecr2', 12, area: 'Écrire des textes variés', ordinal: 0),
      ], subject: 'FR');
      expect(sections.map((s) => s.title), [
        'Écrire des textes variés',
        'Lire des textes variés',
      ]);
      expect(sections.first.nodes.map((n) => n.id), ['ecr1', 'ecr2']);
      expect(sections.last.nodes.map((n) => n.id), ['lire1', 'lire2']);
      expect(sections.first.nodes.first.state, PathNodeState.active);
    });

    test('a leaf with no area goes last, untitled, never dropped', () {
      final sections = build([
        placed('orphan', 5),
        placed('a', 10, area: 'Écrire des textes variés', ordinal: 0),
      ], subject: 'FR');
      expect(sections.map((s) => s.title), ['Écrire des textes variés', null]);
      expect(sections.last.nodes.single.id, 'orphan');
    });

    test('English titles when the backend has them, French otherwise', () {
      final sections = build(
        [
          placed(
            'n',
            1,
            area: 'Arithmétique',
            areaEn: 'Arithmetic',
            ordinal: 0,
          ),
          placed(
            'l',
            2,
            area: 'Lire des textes variés',
            areaEn: '',
            ordinal: 1,
          ),
        ],
        english: true,
        subject: 'FR',
      );
      expect(sections.map((s) => s.title), [
        'Arithmetic',
        'Lire des textes variés',
      ]);
    });

    test('a cache with any row from an older backend uses the table', () {
      final sections = build([
        placed('a', 1, area: 'Ignoré', ordinal: 0),
        leaf('g', 'mathematique/geometrie/b:A/o:1'),
      ]);
      expect(sections.map((s) => s.title), contains('Géométrie'));
      expect(sections.map((s) => s.title), isNot(contains('Ignoré')));
    });
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

  test('a mastered node never reads short: no "0/2" under a gold check', () {
    final sections = buildCarteSections(
      subject: 'MATH',
      leaves: [
        leaf('a', 'mathematique/mesure/b:A/o:1'),
        leaf('b', 'mathematique/mesure/b:A/o:2'),
        leaf('c', 'mathematique/mesure/b:A/o:3'),
      ],
      playable: {'a', 'b', 'c'},
      masteries: [
        mastery('a', 90, mastered: true),
        mastery('b', 95, mastered: true),
      ],
      appLocale: const Locale('fr', 'CA'),
      lessonCounts: {'a': (0, 2), 'b': (2, 2), 'c': (0, 2)},
      describeLessons: (done, total) => '$done/$total',
    );
    final [a, b, c] = sections.single.nodes;
    expect(a.state, PathNodeState.mastered);
    expect(a.lessons, isNull);
    expect(a.lessonsLabel, isNull);
    expect(b.lessons, (2, 2), reason: 'all done: the count agrees');
    expect(c.state, PathNodeState.active);
    expect(c.lessonsLabel, '0/2', reason: 'the node being played keeps it');
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
        nodes.singleWhere((n) => n.id == 'a').state,
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
      // The lessonless node trails the strand (K10).
      expect(nodes.map((n) => n.id), ['a', 'c', 'd', 'b']);
      expect(nodes.map((n) => n.state), [
        PathNodeState.completed,
        PathNodeState.completed,
        PathNodeState.active,
        PathNodeState.soon,
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
        PathNodeState.locked,
        PathNodeState.locked,
      ], reason: 'a node finished out of order waits its turn (Hafid)');
    });

    test('server mastery counts as done for the sequence', () {
      final nodes = build(
        four,
        masteries: [mastery('a', 95, mastered: true)],
      ).single.nodes;
      expect(nodes[1].state, PathNodeState.active);
    });

    test('server mastery past the frontier unlocks nothing', () {
      final nodes = build(
        four,
        masteries: [mastery('c', 95, mastered: true)],
      ).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.active,
        PathNodeState.locked,
        PathNodeState.locked,
        PathNodeState.locked,
      ]);
    });

    test('once the frontier reaches them, done nodes show done again', () {
      final nodes = build(
        four,
        completed: {'a', 'b', 'c'},
        masteries: [mastery('c', 95, mastered: true)],
      ).single.nodes;
      expect(nodes.map((n) => n.state), [
        PathNodeState.completed,
        PathNodeState.completed,
        PathNodeState.mastered,
        PathNodeState.active,
      ]);
    });

    test('the frontier spans sections: a later area waits too', () {
      final sections = build(
        [
          leaf('n', 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1'),
          leaf('g', 'mathematique/geometrie/b:A/o:1'),
        ],
        completed: {'g'},
      );
      expect(sections.first.nodes.single.state, PathNodeState.active);
      expect(sections.last.nodes.single.state, PathNodeState.locked);
    });

    test('a node with no lesson past the frontier is still "soon"', () {
      final nodes = build(four, playable: {'a', 'b', 'd'}).single.nodes;
      expect(nodes.singleWhere((n) => n.id == 'c').state, PathNodeState.soon);
    });
  });

  group('the node the Carte scrolls to', () {
    final three = [
      leaf('a', 'mathematique/mesure/b:A/o:1'),
      leaf('b', 'mathematique/mesure/b:A/o:2'),
      leaf('c', 'mathematique/mesure/b:A/o:3'),
    ];

    test('is the active node', () {
      expect(focusNodeIdOf(build(three, completed: {'a'})), 'b');
    });

    test('is the last one reached once every node is done', () {
      expect(focusNodeIdOf(build(three, completed: {'a', 'b', 'c'})), 'c');
    });

    test('is nothing when nothing is open', () {
      expect(focusNodeIdOf(build(three, playable: const {})), isNull);
    });
  });

  group('lessons before « Bientôt » (K10)', () {
    CachedSkillNode at(String id, int order, String area, int ordinal) =>
        CachedSkillNode(
          id: id,
          labelFr: 'fr-$id',
          labelEn: '',
          stableKey: 'fls/x/b:A/o:$order',
          subject: 'FLS',
          grade: 1,
          docOrder: order,
          areaLabelFr: area,
          areaOrdinal: ordinal,
        );

    // FLS on the dev-stack: a long "Stratégies" strand with no lessons,
    // then the one strand that has some.
    final fls = [
      for (var i = 0; i < 20; i++) at('s$i', i, 'Stratégies', 0),
      at('v1', 30, 'Vocabulaire', 1),
      at('v2', 31, 'Vocabulaire', 1),
      at('v3', 32, 'Vocabulaire', 1),
    ];

    test('a strand with no lesson moves after the strands that have one', () {
      final sections = build(fls, playable: {'v2'}, subject: 'FLS');
      expect(sections.map((s) => s.title), ['Vocabulaire', 'Stratégies']);
      expect(sections.first.nodes.first.id, 'v2');
      expect(sections.first.nodes.first.state, PathNodeState.active);
    });

    test('inside a strand, « Bientôt » nodes trail the playable ones', () {
      final nodes = build(fls, playable: {'v2', 'v3'}, subject: 'FLS')
          .first
          .nodes;
      expect(nodes.map((n) => n.id), ['v2', 'v3', 'v1']);
      expect(nodes.map((n) => n.state), [
        PathNodeState.active,
        PathNodeState.locked,
        PathNodeState.soon,
      ]);
    });

    test('nothing playable yet keeps the document order', () {
      final sections = build(fls, playable: const {}, subject: 'FLS');
      expect(sections.map((s) => s.title), ['Stratégies', 'Vocabulaire']);
    });
  });

  test('connectors are solid only between two open nodes (K10)', () {
    PathNode n(PathNodeState state) =>
        PathNode(id: state.name, label: '', state: state);
    expect(
      dottedConnectors([
        n(PathNodeState.completed),
        n(PathNodeState.active),
        n(PathNodeState.locked),
        n(PathNodeState.soon),
      ]),
      [false, true, true],
    );
    expect(
      dottedConnectors([n(PathNodeState.soon), n(PathNodeState.active)]),
      [true],
      reason: 'the line out of an hourglass was solid',
    );
  });
}
