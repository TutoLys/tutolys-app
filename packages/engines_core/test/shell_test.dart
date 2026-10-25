import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engine_sdk/testing.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const fr = Locale('fr');

Widget _app(Widget child) => MaterialApp(
  theme: TutolysTheme.village(),
  home: Scaffold(body: child),
);

void main() {
  group('ActivityShell', () {
    testWidgets('VALIDER is disabled until there is an answer, and says so', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(),
            showValidate: true,
          ),
        ),
      );
      final validate = find.widgetWithText(TextButton, 'VALIDER');
      expect(validate, findsOneWidget);
      expect(tester.widget<TextButton>(validate).onPressed, isNull);
      handle.dispose();
    });

    testWidgets(
      'the retry banner speaks in words and an icon, not only amber',
      (tester) async {
        var acted = false;
        await tester.pumpWidget(
          _app(
            ActivityShell(
              locale: fr,
              onClose: () {},
              body: const SizedBox(),
              feedback: ShellFeedback(
                kind: ShellFeedbackKind.retry,
                title: 'Presque !',
                message: 'Pas tout à fait — essaie encore.',
                actionLabel: 'Réessayer',
                onAction: () => acted = true,
              ),
            ),
          ),
        );
        expect(find.text('Presque !'), findsOneWidget);
        expect(find.byIcon(Icons.track_changes_rounded), findsOneWidget);
        expect(
          find.byIcon(Icons.close_rounded),
          findsOneWidget,
          reason: 'the close button, not a wrong-answer X',
        );
        await tester.tap(find.text('RÉESSAYER'));
        expect(acted, isTrue);
      },
    );

    testWidgets('Enter validates, and acts on the banner when one is up', (
      tester,
    ) async {
      var validated = 0;
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(),
            showValidate: true,
            onValidate: () => validated++,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(validated, 1);
    });

    testWidgets('legacy chrome hides what it cannot honestly show', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ActivityShell(locale: fr, onClose: () {}, body: const Text('engine')),
        ),
      );
      expect(find.text('engine'), findsOneWidget);
      expect(find.text('VALIDER'), findsNothing);
      expect(find.text('INDICE'), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('lays out at phone width without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(height: 200),
            progress: .5,
            xp: 25,
            inARow: 3,
            promptText: 'Combien font 7 + 5 ?',
            onSpeak: () {},
            onHint: () {},
            showValidate: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('3 EN SÉRIE'), findsOneWidget);
    });
  });

  group('LearningActivityView', () {
    late InMemoryEventOutbox outbox;

    ActivitySessionController controller({int questions = 2}) {
      outbox = InMemoryEventOutbox();
      return ActivitySessionController(
        envelope: QuestionEnvelope.parse(fakeEnvelope(questions: questions))
            .valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
        store: InMemoryActivitySessionStore(outbox),
        appVersion: '0.2.0',
        seed: 3,
      );
    }

    testWidgets(
      'pick, VALIDER, Presque, retry, Bravo, done — through the real controller',
      (tester) async {
        final c = controller(questions: 1);
        var done = false;
        await tester.runAsync(() => c.start());
        await tester.pumpWidget(
          _app(
            LearningActivityView(
              controller: c,
              locale: fr,
              onDone: () => done = true,
            ),
          ),
        );

        expect(
          find.text('Q0'),
          findsOneWidget,
          reason: 'the shell renders the prompt',
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'VALIDER'))
              .onPressed,
          isNull,
        );

        await tester.tap(find.byKey(const ValueKey('option-a')));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.tap(find.text('VALIDER'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        expect(find.text('Presque !'), findsOneWidget);

        await tester.tap(find.text('RÉESSAYER'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('option-b')));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.tap(find.text('VALIDER'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        expect(find.text('Bravo !'), findsOneWidget);

        await tester.tap(find.text('CONTINUER'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.pump();
        expect(done, isTrue);
        expect(outbox.all.map((e) => e['event_type']).last, 'session_end');
        c.dispose();
      },
    );

    testWidgets('the hint is revealed once and recorded', (tester) async {
      final c = controller();
      await tester.runAsync(() => c.start());
      await tester.pumpWidget(
        _app(LearningActivityView(controller: c, locale: fr, onDone: () {})),
      );
      await tester.tap(find.text('INDICE'));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      expect(find.text('Compte sur tes doigts.'), findsOneWidget);
      expect(find.text('INDICE'), findsNothing);
      expect(outbox.all.last['event_type'], 'hint_used');
      c.dispose();
    });

    testWidgets('an engine the app does not have asks for an update', (
      tester,
    ) async {
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse(
          fakeEnvelope(engineKey: 'from_the_future'),
        ).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
        store: InMemoryActivitySessionStore(),
        appVersion: '0.2.0',
      );
      await tester.runAsync(() => c.start());
      await tester.pumpWidget(
        _app(LearningActivityView(controller: c, locale: fr, onDone: () {})),
      );
      expect(find.textContaining('mise à jour'), findsOneWidget);
      c.dispose();
    });
  });

  testWidgets('LegacyEngineHost plays a real mcq exercise inside the shell', (
    tester,
  ) async {
    final outbox = InMemoryEventOutbox();
    final bridge = LegacyFeedbackBridge(beat: Duration.zero);
    final seen = <RuntimeEvent>[];
    bridge.events.listen(seen.add);
    ExerciseResult? result;
    await tester.pumpWidget(
      _app(
        LegacyEngineHost(
          envelope: {
            'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
            'version': 1,
            'engine_key': 'mcq',
            'engine_min_version': 1,
            'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
            'subject': 'MATH',
            'grade': 1,
            'rank': 0,
            'prompt': {'text': 'Combien font 7 + 5 ?'},
            'config': {
              'options': [
                {'id': 'a', 'label': '10'},
                {'id': 'b', 'label': '12'},
              ],
              'correct': 'b',
              'shuffle': false,
            },
          },
          registry: EngineRegistry([const McqEngine()]),
          telemetry: TelemetryClient(
            outbox: outbox,
            sessionId: 's',
            appVersion: '0.2.0',
          ),
          feedback: bridge,
          locale: fr,
          character: const Text('fox'),
          onFinished: (r) => result = r,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('fox'),
      findsOneWidget,
      reason: 'the character slot is filled',
    );
    expect(
      find.text('Combien font 7 + 5 ?'),
      findsOneWidget,
      reason: 'the runner still renders its prompt',
    );

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(result?.outcome, ExerciseOutcome.completed);
    expect(seen.whereType<AnswerEvaluated>().single.result.isCorrect, isTrue);
    expect(
      outbox.all.map((e) => e['event_type']),
      contains('exercise_complete'),
      reason: 'legacy telemetry is untouched',
    );
    bridge.dispose();
  });
}
