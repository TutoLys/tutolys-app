import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// G12 (« Suivant » on the celebration), the exported stop sheet (app ADR
/// 0107, AM20) and two columns on a phone held sideways (AM21).
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: TutolysTheme.village(),
    home: Scaffold(body: child),
  );

  const summary = ActivitySummary(questions: 5, solved: 5, firstTry: 4, xp: 12);

  group('G12: the celebration leads on', () {
    testWidgets('with no next lesson, Continuer is the only way out', (
      tester,
    ) async {
      var back = 0;
      await tester.pumpWidget(
        host(
          ActivityCompleteView(
            summary: summary,
            locale: const Locale('fr'),
            onContinue: () => back++,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('complete-continue')), findsOne);
      expect(find.byKey(const ValueKey('complete-back-to-map')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('complete-continue')));
      expect(back, 1);
    });

    testWidgets('Suivant is primary and Enter\'s action; Retour à la carte '
        'goes back', (tester) async {
      var next = 0;
      var back = 0;
      await tester.pumpWidget(
        host(
          ActivityCompleteView(
            summary: summary,
            locale: const Locale('fr'),
            onContinue: () => back++,
            onNext: () => next++,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SUIVANT'), findsOne);
      expect(find.text('Retour à la carte'), findsOne);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(next, 1);
      await tester.tap(find.byKey(const ValueKey('complete-next')));
      expect(next, 2);
      await tester.tap(find.byKey(const ValueKey('complete-back-to-map')));
      expect((next, back), (2, 1));
    });
  });

  testWidgets('K18: practice ends on « Entraînement », never « +0 XP »', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ActivityCompleteView(
          summary: const ActivitySummary(
            questions: 5,
            solved: 5,
            firstTry: 4,
            xp: 0,
            practice: true,
          ),
          locale: const Locale('fr'),
          onContinue: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('complete-practice')), findsOne);
    expect(find.text('Entraînement'), findsOne);
    expect(find.textContaining('XP'), findsNothing);
    // A label, not something that looks tappable: no ↻, no outline.
    expect(find.byIcon(Icons.replay_rounded), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('complete-practice')),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('AM34: a big card\'s short label is 28 px and centred', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Center(
          child: SizedBox(
            width: 120,
            child: AnswerTile(
              label: '4',
              large: true,
              state: AnswerTileState.idle,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final t = tester.widget<Text>(find.text('4'));
    expect(t.style!.fontSize, 28);
    expect(t.textAlign, TextAlign.center);
  });

  group('the stop sheet is exported', () {
    for (final (key, want) in [('stop-continue', false), ('stop-quit', true)]) {
      testWidgets('$key returns $want', (tester) async {
        bool? got;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => got = await showActivityStopSheet(
                  context,
                  ShellStrings.of(const Locale('fr')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Tu veux arrêter ?'), findsOne);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(got, want);
      });
    }
  });

  group('AM21: a phone on its side gets two columns', () {
    Future<ActivitySessionController> pump(
      WidgetTester tester,
      Size size, {
      bool picture = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse({
          'exercise_id': '1c3d6d41-a465-42be-b3a9-c1dc8460e24c',
          'version': 1,
          'content_hash': 'h',
          'engine_key': 'mcq',
          'engine_min_version': 1,
          'skill_node_id': '5a221f09-99f7-597e-bc4a-34e7ccafaa3b',
          'subject': 'MATH',
          'grade': 1,
          'rank': 0,
          'prompt': {
            'text':
                'Il fait très chaud à la plage. Quelle température '
                'fait-il ?',
            if (picture) 'image_ref': 'foxy',
          },
          'config': {
            'options': [
              for (final (i, l) in [
                'un carré',
                'un triangle',
                'un cercle',
              ].indexed)
                {'id': 'o$i', 'label': l},
            ],
            'correct': 'o0',
            'shuffle': false,
          },
        }).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([
          eraseEngine(const SingleChoiceEngine()),
        ]),
        evaluators: EvaluatorRegistry(const [McqExactEvaluator()]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 1,
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        host(
          LearningActivityView(
            controller: c,
            locale: const Locale('fr'),
            character: const SizedBox.square(
              key: ValueKey('fox'),
              dimension: 56,
            ),
            onDone: () {},
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    testWidgets('812 × 375: the question left, the answers right', (
      tester,
    ) async {
      final c = await pump(tester, const Size(812, 375));
      expect(find.byKey(const ValueKey('landscape-columns')), findsOne);
      expect(tester.takeException(), isNull);
      final prompt = tester.getCenter(find.byKey(const ValueKey('prompt-row')));
      final answer = tester.getCenter(
        find.byKey(const ValueKey('mcq-option-o0')),
      );
      expect(prompt.dx, lessThan(answer.dx));
      // Still playable: pick, then VALIDER.
      await tester.tap(find.byKey(const ValueKey('mcq-option-o0')));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      await tester.tap(find.text('VALIDER'));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      expect(find.text('Bravo !'), findsOne);
      c.dispose();
    });

    testWidgets('AM33: sideways, the question and 🔊 lead, above the picture, '
        'with no fox', (tester) async {
      final c = await pump(tester, const Size(812, 375), picture: true);
      final question = tester.getTopLeft(
        find.byKey(const ValueKey('prompt-row')),
      );
      final image = tester.getTopLeft(
        find.byKey(const ValueKey('prompt-image')),
      );
      expect(question.dy, lessThan(image.dy));
      expect(question.dy, lessThan(375));
      expect(find.byKey(const ValueKey('fox')), findsNothing);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('upright, the picture still leads', (tester) async {
      final c = await pump(tester, const Size(800, 1200), picture: true);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('prompt-image'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('prompt-row'))).dy,
        ),
      );
      c.dispose();
    });

    testWidgets('upright, and on a tall landscape screen: one column', (
      tester,
    ) async {
      for (final size in [const Size(375, 812), const Size(1280, 800)]) {
        final c = await pump(tester, size);
        expect(find.byKey(const ValueKey('landscape-columns')), findsNothing);
        c.dispose();
      }
    });
  });
}
