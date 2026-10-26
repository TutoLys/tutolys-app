import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const square = <String, Object?>{
  'pegs': 5,
  'task': 'build',
  'target': 'square',
};

const copyL = <String, Object?>{
  'pegs': 5,
  'task': 'copy',
  // An L of 6 corners.
  'model': [
    {'row': 0, 'col': 0},
    {'row': 0, 'col': 1},
    {'row': 1, 'col': 1},
    {'row': 1, 'col': 2},
    {'row': 2, 'col': 2},
    {'row': 2, 'col': 0},
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'geometry_lab',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Fais un carré avec l’élastique.'},
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
      engines: LearningEngineRegistry([eraseEngine(const GeometryLabEngine())]),
      evaluators: EvaluatorRegistry(const [GeometryLabEvaluator()]),
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

GeoContent parsed(Map<String, Object?> config) =>
    const GeometryLabEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const GeometryLabEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

OrderingAnswer band(List<Peg> pegs) =>
    OrderingAnswer([for (final p in pegs) GeometryLabEngine.pegId(p)]);

void main() {
  const engine = GeometryLabEngine();
  const evaluator = GeometryLabEvaluator();

  group('GeoShape', () {
    test('a peg the band runs straight through is not a corner', () {
      expect(GeoShape.corners([(0, 0), (0, 1), (0, 2), (2, 2), (2, 0)]), [
        (0, 0),
        (0, 2),
        (2, 2),
        (2, 0),
      ]);
    });

    test('a crossed band is not a figure', () {
      expect(GeoShape.simple([(0, 0), (2, 2), (0, 2), (2, 0)]), isFalse);
      expect(GeoShape.simple([(0, 0), (0, 2), (0, 1), (2, 1)]), isFalse);
      expect(GeoShape.simple([(0, 0), (0, 1), (0, 2)]), isFalse);
      expect(GeoShape.simple([(0, 0), (0, 2), (2, 2), (2, 0)]), isTrue);
    });

    test('names figures as mathematics does', () {
      const sq = [(0, 0), (0, 2), (2, 2), (2, 0)];
      const tilted = [(0, 1), (1, 2), (2, 1), (1, 0)];
      const rect = [(0, 0), (0, 3), (1, 3), (1, 0)];
      const rhombus = [(0, 1), (2, 2), (4, 1), (2, 0)];
      expect(GeoShape.matches(sq, GeoTarget.square, 0), isTrue);
      expect(GeoShape.matches(tilted, GeoTarget.square, 0), isTrue);
      expect(GeoShape.matches(sq, GeoTarget.rectangle, 0), isTrue);
      expect(GeoShape.matches(sq, GeoTarget.rhombus, 0), isTrue);
      expect(GeoShape.matches(rect, GeoTarget.square, 0), isFalse);
      expect(GeoShape.matches(rect, GeoTarget.rectangle, 0), isTrue);
      expect(GeoShape.matches(rhombus, GeoTarget.rhombus, 0), isTrue);
      expect(GeoShape.matches(rhombus, GeoTarget.square, 0), isFalse);
      expect(GeoShape.matches(rect, GeoTarget.polygon, 4), isTrue);
    });

    test('the same figure, moved or traced backwards', () {
      const model = [(0, 0), (0, 1), (1, 1), (1, 2), (2, 2), (2, 0)];
      final moved = [for (final p in model) (p.$1 + 2, p.$2 + 1)];
      expect(GeoShape.sameFigure(model, moved), isTrue);
      expect(GeoShape.sameFigure(model, moved.reversed.toList()), isTrue);
      expect(
        GeoShape.sameFigure(model, [...moved.skip(2), ...moved.take(2)]),
        isTrue,
      );
      // Mirrored: not the same at grade 1.
      expect(
        GeoShape.sameFigure(model, [for (final p in model) (p.$1, 2 - p.$2)]),
        isFalse,
      );
    });
  });

  group('parse', () {
    test('rejects what cannot be played', () {
      expect(reason({...square, 'pegs': 9}), contains('3 to 7'));
      expect(reason({...square, 'target': 'circle'}), contains('triangle'));
      expect(reason({...square, 'target': 'polygon'}), contains('sides'));
      expect(reason({...square, 'sides': 4}), contains('polygon'));
      expect(
        reason({
          ...copyL,
          'model': [
            {'row': 0, 'col': 0},
            {'row': 2, 'col': 2},
            {'row': 0, 'col': 2},
            {'row': 2, 'col': 0},
          ],
        }),
        contains('cross itself'),
      );
      expect(
        reason({
          ...copyL,
          'model': [
            {'row': 0, 'col': 0},
            {'row': 0, 'col': 1},
            {'row': 0, 'col': 2},
            {'row': 2, 'col': 0},
          ],
        }),
        contains('corner by'),
      );
      expect(reason({...copyL, 'target': 'square'}), contains('build'));
    });
  });

  group('the band', () {
    test('stretches, takes back, closes and reopens', () {
      final c = parsed(square);
      var s = engine.initialize(c, const EngineSeed(1));
      for (final p in [(0, 0), (0, 2), (2, 2), (3, 3)]) {
        s = engine.reduce(s, TapPeg(p)).state;
      }
      s = engine.reduce(s, const TapPeg((3, 3))).state;
      expect(s.band, [(0, 0), (0, 2), (2, 2)]);
      s = engine.reduce(s, const TapPeg((2, 0))).state;
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const TapPeg((0, 0))).state;
      expect(s.closed, isTrue);
      expect(engine.reduce(s, const TapPeg((4, 4))).state.band.length, 4);
      final reopened = engine.reduce(s, const TapPeg((2, 0))).state;
      expect(reopened.closed, isFalse);
      expect(engine.reduce(s, const ClearBand()).state.band, isEmpty);
      expect(engine.reduce(s, const TapPeg((9, 9))).state, same(s));
    });

    test('grades the geometry; a wrong figure stays', () {
      final c = parsed(square);
      final r = evaluator.evaluate(
        c,
        band([(0, 0), (0, 3), (1, 3), (1, 0)]),
        ctx,
      );
      expect(r.outcome, Outcome.incorrect);
      expect(r.itemResults, {'simple': true, 'shape': false});
      final crossed = evaluator.evaluate(
        c,
        band([(0, 0), (2, 2), (0, 2), (2, 0)]),
        ctx,
      );
      expect(crossed.itemResults, {'simple': false, 'shape': false});
      expect(
        evaluator
            .evaluate(c, band([(1, 2), (2, 3), (3, 2), (2, 1)]), ctx)
            .outcome,
        Outcome.correct,
      );
      final cc = parsed(copyL);
      expect(
        evaluator
            .evaluate(
              cc,
              band([(2, 1), (2, 2), (3, 2), (3, 3), (4, 3), (4, 1)]),
              ctx,
            )
            .outcome,
        Outcome.correct,
      );
      var s = GeoState(
        pegs: 5,
        band: const [(0, 0), (0, 3), (1, 3), (1, 0)],
        closed: true,
      );
      s = engine.applyFeedback(s, r);
      expect(s.band.length, 4);
      expect(s.solved, isFalse);
    });

    test('snapshot round-trips and refuses nonsense', () {
      final c = parsed(square);
      const s = GeoState(pegs: 5, band: [(0, 0), (0, 2), (2, 2)], closed: true);
      final back = engine.restore(c, engine.snapshot(s))!;
      expect(back.band, s.band);
      expect(back.closed, isTrue);
      expect(
        engine.restore(c, {
          'band': ['9,9'],
        }),
        isNull,
      );
      expect(
        engine.restore(c, {
          'band': ['0,0', '0,1'],
          'closed': true,
        }),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('build a square by tapping pegs: wrong, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(square);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      Future<void> tap(int r, int col) async {
        await tester.tap(find.byKey(ValueKey('geo-peg-$r-$col')));
        await settle(tester);
      }

      // A rectangle first.
      for (final (r, col) in [(0, 0), (0, 3), (1, 3), (1, 0), (0, 0)]) {
        await tap(r, col);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      // Reopen at the last peg, take back two corners, then stretch the
      // band down to make a 3 × 3 square.
      await tap(1, 0); // reopens
      await tap(1, 0); // takes back (1,0)
      await tap(1, 3); // takes back (1,3)
      await tap(3, 3);
      await tap(3, 0);
      await tap(0, 0); // closes
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

    testWidgets('copy: model and board stack on a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor({...copyL, 'pegs': 7});
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('geo-model')), findsOne);
      expect(find.byKey(const ValueKey('geo-board')), findsOne);
      expect(
        find.bySemanticsLabel(RegExp('Le modèle : une figure à 6 côtés')),
        findsOne,
      );
      c.dispose();
    });
  });
}
