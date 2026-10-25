import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend sample `content/samples/soc_timeline_morning.json`, verbatim.
const morningConfig = <String, Object?>{
  'items': [
    {'id': 'reveil', 'label': 'Je me réveille', 'order': 0},
    {'id': 'dejeuner', 'label': 'Je déjeune', 'order': 1},
    {'id': 'dents', 'label': 'Je me brosse les dents', 'order': 2},
    {'id': 'ecole', 'label': 'Je pars à l\'école', 'order': 3},
  ],
  'start_label': 'Le matin',
  'end_label': 'Plus tard',
  'hint': 'Qu\'est-ce que tu fais en premier en te levant ?',
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'timeline_calendar',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'SOC',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Mets ta matinée en ordre'},
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
        eraseEngine(const TimelineOrderEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [TimelineOrderEvaluator()]),
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
  for (var i = 0; i < 40; i++) {
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

TimelineState placeAll(
  TimelineOrderEngine engine,
  TimelineState s,
  List<String> ids,
) {
  for (final id in ids) {
    s = engine.reduce(s, PlaceInOrder(id)).state;
  }
  return s;
}

void main() {
  const engine = TimelineOrderEngine();
  final content = engine.parse(morningConfig).valueOrNull!;

  group('parse', () {
    test('reads real content; the answer follows order, not authoring', () {
      final shuffled = engine.parse({
        'items': [
          {'id': 'c', 'label': 'trois', 'order': 2},
          {'id': 'a', 'label': 'un', 'order': 0},
          {'id': 'b', 'label': 'deux', 'order': 1},
        ],
      }).valueOrNull!;
      expect(shuffled.answer, ['a', 'b', 'c']);
      expect(shuffled.startLabel, isNull);
      expect(content.answer, ['reveil', 'dejeuner', 'dents', 'ecole']);
      expect(content.startLabel, 'Le matin');
      expect(content.endLabel, 'Plus tard');
    });

    test('refuses content that cannot be played', () {
      ParseResult<TimelineContent> items(List<Map<String, Object?>> i) =>
          engine.parse({'items': i});
      Map<String, Object?> it(String id, int order) => {
        'id': id,
        'label': id,
        'order': order,
      };

      expect(
        items([it('a', 0), it('b', 1)]),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'two items is not a sequence',
      );
      expect(
        items([it('a', 0), it('b', 1), it('c', 1)]),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'a shared order has two right answers',
      );
      expect(
        items([it('a', 0), it('b', 1), it('c', 3)]),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'a gap in order',
      );
      expect(
        items([it('a', 1), it('b', 2), it('c', 3)]),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'order starts at 0',
      );
      expect(
        items([it('a', 0), it('a', 1), it('c', 2)]),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'duplicate ids',
      );
    });
  });

  group('reduce', () {
    test('fill the next empty position; send one back; refills the gap', () {
      var s = engine.initialize(content, const EngineSeed(1));
      expect(s.slots, [null, null, null, null]);
      final t = engine.reduce(s, const PlaceInOrder('dents'));
      expect(t.events.single.payload, {'item_id': 'dents', 'position': 0});
      s = placeAll(engine, t.state, ['reveil', 'ecole']);
      expect(s.slots, ['dents', 'reveil', 'ecole', null]);
      s = engine.reduce(s, const ClearPosition(0)).state;
      expect(s.slots, [null, 'reveil', 'ecole', null]);
      s = engine.reduce(s, const PlaceInOrder('dejeuner')).state;
      expect(s.slots.first, 'dejeuner', reason: 'the first gap fills first');
      expect(
        engine.reduce(s, const PlaceInOrder('reveil')).events,
        isEmpty,
        reason: 'already placed',
      );
    });

    test('submittable only once every position is filled', () {
      var s = placeAll(
        engine,
        engine.initialize(content, const EngineSeed(1)),
        ['reveil', 'dejeuner', 'dents'],
      );
      expect(engine.extractAnswer(s), isNull);
      s = placeAll(engine, s, ['ecole']);
      expect(engine.extractAnswer(s)!.orderedItemIds, content.answer);
    });

    test('the tray never starts in the right order', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(
          engine.initialize(content, EngineSeed(seed)).tray,
          isNot(content.answer),
        );
      }
    });
  });

  group('TimelineOrderEvaluator', () {
    test('partial credit: right positions lock, wrong ones empty', () {
      var s = placeAll(
        engine,
        engine.initialize(content, const EngineSeed(1)),
        ['reveil', 'dents', 'dejeuner', 'ecole'],
      );
      final r = const TimelineOrderEvaluator().evaluate(
        content,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.score, 0.5);
      expect(r.evaluator, 'timeline_calendar.exact@1');
      expect(r.itemResults, {'0': true, '1': false, '2': false, '3': true});
      s = engine.applyFeedback(s, r);
      expect(s.locked, {0, 3});
      expect(s.slots, ['reveil', null, null, 'ecole']);
      expect(
        engine.reduce(s, const ClearPosition(0)).events,
        isEmpty,
        reason: 'locked',
      );
    });

    test('all right is correct with no error; none right is incorrect', () {
      final right = const TimelineOrderEvaluator().evaluate(
        content,
        OrderingAnswer(content.answer),
        ctx,
      );
      expect(right.outcome, Outcome.correct);
      expect(right.errors, isEmpty);
      final wrong = const TimelineOrderEvaluator().evaluate(
        content,
        OrderingAnswer(['ecole', 'dents', 'dejeuner', 'reveil']),
        ctx,
      );
      expect(wrong.outcome, Outcome.incorrect);
    });
  });

  group('distractors and given positions', () {
    const seasons = <String, Object?>{
      'items': [
        {'id': 'printemps', 'label': 'printemps', 'order': 0, 'given': true},
        {'id': 'ete', 'label': 'été', 'order': 1},
        {'id': 'automne', 'label': 'automne', 'order': 2},
        {'id': 'hiver', 'label': 'hiver', 'order': 3},
      ],
      'distractors': [
        {'id': 'lundi', 'label': 'lundi'},
      ],
    };
    final c = engine.parse(seasons).valueOrNull!;

    test(
      'a given position starts filled and locked; distractors join the tray',
      () {
        expect(c.given, {0});
        final s = engine.initialize(c, const EngineSeed(2));
        expect(s.slots, ['printemps', null, null, null]);
        expect(s.locked, {0});
        expect(s.tray, unorderedEquals(['ete', 'automne', 'hiver', 'lundi']));
        expect(
          engine.reduce(s, const ClearPosition(0)).events,
          isEmpty,
          reason: 'a given item cannot be taken out',
        );
      },
    );

    test(
      'right order leaves the distractor in the tray; given is not graded',
      () {
        var s = placeAll(engine, engine.initialize(c, const EngineSeed(2)), [
          'ete',
          'automne',
          'hiver',
        ]);
        expect(s.isPlaced('lundi'), isFalse);
        final r = const TimelineOrderEvaluator().evaluate(
          c,
          engine.extractAnswer(s)!,
          ctx,
        );
        expect(r.outcome, Outcome.correct);
        expect(r.itemResults.keys, ['1', '2', '3']);
      },
    );

    test('a distractor placed in the sequence marks that position wrong', () {
      final s = placeAll(engine, engine.initialize(c, const EngineSeed(2)), [
        'ete',
        'lundi',
        'hiver',
      ]);
      final r = const TimelineOrderEvaluator().evaluate(
        c,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(r.itemResults, {'1': true, '2': false, '3': true});
      expect(r.score, closeTo(2 / 3, 1e-9), reason: 'given left out of score');
      final after = engine.applyFeedback(s, r);
      expect(after.slots, ['printemps', 'ete', null, 'hiver']);
      expect(after.isPlaced('lundi'), isFalse, reason: 'back to the tray');
    });

    test(
      'restore keeps the given position and refuses a snapshot without it',
      () {
        final s = engine.initialize(c, const EngineSeed(2));
        final snap =
            jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>;
        expect(engine.restore(c, snap)!.slots.first, 'printemps');
        expect(engine.restore(c, {...snap, 'locked': <int>[]}), isNull);
      },
    );

    test('refuses a board with fewer than two items left to place', () {
      expect(
        engine.parse({
          'items': [
            {'id': 'a', 'label': 'a', 'order': 0, 'given': true},
            {'id': 'b', 'label': 'b', 'order': 1, 'given': true},
            {'id': 'c', 'label': 'c', 'order': 2},
          ],
        }),
        isA<ParseInvalid<TimelineContent>>(),
      );
      expect(
        engine.parse({
          ...seasons,
          'distractors': [
            {'id': 'ete', 'label': 'x'},
          ],
        }),
        isA<ParseInvalid<TimelineContent>>(),
        reason: 'a distractor id clashing with an item',
      );
    });

    testWidgets('in the shell, the given tile is neutral, not green', (
      tester,
    ) async {
      tallView(tester);
      final (ctl, _) = controllerFor(seasons);
      await tester.runAsync(ctl.start);
      await tester.pumpWidget(app(ctl));
      final tile = tester.widget<AnswerTile>(
        find.descendant(
          of: find.byKey(const ValueKey('timeline-slot-0')),
          matching: find.byType(AnswerTile),
        ),
      );
      expect(tile.state, AnswerTileState.idle);
      expect(tile.onTap, isNull);
      expect(find.byKey(const ValueKey('timeline-item-lundi')), findsOneWidget);
      ctl.dispose();
    });
  });

  group('snapshot', () {
    test('round-trips through JSON', () {
      var s = placeAll(
        engine,
        engine.initialize(content, const EngineSeed(1)),
        ['reveil', 'dents'],
      );
      s = s.copyWith(locked: {0});
      final back = engine.restore(
        content,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.tray, s.tray);
      expect(back.slots, s.slots);
      expect(back.locked, {0});
    });

    test('a snapshot that does not fit the content is refused', () {
      final s = engine.initialize(content, const EngineSeed(1));
      final snap = engine.snapshot(s);
      expect(
        engine.restore(content, {
          ...snap,
          'slots': [null],
        }),
        isNull,
      );
      expect(
        engine.restore(content, {
          ...snap,
          'locked': [2],
        }),
        isNull,
        reason: 'a locked position must hold an item',
      );
    });
  });

  group('in the shell', () {
    testWidgets('two swapped → partial "Presque" → fix → Bravo', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(morningConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Le matin'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);

      for (final id in ['reveil', 'dents', 'dejeuner', 'ecole']) {
        await tester.tap(find.byKey(ValueKey('timeline-item-$id')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);

      for (final id in ['dejeuner', 'dents']) {
        await tester.tap(find.byKey(ValueKey('timeline-item-$id')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .toList();
      expect(attempts.map((e) => e['is_correct']), [false, true]);
      c.dispose();
    });

    testWidgets('keyboard alone can order', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(morningConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('timeline-item-reveil')),
      );
      expect((c.current!.state as TimelineState).slots.first, 'reveil');
      c.dispose();
    });

    testWidgets('one row when it fits, top to bottom on a phone', (
      tester,
    ) async {
      tallView(tester);
      final (wide, _) = controllerFor(morningConfig);
      await tester.runAsync(wide.start);
      await tester.pumpWidget(app(wide));
      final y0 = tester.getTopLeft(
        find.byKey(const ValueKey('timeline-slot-0')),
      );
      final y3 = tester.getTopLeft(
        find.byKey(const ValueKey('timeline-slot-3')),
      );
      expect(y3.dy, y0.dy);
      expect(y3.dx, greaterThan(y0.dx));
      wide.dispose();

      tallView(tester, width: 375);
      final (narrow, _) = controllerFor(morningConfig);
      await tester.runAsync(narrow.start);
      await tester.pumpWidget(app(narrow));
      expect(tester.takeException(), isNull);
      final n0 = tester.getTopLeft(
        find.byKey(const ValueKey('timeline-slot-0')),
      );
      final n3 = tester.getTopLeft(
        find.byKey(const ValueKey('timeline-slot-3')),
      );
      expect(n3.dy, greaterThan(n0.dy));
      expect(n3.dx, n0.dx);
      narrow.dispose();
    });
  });
}
