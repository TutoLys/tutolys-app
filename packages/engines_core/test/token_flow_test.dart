import 'package:engines_core/src/widgets/token_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> runs(List<String> tokens) => [
  for (final run in TokenFlow.runsOf([
    for (final t in tokens) TokenPiece.single(t, Text(t)),
  ]))
    run.map((p) => p.first).join('|'),
];

void main() {
  test('closing punctuation joins the word before it', () {
    expect(runs(['Mon', 'frère', 'joue', '.']), ['Mon', 'frère', 'joue|.']);
    expect(runs(['Hier', ',', 'Léa', 'a', 'nagé', '.']), [
      'Hier|,',
      'Léa',
      'a',
      'nagé|.',
    ]);
  });

  test('an elided word joins the next one', () {
    expect(runs(["J'", 'ai', 'soif', '.']), ["J'|ai", 'soif|.']);
    expect(runs(['l’', 'école']), ['l’|école']);
    expect(runs(["n'", 'aime', 'pas']), ["n'|aime", 'pas']);
  });

  test('French spaced punctuation keeps its space', () {
    expect(runs(['Viens', '!']), ['Viens', '!']);
    expect(runs(['Pourquoi', '?']), ['Pourquoi', '?']);
    expect(runs(['Il', 'dit', ':']), ['Il', 'dit', ':']);
  });

  test('a framed group joins by its own first and last token', () {
    final r = TokenFlow.runsOf(const [
      TokenPiece(first: 'Mon', last: 'frère', child: SizedBox()),
      TokenPiece(first: 'joue', last: 'joue', child: SizedBox()),
      TokenPiece(first: '.', last: '.', child: SizedBox()),
    ]);
    expect(r.map((x) => x.length), [1, 2]);
  });

  testWidgets('a joined run is one row, with no gap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TokenFlow(
            pieces: [
              for (final t in ['Max', 'joue', '.'])
                TokenPiece.single(t, Text(t)),
            ],
          ),
        ),
      ),
    );
    final joue = tester.getRect(find.text('joue'));
    final dot = tester.getRect(find.text('.'));
    expect(dot.left, joue.right);
    final max = tester.getRect(find.text('Max'));
    expect(joue.left - max.right, 6);
  });
}
