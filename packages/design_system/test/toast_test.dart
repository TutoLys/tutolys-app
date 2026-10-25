import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({double width = 1000}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800), disableAnimations: true),
    child: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => VillageToast.show(context, 'Bientôt !'),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ),
);

/// Lets the toast run out, so no timer outlives the test.
Future<void> finish(WidgetTester tester) =>
    tester.pump(VillageToast.visibleFor + const Duration(milliseconds: 50));

void main() {
  testWidgets('shows, then leaves on its own', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Bientôt !'), findsOneWidget);

    await tester.pump(
      VillageToast.visibleFor + const Duration(milliseconds: 50),
    );
    expect(find.text('Bientôt !'), findsNothing);
  });

  testWidgets('a new toast replaces the one showing', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Bientôt !'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('never takes a tap meant for the page', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('Bientôt !'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    await finish(tester);
  });

  testWidgets('sits above the bottom tab bar on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(width: 390));
    await tester.tap(find.text('go'));
    await tester.pump();
    // Let it finish sliding up before measuring.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final bottom = 800 - tester.getRect(find.text('Bientôt !')).bottom;
    expect(bottom, greaterThan(78), reason: 'clear of the 78px tab bar');
    await finish(tester);
  });
}
