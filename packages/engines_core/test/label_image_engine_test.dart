import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// L9, Hafid's fox emotions, with the proposed points (content/images/README).
const emotions = <String, Object?>{
  'image_ref': 'img_emotions',
  'aspect_ratio': 1.4286,
  'points': [
    {'id': 'p_joie', 'x': 0.167, 'y': 0.2},
    {'id': 'p_tristesse', 'x': 0.5, 'y': 0.2},
    {'id': 'p_colere', 'x': 0.833, 'y': 0.2},
    {'id': 'p_peur', 'x': 0.333, 'y': 0.7},
    {'id': 'p_surprise', 'x': 0.666, 'y': 0.7},
  ],
  'labels': [
    {'id': 'joie', 'label': 'la joie', 'point': 'p_joie'},
    {'id': 'tristesse', 'label': 'la tristesse', 'point': 'p_tristesse'},
    {'id': 'colere', 'label': 'la colère', 'point': 'p_colere'},
    {'id': 'peur', 'label': 'la peur', 'point': 'p_peur'},
    {'id': 'surprise', 'label': 'la surprise', 'point': 'p_surprise'},
    {'id': 'fatigue', 'label': 'la fatigue'},
  ],
};

// Two points, no distractor: the smallest board.
const compass = <String, Object?>{
  'image_ref': 'img_classroom',
  'aspect_ratio': 1,
  'points': [
    {'id': 'n', 'x': 0.865, 'y': 0.75},
    {'id': 's', 'x': 0.865, 'y': 0.94},
  ],
  'labels': [
    {'id': 'nord', 'label': 'Nord', 'point': 'n'},
    {'id': 'sud', 'label': 'Sud', 'point': 's'},
  ],
  'shuffle': false,
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'label_image',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'CCQ',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Place le nom de chaque émotion.'},
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
      engines: LearningEngineRegistry([eraseEngine(const LabelImageEngine())]),
      evaluators: EvaluatorRegistry(const [LabelImageEvaluator()]),
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
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

LabelContent parsed(Map<String, Object?> config) =>
    const LabelImageEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const LabelImageEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

Future<void> place(WidgetTester tester, String label, String point) async {
  await tester.tap(find.byKey(ValueKey('label-chip-$label')));
  await settle(tester);
  await tester.tap(find.byKey(ValueKey('label-point-$point')));
  await settle(tester);
}

void main() {
  const engine = LabelImageEngine();

  group('parse', () {
    test('the L9 board parses, with one distractor', () {
      final c = parsed(emotions);
      expect(c.points, hasLength(5));
      expect(c.labels, hasLength(6));
      expect(c.label('fatigue').point, isNull);
      expect(c.answer['p_peur'], 'peur');
    });

    test('rejects what cannot be played', () {
      List<Map<String, Object?>> labels() => [
        for (final l in emotions['labels']! as List)
          Map<String, Object?>.of(l as Map<String, Object?>),
      ];
      expect(reason({...emotions, 'image_ref': null}), contains('image_ref'));
      expect(reason({...emotions, 'aspect_ratio': 9}), contains('0.25 to 4'));
      expect(
        reason({
          ...emotions,
          'points': [
            {'id': 'a', 'x': 0.5, 'y': 1.2},
            {'id': 'b', 'x': 0.5, 'y': 0.5},
          ],
        }),
        contains('between 0 and 1'),
      );
      expect(
        reason({...emotions, 'labels': labels()..removeAt(0)}),
        contains('Every point needs its label'),
      );
      expect(
        reason({...emotions, 'labels': labels()..[1]['point'] = 'p_joie'}),
        contains('one label'),
      );
      expect(
        reason({
          ...emotions,
          'labels': [
            ...labels(),
            {'id': 'x1', 'label': 'x'},
            {'id': 'x2', 'label': 'y'},
          ],
        }),
        contains('2 distractor'),
      );
      expect(
        reason({...emotions, 'labels': labels()..[0]['point'] = 'nowhere'}),
        contains('one of the points'),
      );
    });
  });

  group('reduce', () {
    test('pick a label, drop it on a point, take it back', () {
      var s = engine.initialize(parsed(compass), const EngineSeed(1));
      s = engine.reduce(s, const TapLabel('nord')).state;
      expect(s.held, 'nord');
      final drop = engine.reduce(s, const TapPoint('n'));
      expect(drop.state.placed, {'n': 'nord'});
      expect(drop.state.held, isNull);
      final back = engine.reduce(drop.state, const TapPoint('n'));
      expect(back.state.placed, isEmpty);
      expect(back.state.held, 'nord');
    });

    test('dropping on a filled point sends its label back to the tray', () {
      var s = engine.initialize(parsed(compass), const EngineSeed(1));
      s = engine.reduce(s, const TapLabel('nord')).state;
      s = engine.reduce(s, const TapPoint('n')).state;
      s = engine.reduce(s, const TapLabel('sud')).state;
      s = engine.reduce(s, const TapPoint('n')).state;
      expect(s.placed, {'n': 'sud'});
      expect(s.placedLabels, isNot(contains('nord')));
    });

    test('VALIDER waits until every point has a label', () {
      var s = engine.initialize(parsed(compass), const EngineSeed(1));
      s = engine.reduce(s, const TapLabel('nord')).state;
      s = engine.reduce(s, const TapPoint('n')).state;
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const TapLabel('sud')).state;
      s = engine.reduce(s, const TapPoint('s')).state;
      expect(engine.extractAnswer(s)!.placements, {'nord': 'n', 'sud': 's'});
    });
  });

  group('LabelImageEvaluator and feedback', () {
    const evaluator = LabelImageEvaluator();

    test('partial credit; right labels lock, wrong ones go back', () {
      final c = parsed(compass);
      var s = engine.initialize(c, const EngineSeed(1));
      for (final (l, p) in [('nord', 's'), ('sud', 'n')]) {
        s = engine.reduce(s, TapLabel(l)).state;
        s = engine.reduce(s, TapPoint(p)).state;
      }
      final swapped = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(swapped.outcome, Outcome.incorrect);
      expect(swapped.evaluator, 'label_image.exact@1');
      s = engine.applyFeedback(s, swapped);
      expect(s.placed, isEmpty);
      expect(s.tried, {'nord|s', 'sud|n'});

      // The same mistake can't be made twice.
      s = engine.reduce(s, const TapLabel('nord')).state;
      expect(engine.reduce(s, const TapPoint('s')).state.placed, isEmpty);
    });

    test('a distractor placed anywhere is wrong; score is over points', () {
      final c = parsed(emotions);
      final result = evaluator.evaluate(
        c,
        PlacementsAnswer({
          'joie': 'p_joie',
          'tristesse': 'p_tristesse',
          'colere': 'p_colere',
          'peur': 'p_peur',
          'fatigue': 'p_surprise',
        }),
        ctx,
      );
      expect(result.outcome, Outcome.partial);
      expect(result.score, 0.8);
      expect(result.itemResults['fatigue'], isFalse);
    });
  });

  group('snapshot', () {
    test('round-trips, and rejects a locked wrong label', () {
      final c = parsed(compass);
      final s = engine
          .initialize(c, const EngineSeed(1))
          .copyWith(placed: {'n': 'nord'}, locked: {'n'}, held: 'sud');
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.placed, {'n': 'nord'});
      expect(back.held, 'sud');
      expect(
        engine.restore(c, {
          ...engine.snapshot(s),
          'placed': {'n': 'sud'},
          'held': null,
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('L9: a swap goes back amber-free, then all right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(emotions);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('label-chip-fatigue')), findsOneWidget);

      await place(tester, 'joie', 'p_tristesse');
      await place(tester, 'tristesse', 'p_joie');
      await place(tester, 'colere', 'p_colere');
      await place(tester, 'peur', 'p_peur');
      await place(tester, 'surprise', 'p_surprise');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      final s = c.current!.state as LabelState;
      expect(s.locked, {'p_colere', 'p_peur', 'p_surprise'});
      expect(find.byKey(const ValueKey('label-chip-joie')), findsOneWidget);

      await place(tester, 'joie', 'p_joie');
      await place(tester, 'tristesse', 'p_tristesse');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      final attempts = outbox.all
          .where((e) => e['event_type'] == 'attempt')
          .map((e) => e['is_correct']);
      expect(attempts, [false, true]);
      c.dispose();
    });

    testWidgets('a placed label shows on its point, with the point named', (
      tester,
    ) async {
      tallView(tester);
      final (c, _) = controllerFor(compass);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(
        find.bySemanticsLabel('repère 1, en bas à droite'),
        findsOneWidget,
      );
      await place(tester, 'nord', 'n');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('label-point-n')),
          matching: find.text('Nord'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('repère 1, en bas à droite : Nord'),
        findsOneWidget,
      );
      c.dispose();
    });

    testWidgets('points stay inside the picture on a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(emotions);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await place(tester, 'colere', 'p_colere');
      expect(tester.takeException(), isNull);
      final picture = tester.getRect(find.byType(AspectRatio).last);
      final chip = tester.getRect(
        find.byKey(const ValueKey('label-point-p_colere')),
      );
      expect(picture.contains(chip.topLeft), isTrue);
      expect(chip.right, lessThanOrEqualTo(picture.right + 0.5));
      c.dispose();
    });
  });
}
