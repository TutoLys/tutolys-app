import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
