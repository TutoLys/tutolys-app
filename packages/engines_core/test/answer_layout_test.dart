import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:engines_core/src/widgets/choice_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX review AM3: answers were 15 px, left-aligned, in 343 px tiles, with
/// the bottom 40 % of a phone screen empty.
void main() {
  String? promptOverride;
  Map<String, Object?> envelope(List<String> labels, {String? prompt}) => {
    'exercise_id': '1c3d6d41-a465-42be-b3a9-c1dc8460e24c',
    'version': 1,
    'content_hash': 'h',
    'engine_key': 'mcq',
    'engine_min_version': 1,
    'skill_node_id': '5a221f09-99f7-597e-bc4a-34e7ccafaa3b',
    'subject': 'MATH',
    'grade': 1,
    'rank': 0,
    'prompt': {
      'text': prompt ?? promptOverride ?? 'Combien de poissons y a-t-il ?',
    },
    'config': {
      'options': [
        for (final (i, l) in labels.indexed) {'id': 'o$i', 'label': l},
      ],
      'correct': 'o0',
      'shuffle': false,
    },
  };

  Future<ActivitySessionController> pump(
    WidgetTester tester,
    List<String> labels, {
    double width = 375,
  }) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(labels)).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([
        eraseEngine(const SingleChoiceEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [McqExactEvaluator()]),
      store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
      appVersion: '0.2.0',
      seed: 1,
    );
    await tester.runAsync(c.start);
    await tester.pumpWidget(
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: LearningActivityView(
            controller: c,
            locale: const Locale('fr'),
            character: const SizedBox.square(
              key: ValueKey('fox'),
              dimension: 56,
            ),
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    return c;
  }

  TextStyle labelStyle(WidgetTester tester, String id) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('mcq-option-$id')),
        matching: find.byType(Text),
      ),
    );
    return text.style!;
  }

  testWidgets('three numbers are a row of big square tiles at 375', (
    tester,
  ) async {
    final c = await pump(tester, ['1', '3', '2']);
    expect(find.byKey(const ValueKey('choice-squares')), findsOneWidget);
    final sizes = [
      for (final id in ['o0', 'o1', 'o2'])
        tester.getSize(find.byKey(ValueKey('mcq-option-$id'))),
    ];
    for (final s in sizes) {
      expect(s.width, greaterThanOrEqualTo(88));
      expect(s.height, s.width);
    }
    // One row.
    final ys = {
      for (final id in ['o0', 'o1', 'o2'])
        tester.getTopLeft(find.byKey(ValueKey('mcq-option-$id'))).dy,
    };
    expect(ys, hasLength(1));
    expect(labelStyle(tester, 'o0').fontSize, 30);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('four short answers are a 2 × 2 grid', (tester) async {
    final c = await pump(tester, ['5', '6', '7', '8']);
    final a = tester.getTopLeft(find.byKey(const ValueKey('mcq-option-o0')));
    final b = tester.getTopLeft(find.byKey(const ValueKey('mcq-option-o1')));
    final d = tester.getTopLeft(find.byKey(const ValueKey('mcq-option-o2')));
    expect(a.dy, b.dy);
    expect(d.dy, greaterThan(a.dy));
    expect(
      tester.getSize(find.byKey(const ValueKey('mcq-option-o0'))).height,
      greaterThanOrEqualTo(88),
    );
    c.dispose();
  });

  testWidgets('word answers are a list, 24 px and centred', (tester) async {
    final c = await pump(tester, ['un carré', 'un triangle', 'un cercle']);
    expect(find.byKey(const ValueKey('choice-squares')), findsNothing);
    final style = labelStyle(tester, 'o1');
    expect(style.fontSize, 24);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('mcq-option-o1')),
        matching: find.byType(Text),
      ),
    );
    expect(text.textAlign, TextAlign.center);
    expect(
      tester.getSize(find.byKey(const ValueKey('mcq-option-o1'))).height,
      greaterThanOrEqualTo(64),
    );
    c.dispose();
  });

  testWidgets('a long sentence answer stays readable, not shrunk', (
    tester,
  ) async {
    final c = await pump(tester, [
      'Parce que le chat avait faim ce matin-là.',
      'Parce que la pluie tombait très fort.',
    ]);
    expect(labelStyle(tester, 'o0').fontSize, 19);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('AM4: at 375 the question gets the fox\'s width', (tester) async {
    final c = await pump(tester, ['1', '3', '2']);
    expect(find.byKey(const ValueKey('fox')), findsNothing);
    c.dispose();
  });

  testWidgets('AM4: a wider screen keeps the fox', (tester) async {
    final c = await pump(tester, ['1', '3', '2'], width: 800);
    expect(find.byKey(const ValueKey('fox')), findsOneWidget);
    c.dispose();
  });

  testWidgets('the fish a question counts draw at 40 px', (tester) async {
    promptOverride = '🐟🐟\nCombien de poissons y a-t-il ?';
    addTearDown(() => promptOverride = null);
    final c = await pump(tester, ['1', '3', '2']);
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('prompt-text')),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(texts.first.data, '🐟🐟');
    expect(texts.first.style!.fontSize, 40);
    expect(texts.last.style!.fontSize, 20);
    expect(find.bySemanticsLabel(RegExp('Combien de poissons')), findsWidgets);
    c.dispose();
  });

  testWidgets('AM32: a chosen answer shows a dot and a 3 px edge', (
    tester,
  ) async {
    final c = await pump(tester, ['un carré', 'un triangle']);
    await tester.tap(find.byKey(const ValueKey('mcq-option-o1')));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    final tile = find.byKey(const ValueKey('mcq-option-o1'));
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );
    final shape =
        tester
                .widget<Material>(
                  find
                      .descendant(of: tile, matching: find.byType(Material))
                      .first,
                )
                .shape!
            as RoundedRectangleBorder;
    expect(shape.side.width, 3);
    c.dispose();
  });

  test('a picture answer never goes in a square', () {
    final layout = ChoiceLayout(
      ids: const ['a', 'b'],
      labelOf: (_) => '3',
      hasPicture: (id) => id == 'a',
      tile: (id, {required square}) => const SizedBox(),
    );
    expect(layout.squares, isFalse);
  });
}
