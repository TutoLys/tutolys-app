import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/path/carte_model.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/path/subject_language.dart';

const fr = Locale('fr', 'CA');
const en = Locale('en', 'CA');

Map<String, Object?> lesson(
  String id,
  String node,
  String locale, {
  int rank = 0,
}) => {
  'exercise_id': id,
  'skill_node_id': node,
  'rank': rank,
  'locale': locale,
};

void main() {
  group('which language a subject asks for', () {
    test('Français and English keep their own language', () {
      expect(contentLocaleFor('FR', en), 'fr-CA');
      expect(contentLocaleFor('EN', fr), 'en-CA');
    });

    test('every other subject follows the app', () {
      for (final s in ['MATH', 'SCI', 'SOC', 'CCQ']) {
        expect(contentLocaleFor(s, en), 'en-CA', reason: s);
        expect(contentLocaleFor(s, fr), 'fr-CA', reason: s);
      }
    });
  });

  group('one lesson per node, in the kid\'s language', () {
    test('the version in the asked language wins', () {
      final picked = pickLessonsByNode([
        lesson('a-fr', 'a', 'fr-CA'),
        lesson('a-en', 'a', 'en-CA'),
      ], locale: 'en-CA');
      expect(picked['a']!['exercise_id'], 'a-en');
    });

    test('no version in it: French, never nothing', () {
      final picked = pickLessonsByNode([
        lesson('a-fr', 'a', 'fr-CA'),
      ], locale: 'en-CA');
      expect(picked['a']!['exercise_id'], 'a-fr');
    });

    test(
      'a sibling\'s English version doesn\'t replace French for a French kid',
      () {
        final picked = pickLessonsByNode([
          lesson('a-en', 'a', 'en-CA'),
          lesson('a-fr', 'a', 'fr-CA'),
        ], locale: 'fr-CA');
        expect(picked['a']!['exercise_id'], 'a-fr');
      },
    );

    test('still the first rank per node', () {
      final picked = pickLessonsByNode([
        lesson('r0', 'a', 'fr-CA'),
        lesson('r1', 'a', 'fr-CA', rank: 1),
      ], locale: 'fr-CA');
      expect(picked['a']!['exercise_id'], 'r0');
    });
  });

  group('the Carte marks a lesson in the other language', () {
    final leaves = [
      const CachedSkillNode(
        id: 'a',
        labelFr: 'Mesurer',
        labelEn: '',
        stableKey: 'mathematique/mesure/b:A/o:1',
        subject: 'MATH',
        grade: 1,
      ),
    ];

    test('a French lesson in an English-mode maths path is tagged FR', () {
      final node = buildCarteSections(
        subject: 'MATH',
        leaves: leaves,
        playable: {'a'},
        masteries: const [],
        appLocale: en,
        lessonLocales: {'a': 'fr-CA'},
        describeLanguage: (l) => 'Lesson in French',
      ).single.nodes.single;
      expect(node.otherLanguage, 'FR');
      expect(node.otherLanguageLabel, 'Lesson in French');
    });

    test('a lesson in the asked language carries no tag', () {
      final node = buildCarteSections(
        subject: 'MATH',
        leaves: leaves,
        playable: {'a'},
        masteries: const [],
        appLocale: fr,
        lessonLocales: {'a': 'fr-CA'},
      ).single.nodes.single;
      expect(node.otherLanguage, isNull);
    });

    test(
      'Français in an English app is not "other": it is its own language',
      () {
        final node = buildCarteSections(
          subject: 'FR',
          leaves: [
            const CachedSkillNode(
              id: 'f',
              labelFr: 'Lire',
              labelEn: '',
              stableKey: 'francais-langue/lire/b:A/o:1',
              subject: 'FR',
              grade: 1,
            ),
          ],
          playable: {'f'},
          masteries: const [],
          appLocale: en,
          lessonLocales: {'f': 'fr-CA'},
        ).expand((s) => s.nodes).single;
        expect(node.otherLanguage, isNull);
      },
    );
  });
}
