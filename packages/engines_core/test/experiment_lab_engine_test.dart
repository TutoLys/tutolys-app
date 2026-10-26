import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// What does a plant need? Water × light.
const plant = <String, Object?>{
  'scene': 'plant',
  'variables': [
    {
      'id': 'eau',
      'label': 'Eau',
      'values': [
        {'id': 'aucune', 'label': 'Pas d’eau'},
        {'id': 'un_peu', 'label': 'Un peu'},
      ],
    },
    {
      'id': 'lumiere',
      'label': 'Lumière',
      'values': [
        {'id': 'noir', 'label': 'Dans le noir'},
        {'id': 'soleil', 'label': 'Au soleil'},
      ],
    },
  ],
  'outcomes': [
    {
      'when': {'eau': 'aucune', 'lumiere': 'noir'},
      'label': 'La plante sèche.',
      'look': 'dry',
    },
    {
      'when': {'eau': 'aucune', 'lumiere': 'soleil'},
      'label': 'La plante sèche.',
      'look': 'dry',
    },
    {
      'when': {'eau': 'un_peu', 'lumiere': 'noir'},
      'label': 'La plante reste petite.',
      'look': 'small',
    },
    {
      'when': {'eau': 'un_peu', 'lumiere': 'soleil'},
      'label': 'La plante pousse bien.',
      'look': 'healthy',
    },
  ],
  'options': [
    {'id': 'deux', 'label': 'Elle a besoin d’eau et de lumière.'},
    {'id': 'eau', 'label': 'Elle a seulement besoin d’eau.'},
    {'id': 'rien', 'label': 'Elle n’a besoin de rien.'},
  ],
  'correct': 'deux',
  'min_runs': 3,
  'shuffle': false,
};

const water = <String, Object?>{
  'scene': 'water',
  'variables': [
    {
      'id': 'chaleur',
      'label': 'Température',
      'values': [
        {'id': 'froid', 'label': 'Congélateur'},
        {'id': 'piece', 'label': 'Cuisine'},
        {'id': 'chaud', 'label': 'Sur le feu'},
      ],
    },
  ],
  'outcomes': [
    {
      'when': {'chaleur': 'froid'},
      'label': 'L’eau devient de la glace.',
      'look': 'ice',
    },
    {
      'when': {'chaleur': 'piece'},
      'label': 'L’eau reste liquide.',
      'look': 'liquid',
    },
    {
      'when': {'chaleur': 'chaud'},
      'label': 'L’eau devient de la vapeur.',
      'look': 'steam',
    },
  ],
  'options': [
    {'id': 'a', 'label': 'La chaleur change l’état de l’eau.'},
    {'id': 'b', 'label': 'L’eau ne change jamais.'},
  ],
  'correct': 'a',
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'experiment_lab',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'SCI',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'De quoi la plante a-t-elle besoin ? Fais des essais.'},
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
        eraseEngine(const ExperimentLabEngine()),
      ]),
      evaluators: EvaluatorRegistry(const [ExperimentLabEvaluator()]),
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
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

ExperimentContent parsed(Map<String, Object?> config) =>
    const ExperimentLabEngine().parse(config).valueOrNull!;

String? reason(Map<String, Object?> config) =>
    switch (const ExperimentLabEngine().parse(config)) {
      ParseInvalid(:final reason) => reason,
      _ => null,
    };

void main() {
  const engine = ExperimentLabEngine();
  const evaluator = ExperimentLabEvaluator();

  group('parse', () {
    test('maps every combination to its outcome', () {
      final c = parsed(plant);
      expect(c.outcomes.keys, hasLength(4));
      expect(c.outcomes['un_peu|soleil']!.look, 'healthy');
      expect(
        c.describe('aucune|noir'),
        'Eau : Pas d’eau, Lumière : Dans le noir',
      );
      // min_runs defaults to 2.
      expect(parsed(water).minRuns, 2);
    });

    test('rejects what cannot be played', () {
      final outcomes = (plant['outcomes']! as List).cast<Object?>();
      expect(
        reason({...plant, 'outcomes': outcomes.take(3).toList()}),
        contains('Every combination'),
      );
      expect(
        reason({
          ...plant,
          'outcomes': [...outcomes, outcomes.first],
        }),
        contains('same when'),
      );
      expect(
        reason({...water, 'scene': 'volcano'}),
        contains('plant, water or mix'),
      );
      final badLook = [
        ...(water['outcomes']! as List).take(2),
        {
          'when': {'chaleur': 'chaud'},
          'label': 'x',
          'look': 'healthy',
        },
      ];
      expect(reason({...water, 'outcomes': badLook}), contains('ice'));
      expect(reason({...plant, 'correct': 'zz'}), contains('correct'));
      expect(reason({...plant, 'min_runs': 5}), contains('min_runs'));
      final noScene = Map.of(water)..remove('scene');
      expect(reason(noScene), contains('look needs a scene'));
    });
  });

  group('reduce', () {
    test('runs are logged once each; the conclusion waits for min_runs', () {
      final c = parsed(plant);
      var s = engine.initialize(c, const EngineSeed(1));
      expect(s.current, 'aucune|noir');
      s = engine.reduce(s, const RunExperiment()).state;
      s = engine.reduce(s, const RunExperiment()).state;
      expect(s.runs, ['aucune|noir']);
      s = engine.reduce(s, const SetVariable(0, 'un_peu')).state;
      s = engine.reduce(s, const RunExperiment()).state;
      expect(
        engine.reduce(s, const PickConclusion('deux')).state.pick.selected,
        isNull,
      );
      s = engine.reduce(s, const SetVariable(1, 'soleil')).state;
      final t = engine.reduce(s, const RunExperiment());
      expect(t.events.single.type, 'experiment_run');
      s = t.state;
      expect(s.shown, 'un_peu|soleil');
      expect(s.readyToConclude, isTrue);
      s = engine.reduce(s, const PickConclusion('eau')).state;
      final wrong = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(wrong.outcome, Outcome.incorrect);
      expect(wrong.evaluator, 'experiment_lab.exact@1');
      s = engine.applyFeedback(s, wrong);
      expect(s.pick.tried, {'eau'});
      // Running more is allowed after a wrong conclusion.
      s = engine.reduce(s, const SetVariable(0, 'aucune')).state;
      s = engine.reduce(s, const RunExperiment()).state;
      expect(s.runs.last, 'aucune|soleil');
    });

    test('snapshot round-trips and refuses an early conclusion', () {
      final c = parsed(plant);
      final s = engine
          .initialize(c, const EngineSeed(1))
          .copyWith(runs: ['aucune|noir', 'un_peu|noir', 'un_peu|soleil']);
      expect(engine.restore(c, engine.snapshot(s))!.runs, hasLength(3));
      final early = engine.snapshot(
        s.copyWith(
          runs: ['aucune|noir'],
          pick: const PickState(
            order: ['deux', 'eau', 'rien'],
            selected: 'deux',
          ),
        ),
      );
      expect(engine.restore(c, early), isNull);
    });
  });

  group('in the shell', () {
    testWidgets('try three experiments, conclude wrong, then right', (
      tester,
    ) async {
      tallView(tester);
      final (c, outbox) = controllerFor(plant);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.text('Fais un essai pour voir.'), findsOne);
      expect(find.byKey(const ValueKey('exp-remaining')), findsOne);

      Future<void> tap(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await settle(tester);
      }

      await tap('exp-run');
      expect(find.text('La plante sèche.'), findsWidgets);
      await tap('exp-eau-un_peu');
      await tap('exp-run');
      await tap('exp-lumiere-soleil');
      await tap('exp-run');
      expect(find.text('La plante pousse bien.'), findsWidgets);
      expect(find.byKey(const ValueKey('exp-remaining')), findsNothing);
      expect(find.byKey(const ValueKey('exp-notebook')), findsOne);

      await tap('exp-choice-eau');
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tap('exp-choice-deux');
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

    testWidgets('fits a phone', (tester) async {
      tallView(tester, width: 375);
      final (c, _) = controllerFor(water);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await tester.tap(find.byKey(const ValueKey('exp-chaleur-chaud')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('exp-run')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(
          RegExp('Sur le feu : L’eau devient de la vapeur'),
        ),
        findsOne,
      );
      c.dispose();
    });
  });
}
