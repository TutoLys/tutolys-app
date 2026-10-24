import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Réduire les animations` has to reach Flutter's own
/// `MediaQuery.disableAnimations`, not sit in a database as a flag nobody
/// reads — which is exactly what it did in all 28 of the old Godot
/// projects, and what the Flutter rebuild spec called out as a defect.
///
/// These test the composition rule directly: the app may *add* a reason to
/// disable animations, never remove the platform's own.
void main() {
  Widget probe({
    required bool platformDisables,
    required bool settingDisables,
    required void Function(bool) report,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: platformDisables),
      child: MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: media.disableAnimations || settingDisables,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Builder(
          builder: (context) {
            report(MediaQuery.disableAnimationsOf(context));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('off everywhere leaves animations on', (tester) async {
    var disabled = true;
    await tester.pumpWidget(probe(
      platformDisables: false,
      settingDisables: false,
      report: (v) => disabled = v,
    ));
    expect(disabled, isFalse);
  });

  testWidgets('the in-app toggle alone disables animations', (tester) async {
    var disabled = false;
    await tester.pumpWidget(probe(
      platformDisables: false,
      settingDisables: true,
      report: (v) => disabled = v,
    ));
    expect(disabled, isTrue);
  });

  testWidgets('the app cannot override the platform asking for less motion',
      (tester) async {
    // The case that matters: a child whose OS is set to reduce motion keeps
    // it even with the in-app toggle off. An accessibility setting is not
    // something an app gets to switch back on.
    var disabled = false;
    await tester.pumpWidget(probe(
      platformDisables: true,
      settingDisables: false,
      report: (v) => disabled = v,
    ));
    expect(disabled, isTrue);
  });

  testWidgets('both on stays on', (tester) async {
    var disabled = false;
    await tester.pumpWidget(probe(
      platformDisables: true,
      settingDisables: true,
      report: (v) => disabled = v,
    ));
    expect(disabled, isTrue);
  });
}
