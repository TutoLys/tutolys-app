import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';

/// Hafid, 2026-10-25: "we no longer do coins". The FAQ explains XP (option
/// A) and the level instead, in both languages, and nothing a child can
/// read promises a currency.
void main() {
  for (final (lang, t) in [
    ('fr', Strings.of(const Locale('fr'))),
    ('en', Strings.of(const Locale('en'))),
  ]) {
    test('$lang: the first answer is about XP, then the level', () {
      final entries = t.helpEntries;
      expect(entries.first.question, contains('XP'));
      expect(entries.first.answer, contains('1 XP'));
      expect(entries.first.answer, contains('10 XP'));
      expect(entries[1].answer, contains('99'));
    });

    test('$lang: no coins, pièces or Boutique anywhere in the FAQ', () {
      final text = [
        for (final e in t.helpEntries) ...[e.question, e.answer],
      ].join(' ').toLowerCase();
      for (final word in ['pièce', 'coin', 'boutique', 'shop']) {
        expect(text, isNot(contains(word)), reason: word);
      }
    });
  }
}
