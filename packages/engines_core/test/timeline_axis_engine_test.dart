import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend sample `content/samples/math_number_line.json`, verbatim.
const numberLine = <String, Object?>{
  'mode': 'axis',
  'ticks': [
    {'id': 't0', 'label': '0'},
    {'id': 't1', 'label': ''},
    {'id': 't2', 'label': ''},
    {'id': 't3', 'label': ''},
    {'id': 't4', 'label': ''},
    {'id': 't5', 'label': '5'},
    {'id': 't6', 'label': ''},
    {'id': 't7', 'label': ''},
    {'id': 't8', 'label': ''},
    {'id': 't9', 'label': ''},
    {'id': 't10', 'label': '10'},
  ],
  'items': [
    {'id': 'n2', 'label': '2', 'tick': 't2'},
    {'id': 'n7', 'label': '7', 'tick': 't7'},
    {'id': 'n9', 'label': '9', 'tick': 't9'},
  ],
  'hint': 'Compte les bonds à partir de 5.',
};

const lifeLine = <String, Object?>{
  'mode': 'axis',
  'ticks': [
    {'id': 'a0', 'label': '0 an'},
    {'id': 'a1', 'label': '1 an'},
    {'id': 'a3', 'label': '3 ans'},
    {'id': 'a6', 'label': '6 ans'},
  ],
  'items': [
    {'id': 'naissance', 'label': 'Je nais', 'tick': 'a0', 'given': true},
    {'id': 'marche', 'label': 'Je marche', 'tick': 'a1'},
    {'id': 'garderie', 'label': 'La garderie', 'tick': 'a3'},
    {'id': 'ecole', 'label': 'L\'école', 'tick': 'a6'},
  ],
  'start_label': 'Avant',
  'end_label': 'Maintenant',
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'timeline_calendar',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Place les nombres sur la droite'},
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
      engines: LearningEngineRegistry([
        eraseEngine(const TimelineCalendarEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [TimelineCalendarEvaluator()]),
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

void view(WidgetTester tester, {double width = 1280}) {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

Future<void> place(WidgetTester tester, String item, String tick) async {
  await tester.tap(find.byKey(ValueKey('axis-item-$item')));
  await settle(tester);
  await tester.tap(find.byKey(ValueKey('axis-tick-$tick')));
  await settle(tester);
}

void main() {
  const engine = TimelineCalendarEngine();
  const axis = TimelineAxisEngine();

  group('parse', () {
    test('mode routes the content; no mode is order mode', () {
      expect(engine.parse(numberLine).valueOrNull, isA<AxisContent>());
      expect(
        engine.parse({
          'items': [
            {'id': 'a', 'label': 'a', 'order': 0},
            {'id': 'b', 'label': 'b', 'order': 1},
            {'id': 'c', 'label': 'c', 'order': 2},
          ],
        }).valueOrNull,
        isA<TimelineContent>(),
      );
      expect(
        engine.parse({...numberLine, 'mode': 'calendar'}),
        isA<ParseInvalid<Object>>(),
      );
    });

    test('refuses an axis that cannot be played', () {
      void refused(Map<String, Object?> patch, String why) => expect(
        axis.parse({...numberLine, ...patch}),
        isA<ParseInvalid<AxisContent>>(),
        reason: why,
      );
      refused({
        'items': [
          {'id': 'a', 'label': '2', 'tick': 't2'},
          {'id': 'b', 'label': '3', 'tick': 't2'},
        ],
      }, 'two items on one tick');
      refused({
        'items': [
          {'id': 'a', 'label': '2', 'tick': 't2'},
          {'id': 'b', 'label': '3', 'tick': 'nope'},
        ],
      }, 'an unknown tick');
      refused({
        'distractors': [
          {'id': 'n2', 'label': 'x'},
        ],
      }, 'a distractor id clashing with an item');
      refused({
        'range': {'min': 0, 'max': 10},
      }, 'ticks and a range together');
      refused({
        'ticks': [
          {'id': 't0', 'label': '0'},
        ],
      }, 'one tick is not an axis');
    });
  });

  group('range: generated ticks, items by value', () {
    // The Questions Maker's two uses.
    const situer = <String, Object?>{
      'mode': 'axis',
      'range': {'min': 0, 'max': 20, 'step': 1, 'label_every': 5},
      'items': [
        {'id': 'n3', 'label': '3', 'at': 3},
        {'id': 'n8', 'label': '8', 'at': 8},
        {'id': 'n12', 'label': '12', 'at': 12},
        {'id': 'n17', 'label': '17', 'at': 17},
      ],
    };
    const leo = <String, Object?>{
      'mode': 'axis',
      'range': {'min': 0, 'max': 6},
      'items': [
        {'id': 'nait', 'label': 'Léo naît', 'at': 0, 'given': true},
        {'id': 'marche', 'label': 'Il marche', 'at': 1},
        {'id': 'garderie', 'label': 'La garderie', 'at': 3},
        {'id': 'velo', 'label': 'Le vélo', 'at': 5},
        {'id': 'ecole', 'label': 'L\'école', 'at': 6},
      ],
      'distractors': [
        {'id': 'auto', 'label': 'Il conduit'},
      ],
    };

    test('0-20 by 1, labelled every 5: 21 ticks, landmarks only', () {
      final c = axis.parse(situer).valueOrNull!;
      expect(c.ticks, hasLength(21));
      expect([for (final t in c.ticks) t.label].where((l) => l.isNotEmpty), [
        '0',
        '5',
        '10',
        '15',
        '20',
      ]);
      expect(c.answer['n12'], 'v12');
    });

    test(
      'label_every defaults to every tick; a value off the grid is refused',
      () {
        final c = axis.parse(leo).valueOrNull!;
        expect(c.ticks.map((t) => t.label), [
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
        ]);
        expect(
          axis.parse({
            ...situer,
            'items': [
              {'id': 'a', 'label': '3', 'at': 3},
              {'id': 'b', 'label': '25', 'at': 25},
            ],
          }),
          isA<ParseInvalid<AxisContent>>(),
        );
        expect(
          axis.parse({
            ...situer,
            'range': {'min': 0, 'max': 100, 'step': 1},
          }),
          isA<ParseInvalid<AxisContent>>(),
          reason: '101 ticks is past the 21-tick cap',
        );
        expect(
          axis.parse({
            ...situer,
            'range': {'min': 0, 'max': 20, 'step': 2, 'label_every': 5},
          }),
          isA<ParseInvalid<AxisContent>>(),
          reason: 'label_every must be a multiple of step',
        );
      },
    );

    test('distractors: right line leaves them; one on a tick is wrong', () {
      final c = axis.parse(leo).valueOrNull!;
      var s = axis.initialize(c, const EngineSeed(1));
      expect(s.tray, contains('auto'));
      expect(s.toPlace, 4);
      void put(String i, String t) => s = axis
          .reduce(axis.reduce(s, TapAxisItem(i)).state, TapTick(t))
          .state;
      put('marche', 'v1');
      put('garderie', 'v3');
      put('velo', 'v5');
      put('auto', 'v6');
      expect(s.complete, isTrue, reason: '4 on the line, whatever they are');
      final r = const TimelineAxisEvaluator().evaluate(
        c,
        axis.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.itemResults['auto'], isFalse);
      expect(r.itemResults['ecole'], isFalse, reason: 'left off the line');
      expect(r.score, closeTo(3 / 5, 1e-9));
      s = axis.applyFeedback(s, r);
      expect(s.placements.containsKey('auto'), isFalse, reason: 'back to tray');
      put('ecole', 'v6');
      final done = const TimelineAxisEvaluator().evaluate(
        c,
        axis.extractAnswer(s)!,
        ctx,
      );
      expect(done.outcome, Outcome.correct);
    });

    testWidgets('a 0-20 line stays one row on a desktop', (tester) async {
      view(tester);
      final (c, _) = controllerFor(situer);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      final a = tester.getTopLeft(find.byKey(const ValueKey('axis-tick-v0')));
      final b = tester.getTopLeft(find.byKey(const ValueKey('axis-tick-v20')));
      expect(b.dy, a.dy, reason: 'horizontal');
      expect(find.text('Placés : 0 sur 4'), findsOneWidget);
      // The instruction fits an axis: a year, not « le bon ordre ».
      expect(find.text('Touche une carte, puis sa place.'), findsOneWidget);
      await place(tester, 'n17', 'v17');
      expect(tester.takeException(), isNull, reason: 'a placed 17 fits');
      expect(find.text('Placés : 1 sur 4'), findsOneWidget);
      c.dispose();
    });
  });

  group('reduce', () {
    final content = axis.parse(numberLine).valueOrNull!;

    test('hold, place, move by placing over; a tick holds one item', () {
      var s = axis.initialize(content, const EngineSeed(1));
      s = axis.reduce(s, const TapAxisItem('n7')).state;
      s = axis.reduce(s, const TapTick('t5')).state;
      expect(s.placements, {'n7': 't5'});
      s = axis.reduce(s, const TapAxisItem('n9')).state;
      final t = axis.reduce(s, const TapTick('t5'));
      expect(t.state.placements, {'n9': 't5'}, reason: 'n7 went back');
      expect(t.events.map((e) => e.type), ['item_removed', 'item_placed']);
      s = axis.reduce(t.state, const TapAxisItem('n9')).state;
      expect(s.held, 'n9', reason: 'taken off its tick, held');
      expect(s.placements, isEmpty);
    });

    test('given items start on their tick and cannot move', () {
      final life = axis.parse(lifeLine).valueOrNull!;
      final s = axis.initialize(life, const EngineSeed(1));
      expect(s.placements, {'naissance': 'a0'});
      expect(s.tray, isNot(contains('naissance')));
      final held = axis.reduce(s, const TapAxisItem('marche')).state;
      expect(
        axis.reduce(held, const TapTick('a0')).events,
        isEmpty,
        reason: 'a given tick is taken',
      );
    });
  });

  group('evaluate', () {
    final content = axis.parse(numberLine).valueOrNull!;

    test('partial credit; right items lock, wrong ones go back', () {
      var s = axis.initialize(content, const EngineSeed(1));
      for (final (i, t) in [('n2', 't2'), ('n7', 't8'), ('n9', 't9')]) {
        s = axis.reduce(axis.reduce(s, TapAxisItem(i)).state, TapTick(t)).state;
      }
      final r = const TimelineCalendarEvaluator().evaluate(
        content,
        axis.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.itemResults, {'n2': true, 'n7': false, 'n9': true});
      expect(r.score, closeTo(2 / 3, 1e-9));
      s = axis.applyFeedback(s, r);
      expect(s.placements, {'n2': 't2', 'n9': 't9'});
      expect(s.locked, {'n2', 'n9'});
    });

    test('given items are not graded', () {
      final life = axis.parse(lifeLine).valueOrNull!;
      final r = const TimelineAxisEvaluator().evaluate(
        life,
        PlacementsAnswer(life.answer),
        ctx,
      );
      expect(r.outcome, Outcome.correct);
      expect(r.itemResults.keys, isNot(contains('naissance')));
    });
  });

  test('snapshots round-trip and never cross modes', () {
    final content = axis.parse(numberLine).valueOrNull!;
    var s = axis.initialize(content, const EngineSeed(1));
    s = axis.reduce(s, const TapAxisItem('n7')).state;
    final snap =
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>;
    final back = engine.restore(content, snap)! as AxisState;
    expect(back.held, 'n7');
    final order = engine.parse({
      'items': [
        {'id': 'a', 'label': 'a', 'order': 0},
        {'id': 'b', 'label': 'b', 'order': 1},
        {'id': 'c', 'label': 'c', 'order': 2},
      ],
    }).valueOrNull!;
    expect(engine.restore(order, snap), isNull);
  });

  group('in the shell', () {
    testWidgets('number line: one off → Presque → fix → Bravo', (tester) async {
      view(tester);
      final (c, outbox) = controllerFor(numberLine);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('axis-line')), findsOneWidget);
      await place(tester, 'n2', 't2');
      await place(tester, 'n7', 't8');
      await place(tester, 'n9', 't9');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await place(tester, 'n7', 't7');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(
        outbox.all
            .where((e) => e['event_type'] == 'attempt')
            .map((e) => e['is_correct']),
        [false, true],
      );
      c.dispose();
    });

    testWidgets('ticks are named for a screen reader, blank or not', (
      tester,
    ) async {
      view(tester);
      final (c, _) = controllerFor(numberLine);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.bySemanticsLabel('repère 5'), findsOneWidget);
      expect(find.bySemanticsLabel('repère 3 après 5'), findsOneWidget);
      expect(find.bySemanticsLabel('repère 4 après 0'), findsOneWidget);
      c.dispose();
    });

    testWidgets('a phone gets the axis top to bottom, with no overflow', (
      tester,
    ) async {
      view(tester, width: 375);
      final (c, _) = controllerFor(lifeLine);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('axis-placed-naissance')),
      );
      final last = tester.getTopLeft(
        find.byKey(const ValueKey('axis-tick-a6')),
      );
      expect(last.dy, greaterThan(first.dy));
      expect(find.text('Avant'), findsOneWidget);
      c.dispose();
    });

    testWidgets('keyboard alone can place', (tester) async {
      view(tester);
      final (c, _) = controllerFor(lifeLine);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> press(Finder target) async {
        for (var i = 0; i < 60; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .descendant(
                    of: target,
                    matching: find.byWidget(focused.widget),
                  )
                  .evaluate()
                  .isNotEmpty) {
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await settle(tester);
            return;
          }
        }
        fail('Tab never reached $target');
      }

      await press(find.byKey(const ValueKey('axis-item-marche')));
      await press(find.byKey(const ValueKey('axis-tick-a1')));
      expect((c.current!.state as AxisState).placements['marche'], 'a1');
      c.dispose();
    });

    testWidgets('order mode still plays through the registered engine', (
      tester,
    ) async {
      view(tester);
      final (c, _) = controllerFor({
        'items': [
          {'id': 'a', 'label': 'un', 'order': 0},
          {'id': 'b', 'label': 'deux', 'order': 1},
          {'id': 'c', 'label': 'trois', 'order': 2},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      for (final id in ['a', 'b', 'c']) {
        await tester.tap(find.byKey(ValueKey('timeline-item-$id')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });
  });
}
