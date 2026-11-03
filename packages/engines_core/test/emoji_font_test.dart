import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:engines_core/src/widgets/answer_tile.dart';
import 'package:engines_core/src/widgets/swatch_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX review AM2 (N17 still open on mobile web): 🐟 🏖️ 🏫 drew as grey line
/// glyphs, so « Combien de poissons ? » couldn't be answered. The engines
/// fall back to a bundled colour emoji font now (ADR 0105).
void main() {
  setUpAll(() async {
    final loader = FontLoader(emojiFontFamily)
      ..addFont(
        File('fonts/TutolysEmoji.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
    await loader.load();
  });

  Widget host(Widget child) => MaterialApp(
    theme: TutolysTheme.village(),
    home: Scaffold(body: Center(child: child)),
  );

  test('the style gets the emoji font as its last fallback, once', () {
    final s = withEmojiFallback(const TextStyle(fontFamilyFallback: ['Other']));
    expect(s.fontFamilyFallback, ['Other', emojiFontFamily]);
    expect(withEmojiFallback(s).fontFamilyFallback, s.fontFamilyFallback);
  });

  testWidgets('content text falls back to the emoji font', (tester) async {
    await tester.pumpWidget(host(const SwatchText('🐟 poissons')));
    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(rich.text.style?.fontFamilyFallback, contains(emojiFontFamily));
  });

  testWidgets('golden: 🐟 🏖️ 🏫 draw in colour', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 300));
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: const ValueKey('emoji-golden'),
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in ['🐟🐟🐟', '🏖️', '🏫 🍎 ⚽'])
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnswerTile(
                      label: l,
                      state: AnswerTileState.idle,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(const ValueKey('emoji-golden')),
      matchesGoldenFile('goldens/emoji_answers.png'),
    );
  });

  test('⚜️ is always in the bundled font, used or not', () {
    final cps = File('fonts/TutolysEmoji.codepoints').readAsLinesSync();
    expect(cps, containsAll(['269C', 'FE0F']));
  });

  test('every emoji the content uses is in the bundled font', () {
    final inFont = {
      for (final l in File('fonts/TutolysEmoji.codepoints').readAsLinesSync())
        if (l.trim().isNotEmpty) int.parse(l, radix: 16),
    };
    // The analyzer doesn't know binary properties; the VM does.
    // ignore: valid_regexps
    final emoji = RegExp(r'\p{Extended_Pictographic}', unicode: true);
    final root = Directory('../../../tutolys-backend/content');
    if (!root.existsSync()) return; // backend tree not beside this checkout
    final missing = <String>{};
    for (final f in root.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      for (final m in emoji.allMatches(f.readAsStringSync())) {
        final c = m.group(0)!.runes.single;
        if (c >= 0x2000 && !inFont.contains(c)) missing.add(m.group(0)!);
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'run tool/build_emoji_font.py to add them to the font',
    );
  });
}
