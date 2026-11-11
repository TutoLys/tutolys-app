import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/page_tab.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/settings/portal_link.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';

/// Zone parent → « Ouvrir le site » opens the parents' portal in the
/// browser (ADR 0127). It said « bientôt » while the site didn't exist.
class _Store extends SessionStore {}

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1),
    kids: [PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1)],
    accessToken: 't',
  );
}

void main() {
  Future<List<Uri>> pumpAndTap(
    WidgetTester tester, {
    required bool opens,
  }) async {
    final opened = <Uri>[];
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWithValue(_Store()),
        sessionControllerProvider.overrideWith(_Session.new),
        externalUrlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
      ],
    );
    addTearDown(c.dispose);
    await c
        .read(pageTabProvider(TabbedPage.settings).notifier)
        .select(SettingsTab.parents.name);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 1400),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: TutolysTheme.learner(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('parent-zone-open-site'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return opened;
  }

  testWidgets('opens the portal, and says nothing when it did', (
    tester,
  ) async {
    final opened = await pumpAndTap(tester, opens: true);
    expect(opened, [Uri.parse(portalUrl)]);
    expect(opened.single.path, '/portail/');
    expect(find.text(Strings.fr.settingsParentZoneFailed), findsNothing);
    expect(find.textContaining('bientôt'), findsNothing);
  });

  testWidgets('says so when nothing on the device can open it', (
    tester,
  ) async {
    await pumpAndTap(tester, opens: false);
    expect(
      find.text(Strings.fr.settingsParentZoneFailed),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
