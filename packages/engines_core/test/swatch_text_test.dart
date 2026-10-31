import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:engines_core/src/widgets/answer_tile.dart';
import 'package:engines_core/src/widgets/swatch_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX review N17: colour-square emoji drew as grey glyphs on Flutter web, so
/// « Find blue » offered three identical squares. They are painted now.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: TutolysTheme.village(),
    home: Scaffold(body: Center(child: child)),
  );

  List<Color> painted(WidgetTester tester) => [
    for (final m in tester.widgetList<SwatchMark>(find.byType(SwatchMark)))
      m.swatch.color,
  ];

  testWidgets('a colour square is painted in its own colour', (tester) async {
    await tester.pumpWidget(host(const SwatchText('🟦')));
    expect(painted(tester), [const Color(0xFF1E88E5)]);
    expect(find.bySemanticsLabel('🟦'), findsOneWidget);
  });

  testWidgets('three colour answers are three different colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            for (final l in ['🟦', '🟩', '🟨'])
              AnswerTile(label: l, state: AnswerTileState.idle, onTap: () {}),
          ],
        ),
      ),
    );
    expect(painted(tester).toSet(), hasLength(3));
  });

  testWidgets('mixed text keeps its words and drops the variation selector', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SwatchText('⚪️ 3 blancs ⭐')));
    expect(painted(tester), hasLength(2));
    final rich = tester.widget<RichText>(find.byType(RichText).last);
    final text = rich.text.toPlainText(includePlaceholders: false);
    expect(text, ' 3 blancs ');
  });

  testWidgets('text without a swatch is a plain Text', (tester) async {
    await tester.pumpWidget(host(const SwatchText('🍎 pomme')));
    expect(find.byType(SwatchMark), findsNothing);
    expect(find.text('🍎 pomme'), findsOneWidget);
  });

  testWidgets('golden: « Find blue. » answers are three colours', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 420));
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: const ValueKey('swatch-golden'),
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in ['🟦', '🟩', '🟨', '⚪ ⚫ ⭐'])
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
      find.byKey(const ValueKey('swatch-golden')),
      matchesGoldenFile('goldens/colour_answers.png'),
    );
  });

  test('every colour shape the content uses has a swatch', () {
    // The glyphs Flutter web can draw monochrome: geometric shapes and the
    // star. Any of them in content must be in [swatches].
    final shape = RegExp(
      '[\u{1F7E0}-\u{1F7EB}\u{2B1B}\u{2B1C}\u{26AA}\u{26AB}'
      '\u{1F534}\u{1F535}\u{2B50}]',
      unicode: true,
    );
    final root = Directory('../../../tutolys-backend/content');
    if (!root.existsSync()) return; // backend tree not beside this checkout
    final missing = <String>{};
    for (final f in root.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final text = f.readAsStringSync();
      jsonDecode(text); // a malformed file would hide glyphs
      for (final m in shape.allMatches(text)) {
        if (!swatches.containsKey(m.group(0)!.runes.single)) {
          missing.add(m.group(0)!);
        }
      }
    }
    expect(missing, isEmpty);
  });
}
