import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/path/kid_label.dart';

CachedSkillNode _leaf({
  String fr = 'Compter',
  String en = '',
  String? shortFr,
  String? shortEn,
  String subject = 'MATH',
}) => CachedSkillNode(
  id: 'l',
  labelFr: fr,
  labelEn: en,
  stableKey: 'k',
  subject: subject,
  grade: 1,
  shortLabelFr: shortFr,
  shortLabelEn: shortEn,
);

void main() {
  group('trimLabel (AM9 fallback)', () {
    test('the review\'s two labels are cut at a word, never mid-word', () {
      expect(
        trimLabel(
          "par ordre croissant ou décroissant à partir d'un nombre donné",
        ),
        'par ordre croissant…',
      );
      expect(
        trimLabel('coordonner le geste et le nom du nombre'),
        'coordonner le geste…',
      );
    });

    test('a short statement is kept whole', () {
      expect(trimLabel('compter jusqu\'à 10'), "compter jusqu'à 10");
    });

    test('the first clause, when it stands on its own', () {
      expect(
        trimLabel('Reconnaître des solides, par exemple un cube'),
        'Reconnaître des solides',
      );
      // One word before the comma isn't a label: keep going.
      expect(trimLabel('Lire, écrire et compter'), 'Lire, écrire et compter');
    });

    test('the verify pass\'s four: elisions, « non », an open aside', () {
      final cases = {
        "dénombrer à partir d’un nombre donné": 'dénombrer à partir…',
        "le résultat d’une addition ou d’une soustraction": 'le résultat…',
        'des régularités non numériques': 'des régularités…',
        'transformation (ajout, retrait, réunion)': 'transformation…',
      };
      cases.forEach((full, expected) {
        final trimmed = trimLabel(full);
        expect(trimmed, isNot(endsWith(',…')), reason: full);
        expect(trimmed, isNot(contains('(')), reason: full);
        for (final bad in ['d’un…', 'd’une…', 'non…', 'à…']) {
          expect(trimmed, isNot(endsWith(bad)), reason: full);
        }
        expect(trimmed, expected, reason: full);
      });
    });

    test('a content word after an elision is a fine end', () {
      expect(
        trimLabel("estimer l’ordre de grandeur d’un nombre"),
        'estimer l’ordre…',
      );
    });

    test('never ends on « de », « l\' » or « the »', () {
      for (final label in [
        'Associer un nombre à une quantité de jetons',
        "Décrire l'organisation d'une société",
        'Identify the main idea of the text',
      ]) {
        final trimmed = trimLabel(label);
        final last = trimmed.replaceAll('…', '').split(' ').last;
        expect(
          {'de', 'à', 'une', "l'", "d'", 'the', 'of'}.contains(last),
          isFalse,
          reason: trimmed,
        );
        expect(trimmed.length, lessThanOrEqualTo(kidLabelMaxChars + 1));
      }
    });
  });

  group('kidLabel', () {
    test('content\'s short label wins', () {
      expect(
        kidLabel(
          _leaf(fr: 'par ordre croissant ou décroissant', shortFr: 'Ranger'),
          english: false,
        ),
        'Ranger',
      );
    });

    test('English: the short English label, then English, then French', () {
      expect(
        kidLabel(_leaf(shortFr: 'Compter', shortEn: 'Count'), english: true),
        'Count',
      );
      expect(kidLabel(_leaf(en: 'Count to 10'), english: true), 'Count to 10');
      expect(kidLabel(_leaf(), english: true), 'Compter');
    });

    test('a blank short label is ignored', () {
      expect(kidLabel(_leaf(shortFr: '  '), english: false), 'Compter');
    });
  });

  group('kidLabelFor: language subjects keep their language (ADR 0023)', () {
    const fr = Locale('fr', 'CA');
    const en = Locale('en', 'CA');
    CachedSkillNode both(String subject) => _leaf(
      fr: 'lire des textes variés',
      en: 'read a variety of texts',
      shortFr: 'Lire',
      shortEn: 'Read',
      subject: subject,
    );

    test('English subjects show short_label_en in a French app', () {
      expect(kidLabelFor(both('EN'), fr), 'Read');
      expect(kidLabelFor(both('ESL'), fr), 'Read');
    });

    test('Français and FLS show short_label_fr in an English app', () {
      expect(kidLabelFor(both('FR'), en), 'Lire');
      expect(kidLabelFor(both('FLS'), en), 'Lire');
    });

    test('other subjects follow the app', () {
      expect(kidLabelFor(both('MATH'), fr), 'Lire');
      expect(kidLabelFor(both('MATH'), en), 'Read');
    });
  });

  test('a French colon never starts a caption line (no-break space)', () {
    final label = kidLabel(
      _leaf(shortFr: 'Mots de science : matière'),
      english: false,
    );
    expect(label, 'Mots de science\u00a0: matière');
    expect(
      frenchSpacing('« Lire » ? oui !'),
      '«\u00a0Lire\u00a0»\u00a0? oui\u00a0!',
    );
  });
}
