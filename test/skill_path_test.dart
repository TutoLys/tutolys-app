import 'package:flutter/rendering.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/path/skill_path.dart';

Widget pathIn({
  required List<PathNode> nodes,
  bool stillness = false,
  bool visible = true,
  ValueChanged<PathNode>? onTap,
  bool compact = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: stillness),
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Visibility(
          visible: visible,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: SkillPath(
            nodes: nodes,
            compact: compact,
            statusLabel: (n) => 'status-${n.id}',
            continueLabel: 'Continuer',
            onTapNode: onTap,
          ),
        ),
      ),
    ),
  ),
);

const _available = PathNode(
  id: 'a',
  label: 'Additionner',
  state: PathNodeState.available,
);

void main() {
  group('the available orb pulses', () {
    testWidgets('when visible and motion is allowed', (tester) async {
      await tester.pumpWidget(pathIn(nodes: const [_available]));
      await tester.pump(const Duration(milliseconds: 600));

      // A running ticker leaves a pending frame; a stopped one does not.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('not under reduced motion', (tester) async {
      await tester.pumpWidget(
        pathIn(nodes: const [_available], stillness: true),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('not while its tab is hidden', (tester) async {
      // IndexedStack keeps the Carte built behind other tabs and does not
      // mute tickers.
      await tester.pumpWidget(
        pathIn(nodes: const [_available], visible: false),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets('only the active node carries the card', (tester) async {
    await tester.pumpWidget(
      pathIn(
        stillness: true,
        nodes: const [
          PathNode(id: 'm', label: 'Compter', state: PathNodeState.mastered),
          PathNode(id: 'x', label: 'Mesurer', state: PathNodeState.active),
          _available,
        ],
      ),
    );

    expect(find.text('STATUS-X'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });

  testWidgets('a completed orb can be replayed, and carries no card', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      pathIn(
        stillness: true,
        onTap: (n) => tapped.add(n.id),
        nodes: const [
          PathNode(id: 'd', label: 'Compter', state: PathNodeState.completed),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('path-orb-d')));
    expect(tapped, ['d']);
    expect(find.text('Continuer'), findsNothing);
  });

  testWidgets('a locked orb ignores taps and shows no click cursor', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      pathIn(
        stillness: true,
        onTap: (n) => tapped.add(n.id),
        nodes: const [
          PathNode(id: 'l', label: 'Pile ou face', state: PathNodeState.locked),
        ],
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('path-orb-l')),
      warnIfMissed: false,
    );
    expect(tapped, isEmpty);

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byKey(const ValueKey('path-orb-l')),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.basic);
  });

  testWidgets('phone sizing shrinks the orbs to the design\'s 50px', (
    tester,
  ) async {
    Future<double> orbWidth({required bool compact}) async {
      await tester.pumpWidget(
        pathIn(stillness: true, compact: compact, nodes: const [_available]),
      );
      return tester
          .getSize(
            find
                .descendant(
                  of: find.byKey(const ValueKey('path-orb-a')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .width;
    }

    expect(await orbWidth(compact: false), 60);
    expect(await orbWidth(compact: true), 50);
  });

  group('a node with several lessons', () {
    testWidgets('shows how many are done under its orb', (tester) async {
      await tester.pumpWidget(
        pathIn(
          stillness: true,
          nodes: const [
            PathNode(
              id: 'a',
              label: 'Additionner',
              state: PathNodeState.available,
              lessons: (2, 4),
              lessonsLabel: '2 of 4 lessons done',
            ),
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lesson-count-a')),
          matching: find.text('2/4'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('2 of 4 lessons done')),
        findsOneWidget,
      );
    });

    testWidgets('a locked node shows no count', (tester) async {
      await tester.pumpWidget(
        pathIn(
          stillness: true,
          nodes: const [
            PathNode(
              id: 'a',
              label: 'Additionner',
              state: PathNodeState.locked,
              lessons: (0, 3),
            ),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('lesson-count-a')), findsNothing);
    });
  });

  testWidgets('a node with no lesson says "bientôt" and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      pathIn(
        stillness: true,
        onTap: (_) => taps++,
        nodes: const [
          PathNode(
            id: 's',
            label: 'Classer des matériaux',
            state: PathNodeState.soon,
            stateLabel: 'Bientôt',
          ),
        ],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('soon-tag-s')),
        matching: find.text('BIENTÔT'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    await tester.tap(find.byKey(const ValueKey('path-orb-s')));
    expect(taps, 0);
  });

  // A short label may run to 32 characters. At 110 px it fits on two lines
  // in Roboto Bold (measured; the test font can't show that), and every
  // column keeps its caption on a 375 px screen.
  testWidgets('phone captions are 110 px wide and stay on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const label = 'Comment une histoire fonctionne';
    await tester.pumpWidget(
      pathIn(
        compact: true,
        nodes: [
          for (var i = 0; i < 4; i++)
            PathNode(id: 'n$i', label: label, state: PathNodeState.locked),
        ],
      ),
    );

    final captions = find.text(label);
    expect(captions, findsNWidgets(4));
    for (final e in captions.evaluate()) {
      final box = e.renderObject! as RenderBox;
      expect(box.constraints.maxWidth, 110);
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(0));
      expect(left + box.size.width, lessThanOrEqualTo(375));
    }
  });

  testWidgets('connectors stop under caption text', (tester) async {
    const label = 'Comment une histoire fonctionne';
    await tester.pumpWidget(
      pathIn(
        compact: true,
        nodes: const [
          PathNode(id: 'a', label: label, state: PathNodeState.available),
          PathNode(id: 'b', label: label, state: PathNodeState.locked),
        ],
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('path-connectors')),
    );
    final holes = (paint.painter! as dynamic).holes as List<Rect>;
    final captions = find.text(label).evaluate().toList();
    expect(holes, isNotEmpty);
    for (final e in captions) {
      final box = e.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final path = tester.getTopLeft(
        find.byKey(const ValueKey('path-connectors')),
      );
      // Every caption's text lies inside the cut-outs.
      expect(holes.any((h) => h.shift(path).overlaps(rect)), isTrue);
    }
  });

  // In the test font every glyph is 10 px wide, so at 110 px
  // « ab cd ef gh ij » breaks as « ab cd ef gh / ij ». Balanced, it is
  // « ab cd ef / gh ij »: about 80 px, two lines.
  testWidgets('two-line captions are balanced', (tester) async {
    const label = 'ab cd ef gh ij';
    await tester.pumpWidget(
      pathIn(
        compact: true,
        nodes: const [
          PathNode(id: 'a', label: label, state: PathNodeState.locked),
        ],
      ),
    );

    final box = tester.renderObject<RenderParagraph>(find.text(label));
    expect(box.size.width, inInclusiveRange(80, 90));
    expect(box.size.height, 28); // two 14 px lines, not three
  });

  testWidgets('the target icon is blue, never red', (tester) async {
    await tester.pumpWidget(pathIn(nodes: const [_available]));

    final target = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('path-target')),
    );
    expect(
      (target.painter! as dynamic).color,
      VillagePalette.light.quebecBlueBright,
    );
  });
}
