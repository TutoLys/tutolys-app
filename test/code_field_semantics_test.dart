import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// K17: with a screen reader on, the pairing code is one enabled text field
/// that takes a tap and typing (it read as disabled before).
void main() {
  Widget field({bool enabled = true, ValueChanged<String>? onChanged}) =>
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TutolysCodeField(
                length: 6,
                alphabet: '23456789ABCDEFGHJKMNPQRSTUVWXYZ',
                autofocus: false,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );

  testWidgets('one enabled, labelled text field; the boxes are silent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(field());

    final fields = find.semantics.byPredicate(
      (n) => n.flagsCollection.isTextField,
    );
    expect(fields, findsOne);
    final node = fields.evaluate().single;
    expect(
      node,
      isSemantics(
        label: 'Code de connexion',
        isTextField: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    // The field covers the code, not a 1px strip.
    expect(node.rect.height, greaterThan(40));
    handle.dispose();
  });

  testWidgets('a screen reader tap focuses it, and typing fills the code', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? typed;
    await tester.pumpWidget(field(onChanged: (v) => typed = v));

    tester.semantics.tap(
      find.semantics.byPredicate((n) => n.flagsCollection.isTextField),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    tester.testTextInput.enterText('zf23xu');
    await tester.pump();
    expect(typed, 'ZF23XU');
    expect(find.text('Z'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('while submitting it says it is disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(field(enabled: false));
    final node = find.semantics
        .byPredicate((n) => n.flagsCollection.isTextField)
        .evaluate()
        .single;
    expect(
      node,
      isSemantics(isTextField: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('one line, with Go on the keyboard; Go submits a full code', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: TutolysCodeField(
            length: 6,
            alphabet: '23456789ABCDEFGHJKMNPQRSTUVWXYZ',
            onCompleted: (v) => completed = v,
          ),
        ),
      ),
    );
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('code-field-input')),
    );
    expect(input.maxLines, 1);
    expect(input.textInputAction, TextInputAction.go);

    await tester.enterText(find.byType(TextField), 'ZF2');
    completed = null;
    await tester.testTextInput.receiveAction(TextInputAction.go);
    expect(completed, isNull, reason: 'a short code is not sent');

    await tester.enterText(find.byType(TextField), 'ZF23XU');
    completed = null;
    await tester.testTextInput.receiveAction(TextInputAction.go);
    expect(completed, 'ZF23XU');
  });
}
