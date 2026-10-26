import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const night = <String, Object?>{
  'task': 'day_night',
  'target': 'night',
  'start': 160,
};

const summer = <String, Object?>{
  'task': 'seasons',
  'target': 'summer',
  'start': 0,
  'near_misses': [
    {
      'at': 'winter',
      'diagnosis': {
        'code': 'sci.seasons.distance_not_tilt',
        'taxonomy_version': 1,
      },
    },
  ],
};

const fullMoon = <String, Object?>{
  'task': 'moon',
  'target': 'full',
  'start': 90,
  'tolerance': 20,
  'near_misses': [
    {
      'at': 'new',
      'diagnosis': {'code': 'sci.moon.full_new_swapped', 'taxonomy_version': 1},
    },
  ],
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'sky_model',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'SCI',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Fais tourner la Terre : il doit faire nuit à Québec.'},
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
      engines: LearningEngineRegistry([eraseEngine(const SkyModelEngine())]),
      evaluators: EvaluatorRegistry(const [SkyModelEvaluator()]),
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

SkyContent parsed(Map<String, Object?> config) =>
    const SkyModelEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const SkyModelEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

BlanksAnswer at(int angle) => BlanksAnswer({'angle': '$angle'});

void main() {
  const engine = SkyModelEngine();
  const evaluator = SkyModelEvaluator();

  group('SkyAngles', () {
    test('distance wraps round the circle', () {
      expect(SkyAngles.distance(350, 10), 20);
      expect(SkyAngles.distance(-30, 330), 0);
      expect(SkyAngles.norm(-15), 345);
    });

    test('day and night are halves with a margin; others are points', () {
      expect(SkyAngles.inside(SkyTask.dayNight, 'night', 60, 25), isTrue);
      expect(SkyAngles.inside(SkyTask.dayNight, 'night', 85, 25), isFalse);
      expect(SkyAngles.inside(SkyTask.dayNight, 'day', 120, 25), isTrue);
      expect(SkyAngles.inside(SkyTask.dayNight, 'noon', 150, 25), isFalse);
      expect(SkyAngles.inside(SkyTask.moon, 'first_quarter', 280, 20), isTrue);
    });
  });

  group('parse', () {
    test('rejects what cannot be played', () {
      expect(reason({...night, 'task': 'tides'}), contains('day_night'));
      expect(reason({...night, 'target': 'summer'}), contains('noon'));
      expect(reason({...night, 'start': 20}), contains('already meets'));
      expect(reason({...night, 'tolerance': 90}), contains('10 to 45'));
      expect(reason({...summer, 'town': 'Lévis'}), contains('day_night'));
      expect(
        reason({
          ...fullMoon,
          'near_misses': [
            {
              'at': 'full',
              'diagnosis': {'code': 'x', 'taxonomy_version': 1},
            },
          ],
        }),
        contains('near_miss'),
      );
      expect(parsed(night).town, 'Québec');
    });
  });

  group('turning and grading', () {
    test('nudges wrap; nothing to check before a move', () {
      final c = parsed(fullMoon);
      var s = engine.initialize(c, const EngineSeed(1));
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const NudgeSky(-SkyModelEngine.step)).state;
      expect(s.angle, 75);
      s = engine.reduce(s, const SetSkyAngle(-10)).state;
      expect(s.angle, 350);
      expect(
        evaluator.evaluate(c, engine.extractAnswer(s)!, ctx).outcome,
        Outcome.correct,
      );
    });

    test('a declared confusion is named', () {
      final moon = evaluator.evaluate(parsed(fullMoon), at(185), ctx);
      expect(moon.outcome, Outcome.incorrect);
      expect(moon.errors.single.code, 'sci.moon.full_new_swapped');
      final season = evaluator.evaluate(parsed(summer), at(10), ctx);
      expect(season.errors.single.code, 'sci.seasons.distance_not_tilt');
      final other = evaluator.evaluate(parsed(summer), at(90), ctx);
      expect(other.errors.single.isUnclassified, isTrue);
      expect(other.evaluator, 'sky_model.exact@1');
    });

    test('snapshot round-trips and refuses a false "solved"', () {
      final c = parsed(night);
      const s = SkyState(angle: 40, moved: true);
      expect(engine.restore(c, engine.snapshot(s))!.angle, 40);
      expect(
        engine.restore(c, {'angle': 180, 'moved': true, 'solved': true}),
        isNull,
      );
      expect(engine.restore(c, {'angle': 400}), isNull);
    });
  });

  group('in the shell', () {
    testWidgets('turn the Earth with the buttons: wrong, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(night);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(
        find.bySemanticsLabel(RegExp('Québec est du côté éclairé')),
        findsOne,
      );
      // 160 → 145: still day.
      await tester.tap(find.byKey(const ValueKey('sky-back')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      // On round to 40, the dark side.
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const ValueKey('sky-back')));
        await settle(tester);
      }
      expect((c.current!.state as SkyState).angle, 40);
      expect(find.bySemanticsLabel(RegExp('du côté sombre')), findsOne);
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

    testWidgets('drag the Moon to where the finger is', (tester) async {
      tallView(tester);
      final (c, _) = controllerFor(fullMoon);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final box = tester.getRect(find.byKey(const ValueKey('sky-model')));
      final earth = Offset(box.left + box.width * 0.58, box.center.dy);
      // A drag ending straight right of the Earth: the full moon.
      final g = await tester.startGesture(earth + const Offset(0, -80));
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(earth + Offset(80.0 * i / 8, -80 + 80.0 * i / 8));
        await tester.pump();
      }
      await g.up();
      await settle(tester);
      final angle = (c.current!.state as SkyState).angle;
      expect(SkyAngles.distance(angle, 0), lessThan(5));
      c.dispose();
    });

    testWidgets('every task fits a phone', (tester) async {
      tallView(tester, width: 375);
      for (final config in [night, summer, fullMoon]) {
        final (c, _) = controllerFor(config);
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c));
        expect(tester.takeException(), isNull);
        c.dispose();
      }
    });
  });
}
