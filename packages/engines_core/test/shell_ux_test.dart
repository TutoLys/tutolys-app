import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engine_sdk/testing.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixes from the UX review of the games
/// (`Platforms/ux-review/games.md`), one group per finding id.

const fr = Locale('fr');

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),
  home: Scaffold(body: child),
);

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) * 1.0;
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final (x, y) = (lum(a), lum(b));
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

ShellFeedback _banner(ShellFeedbackKind kind) => ShellFeedback(
  kind: kind,
  title: 'Titre',
  message: 'Message',
  actionLabel: 'Action',
  onAction: () {},
);

void main() {
  group('G1 the banner reads at AA', () {
    for (final dark in [false, true]) {
      for (final kind in ShellFeedbackKind.values) {
        testWidgets('${kind.name}, ${dark ? 'dark' : 'light'}', (tester) async {
          await tester.pumpWidget(
            _app(
              ActivityShell(
                locale: fr,
                onClose: () {},
                body: const SizedBox(),
                feedback: _banner(kind),
              ),
              dark: dark,
            ),
          );
          final button = tester.widget<FilledButton>(find.byType(FilledButton));
          final style = button.style!;
          final bg = style.backgroundColor!.resolve({})!;
          final fg = style.foregroundColor!.resolve({})!;
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));

          final message = tester.widget<Text>(find.text('Message'));
          expect(message.style!.fontSize, greaterThanOrEqualTo(14));
          final ground =
              (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: find.text('Message'),
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .color!;
          expect(
            contrast(message.style!.color!, ground),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  });

  group('G6 Enter on a focused tile picks it, never submits', () {
    testWidgets('a focused tile takes Enter; the shell takes it otherwise', (
      tester,
    ) async {
      var picked = 0;
      var validated = 0;
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            showValidate: true,
            onValidate: () => validated++,
            body: AnswerTile(
              label: 'chat',
              state: AnswerTileState.idle,
              onTap: () => picked++,
            ),
          ),
        ),
      );
      // The tile's own focus node, as Tab would reach it.
      final tile = Focus.of(tester.element(find.text('chat')))..requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect((picked, validated), (1, 0));

      tile.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((picked, validated), (1, 1));
    });
  });

  group('G2 VALIDER before an answer says what is missing', () {
    testWidgets('a tap shows the nudge for a moment, and validates nothing', (
      tester,
    ) async {
      var validated = 0;
      Widget shell({bool ready = false}) => _app(
        ActivityShell(
          locale: fr,
          onClose: () {},
          body: const SizedBox(),
          showValidate: true,
          onValidate: ready ? () => validated++ : null,
        ),
      );
      await tester.pumpWidget(shell());
      expect(find.byKey(const ValueKey('validate-nudge')), findsNothing);
      await tester.tap(find.text('VALIDER'));
      await tester.pump();
      expect(find.text('Choisis d’abord ta réponse !'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
      expect(validated, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('validate-nudge')), findsNothing);

      // Once there is an answer, the nudge goes and VALIDER validates.
      await tester.tap(find.text('VALIDER'));
      await tester.pump();
      await tester.pumpWidget(shell(ready: true));
      expect(find.byKey(const ValueKey('validate-nudge')), findsNothing);
      await tester.tap(find.text('VALIDER'));
      expect(validated, 1);
    });
  });

  group('G5 the close button asks before throwing a série away', () {
    ActivitySessionController controller() => ActivitySessionController(
      envelope: QuestionEnvelope.parse(fakeEnvelope(questions: 2)).valueOrNull!,
      kidId: 'kid',
      engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
      evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
      store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
      appVersion: '0.2.0',
      seed: 3,
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pumpAndSettle();
    }

    testWidgets('nothing started: ✕ leaves at once', (tester) async {
      final c = controller();
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
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      expect(find.byKey(const ValueKey('stop-sheet')), findsNothing);
      expect(done, isTrue);
      c.dispose();
    });

    testWidgets('started: Continuer keeps playing, Arrêter leaves', (
      tester,
    ) async {
      final c = controller();
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
      await tester.tap(find.byKey(const ValueKey('option-a')));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      expect(find.text('Tu veux arrêter ?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stop-continue')));
      await settle(tester);
      expect(find.byKey(const ValueKey('stop-sheet')), findsNothing);
      expect(done, isFalse);
      expect(c.state.phase.isTerminal, isFalse);
      expect(c.current!.answer, isNotNull, reason: 'the pick is still there');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('stop-quit')));
      await settle(tester);
      expect(done, isTrue);
      c.dispose();
    });
  });

  group('G10 the listen buttons are big enough to find and hit', () {
    testWidgets('the prompt speaker is 56 dp, solid, and reads', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          _app(
            ActivityShell(
              locale: fr,
              onClose: () {},
              body: const SizedBox(),
              promptText: 'Écoute.',
              onSpeak: () {},
            ),
            dark: dark,
          ),
        );
        final speak = find.byKey(const ValueKey('prompt-speak'));
        expect(tester.getSize(speak), const Size(56, 56));
        final style = tester.widget<IconButton>(speak).style!;
        expect(
          contrast(
            style.foregroundColor!.resolve({})!,
            style.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(3),
          reason: dark ? 'dark' : 'light',
        );
      }
    });

    testWidgets('the tile speaker is at least 48 dp, apart from the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ContentSpeakerScope(
            speaker: _Silent(),
            child: Center(
              child: SizedBox(
                width: 300,
                child: AnswerTile(
                  label: 'chat',
                  audioRef: 'a1',
                  state: AnswerTileState.idle,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final speak = find.byKey(const ValueKey('tile-speak-a1'));
      final size = tester.getSize(speak);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      final gap =
          tester.getTopLeft(find.text('chat')).dx -
          tester.getTopRight(speak).dx;
      expect(gap, greaterThanOrEqualTo(12));
    });
  });

  group('G11 idle tiles and empty slots have a 3:1 edge', () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'dark' : 'light', (tester) async {
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                AnswerTile(
                  label: 'chat',
                  state: AnswerTileState.idle,
                  onTap: () {},
                ),
                AnswerSlot(
                  index: 1,
                  label: null,
                  state: AnswerTileState.idle,
                  onTap: null,
                  emptyLabel: 'case 1, vide',
                ),
              ],
            ),
            dark: dark,
          ),
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AnswerTile),
                matching: find.byType(Material),
              )
              .first,
        );
        final side = (material.shape! as RoundedRectangleBorder).side.color;
        expect(contrast(side, material.color!), greaterThanOrEqualTo(3));
        expect(find.byKey(const ValueKey('slot-dash')), findsOneWidget);
      });
    }
  });
}

class _Silent implements ContentSpeaker {
  @override
  void speak({required String audioRef, required String partId}) {}
}
