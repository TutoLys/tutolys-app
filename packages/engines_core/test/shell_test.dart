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
      // Still tappable, to say what's missing (UX review G2), with the
      // reason as a hint for a screen reader.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('validate'))).hint,
        'Choisis d’abord ta réponse !',
      );
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
        // Before an answer, VALIDER only says what's missing (G2).
        await tester.tap(find.text('VALIDER'));
        await tester.pump();
        expect(find.byKey(const ValueKey('validate-nudge')), findsOneWidget);
        expect(find.text('Presque !'), findsNothing);

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

  testWidgets(
    'LegacyEngineHost: a timed speed_tap answer registers inside the shell',
    (tester) async {
      final outbox = InMemoryEventOutbox();
      final bridge = LegacyFeedbackBridge(beat: Duration.zero);
      ExerciseResult? result;
      await tester.pumpWidget(
        _app(
          LegacyEngineHost(
            envelope: {
              'exercise_id': 'c89696ba-26f1-460c-8e2a-b02ca6a294f3',
              'version': 1,
              'engine_key': 'speed_tap',
              'engine_min_version': 1,
              'skill_node_id': '6caa74dd-747a-5372-9f1a-4df9fc889e9e',
              'subject': 'MATH',
              'grade': 1,
              'rank': 0,
              'prompt': {'text': 'Combien font 4 + 3 ?'},
              'config': {
                'correct': 'b',
                'options': [
                  {'id': 'a', 'label': '6'},
                  {'id': 'b', 'label': '7'},
                  {'id': 'c', 'label': '8'},
                ],
                'shuffle': false,
                'time_limit_ms': 8000,
              },
            },
            registry: EngineRegistry([const SpeedTapEngine()]),
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
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(outbox.all.map((e) => e['event_type']), contains('attempt'));
      expect(result?.outcome, ExerciseOutcome.completed);
      bridge.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('VALIDER sits on the right, INDICE on the left', (tester) async {
    for (final withHint in [true, false]) {
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(),
            showValidate: true,
            onValidate: () {},
            onHint: withHint ? () {} : null,
          ),
        ),
      );
      final width = tester.getSize(find.byType(ActivityShell)).width;
      expect(
        tester.getCenter(find.text('VALIDER')).dx,
        greaterThan(width * 0.75),
        reason: 'hint: $withHint',
      );
      if (withHint) {
        expect(
          tester.getCenter(find.text('INDICE')).dx,
          lessThan(width * 0.25),
        );
      }
    }
  });

  testWidgets(
    'completing the last question leaves on its own, without waiting for a repaint',
    (tester) async {
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse(fakeEnvelope(questions: 1))
            .valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
        store: InMemoryActivitySessionStore(),
        appVersion: '0.2.0',
      );
      var done = false;
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        _app(
          LearningActivityView(
            controller: c,
            locale: fr,
            onDone: () => done = true,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('option-b')));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.tap(find.text('VALIDER'));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.tap(find.text('CONTINUER'));
      // No pump: the old post-frame callback only ran on the next frame.
      await tester.runAsync(() => pumpEventQueue());
      expect(done, isTrue);
      c.dispose();
    },
  );

  testWidgets('the progress fill is actually drawn (it had zero height)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ActivityShell(
          locale: fr,
          onClose: () {},
          body: const SizedBox(),
          progress: 0.5,
        ),
      ),
    );
    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );
    final size = tester.getSize(fill.first);
    expect(size.height, greaterThan(0));
    final trackWidth = (tester.renderObject(
      find.byType(FractionallySizedBox).first,
    ) as RenderBox).constraints.maxWidth;
    expect(
      size.width,
      closeTo(trackWidth / 2, 1),
      reason: 'half done, half drawn',
    );
  });

  testWidgets('the countdown fill is drawn too', (tester) async {
    await tester.pumpWidget(
      _app(
        CountdownBar(
          duration: const Duration(seconds: 4),
          round: 0,
          running: true,
          onExpired: () {},
          semanticsLabel: 'Temps restant',
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(fill.first).height, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  group('ActivityCompleteView', () {
    Widget view({
      required ActivitySummary summary,
      required VoidCallback onContinue,
      Locale locale = fr,
      bool still = true,
    }) => MaterialApp(
      theme: TutolysTheme.village(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: ActivityCompleteView(
            summary: summary,
            locale: locale,
            onContinue: onContinue,
          ),
        ),
      ),
    );

    testWidgets('a perfect run says so, with XP and what was right', (
      tester,
    ) async {
      var continued = false;
      await tester.pumpWidget(
        view(
          summary: const ActivitySummary(
            questions: 3,
            solved: 3,
            firstTry: 3,
            xp: 45,
          ),
          onContinue: () => continued = true,
        ),
      );
      expect(find.text('Parfait !'), findsOneWidget);
      expect(find.text('+45 XP'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(continued, isTrue, reason: 'Enter continues');
    });

    testWidgets('otherwise a plain well-done; English follows the locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        view(
          summary: const ActivitySummary(
            questions: 2,
            solved: 2,
            firstTry: 1,
            xp: 25,
          ),
          onContinue: () {},
          locale: const Locale('en'),
        ),
      );
      expect(find.text('Exercise complete!'), findsOneWidget);
      expect(find.text('first try'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets('with motion, the XP counts up and Continuer works at once', (
      tester,
    ) async {
      var continued = false;
      await tester.pumpWidget(
        view(
          summary: const ActivitySummary(
            questions: 1,
            solved: 1,
            firstTry: 1,
            xp: 15,
          ),
          onContinue: () => continued = true,
          still: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('+15 XP'), findsNothing, reason: 'still counting');
      await tester.tap(find.text('CONTINUER'));
      expect(continued, isTrue, reason: 'never waits on the animation');
      await tester.pumpAndSettle();
      expect(find.text('+15 XP'), findsOneWidget);
    });
  });
}
