import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/path/carte_model.dart';
import 'package:tutolys_app/features/path/carte_section.dart';
import 'package:tutolys_app/features/path/skill_path.dart';

/// The roll-up's motion on its own (ADR 0124); the Carte's behaviour is in
/// path_screen_test.dart.
void main() {
  final nodes = [
    for (var i = 0; i < 12; i++)
      PathNode(
        id: 'n$i',
        label: 'Étape $i',
        state: i < 3 ? PathNodeState.completed : PathNodeState.available,
      ),
  ];
  final section = PathSection(title: 'Géométrie', nodes: nodes);
  final settled = <bool>[];

  Widget app({required bool open, bool still = false}) => MediaQuery(
    data: MediaQueryData(size: const Size(800, 900), disableAnimations: still),
    child: MaterialApp(
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: TutolysTheme.village(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CarteSection(
            section: section,
            title: 'Géométrie',
            open: open,
            holdsNext: true,
            compact: false,
            pathHeight: SkillPath.heightOf(
              nodes,
              compact: false,
              inlineCard: true,
            ),
            onToggle: () {},
            onSettled: settled.add,
            path: (revealedTo) => SkillPath(
              nodes: nodes,
              statusLabel: (_) => '',
              continueLabel: '',
              revealedTo: revealedTo,
            ),
          ),
        ),
      ),
    ),
  );

  final orb = find.byKey(const ValueKey('path-orb-n0'));
  double height(WidgetTester t) => t.getSize(find.byType(CarteSection)).height;
  // On screen, so it sees the tuck's transform; the wide orb is 60px.
  double lastOrbScale(WidgetTester t) =>
      t.getRect(find.byKey(const ValueKey('path-orb-n11'))).width /
      t.getSize(find.byKey(const ValueKey('path-orb-n11'))).width;

  setUp(settled.clear);

  testWidgets('it rolls up in under 400 ms, the last orb first', (
    tester,
  ) async {
    await tester.pumpWidget(app(open: true));
    final full = height(tester);
    expect(lastOrbScale(tester), closeTo(1, 1e-9));

    await tester.pumpWidget(app(open: false));
    await tester.pump(const Duration(milliseconds: 170));
    final midway = height(tester);
    expect(midway, lessThan(full));
    expect(midway, greaterThan(64));
    expect(lastOrbScale(tester), lessThan(1), reason: 'tucked already');
    expect(orb, findsOneWidget, reason: 'the first orb is still out');

    await tester.pump(const Duration(milliseconds: 225));
    expect(orb, findsNothing);
    expect(settled, [false]);
  });

  testWidgets('unrolling restores every orb at full size', (tester) async {
    await tester.pumpWidget(app(open: false));
    expect(orb, findsNothing);
    final closed = height(tester);

    await tester.pumpWidget(app(open: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(height(tester), greaterThan(closed));

    await tester.pump(const Duration(milliseconds: 300));
    expect(lastOrbScale(tester), closeTo(1, 1e-9));
    expect(settled, [true]);
  });

  testWidgets('a tap mid-roll just turns it around', (tester) async {
    await tester.pumpWidget(app(open: true));
    await tester.pumpWidget(app(open: false));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(app(open: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(orb, findsOneWidget);
    expect(settled, [true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: an instant toggle, no frames between', (
    tester,
  ) async {
    await tester.pumpWidget(app(open: true, still: true));
    await tester.pumpWidget(app(open: false, still: true));
    expect(orb, findsNothing);
    await tester.pumpWidget(app(open: true, still: true));
    expect(orb, findsOneWidget);
    expect(lastOrbScale(tester), closeTo(1, 1e-9));
  });

  testWidgets('the fox points only while its section is closed', (
    tester,
  ) async {
    final fox = find.byKey(const ValueKey('carte-section-fox'));
    await tester.pumpWidget(app(open: true, still: true));
    expect(fox, findsNothing);
    await tester.pumpWidget(app(open: false, still: true));
    expect(fox, findsOneWidget);
  });

  testWidgets('a closed header fits a narrow phone, fox and all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(288, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(open: false, still: true));
    expect(tester.takeException(), isNull);
  });

  test('the trail never overstates or hides progress', () {
    expect(trailFilled(done: 0, total: 40, dots: 8), 0);
    expect(trailFilled(done: 1, total: 40, dots: 8), 1);
    expect(trailFilled(done: 39, total: 40, dots: 8), 7);
    expect(trailFilled(done: 40, total: 40, dots: 8), 8);
    expect(trailFilled(done: 3, total: 3, dots: 3), 3);
    expect(trailFilled(done: 0, total: 0, dots: 0), 0);
  });
}
