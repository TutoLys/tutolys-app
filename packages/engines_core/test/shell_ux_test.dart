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

  group('G8 the hint is offered after two misses', () {
    testWidgets('INDICE turns gold after the second miss, not before', (
      tester,
    ) async {
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse(fakeEnvelope(questions: 1))
            .valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        _app(LearningActivityView(controller: c, locale: fr, onDone: () {})),
      );
      Future<void> settle() async {
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.pump();
      }

      bool offered() {
        final style = tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('hint')))
            .style!;
        return style.backgroundColor?.resolve({}) != null;
      }

      for (final (miss, option) in [(1, 'a'), (2, 'c')]) {
        expect(offered(), isFalse, reason: 'before miss $miss');
        await tester.tap(find.byKey(ValueKey('option-$option')));
        await settle();
        await tester.tap(find.text('VALIDER'));
        await settle();
        await tester.tap(find.text('RÉESSAYER'));
        await settle();
      }
      expect(offered(), isTrue);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('hint'))).hint,
        'Un indice peut t’aider.',
      );
      // Once revealed, INDICE goes.
      await tester.tap(find.byKey(const ValueKey('hint')));
      await settle();
      expect(find.byKey(const ValueKey('hint')), findsNothing);
      c.dispose();
    });
  });

  group('P3 polish', () {
    testWidgets('G14 large tiles: 88 dp on a tablet, 72 at phone width', (
      tester,
    ) async {
      for (final (width, height) in [(1000.0, 88.0), (375.0, 72.0)]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            Center(
              child: SizedBox(
                width: 200,
                child: AnswerTile(
                  label: 'chat',
                  large: true,
                  state: AnswerTileState.idle,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(AnswerTile)).height,
          greaterThanOrEqualTo(height),
        );
      }
    });

    testWidgets('G16 « N de suite » is 12 px, deep green, with an icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(),
            inARow: 3,
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('3 DE SUITE !'));
      expect(text.style!.fontSize, greaterThanOrEqualTo(12));
      expect(
        contrast(text.style!.color!, VillagePalette.light.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('in-a-row')),
          matching: find.byIcon(Icons.bolt_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('G17 the countdown turns gold, not amber, when time is short', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CountdownBar(
            duration: const Duration(seconds: 8),
            round: 0,
            running: true,
            onExpired: () {},
            semanticsLabel: 'Temps',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color);
      expect(fills, contains(VillagePalette.light.gold));
      expect(fills, isNot(contains(VillagePalette.light.retry)));
    });

    testWidgets('G18 the hint icon is the sparkle, readable on gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ActivityShell(
            locale: fr,
            onClose: () {},
            body: const SizedBox(),
            revealedHint: 'Compte sur tes doigts.',
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome_rounded));
      expect(
        contrast(icon.color!, VillagePalette.light.goldPale),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('N1 the progress track shows from question 1, with a count', () {
    testWidgets('outlined track at 3:1, and « 1 / 2 »', (tester) async {
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse(fakeEnvelope(questions: 2))
            .valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        evaluators: EvaluatorRegistry([FakeExactEvaluator()]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        _app(LearningActivityView(controller: c, locale: fr, onDone: () {})),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      // The track has real width at 0 %: its Stack shrank to 0 px before.
      expect(
        tester.getSize(find.byKey(const ValueKey('progress-track'))).width,
        greaterThan(100),
      );
      final track = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('progress-track')),
      );
      final border = (track.decoration as BoxDecoration).border! as Border;
      expect(
        contrast(border.top.color, VillagePalette.light.surface),
        greaterThanOrEqualTo(3),
      );
      c.dispose();
    });
  });

  group('N2 nothing moves between questions', () {
    testWidgets('the speaker keeps its place whatever the prompt length', (
      tester,
    ) async {
      Future<Offset> speakerAt(String prompt) async {
        await tester.pumpWidget(
          _app(
            ActivityShell(
              locale: fr,
              onClose: () {},
              body: const SizedBox(),
              promptText: prompt,
              onSpeak: () {},
            ),
          ),
        );
        return tester.getTopLeft(find.byKey(const ValueKey('prompt-speak')));
      }

      final short = await speakerAt('Compte.');
      final long = await speakerAt(
        'Laquelle de ces façons de dire la phrase est la bonne ?',
      );
      expect(long, short);
    });

    testWidgets('VALIDER keeps its place with or without INDICE', (
      tester,
    ) async {
      Future<Offset> validerAt({required bool hint}) async {
        await tester.pumpWidget(
          _app(
            ActivityShell(
              locale: fr,
              onClose: () {},
              body: const SizedBox(),
              showValidate: true,
              onHint: hint ? () {} : null,
            ),
          ),
        );
        return tester.getTopLeft(find.text('VALIDER'));
      }

      expect(await validerAt(hint: true), await validerAt(hint: false));
    });
  });

  group('N3 opening the hint never moves the board', () {
    testWidgets('the board keeps its place; the hint shows by the buttons', (
      tester,
    ) async {
      Future<Offset> boardAt({String? hint}) async {
        await tester.pumpWidget(
          _app(
            ActivityShell(
              locale: fr,
              onClose: () {},
              promptText: 'Compte.',
              showValidate: true,
              revealedHint: hint,
              onHint: hint == null ? () {} : null,
              body: const SizedBox(key: ValueKey('board'), height: 100),
            ),
          ),
        );
        return tester.getTopLeft(find.byKey(const ValueKey('board')));
      }

      final before = await boardAt();
      final after = await boardAt(hint: 'Compte sur tes doigts.');
      expect(after, before);
      expect(
        tester.getTopLeft(find.text('Compte sur tes doigts.')).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('board'))).dy,
        ),
      );
    });
  });

  group('N4 the hand demo: first question, then only after misses', () {
    testWidgets('shows on Q1, not on Q2, and again after two misses', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const q = <String, Object?>{
        'tiles': [
          {'id': 'a', 'label': '1'},
          {'id': 'b', 'label': '2'},
          {'id': 'c', 'label': '3'},
        ],
        'target': ['a', 'b'],
      };
      final c = ActivitySessionController(
        envelope: QuestionEnvelope.parse({
          'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
          'version': 1,
          'content_hash': 'h',
          'engine_key': 'compose_build',
          'engine_min_version': 1,
          'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
          'subject': 'MATH',
          'grade': 1,
          'rank': 0,
          'config': {
            'questions': [
              {
                'prompt': {'text': 'Un.'},
                'config': q,
              },
              {
                'prompt': {'text': 'Deux.'},
                'config': q,
              },
            ],
          },
        }).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([
          eraseEngine(const ComposeSlotsEngine()),
        ]),
        evaluators: EvaluatorRegistry(const [ComposeBuildEvaluator()]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 3,
      );
      await tester.runAsync(c.start);
      await tester.pumpWidget(
        _app(LearningActivityView(controller: c, locale: fr, onDone: () {})),
      );
      Future<void> settle() async {
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
        await tester.pump();
      }

      final hand = find.byKey(const ValueKey('idle-hand'));
      Future<void> idle() =>
          tester.pump(IdleHandHint.wait + const Duration(seconds: 3));
      Future<void> place(String ids) async {
        for (final id in ids.split('')) {
          await tester.tap(find.byKey(ValueKey('compose-tile-$id')));
          await settle();
        }
        await tester.tap(find.text('VALIDER'));
        await settle();
      }

      await idle();
      expect(hand, findsOneWidget, reason: 'question 1');
      await place('ab');
      await tester.tap(find.text('CONTINUER'));
      await settle();

      await idle();
      expect(hand, findsNothing, reason: 'question 2, untouched');
      // Two misses with both slots wrong: nothing locks, the board is
      // untouched again, and now the demo comes back.
      for (var miss = 0; miss < 2; miss++) {
        await place('ca');
        await tester.tap(find.text('RÉESSAYER'));
        await settle();
      }
      await idle();
      expect(hand, findsOneWidget, reason: 'after two misses');
      c.dispose();
    });
  });

  group('N8 keyboard focus is a 2 px blue outline, never a fill', () {
    testWidgets('shown on keyboard focus only, gone on unfocus', (
      tester,
    ) async {
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 200,
              child: AnswerTile(
                label: 'chat',
                state: AnswerTileState.retry,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.focusColor, Colors.transparent);
      final ring = find.byKey(const ValueKey('focus-ring'));

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final node = Focus.of(tester.element(find.text('chat')))..requestFocus();
      await tester.pump();
      expect(ring, findsOneWidget);
      final border =
          (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.width, 2);
      expect(border.top.color, VillagePalette.light.quebecBlueBright);

      node.unfocus();
      await tester.pump();
      expect(ring, findsNothing);

      // Touch mode: focus draws nothing.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      node.requestFocus();
      await tester.pump();
      expect(ring, findsNothing);
    });
  });

  group('picture answers draw big for pre-readers', () {
    testWidgets('an emoji-only label is 34 px; a word stays 15 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AnswerTile(
                label: '🐱',
                state: AnswerTileState.idle,
                onTap: () {},
              ),
              AnswerTile(
                label: 'cat',
                state: AnswerTileState.idle,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('🐱')).style!.fontSize, 34);
      expect(tester.widget<Text>(find.text('cat')).style!.fontSize, 15);
    });
  });
}

class _Silent implements ContentSpeaker {
  @override
  void speak({required String audioRef, required String partId}) {}
}
