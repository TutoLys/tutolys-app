import 'dart:math' as math;

import 'package:design_system/design_system.dart';
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
}
