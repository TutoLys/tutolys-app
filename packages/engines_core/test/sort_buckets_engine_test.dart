import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend sample `content/samples/math_sort_even_odd.json`, verbatim.
const sortConfig = <String, Object?>{
  'buckets': [
    {'id': 'pair', 'label': 'Pair'},
    {'id': 'impair', 'label': 'Impair'},
  ],
  'items': [
    {'id': 'n2', 'label': '2', 'correct_bucket': 'pair'},
    {'id': 'n7', 'label': '7', 'correct_bucket': 'impair'},
    {'id': 'n4', 'label': '4', 'correct_bucket': 'pair'},
    {'id': 'n9', 'label': '9', 'correct_bucket': 'impair'},
  ],
  'hint': 'Un nombre pair se partage en deux groupes égaux.',
};

const livingConfig = <String, Object?>{
  'buckets': [
    {'id': 'vivant', 'label': 'Vivant'},
    {'id': 'non_vivant', 'label': 'Non vivant'},
  ],
  'items': [
    {'id': 'chat', 'label': 'chat', 'correct_bucket': 'vivant'},
    {'id': 'roche', 'label': 'roche', 'correct_bucket': 'non_vivant'},
  ],
  'shuffle': false,
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'sort_buckets',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Classe chaque nombre'},
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
      engines: LearningEngineRegistry([eraseEngine(const SortBucketsEngine())]),
      evaluators: EvaluatorRegistry(const [SortBucketsEvaluator()]),
      store: InMemoryActivitySessionStore(outbox),
      appVersion: '0.2.0',
      seed: 3,
    ),
    outbox,
  );
}

Widget app(ActivitySessionController c, {VoidCallback? onDone}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(
    body: LearningActivityView(
      controller: c,
      locale: fr,
      onDone: onDone ?? () {},
    ),
  ),
);

/// A tablet-sized view, so the whole board is on screen.
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

SortState sortAll(
  SortBucketsEngine engine,
  SortState s,
  Map<String, String> placements,
) {
  for (final e in placements.entries) {
    s = engine
        .reduce(engine.reduce(s, TapSortItem(e.key)).state, TapBucket(e.value))
        .state;
  }
  return s;
}

void main() {
  const engine = SortBucketsEngine();
  final content = engine.parse(sortConfig).valueOrNull!;

  group('parse', () {
    test('reads real content; buckets keep their authored order', () {
      expect(content.buckets.map((b) => b.id), ['pair', 'impair']);
      expect(content.answer, {
        'n2': 'pair',
        'n7': 'impair',
        'n4': 'pair',
        'n9': 'impair',
      });
      expect(content.shuffle, isTrue, reason: 'shuffle defaults to true');
      expect(engine.parse(livingConfig).valueOrNull!.shuffle, isFalse);
    });

    test('refuses content that cannot be played', () {
      ParseResult<SortContent> with_(Map<String, Object?> patch) =>
          engine.parse({...sortConfig, ...patch});

      expect(
        with_({
          'buckets': [
            {'id': 'pair', 'label': 'Pair'},
          ],
        }),
        isA<ParseInvalid<SortContent>>(),
        reason: 'one bucket is not a sort',
      );
      expect(
        with_({
          'items': [
            {'id': 'n2', 'label': '2', 'correct_bucket': 'zut'},
            {'id': 'n7', 'label': '7', 'correct_bucket': 'impair'},
          ],
        }),
        isA<ParseInvalid<SortContent>>(),
        reason: 'an item whose bucket does not exist',
      );
      expect(
        with_({
          'items': [
            {'id': 'n2', 'label': '2', 'correct_bucket': 'pair'},
            {'id': 'n2', 'label': '7', 'correct_bucket': 'impair'},
          ],
        }),
        isA<ParseInvalid<SortContent>>(),
        reason: 'duplicate item ids',
      );
      expect(
        with_({
          'buckets': [
            {'id': 'a', 'label': 'A'},
            {'id': 'a', 'label': 'B'},
          ],
        }),
        isA<ParseInvalid<SortContent>>(),
        reason: 'duplicate bucket ids',
      );
    });
  });

  group('reduce', () {
    test('pick an item, drop it in a bucket, take it back out', () {
      var s = engine.initialize(content, const EngineSeed(1));
      expect(s.itemOrder, unorderedEquals(['n2', 'n7', 'n4', 'n9']));
      expect(
        engine.reduce(s, const TapBucket('pair')).events,
        isEmpty,
        reason: 'nothing held',
      );
      s = engine.reduce(s, const TapSortItem('n2')).state;
      expect(s.selected, 'n2');
      final placed = engine.reduce(s, const TapBucket('pair'));
      expect(placed.events.single.type, 'item_placed');
      expect(placed.events.single.payload, {
        'item_id': 'n2',
        'bucket_id': 'pair',
      });
      s = placed.state;
      expect(s.placements, {'n2': 'pair'});
      expect(s.selected, isNull);

      final out = engine.reduce(s, const TapSortItem('n2'));
      expect(out.events.single.type, 'item_removed');
      expect(out.state.placements, isEmpty);
      expect(
        out.state.selected,
        'n2',
        reason: 'held, ready for another bucket',
      );

      expect(
        engine.reduce(out.state, const TapSortItem('n2')).state.selected,
        isNull,
        reason: 'tapping the held item again puts it down',
      );
    });

    test('holding an item, a tap on a sorted item drops it in that bucket', () {
      var s = sortAll(engine, engine.initialize(content, const EngineSeed(1)), {
        'n7': 'impair',
      });
      s = engine.reduce(s, const TapSortItem('n9')).state;
      final t = engine.reduce(s, const TapSortItem('n7'));
      expect(t.state.placements, {'n7': 'impair', 'n9': 'impair'});
      expect(t.state.selected, isNull);
      expect(t.events.single.type, 'item_placed');
    });

    test('submittable only once every item is sorted', () {
      var s = engine.initialize(content, const EngineSeed(1));
      s = sortAll(engine, s, {'n2': 'pair', 'n7': 'impair', 'n4': 'pair'});
      expect(engine.extractAnswer(s), isNull);
      s = sortAll(engine, s, {'n9': 'impair'});
      expect(engine.extractAnswer(s)!.placements, hasLength(4));
    });

    test('a seed reproduces the tray order; shuffle:false keeps it', () {
      expect(
        engine.initialize(content, const EngineSeed(5)).itemOrder,
        engine.initialize(content, const EngineSeed(5)).itemOrder,
      );
      final living = engine.parse(livingConfig).valueOrNull!;
      expect(engine.initialize(living, const EngineSeed(5)).itemOrder, [
        'chat',
        'roche',
      ]);
    });
  });

  group('SortBucketsEvaluator', () {
    test(
      'partial credit: right items lock, wrong ones go back to the tray',
      () {
        var s = sortAll(
          engine,
          engine.initialize(content, const EngineSeed(1)),
          {'n2': 'pair', 'n7': 'impair', 'n4': 'impair', 'n9': 'impair'},
        );
        final r = const SortBucketsEvaluator().evaluate(
          content,
          engine.extractAnswer(s)!,
          ctx,
        );
        expect(r.outcome, Outcome.partial);
        expect(r.score, 0.75);
        expect(r.evaluator, 'sort_buckets.exact@1');
        expect(r.itemResults, {
          'n2': true,
          'n7': true,
          'n4': false,
          'n9': true,
        });
        s = engine.applyFeedback(s, r);
        expect(s.locked, {'n2', 'n7', 'n9'});
        expect(s.placements, {'n2': 'pair', 'n7': 'impair', 'n9': 'impair'});
        expect(
          engine.reduce(s, const TapSortItem('n2')).events,
          isEmpty,
          reason: 'locked',
        );
        expect(engine.extractAnswer(s), isNull);
      },
    );

    test('all wrong is incorrect; all right is correct with no error', () {
      final wrong = const SortBucketsEvaluator().evaluate(
        content,
        PlacementsAnswer({
          'n2': 'impair',
          'n7': 'pair',
          'n4': 'impair',
          'n9': 'pair',
        }),
        ctx,
      );
      expect(wrong.outcome, Outcome.incorrect);
      expect(wrong.score, 0);
      final right = const SortBucketsEvaluator().evaluate(
        content,
        PlacementsAnswer(content.answer),
        ctx,
      );
      expect(right.outcome, Outcome.correct);
      expect(right.errors, isEmpty);
    });

    test('an answer that skips an item is a programming error', () {
      expect(
        () => const SortBucketsEvaluator().evaluate(
          content,
          PlacementsAnswer({'n2': 'pair'}),
          ctx,
        ),
        throwsArgumentError,
      );
    });
  });

  group('snapshot', () {
    test('round-trips through JSON', () {
      var s = sortAll(engine, engine.initialize(content, const EngineSeed(1)), {
        'n2': 'pair',
      });
      s = engine.reduce(s, const TapSortItem('n7')).state;
      s = s.copyWith(locked: {'n2'});
      final back = engine.restore(
        content,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.itemOrder, s.itemOrder);
      expect(back.placements, s.placements);
      expect(back.selected, 'n7');
      expect(back.locked, {'n2'});
    });

    test('a snapshot from other content is refused, not trusted', () {
      final living = engine.parse(livingConfig).valueOrNull!;
      final s = engine.initialize(content, const EngineSeed(1));
      expect(engine.restore(living, engine.snapshot(s)), isNull);
      expect(engine.restore(content, {'item_order': 'nope'}), isNull);
    });
  });

  group('in the shell', () {
    testWidgets('one wrong item → partial "Presque" → fix it → Bravo', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(sortConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Pair'), findsOneWidget);
      expect(find.text('Impair'), findsOneWidget);

      for (final (item, bucket) in [
        ('n2', 'pair'),
        ('n7', 'impair'),
        ('n4', 'impair'),
        ('n9', 'impair'),
      ]) {
        await tester.tap(find.byKey(ValueKey('sort-item-$item')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('sort-bucket-$bucket')));
        await settle(tester);
      }
      expect(find.byKey(const ValueKey('sort-placed-n4')), findsOneWidget);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      expect(find.textContaining('Certaines sont justes'), findsOneWidget);

      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      expect(
        tester
            .widget<AnswerTile>(find.byKey(const ValueKey('sort-placed-n2')))
            .state,
        AnswerTileState.correct,
      );
      expect(
        find.byKey(const ValueKey('sort-item-n4')),
        findsOneWidget,
        reason: 'the wrong item is back in the tray',
      );

      await tester.tap(find.byKey(const ValueKey('sort-item-n4')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('sort-bucket-pair')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);

      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .toList();
      expect(attempts, hasLength(2), reason: 'one attempt per checked board');
      expect(attempts.map((e) => e['is_correct']), [false, true]);
      c.dispose();
    });

    testWidgets('keyboard alone can sort', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(livingConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('sort-item-chat')),
      );
      await pressWithKeyboard(
        tester,
        find.byKey(const ValueKey('sort-bucket-vivant')),
      );
      expect((c.current!.state as SortState).placements, {'chat': 'vivant'});
      c.dispose();
    });

    testWidgets('a série of two sorting questions plays through', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor({
        'questions': [
          {
            'prompt': {'text': 'Classe les nombres'},
            'config': sortConfig,
          },
          {
            'prompt': {'text': 'Vivant ou non vivant ?'},
            'config': livingConfig,
          },
        ],
      });
      var done = false;
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, onDone: () => done = true));
      expect(find.text('Classe les nombres'), findsOneWidget);
      for (final e in content.answer.entries) {
        await tester.tap(find.byKey(ValueKey('sort-item-${e.key}')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('sort-bucket-${e.value}')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('CONTINUER'));
      await settle(tester);
      expect(find.text('Vivant ou non vivant ?'), findsOneWidget);
      for (final (item, bucket) in [
        ('chat', 'vivant'),
        ('roche', 'non_vivant'),
      ]) {
        await tester.tap(find.byKey(ValueKey('sort-item-$item')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('sort-bucket-$bucket')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(done, isFalse);
      c.dispose();
    });

    testWidgets('four buckets on a phone wrap two to a row', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({
        'buckets': [
          for (final id in ['a', 'b', 'c', 'd']) {'id': id, 'label': id},
        ],
        'items': [
          for (final id in ['a', 'b', 'c', 'd'])
            {'id': 'i$id', 'label': 'item $id', 'correct_bucket': id},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final a = tester.getTopLeft(find.byKey(const ValueKey('sort-bucket-a')));
      final cc = tester.getTopLeft(find.byKey(const ValueKey('sort-bucket-c')));
      expect(cc.dy, greaterThan(a.dy));
      c.dispose();
    });
  });
}
