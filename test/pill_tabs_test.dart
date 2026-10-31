import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/page_tab.dart';
import 'package:tutolys_app/core/widgets/pill_tabs.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';

Widget _wrap(Widget child, {bool still = false, double width = 800}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 900), disableAnimations: still),
    child: MaterialApp(
      theme: TutolysTheme.learner(),
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

/// A row of three pills whose selection lives here, like a page's would.
class _Row extends StatefulWidget {
  const _Row();

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  String selected = 'a';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PillTabs<String>(
        keyPrefix: 't',
        selected: selected,
        compact: false,
        onSelect: (v) => setState(() => selected = v),
        tabs: const [
          PillTab(value: 'a', label: 'Alpha'),
          PillTab(value: 'b', label: 'Bravo'),
          PillTab(value: 'c', label: 'Charlie'),
        ],
      ),
      PillTabPanel(tabKey: selected, child: Text('panel $selected')),
    ],
  );
}

class _Kid extends Notifier<String?> {
  @override
  String? build() => 'lea';

  void set(String? id) => state = id;
}

final _kid = NotifierProvider<_Kid, String?>(_Kid.new);

void main() {
  group('PillTabs', () {
    String selected(WidgetTester tester) =>
        tester.state<_RowState>(find.byType(_Row)).selected;

    void focus(WidgetTester tester, String value) => tester
        .widget<InkWell>(find.byKey(ValueKey('t-$value')))
        .focusNode!
        .requestFocus();

    testWidgets('a tap selects', (tester) async {
      await tester.pumpWidget(_wrap(const _Row(), still: true));
      await tester.tap(find.text('Bravo'));
      await tester.pump();
      expect(selected(tester), 'b');
      expect(find.text('panel b'), findsOneWidget);
    });

    testWidgets('arrows move and select, wrapping; Home and End jump', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Row(), still: true));
      focus(tester, 'a');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(selected(tester), 'b');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(selected(tester), 'c');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(selected(tester), 'a', reason: 'wraps round');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(selected(tester), 'c');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(selected(tester), 'a');
    });

    testWidgets('Enter selects the focused pill', (tester) async {
      await tester.pumpWidget(_wrap(const _Row(), still: true));
      focus(tester, 'c');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected(tester), 'c');
    });

    testWidgets('a screen reader hears tabs, selected, and their place', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Row(), still: true));

      expect(
        tester.getSemantics(find.byKey(const ValueKey('t-a'))),
        matchesSemantics(
          label: 'Alpha, onglet 1 sur 3',
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('t-b'))),
        matchesSemantics(
          label: 'Bravo, onglet 2 sur 3',
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('reduced motion swaps the panel at once', (tester) async {
      await tester.pumpWidget(_wrap(const _Row(), still: true));
      await tester.tap(find.text('Bravo'));
      await tester.pump();
      expect(find.text('panel a'), findsNothing);
      expect(find.text('panel b'), findsOneWidget);
    });

    testWidgets('otherwise the old panel fades out', (tester) async {
      await tester.pumpWidget(_wrap(const _Row()));
      await tester.tap(find.text('Bravo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('panel a'), findsOneWidget, reason: 'still fading');
      await tester.pumpAndSettle();
      expect(find.text('panel a'), findsNothing);
    });
  });

  group('the remembered tab', () {
    late LocalDatabase db;
    late ProviderContainer c;

    setUp(() {
      db = LocalDatabase.memory();
      c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWith((ref) => ref.watch(_kid)),
        ],
      );
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<String?> settle(String page) async {
      final sub = c.listen(pageTabProvider(page), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final v = c.read(pageTabProvider(page));
      sub.close();
      return v;
    }

    test('is kept per kid and per page', () async {
      await c.read(pageTabProvider(TabbedPage.settings).notifier).select('sound');
      await c.read(pageTabProvider(TabbedPage.profile).notifier).select('recent');

      c.read(_kid.notifier).set('noah');
      expect(await settle(TabbedPage.settings), isNull,
          reason: "Noah never chose: his first tab, not Léa's");

      c.read(_kid.notifier).set('lea');
      expect(await settle(TabbedPage.settings), 'sound');
      expect(await settle(TabbedPage.profile), 'recent');
    });

    test('a choice made before the read lands is not undone', () async {
      await c.read(pageTabProvider(TabbedPage.settings).notifier).select('sound');
      c.read(_kid.notifier).set('noah');
      c.read(_kid.notifier).set('lea');
      await c.read(pageTabProvider(TabbedPage.settings).notifier).select('parents');
      expect(await settle(TabbedPage.settings), 'parents');
    });
  });

  group('Réglages', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      double width = 900,
      double height = 1400,
      String? stored,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('lea'),
          sessionControllerProvider.overrideWith(_Session.new),
        ],
      );
      addTearDown(c.dispose);
      if (stored != null) {
        await c.read(pageTabProvider(TabbedPage.settings).notifier).select(stored);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _wrap(const SettingsScreen(), still: true, width: width),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('opens on Apparence, one group at a time', (tester) async {
      await pump(tester);
      expect(find.text(Strings.fr.settingsTheme), findsOneWidget);
      expect(find.text(Strings.fr.settingsVolume), findsNothing);
      // Under every tab.
      expect(find.text(Strings.fr.navHelp), findsOneWidget);
    });

    testWidgets('a pill shows its group and is remembered', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('settings-tab-sound')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.fr.settingsVolume), findsOneWidget);
      expect(find.text(Strings.fr.settingsTheme), findsNothing);
      expect(c.read(pageTabProvider(TabbedPage.settings)), 'sound');
    });

    testWidgets('a deep link opens straight on its tab', (tester) async {
      await pump(tester, stored: SettingsTab.parents.name);
      expect(find.byKey(const ValueKey('settings-passcodes')), findsOneWidget);
    });

    testWidgets('four pills: Notifications is a section of Expérience', (
      tester,
    ) async {
      await pump(tester, stored: SettingsTab.experience.name);
      expect(SettingsTab.values.map((t) => t.name), [
        'appearance',
        'sound',
        'experience',
        'parents',
      ]);
      expect(find.byKey(const ValueKey('settings-tab-notifications')), findsNothing);
      expect(find.text(Strings.fr.settingsLanguage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-section-notifications')),
        findsOneWidget,
      );
      expect(find.text(Strings.fr.settingsDailyReminders), findsOneWidget);
      expect(find.text(Strings.fr.settingsFlameReminders), findsOneWidget);
    });

    testWidgets('a link to the old Notifications tab lands on Expérience, '
        'scrolled to the section', (tester) async {
      await pump(tester, stored: SettingsTab.notificationsSection, height: 500);
      expect(SettingsTab.from('notifications'), SettingsTab.experience);
      final heading = find.byKey(const ValueKey('settings-section-notifications'));
      final top = tester.getTopLeft(heading).dy;
      expect(top, lessThan(500), reason: 'scrolled into view');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('settings-tab-experience'))).dy,
        lessThan(0),
        reason: 'the page scrolled past the pills to get there',
      );
    });


    // The window widths Hafid named, as the width the shell leaves the page
    // (84px rail from 600, 224px sidebar from 1024).
    // A phone gets the grid instead (AM6), tested below.
    for (final (window, page) in [
      (768.0, 684.0),
      (1024.0, 800.0),
      (1950.0, 1726.0),
    ]) {
      testWidgets('pills at $window: none cut without a fade', (tester) async {
        await pump(tester, width: page);
        final row = find.byKey(const ValueKey('pill-tabs-fade'));
        final rowBox = tester.getRect(row);
        final dynamic state = tester.state(find.byType(PillTabs<SettingsTab>));
        final fading = state.fading as ({bool before, bool after});
        for (final tab in SettingsTab.values) {
          final pill = tester.getRect(
            find.byKey(ValueKey('settings-tab-${tab.name}')),
          );
          if (pill.right > rowBox.right + 0.5) {
            expect(fading.after, isTrue, reason: '${tab.name} cut on the right');
          }
          if (pill.left < rowBox.left - 0.5) {
            expect(fading.before, isTrue, reason: '${tab.name} cut on the left');
          }
        }
        if (!fading.after && !fading.before) {
          for (final tab in SettingsTab.values) {
            final pill = tester.getRect(
              find.byKey(ValueKey('settings-tab-${tab.name}')),
            );
            expect(pill.right, lessThanOrEqualTo(rowBox.right + 0.5));
          }
        }
      });
    }

    testWidgets('a phone: all four tabs in a 2×2 grid, 48px or taller (AM6)', (
      tester,
    ) async {
      await pump(tester, width: 375);
      expect(find.byKey(const ValueKey('pill-tabs-fade')), findsNothing);
      final rects = [
        for (final tab in SettingsTab.values)
          tester.getRect(find.byKey(ValueKey('settings-tab-${tab.name}'))),
      ];
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(375));
        expect(r.height, greaterThanOrEqualTo(48));
      }
      expect(rects[0].top, rects[1].top, reason: 'two to a row');
      expect(rects[2].top, greaterThan(rects[0].bottom));
      expect(rects[0].width, closeTo(rects[1].width, 0.5), reason: 'equal');
      await tester.tap(find.byKey(const ValueKey('settings-tab-parents')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-passcodes')), findsOneWidget);
    });

    testWidgets('sign-out is a neutral outline, never red (AM7)', (
      tester,
    ) async {
      await pump(tester, stored: SettingsTab.parents.name);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('settings-sign-out')),
      );
      final fg = button.style!.foregroundColor!.resolve({});
      expect(fg, isIn([VillagePalette.light.ink, VillagePalette.dark.ink]));
      expect(fg, isNot(TutolysColors.danger));
    });

    testWidgets('Zone parent holds sign-out', (tester) async {
      await pump(tester, stored: SettingsTab.parents.name);
      expect(find.text(Strings.fr.settingsParentZone), findsWidgets);
      expect(find.byKey(const ValueKey('settings-passcodes')), findsOneWidget);
    });

    testWidgets('an unknown stored tab falls back to the first', (tester) async {
      await pump(tester, stored: 'gone');
      expect(find.text(Strings.fr.settingsTheme), findsOneWidget);
    });

    testWidgets('fits a phone: every tab, no overflow', (tester) async {
      await pump(tester, width: 360);
      for (final tab in SettingsTab.values) {
        final pill = find.byKey(ValueKey('settings-tab-${tab.name}'));
        await tester.ensureVisible(pill);
        await tester.pumpAndSettle();
        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab.name);
      }
    });
  });
}

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1),
    accessToken: 'token',
  );
}
