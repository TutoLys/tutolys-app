import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend samples, verbatim.
const planConfig = <String, Object?>{
  'layout': 'grid',
  'columns': 3,
  'scene_items': [
    {'id': 'a1', 'label': '🌳'},
    {'id': 'b1', 'label': ''},
    {'id': 'c1', 'label': '🏫'},
    {'id': 'a2', 'label': ''},
    {'id': 'b2', 'label': '🏠'},
    {'id': 'c2', 'label': ''},
    {'id': 'a3', 'label': '🏪'},
    {'id': 'b3', 'label': ''},
    {'id': 'c3', 'label': '🌳'},
  ],
  'correct_ids': ['c1'],
  'column_labels': ['A', 'B', 'C'],
  'row_labels': ['1', '2', '3'],
  'legend': [
    {'symbol': '🏫', 'label': 'école'},
    {'symbol': '🏠', 'label': 'maison'},
    {'symbol': '🏪', 'label': 'épicerie'},
    {'symbol': '🌳', 'label': 'parc'},
  ],
};

const sentenceConfig = <String, Object?>{
  'layout': 'words',
  'scene_items': [
    {'id': 'w1', 'label': 'Le'},
    {'id': 'w2', 'label': 'chat'},
    {'id': 'w3', 'label': 'dort'},
    {'id': 'w4', 'label': '.'},
  ],
  'correct_ids': ['w4'],
};

const evensConfig = <String, Object?>{
  'scene_items': [
    {'id': 'n2', 'label': '2'},
    {'id': 'n3', 'label': '3'},
    {'id': 'n6', 'label': '6'},
    {'id': 'n7', 'label': '7'},
    {'id': 'n8', 'label': '8'},
  ],
  'correct_ids': ['n2', 'n6', 'n8'],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'find_it',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'SOC',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Où est l\'école ?'},
  'config': config,
};

(ActivitySessionController, InMemoryEventOutbox) controllerFor(
  Map<String, Object?> config,
) {
  final outbox = InMemoryEventOutbox();
  return (
    ActivitySessionController(
      envelope: QuestionEnvelope.parse(envelope(config)).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([eraseEngine(const FindItEngine())]),
      evaluators: EvaluatorRegistry(const [FindItEvaluator()]),
      store: InMemoryActivitySessionStore(outbox),
      appVersion: '0.2.0',
      seed: 3,
    ),
    outbox,
  );
}

Widget app(ActivitySessionController c) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
  ),
);

void tallView(WidgetTester tester, {double width = 1000}) {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

Future<void> pressWithKeyboard(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 60; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        find
            .descendant(of: target, matching: find.byWidget(focused.widget))
            .evaluate()
            .isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      return;
    }
  }
  fail('Tab never reached $target');
}

void main() {
  const engine = FindItEngine();

  group('parse', () {
    test('reads each layout; plans and sentences keep their order', () {
      final plan = engine.parse(planConfig).valueOrNull!;
      expect(plan.layout, FindItLayout.grid);
      expect(plan.rows, 3);
      expect(plan.legend, hasLength(4));
      expect(plan.cells[1].label, '', reason: 'a blank square on a plan');
      expect(engine.initialize(plan, const EngineSeed(9)).order, [
        for (final c in plan.cells) c.id,
      ]);
      final sentence = engine.parse(sentenceConfig).valueOrNull!;
      expect(engine.initialize(sentence, const EngineSeed(9)).order, [
        'w1',
        'w2',
        'w3',
        'w4',
      ]);
      final evens = engine.parse(evensConfig).valueOrNull!;
      expect(evens.layout, FindItLayout.items, reason: 'items is the default');
      expect(evens.multiple, isTrue);
    });

    test('refuses content that cannot be played', () {
      void refused(Map<String, Object?> config, String why) => expect(
        engine.parse(config),
        isA<ParseInvalid<FindItContent>>(),
        reason: why,
      );
      refused({...sentenceConfig, 'layout': 'map'}, 'unknown layout');
      refused({
        ...sentenceConfig,
        'correct_ids': ['zz'],
      }, 'a right answer that is not in the scene');
      refused({
        ...sentenceConfig,
        'correct_ids': ['w1', 'w2', 'w3', 'w4'],
      }, 'everything right: nothing to find');
      refused({...planConfig, 'columns': 4}, 'columns not dividing the cells');
      refused({
        ...planConfig,
        'row_labels': ['1', '2'],
      }, 'one row label short');
      refused({
        ...sentenceConfig,
        'scene_items': [
          {'id': 'w1', 'label': ''},
          {'id': 'w2', 'label': 'chat'},
        ],
      }, 'a blank word: only a grid may have blank cells');
    });
  });

  group('letters, joined marks, Cartesian origin, compass', () {
    test('punctuation joins by default; "?" is the content\'s call', () {
      final c = engine.parse({
        'layout': 'words',
        'scene_items': [
          {'id': 'w1', 'label': 'Où'},
          {'id': 'w2', 'label': 'vas-tu'},
          {'id': 'w3', 'label': '?'},
          {'id': 'w4', 'label': 'Ici'},
          {'id': 'w5', 'label': '.'},
          {'id': 'w6', 'label': '!', 'join': true},
        ],
        'correct_ids': ['w3'],
      }).valueOrNull!;
      expect(
        [for (final x in c.cells) x.join],
        [
          false,
          false,
          false, // French puts a space before ?
          false,
          true,
          true,
        ],
      );
    });

    test('bottom_left: rows listed from the bottom are shown bottom-up', () {
      // (x, y) with the origin at the bottom left: listed y = 1 first.
      final c = engine.parse({
        'layout': 'grid',
        'columns': 2,
        'origin': 'bottom_left',
        'scene_items': [
          {'id': 'x1y1', 'label': ''},
          {'id': 'x2y1', 'label': ''},
          {'id': 'x1y2', 'label': ''},
          {'id': 'x2y2', 'label': '⭐'},
        ],
        'correct_ids': ['x2y2'],
        'row_labels': ['1', '2'],
      }).valueOrNull!;
      expect(c.cells.map((x) => x.id), ['x1y2', 'x2y2', 'x1y1', 'x2y1']);
      expect(c.rowLabels, ['2', '1'], reason: 'top row drawn first');
      expect(
        engine.parse({...planConfig, 'origin': 'middle'}),
        isA<ParseInvalid<FindItContent>>(),
      );
    });

    testWidgets('bottom_left: (2, 2) is drawn top right, named by its labels', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor({
        'layout': 'grid',
        'columns': 2,
        'origin': 'bottom_left',
        'scene_items': [
          {'id': 'x1y1', 'label': ''},
          {'id': 'x2y1', 'label': ''},
          {'id': 'x1y2', 'label': ''},
          {'id': 'x2y2', 'label': ''},
        ],
        'correct_ids': ['x2y2'],
        'row_labels': ['1', '2'],
        'column_labels': ['1', '2'],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('find-cell-x2y2')),
      );
      final bottom = tester.getTopLeft(
        find.byKey(const ValueKey('find-cell-x2y1')),
      );
      expect(top.dy, lessThan(bottom.dy));
      expect(find.bySemanticsLabel('colonne 2, rangée 2'), findsOneWidget);
      c.dispose();
    });

    testWidgets('letters: one word, each letter named by its place', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor({
        'layout': 'letters',
        'scene_items': [
          for (final (i, l) in ['v', 'e', 'r', 't'].indexed)
            {'id': 'l$i', 'label': l},
        ],
        'correct_ids': ['l3'],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.bySemanticsLabel('lettre 4 : t'), findsOneWidget);
      final a = tester.getTopRight(find.byKey(const ValueKey('find-cell-l0')));
      final b = tester.getTopLeft(find.byKey(const ValueKey('find-cell-l1')));
      expect(b.dx - a.dx, lessThanOrEqualTo(2), reason: 'no gap in a word');
      c.dispose();
    });

    testWidgets('compass labels around a plan; 6×6 still fits a phone', (
      tester,
    ) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'layout': 'grid',
        'columns': 6,
        'scene_items': [
          for (var i = 0; i < 36; i++)
            {'id': 'c$i', 'label': i == 7 ? '🏠' : ''},
        ],
        'correct_ids': ['c1'],
        'row_labels': [for (var i = 1; i <= 6; i++) '$i'],
        'column_labels': ['A', 'B', 'C', 'D', 'E', 'F'],
        'edge_labels': {
          'top': 'Nord',
          'right': 'Est',
          'bottom': 'Sud',
          'left': 'Ouest',
        },
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      for (final w in ['Nord', 'Est', 'Sud', 'Ouest']) {
        expect(find.text(w), findsOneWidget);
      }
      final size = tester.getSize(find.byKey(const ValueKey('find-cell-c0')));
      // ignore: avoid_print
      print('6x6 with axes and compass at 375px: ${size.width}px squares');
      expect(size.width, greaterThanOrEqualTo(32));
      c.dispose();
    });
  });

  group('reduce', () {
    test('one right answer: a new pick replaces the last', () {
      final c = engine.parse(sentenceConfig).valueOrNull!;
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapCell('w2')).state;
      s = engine.reduce(s, const TapCell('w4')).state;
      expect(s.selected, {'w4'});
      final t = engine.reduce(s, const TapCell('w4'));
      expect(t.state.selected, isEmpty, reason: 'tap again to unpick');
      expect(t.events.single.type, 'option_deselected');
      expect(engine.extractAnswer(t.state), isNull);
    });

    test('several right answers: each tap toggles', () {
      final c = engine.parse(evensConfig).valueOrNull!;
      var s = engine.initialize(c, const EngineSeed(1));
      for (final id in ['n2', 'n3', 'n6']) {
        s = engine.reduce(s, TapCell(id)).state;
      }
      expect(s.selected, {'n2', 'n3', 'n6'});
    });
  });

  group('FindItEvaluator', () {
    final c = engine.parse(evensConfig).valueOrNull!;

    test('partial: right picks lock, wrong ones turn amber for good', () {
      var s = engine.initialize(c, const EngineSeed(1));
      for (final id in ['n2', 'n3', 'n6']) {
        s = engine.reduce(s, TapCell(id)).state;
      }
      final r = const FindItEvaluator().evaluate(
        c,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.itemResults, {'n2': true, 'n3': false, 'n6': true});
      expect(r.score, 0.5, reason: '2 right of (3 to find + 1 wrong pick)');
      expect(r.evaluator, 'find_it.exact@1');
      s = engine.applyFeedback(s, r);
      expect(s.found, {'n2', 'n6'});
      expect(s.tried, {'n3'});
      expect(s.selected, isEmpty);
      expect(engine.reduce(s, const TapCell('n3')).events, isEmpty);
      expect(engine.reduce(s, const TapCell('n2')).events, isEmpty);

      s = engine.reduce(s, const TapCell('n8')).state;
      final done = const FindItEvaluator().evaluate(
        c,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(done.outcome, Outcome.correct, reason: 'found ones count again');
    });

    test('picking everything never scores well', () {
      final r = const FindItEvaluator().evaluate(
        c,
        MultiSelectAnswer(['n2', 'n3', 'n6', 'n7', 'n8']),
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.score, 0.6);
    });

    test('nothing right is incorrect', () {
      final r = const FindItEvaluator().evaluate(
        c,
        MultiSelectAnswer(['n3']),
        ctx,
      );
      expect(r.outcome, Outcome.incorrect);
      expect(r.score, 0);
    });
  });

  group('snapshot', () {
    test('round-trips, and refuses a reordered plan', () {
      final c = engine.parse(planConfig).valueOrNull!;
      var s = engine.initialize(c, const EngineSeed(1));
      s = engine.reduce(s, const TapCell('b2')).state;
      s = s.copyWith(tried: {'a1'}, selected: {'c1'});
      final snap =
          jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>;
      final back = engine.restore(c, snap)!;
      expect(back.tried, {'a1'});
      expect(back.selected, {'c1'});
      expect(back.single, isTrue);
      expect(
        engine.restore(c, {
          ...snap,
          'order': (snap['order'] as List).reversed.toList(),
        }),
        isNull,
      );
      expect(
        engine.restore(c, {
          ...snap,
          'found': ['a1'],
        }),
        isNull,
        reason: 'a found cell must be a right one',
      );
    });
  });

  group('in the shell', () {
    testWidgets('plan: a wrong square turns amber, then the right one', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(planConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('find-legend')), findsOneWidget);
      expect(find.text('🏫  école'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('find-cell-b2')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('RÉESSAYER'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect((c.current!.state as FindItState).tried, {'b2'});

      await tester.tap(find.byKey(const ValueKey('find-cell-c1')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .map((e) => e['is_correct']);
      expect(attempts, [false, true]);
      c.dispose();
    });

    testWidgets('a blank square is named by where it is', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(planConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(
        find.bySemanticsLabel('colonne B, rangée 1'),
        findsOneWidget,
        reason: 'b1 is blank',
      );
      expect(find.bySemanticsLabel('🏫, colonne C, rangée 1'), findsOneWidget);
      c.dispose();
    });

    testWidgets('multi: the count follows what is found', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(evensConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Trouvés : 0 sur 3'), findsOneWidget);
      for (final id in ['n2', 'n6']) {
        await tester.tap(find.byKey(ValueKey('find-cell-$id')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(find.text('Trouvés : 2 sur 3'), findsOneWidget);
      c.dispose();
    });

    testWidgets('keyboard alone can pick a word', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(sentenceConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('find-cell-w4')),
      );
      expect((c.current!.state as FindItState).selected, {'w4'});
      c.dispose();
    });

    testWidgets('an 8×8 grid fits a phone with tappable cells', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'layout': 'grid',
        'columns': 8,
        'scene_items': [
          for (var i = 0; i < 64; i++) {'id': 'c$i', 'label': ''},
        ],
        'correct_ids': ['c9'],
        'row_labels': [for (var i = 8; i >= 1; i--) '$i'],
        'column_labels': [for (var i = 1; i <= 8; i++) '$i'],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byKey(const ValueKey('find-cell-c0')));
      expect(size.width, greaterThanOrEqualTo(32));
      c.dispose();
    });
  });

  group('seamless grid (2026-11-16 play-test, univers social 19)', () {
    // A side view: sky (blank), land (🟫), a letter on the hilltop.
    final relief = <String, Object?>{
      'layout': 'grid',
      'columns': 3,
      'seamless': true,
      'scene_items': [
        {'id': 'a1', 'label': ''},
        {'id': 'b1', 'label': 'A'},
        {'id': 'c1', 'label': ''},
        {'id': 'a2', 'label': '🟫'},
        {'id': 'b2', 'label': '🟫'},
        {'id': 'c2', 'label': '🟫'},
      ],
      'correct_ids': ['b1'],
    };

    test('parse: seamless is an optional bool, off by default', () {
      const engine = FindItEngine();
      expect(engine.parse(relief).valueOrNull!.seamless, isTrue);
      expect(engine.parse(planConfig).valueOrNull!.seamless, isFalse);
      expect(engine.parse({...relief, 'seamless': 'yes'}).valueOrNull, isNull);
    });

    testWidgets('cells touch, and 🟫 paints the whole cell', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(relief);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final a2 = tester.getRect(find.byKey(const ValueKey('find-cell-a2')));
      final b2 = tester.getRect(find.byKey(const ValueKey('find-cell-b2')));
      final b1 = tester.getRect(find.byKey(const ValueKey('find-cell-b1')));
      expect(b2.left, a2.right, reason: 'no gap across');
      expect(b2.top, b1.bottom, reason: 'no gap down');
      // The land is painted, not drawn as a small emoji.
      expect(find.text('🟫'), findsNothing);
      final land = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const ValueKey('find-cell-b2')),
          matching: find.byType(Material),
        ),
      );
      expect(land.color, const Color(0xFF8B5A2B));
      // Still named for a screen reader.
      expect(find.bySemanticsLabel('🟫, colonne 2, rangée 2'), findsOneWidget);
      c.dispose();
    });

    testWidgets('a picked cell still shows it is picked', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(relief);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('find-cell-b1')));
      await settle(tester);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('find-cell-b1')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.decoration, isA<BoxDecoration>());
      c.dispose();
    });
  });
}
