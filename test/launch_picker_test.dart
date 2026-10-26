import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/core/routing/app_shell.dart';
import 'package:tutolys_app/core/routing/village_shell.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/outbox_flusher_provider.dart';
import 'package:tutolys_app/features/launch/launch_flow.dart';
import 'package:tutolys_app/features/launch/tutolys_welcome_screen.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_screen.dart';
import 'package:tutolys_app/features/path/path_controller.dart';

/// Refreshes succeed, except that a switch to another kid can be held open
/// with [hold], to look at the screen while the switch is in flight.
class _Api extends PairingApi {
  _Api() : super(dio: Dio());

  Completer<void>? hold;

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    await hold?.future;
    return RefreshSucceeded(accessToken: 'access-$deviceToken', expiresIn: 900);
  }
}

class _OfflineCurriculumApi extends CurriculumApi {
  _OfflineCurriculumApi() : super(dio: Dio());

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async => const CurriculumTreeOffline();
}

class _OfflineContentApi extends ContentApi {
  _OfflineContentApi() : super(dio: Dio());

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async => const ManifestOffline();
}

/// Pairs [kids] in order, so the last one is the active kid, as on Hafid's
/// device where Léa was paired last.
Future<SessionStore> _storeWith(List<(String, String)> kids) async {
  final store = SessionStore();
  for (final (id, name) in kids) {
    await store.savePairing(
      deviceToken: 'tok-$id',
      kidId: id,
      kidDisplayName: name,
      gradeLevel: 1,
    );
  }
  return store;
}

ProviderContainer _container(SessionStore store, _Api api) {
  final db = LocalDatabase.memory();
  final c = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      sessionAutoRefreshProvider.overrideWithValue(false),
      outboxFlusherAutoStartProvider.overrideWithValue(false),
      notificationsPollingProvider.overrideWithValue(false),
      recoveryRetriesProvider.overrideWithValue(false),
      localDatabaseProvider.overrideWithValue(db),
      curriculumApiProvider.overrideWithValue(_OfflineCurriculumApi()),
      contentApiProvider.overrideWithValue(_OfflineContentApi()),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return c;
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(1280, 900), disableAnimations: true),
    child: MaterialApp(
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: TutolysTheme.learner(),
      home: const AppShell(),
    ),
  ),
);

/// Through the loader to the welcome screen.
Future<void> _toWelcome(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(LaunchFlow.doneBeatReduced);
  await tester.pumpAndSettle();
  expect(find.byType(TutolysWelcomeScreen), findsOneWidget);
}

void main() {
  final fr = Strings.fr;

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('one kid: greeted by name, and Jouer enters the Village', (
    tester,
  ) async {
    final c = _container(await _storeWith([('k1', 'Yelhan')]), _Api());
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);

    expect(find.text(fr.welcomeGreeting('Yelhan')), findsOneWidget);
    expect(find.text(fr.welcomePlay), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-kids')), findsNothing);

    await tester.tap(find.text(fr.welcomePlay));
    await tester.pumpAndSettle();
    expect(find.byType(VillageShell), findsOneWidget);
  });

  testWidgets('several kids: the welcome screen is the picker, naming no one', (
    tester,
  ) async {
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa')]),
      _Api(),
    );
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);

    // Léa played last, but the fox greets nobody by name.
    expect(c.read(sessionControllerProvider).kid!.id, 'k2');
    expect(find.text(fr.welcomeGreeting('Léa')), findsNothing);
    expect(find.text(fr.welcomeGreeting('Yelhan')), findsNothing);
    expect(find.text(fr.welcomeHello), findsOneWidget);
    expect(find.text(fr.welcomeWhoToday), findsOneWidget);
    expect(find.text(fr.welcomePlay), findsNothing);

    // One tile each, the last kid not singled out, and "Ajouter un profil".
    expect(find.byKey(const ValueKey('who-kid-k1')), findsOneWidget);
    expect(find.byKey(const ValueKey('who-kid-k2')), findsOneWidget);
    expect(find.byKey(const ValueKey('who-add')), findsOneWidget);
    // Nothing kid-scoped is built yet, and no second picker follows.
    expect(find.byType(VillageShell), findsNothing);
    expect(find.text(fr.whoIsPlaying), findsNothing);
  });

  testWidgets('tapping a kid enters as them, never via the last kid', (
    tester,
  ) async {
    final api = _Api();
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa')]),
      api,
    );
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);

    // Hold the switch's token refresh open: until it lands, the welcome
    // screen stays, and nothing is built for Léa.
    api.hold = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('who-kid-k1')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VillageShell), findsNothing);
      expect(find.byType(TutolysWelcomeScreen), findsOneWidget);
    }

    api.hold!.complete();
    // Frame by frame: the Village only ever appears for Yelhan.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(VillageShell).evaluate().isNotEmpty) {
        expect(c.read(sessionControllerProvider).kid!.id, 'k1');
      }
    }
    await tester.pumpAndSettle();
    expect(find.byType(VillageShell), findsOneWidget);
    expect(c.read(sessionControllerProvider).kid!.id, 'k1');
    expect(c.read(sessionControllerProvider).accessToken, 'access-tok-k1');
    expect(c.read(sessionControllerProvider).stage, ProfileStage.none);
  });

  testWidgets('tapping the last kid enters as them, with no second picker', (
    tester,
  ) async {
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa')]),
      _Api(),
    );
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);

    await tester.tap(find.byKey(const ValueKey('who-kid-k2')));
    await tester.pumpAndSettle();
    expect(find.byType(VillageShell), findsOneWidget);
    expect(find.text(fr.whoIsPlaying), findsNothing);
    expect(c.read(sessionControllerProvider).kid!.id, 'k2');
  });

  testWidgets('"Ajouter un profil" opens pairing from the launch screen', (
    tester,
  ) async {
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa')]),
      _Api(),
    );
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);

    await tester.tap(find.byKey(const ValueKey('who-add')));
    await tester.pumpAndSettle();
    expect(find.byType(PairingScreen), findsOneWidget);
    expect(c.read(sessionControllerProvider).stage, ProfileStage.adding);
  });

  testWidgets('the picker fits a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa'), ('k3', 'Noé')]),
      _Api(),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            disableAnimations: true,
          ),
          child: MaterialApp(
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: TutolysTheme.learner(),
            home: TutolysWelcomeScreen(
              onStart: () {},
              kids: await SessionStore().pairedKids(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('who-kid-k3')), findsOneWidget);
  });
}
