import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
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
}
