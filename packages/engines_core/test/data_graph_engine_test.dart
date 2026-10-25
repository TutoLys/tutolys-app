import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

// The backend sample `content/samples/math_data_graph_build.json`, verbatim.
const buildConfig = <String, Object?>{
  'mode': 'build',
  'chart_type': 'pictograph',
  'categories': [
    {'id': 'pomme', 'label': 'pommes', 'symbol': '🍎', 'value': 4},
    {'id': 'banane', 'label': 'bananes', 'symbol': '🍌', 'value': 2},
    {'id': 'poire', 'label': 'poires', 'symbol': '🍐', 'value': 3},
  ],
  'source': ['🍎', '🍌', '🍐', '🍎', '🍐', '🍎', '🍌', '🍐', '🍎'],
  'max': 5,
  'hint': 'Compte un fruit à la fois, et barre-le dans ta tête.',
};

const readConfig = <String, Object?>{
  'chart_type': 'bar',
  'categories': [
    {'id': 'chat', 'label': 'chat', 'value': 6},
    {'id': 'chien', 'label': 'chien', 'value': 8},
    {'id': 'poisson', 'label': 'poisson', 'value': 3},
  ],
  'options': [
    {'id': 'a', 'label': 'le chat'},
    {'id': 'b', 'label': 'le chien'},
    {'id': 'c', 'label': 'le poisson'},
  ],
  'correct': 'b',
  'shuffle': false,
};

Map<String, Object?> envelope(Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': 'data_graph',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Fais le diagramme des fruits'},
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
      engines: LearningEngineRegistry([eraseEngine(const DataGraphEngine())]),
      evaluators: EvaluatorRegistry(const [DataGraphEvaluator()]),
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

void view(WidgetTester tester, {double width = 1000}) {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

Future<void> raise(WidgetTester tester, String id, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(ValueKey('graph-$id-plus')));
    await settle(tester);
  }
}

void main() {
  const engine = DataGraphEngine();

  group('parse', () {
    test('reads both modes; max defaults from the values', () {
      final b = engine.parse(buildConfig).valueOrNull!;
      expect(b.mode, DataGraphMode.build);
      expect(b.chartType, ChartType.pictograph);
      expect(b.source, hasLength(9));
      expect(b.max, 5);
      final r = engine.parse(readConfig).valueOrNull!;
      expect(r.mode, DataGraphMode.read, reason: 'read is the default');
      expect(r.max, 10, reason: 'top value 8 rounds up to 10');
    });

    test('refuses content that cannot be played', () {
      void refused(Map<String, Object?> config, String why) => expect(
        engine.parse(config),
        isA<ParseInvalid<DataGraphContent>>(),
        reason: why,
      );
      refused({...readConfig, 'correct': 'z'}, 'correct names no option');
      refused({...buildConfig, 'max': 3}, 'a value above max');
      refused({
        ...buildConfig,
        'categories': [
          {'id': 'pomme', 'label': 'pommes', 'value': 4},
          {'id': 'banane', 'label': 'bananes', 'value': 2},
        ],
      }, 'a pictograph without symbols');
      refused({
        ...buildConfig,
        'options': readConfig['options'],
      }, 'building has no options');
      refused({...readConfig}..remove('options'), 'reading needs options');
    });
  });

  group('build', () {
    final content = engine.parse(buildConfig).valueOrNull!;

    test('bars start at 0; nothing to check until one moves', () {
      var s = engine.initialize(content, const EngineSeed(1));
      expect(s.values, {'pomme': 0, 'banane': 0, 'poire': 0});
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const StepBar('pomme', 1)).state;
      expect(engine.extractAnswer(s), isA<BlanksAnswer>());
      expect(
        engine.reduce(s, const StepBar('banane', -1)).events,
        isEmpty,
        reason: 'never below 0',
      );
    });

    test('partial credit: right bars lock, wrong ones stay amber', () {
      var s = engine.initialize(content, const EngineSeed(1));
      for (final (id, n) in [('pomme', 4), ('banane', 3), ('poire', 3)]) {
        for (var i = 0; i < n; i++) {
          s = engine.reduce(s, StepBar(id, 1)).state;
        }
      }
      final r = const DataGraphEvaluator().evaluate(
        content,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(r.outcome, Outcome.partial);
      expect(r.itemResults, {'pomme': true, 'banane': false, 'poire': true});
      expect(r.score, closeTo(2 / 3, 1e-9));
      expect(r.evaluator, 'data_graph.exact@1');
      s = engine.applyFeedback(s, r);
      expect(s.locked, {'pomme', 'poire'});
      expect(s.wrong, {'banane'});
      expect(s.values['banane'], 3, reason: 'kept, to fix');
      expect(engine.reduce(s, const StepBar('pomme', 1)).events, isEmpty);
      s = engine.reduce(s, const StepBar('banane', -1)).state;
      expect(s.wrong, isEmpty, reason: 'changed, so no longer marked');
      final done = const DataGraphEvaluator().evaluate(
        content,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(done.outcome, Outcome.correct);
    });

    test('snapshot round-trips', () {
      var s = engine.initialize(content, const EngineSeed(1));
      s = engine.reduce(s, const StepBar('poire', 1)).state;
      final back = engine.restore(
        content,
        jsonDecode(jsonEncode(engine.snapshot(s))) as Map<String, Object?>,
      )!;
      expect(back.values, s.values);
      expect(back.touched, isTrue);
    });
  });

  group('read', () {
    final content = engine.parse(readConfig).valueOrNull!;

    test('a wrong pick turns amber; the right one is correct', () {
      var s = engine.initialize(content, const EngineSeed(1));
      expect(s.optionOrder, ['a', 'b', 'c'], reason: 'shuffle: false');
      s = engine.reduce(s, const PickGraphOption('a')).state;
      final wrong = const DataGraphEvaluator().evaluate(
        content,
        engine.extractAnswer(s)!,
        ctx,
      );
      expect(wrong.outcome, Outcome.incorrect);
      s = engine.applyFeedback(s, wrong);
      expect(s.tried, {'a'});
      expect(engine.reduce(s, const PickGraphOption('a')).events, isEmpty);
      s = engine.reduce(s, const PickGraphOption('b')).state;
      expect(
        const DataGraphEvaluator()
            .evaluate(content, engine.extractAnswer(s)!, ctx)
            .outcome,
        Outcome.correct,
      );
    });
  });

  group('in the shell', () {
    testWidgets('build a pictograph: one bar off → Presque → fix → Bravo', (
      tester,
    ) async {
      view(tester);
      final (c, outbox) = controllerFor(buildConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(find.byKey(const ValueKey('graph-source')), findsOneWidget);
      await raise(tester, 'pomme', 4);
      await raise(tester, 'banane', 3);
      await raise(tester, 'poire', 3);
      expect(
        find.text('🍎'),
        findsNWidgets(4 + 4),
        reason: 'source + bar; the label is "🍎 pommes"',
      );
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('graph-banane-minus')));
      await settle(tester);
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

    testWidgets('a locked bar\'s buttons are disabled', (tester) async {
      view(tester);
      final (c, _) = controllerFor(buildConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      await raise(tester, 'pomme', 4);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      final plus = tester.widget<InkWell>(
        find.byKey(const ValueKey('graph-pomme-plus')),
      );
      expect(plus.onTap, isNull);
      c.dispose();
    });

    testWidgets('read a bar chart: the bars are drawn to scale', (
      tester,
    ) async {
      view(tester);
      final (c, _) = controllerFor(readConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final chien = tester.getSize(
        find.byKey(const ValueKey('graph-bar-chien')),
      );
      final poisson = tester.getSize(
        find.byKey(const ValueKey('graph-bar-poisson')),
      );
      expect(chien.height / poisson.height, closeTo(8 / 3, 0.01));
      expect(find.bySemanticsLabel('chien : 8'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('graph-option-b')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      c.dispose();
    });

    testWidgets('keyboard alone can raise a bar', (tester) async {
      view(tester);
      final (c, _) = controllerFor(buildConfig);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      final target = find.byKey(const ValueKey('graph-poire-plus'));
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null &&
            find
                .descendant(of: target, matching: find.byWidget(focused.widget))
                .evaluate()
                .isNotEmpty) {
          break;
        }
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect((c.current!.state as DataGraphState).values['poire'], 1);
      c.dispose();
    });

    testWidgets('six categories fit a phone', (tester) async {
      view(tester, width: 375);
      final (c, _) = controllerFor({
        'mode': 'build',
        'categories': [
          for (var i = 0; i < 6; i++)
            {'id': 'c$i', 'label': 'cat$i', 'value': i},
        ],
      });
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c));
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
