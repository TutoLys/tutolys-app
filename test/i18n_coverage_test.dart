import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';

/// Guards the FR/EN toggle against the way it actually breaks: not a missing
/// translation, but a French string typed straight into a widget, which the
/// toggle then cannot touch.
///
/// Scans `lib/` for accented literals outside the one file allowed to hold
/// them. Crude on purpose — it catches the real failure (someone writes
/// `'Quêtes du jour'` in a build method) without a code generator.
void main() {
  test('no French text is hardcoded outside strings.dart', () {
    final accented = RegExp(r'''(['"])[^'"\n]*[éèêëàâçûùôîïÉÈÊÀÇÎÔÛ][^'"\n]*\1''');

    // Language names stay in their own language — "Français" must read
    // "Français" to an English speaker choosing it, so the Langue control's
    // own options are deliberately not translated.
    final allowed = <String>{"'Français'", "'English'"};

    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('core/i18n/strings.dart')) continue;
      if (file.path.endsWith('.g.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.trimLeft();
        // Comments and doc comments may describe UI copy freely.
        if (code.startsWith('//') || code.startsWith('///')) continue;

        for (final match in accented.allMatches(line)) {
          final literal = match.group(0)!;
          if (allowed.contains(literal)) continue;
          offenders.add('${file.path}:${i + 1}  $literal');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These are user-visible French strings the language toggle '
          'cannot reach. Move them into Strings (both locales):\n'
          '${offenders.join('\n')}',
    );
  });

  test('no widget hardcodes a string that already exists in Strings', () {
    // The accent scan above misses unaccented French — `'Aide & support'`
    // slipped through it and shipped a dead snackbar. This catches the more
    // useful case regardless of accents: a literal that duplicates a value
    // `Strings` already owns is, by definition, text the toggle cannot
    // reach.
    const fr = Strings.fr;
    final owned = <String>{
      fr.navHelp,
      fr.navVillage,
      fr.navCarte,
      fr.navQuetes,
      fr.navProgres,
      fr.navProfil,
      fr.navReglages,
      fr.settingsAbout,
      fr.settingsSignOut,
      fr.settingsTitle,
    };

    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('core/i18n/strings.dart')) continue;
      if (file.path.endsWith('.g.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        for (final value in owned) {
          if (lines[i].contains("'$value'") || lines[i].contains('"$value"')) {
            offenders.add('${file.path}:${i + 1}  "$value"');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use the Strings getter instead of the literal:\n'
          '${offenders.join('\n')}',
    );
  });
}
