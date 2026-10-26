import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/village_nav.dart';

/// The shell is pure presentation, so these tests supply their own
/// destinations rather than reaching for the app's localised list.
const _primary = <VillageDestination>[
  VillageDestination(label: 'Village', asset: 'asset-village.png'),
  VillageDestination(label: 'Carte', asset: 'asset-carte.png'),
  VillageDestination(label: 'Quêtes', asset: 'asset-quetes.png'),
  VillageDestination(label: 'Progrès', asset: 'asset-progres.png'),
  VillageDestination(label: 'Profil', asset: 'asset-profil.png'),
];

const _secondary = <VillageDestination>[
  VillageDestination(label: 'Réglages', asset: 'asset-reglages.png'),
];

/// The shell's whole job is being three different things at three widths,
/// so that is what these assert — not that it renders at all.
void main() {
  Widget harness({
    required Size size,
    int currentIndex = 0,
    ValueChanged<int>? onSelect,
    ValueChanged<int>? onSecondarySelect,
    VoidCallback? onHelp,
    List<VillageDestination>? destinations,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(
          body: VillageNavShell(
            destinations: destinations ?? _primary,
            secondary: _secondary,
            currentIndex: currentIndex,
            onSelect: onSelect ?? (_) {},
            onSecondarySelect: onSecondarySelect,
            helpLabel: 'Aide & support',
            onHelp: onHelp ?? () {},
            child: const Text('page content'),
          ),
        ),
      ),
    );
  }

  const desktop = Size(1280, 900);
  const tablet = Size(900, 900);
  const phone = Size(390, 844);

  group('desktop, >= 1024', () {
    testWidgets('shows the full sidebar with labels and the wordmark',
        (tester) async {
      await tester.pumpWidget(harness(size: desktop));

      expect(find.text('TutoLys'), findsOneWidget);
      for (final d in _primary) {
        expect(find.text(d.label), findsOneWidget);
      }
      expect(find.text('Réglages'), findsOneWidget);
      expect(find.text('Aide & support'), findsOneWidget);
    });

    testWidgets('the sidebar is exactly the design\'s 224px', (tester) async {
      await tester.pumpWidget(harness(size: desktop));

      final sidebar = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.constraints?.maxWidth == 224);
      expect(sidebar.constraints!.maxWidth, VillageMetrics.sidebarWidth);
    });

    testWidgets('tapping a destination reports its index', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(harness(size: desktop, onSelect: (i) => tapped = i));

      await tester.tap(find.text('Quêtes'));
      expect(tapped, 2);
    });

    testWidgets('the secondary section reports separately from the primary',
        (tester) async {
      var primary = -1;
      var secondary = -1;
      await tester.pumpWidget(harness(
        size: desktop,
        onSelect: (i) => primary = i,
        onSecondarySelect: (i) => secondary = i,
      ));

      await tester.tap(find.text('Réglages'));
      expect(secondary, 0);
      expect(primary, -1, reason: 'Réglages is not a primary destination');
    });

    testWidgets('help is reachable from the footer', (tester) async {
      var helped = false;
      await tester.pumpWidget(
        harness(size: desktop, onHelp: () => helped = true),
      );

      await tester.tap(find.text('Aide & support'));
      expect(helped, isTrue);
    });
  });

  group('tablet, 768-1023', () {
    testWidgets('collapses to an 84px rail with no labels', (tester) async {
      await tester.pumpWidget(harness(size: tablet));

      final rail = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.constraints?.maxWidth == 84);
      expect(rail.constraints!.maxWidth, VillageMetrics.railWidth);

      expect(find.text('Village'), findsNothing);
      expect(find.text('TutoLys'), findsNothing,
          reason: 'the wordmark goes, the mark stays');
      expect(find.text('Aide & support'), findsNothing);
    });

    testWidgets('icons still navigate without their labels', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(harness(size: tablet, onSelect: (i) => tapped = i));

      await tester.tap(find.byType(InkWell).at(1));
      expect(tapped, 1);
    });
  });

  group('phone, < 768', () {
    testWidgets('uses a bottom tab bar, not a sidebar', (tester) async {
      await tester.pumpWidget(harness(size: phone));

      final bar = tester.widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxHeight == 78);
      expect(bar, isNotEmpty, reason: 'the design\'s 78px tab bar');

      expect(
        tester.widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints?.maxWidth == 224),
        isEmpty,
      );
    });

    testWidgets('shows the five primary labels but not Réglages',
        (tester) async {
      await tester.pumpWidget(harness(size: phone));

      for (final d in _primary) {
        expect(find.text(d.label), findsOneWidget);
      }
      expect(
        find.text('Réglages'),
        findsNothing,
        reason: 'six tabs in a thumb\'s reach is one too many — it moves to '
            'the header on mobile',
      );
    });
  });

  group('badges', () {
    const withBadge = <VillageDestination>[
      VillageDestination(label: 'Village', asset: 'asset-village.png'),
      VillageDestination(
        label: 'Quêtes',
        asset: 'asset-quetes.png',
        badge: 3,
      ),
    ];

    testWidgets('a count renders', (tester) async {
      await tester.pumpWidget(
        harness(size: desktop, destinations: withBadge),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('zero is treated as no badge, so callers need no special case',
        (tester) async {
      await tester.pumpWidget(harness(
        size: desktop,
        destinations: const [
          VillageDestination(label: 'Village', asset: 'asset-village.png'),
          VillageDestination(
            label: 'Quêtes',
            asset: 'asset-quetes.png',
            badge: 0,
          ),
        ],
      ));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('badges survive the rail, where labels do not', (tester) async {
      await tester.pumpWidget(
        harness(size: tablet, destinations: withBadge),
      );
      expect(find.text('Quêtes'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });
  });

  testWidgets('the page content renders at every width', (tester) async {
    for (final size in [desktop, tablet, phone]) {
      await tester.pumpWidget(harness(size: size));
      expect(find.text('page content'), findsOneWidget);
    }
  });

  group('a destination with its own icon (Profil shows the avatar)', () {
    final withAvatar = [
      ..._primary.take(4),
      VillageDestination(
        label: 'Profil',
        asset: 'asset-profil.png',
        icon: (size) => SizedBox.square(
          key: ValueKey('avatar-$size'),
          dimension: size,
        ),
      ),
    ];

    for (final (name, size, iconSize) in [
      ('sidebar', desktop, 22.0),
      ('rail', tablet, 24.0),
      ('bottom bar', phone, 23.0),
    ]) {
      testWidgets('draws it in the $name', (tester) async {
        await tester.pumpWidget(
          harness(size: size, destinations: withAvatar),
        );
        expect(find.byKey(ValueKey('avatar-$iconSize')), findsOneWidget);
      });
    }

    testWidgets('without one, the asset icon stays', (tester) async {
      await tester.pumpWidget(harness(size: desktop));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/asset-profil.png',
        ),
        findsOneWidget,
      );
    });
  });
}
