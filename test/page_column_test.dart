import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/core/routing/village_nav.dart';
import 'package:tutolys_app/core/widgets/page_column.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/about/about_screen.dart';
import 'package:tutolys_app/features/help/help_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'y', displayName: 'Yelhan', gradeLevel: 1),
    accessToken: 'token',
  );
}

/// The shell as `VillageShell` builds it: sidebar or rail, header, and the
/// pages in an `IndexedStack`.
Future<void> _pumpInShell(WidgetTester tester, double width, int page) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = LocalDatabase.memory();
  addTearDown(db.close);
  final c = ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      activeKidIdProvider.overrideWithValue('y'),
      sessionControllerProvider.overrideWith(_Session.new),
    ],
  );
  addTearDown(c.dispose);
  final s = Strings.fr;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: TutolysTheme.village(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: VillageNavShell(
              destinations: [
                VillageDestination(
                  label: s.navVillage,
                  asset: 'asset-village.png',
                ),
              ],
              currentIndex: 0,
              onSelect: (_) {},
              child: Column(
                children: [
                  const VillageHeader(name: 'Y', subtitle: '', stats: []),
                  Expanded(
                    child: IndexedStack(
                      index: page,
                      children: const [
                        SettingsScreen(),
                        HelpScreen(),
                        AboutScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('PageColumn.insets', () {
    test('equal sides, at least the gutter', () {
      final i = PageColumn.insets(1000);
      expect(i.left, i.right);
      expect(i.left, (1000 - PageWidth.column) / 2);
      expect(PageColumn.insets(500).left, Space.md, reason: 'phone gutter');
      expect(PageColumn.insets(700).left, Space.lg);
    });

    test('widens from PageWidth.wideFrom', () {
      expect(
        1726 - PageColumn.insets(1726).horizontal,
        PageWidth.columnWide,
      );
      expect(
        1300 - PageColumn.insets(1300).horizontal,
        PageWidth.column,
      );
    });
  });

  // The page area is the window less the sidebar (224, from 1024) or the
  // rail (84). Hafid, 2026-10-29: the column must sit in its middle.
  for (final width in [1024.0, 1950.0]) {
    final pageLeft = width >= Breakpoints.medium
        ? VillageMetrics.sidebarWidth
        : VillageMetrics.railWidth;
    final pageCentre = (pageLeft + width) / 2;

    for (final (index, name) in [(0, 'Réglages'), (1, 'Aide'), (2, 'À propos')]) {
      testWidgets('$name at $width: centred in the page area', (tester) async {
        await _pumpInShell(tester, width, index);
        final pages = [SettingsScreen, HelpScreen, AboutScreen];
        final scroll = find.descendant(
          of: find.byType(pages[index]),
          matching: find.byType(SingleChildScrollView),
        );
        final view = tester.getRect(scroll.first);
        expect(view.left, pageLeft);
        expect(view.right, width);
        final content = tester.getRect(
          find.descendant(of: scroll.first, matching: find.byType(Column)).first,
        );
        expect(content.center.dx, closeTo(pageCentre, 0.5));
        if (width == 1950 && index < 2) {
          expect(content.width, PageWidth.columnWide);
        }
      });
    }
  }
}
