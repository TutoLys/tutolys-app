import 'package:design_system/design_system.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The size each label was drawn at.
Map<String, double> sizes(WidgetTester tester, List<String> labels) => {
  for (final l in labels)
    l: tester
        .widget<RichText>(
          find.descendant(
            of: find.widgetWithText(AnswerTile, l),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!
        .fontSize!,
};

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: TutolysTheme.village(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('a set shares the smallest size any label needs', () {
    expect(
      AnswerTile.sharedLabelSize([
        'Une journée à la plage',
        'Une partie de hockey en hiver',
      ], prominent: true),
      19,
    );
    expect(
      AnswerTile.sharedLabelSize(['en été', 'Des pompiers'], large: true),
      20,
    );
    // A picture answer is content and keeps its own size.
    expect(AnswerTile.sharedLabelSize(['🍎', 'pomme'], large: true), 28);
    expect(AnswerTile.sharedLabelSize(['🍎', '🍐'], prominent: true), isNull);
  });

  testWidgets('the key is drawn at the same size as the decoys', (
    tester,
  ) async {
    // Grade-2 univers social 89: the longest option was the key, and it
    // alone shrank to 19 px.
    const labels = [
      'Une journée à la plage',
      'La récolte des pommes',
      'Une partie de hockey en hiver',
    ];
    final shared = AnswerTile.sharedLabelSize(labels, prominent: true);
    await pump(
      tester,
      SizedBox(
        width: 400,
        child: Column(
          children: [
            for (final l in labels)
              AnswerTile(
                label: l,
                prominent: true,
                labelSize: shared,
                state: AnswerTileState.idle,
                onTap: () {},
              ),
          ],
        ),
      ),
    );
    expect(sizes(tester, labels).values.toSet(), {19});
  });

  testWidgets('a narrow tile shrinks a long word instead of breaking it', (
    tester,
  ) async {
    // Grade-2 univers social 93 drew « pompier / s » and « patinoir / e ».
    const labels = ['Des pompiers', 'sur la patinoire'];
    await pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in labels)
            // The test font draws every glyph a full em wide, so a tile
            // narrow enough to break « pompiers » at 20 px needs 160 px
            // here to fit it at the shrunk size (Baloo needs far less).
            SizedBox(
              width: 160,
              child: AnswerTile(
                label: l,
                large: true,
                labelSize: 20,
                state: AnswerTileState.idle,
                onTap: () {},
              ),
            ),
        ],
      ),
    );
    for (final l in labels) {
      final tile = find.byWidgetPredicate(
        (w) => w is AnswerTile && w.label == l,
      );
      final tileRect = tester.getRect(tile);
      for (final w in l.split(' ')) {
        final word = find.descendant(of: tile, matching: find.text(w));
        expect(word, findsOneWidget, reason: '« $w » drawn whole in « $l »');
        final r = tester.getRect(word);
        expect(r.left, greaterThanOrEqualTo(tileRect.left));
        expect(r.right, lessThanOrEqualTo(tileRect.right));
      }
    }
  });
}
