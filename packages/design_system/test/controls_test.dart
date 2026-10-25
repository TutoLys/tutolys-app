import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool dark = false, bool still = false}) =>
    MaterialApp(
      theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    );

/// The filled part of a progress bar: the only box carrying a gradient.
double fillWidth(WidgetTester tester) {
  final fill = tester
      .widgetList<Container>(find.byType(Container))
      .firstWhere((c) => (c.decoration as BoxDecoration?)?.gradient != null);
  return tester.getSize(find.byWidget(fill)).width;
}

void main() {
  group('VillageProgressBar', () {
    testWidgets('fills to its value with the blue to gold gradient', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const VillageProgressBar(value: 0.5), still: true),
      );
      expect(fillWidth(tester), 150);
    });

    testWidgets('a tiny non-zero value still shows as a dot', (tester) async {
      await tester.pumpWidget(
        host(const VillageProgressBar(value: 0.01), still: true),
      );
      expect(fillWidth(tester), 8, reason: 'never thinner than it is tall');
    });

    testWidgets('out-of-range and NaN values are clamped, not thrown', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const VillageProgressBar(value: 3), still: true),
      );
      expect(fillWidth(tester), 300);
      await tester.pumpWidget(
        host(const VillageProgressBar(value: double.nan), still: true),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('eases to a new value instead of jumping', (tester) async {
      await tester.pumpWidget(host(const VillageProgressBar(value: 0)));
      await tester.pumpWidget(host(const VillageProgressBar(value: 1)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fillWidth(tester), inExclusiveRange(0, 300));
      await tester.pumpAndSettle();
      expect(fillWidth(tester), 300);
    });
  });

  group('VillageLoader', () {
    testWidgets('animates, and rests when motion is reduced', (tester) async {
      await tester.pumpWidget(host(const VillageLoader()));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(host(const VillageLoader(), still: true));
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'no ticking when the kid asked for calm',
      );
    });
  });

  group('VillageSwitch', () {
    testWidgets('a tap flips it', (tester) async {
      bool? got;
      await tester.pumpWidget(
        host(VillageSwitch(value: false, onChanged: (v) => got = v)),
      );
      await tester.tap(find.byType(VillageSwitch));
      expect(got, isTrue);
    });

    testWidgets('the keyboard flips it, like a real switch', (tester) async {
      bool? got;
      await tester.pumpWidget(
        host(VillageSwitch(value: true, onChanged: (v) => got = v)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, isFalse);
    });

    testWidgets('announces as a toggled switch', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          VillageSwitch(
            value: true,
            onChanged: (_) {},
            semanticLabel: 'Musique de fond',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(VillageSwitch)),
        matchesSemantics(
          label: 'Musique de fond',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('has a finger-sized hit area', (tester) async {
      await tester.pumpWidget(
        host(VillageSwitch(value: false, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(VillageSwitch)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('VillageSegmented', () {
    testWidgets('tapping an option selects it', (tester) async {
      int? got;
      await tester.pumpWidget(
        host(
          VillageSegmented(
            options: const ['Clair', 'Sombre'],
            selected: 0,
            onSelect: (i) => got = i,
          ),
        ),
      );
      await tester.tap(find.text('Sombre'));
      expect(got, 1);
    });

    testWidgets('options are equal width, so the pill never changes size', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          VillageSegmented(
            options: const ['Français', 'English'],
            selected: 0,
            onSelect: (_) {},
          ),
        ),
      );
      final a = tester.getSize(
        find.ancestor(
          of: find.text('Français'),
          matching: find.byType(InkWell),
        ),
      );
      final b = tester.getSize(
        find.ancestor(of: find.text('English'), matching: find.byType(InkWell)),
      );
      expect(a.width, b.width);
    });

    testWidgets('in dark mode the chosen pill is lighter than its channel', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          VillageSegmented(
            options: const ['Clair', 'Sombre'],
            selected: 1,
            onSelect: (_) {},
          ),
          dark: true,
        ),
      );
      final pill = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.boxShadow != null && d.color != null)
          .color!;
      expect(
        pill.computeLuminance(),
        greaterThan(VillageDarkColors.track.computeLuminance()),
        reason: 'the design\'s dark surface pill read as a hole in the track',
      );
    });
  });

  group('VillageSlider', () {
    testWidgets('drags and reports the new value', (tester) async {
      double? got;
      await tester.pumpWidget(
        host(VillageSlider(value: 70, onChanged: (v) => got = v)),
      );
      await tester.tap(find.byType(Slider));
      expect(got, closeTo(50, 5), reason: 'a tap in the middle is about half');
    });
  });
}
