import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/core/routing/app_shell.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/core/routing/village_shell.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/api/passcode_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/outbox_flusher_provider.dart';
import 'package:tutolys_app/features/launch/launch_flow.dart';
import 'package:tutolys_app/features/launch/tutolys_welcome_screen.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/assignments/assignments_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_entry_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_service.dart';
import 'package:tutolys_app/features/path/path_controller.dart';

/// Refreshes succeed, except that a switch to another kid can be held open
/// with [hold], to look at the screen while the switch is in flight.
class _Api extends PairingApi {
  _Api() : super(dio: Dio());

  Completer<void>? hold;

  /// What a typed kid code pairs: a new kid, Noé.
  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async =>
      const PairingSucceeded(
        deviceToken: 'tok-k3',
        accessToken: 'access-tok-k3',
        expiresIn: 900,
        kidId: 'k3',
        kidDisplayName: 'Noé',
        gradeLevel: 1,
      );

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    await hold?.future;
    return RefreshSucceeded(accessToken: 'access-$deviceToken', expiresIn: 900);
  }
}

/// Nobody has a passcode, unless [leaHasOne]: then Léa's is the flame, the
/// star, the fox.
class _PasscodeApi extends PasscodeApi {
  _PasscodeApi() : super(dio: Dio());

  bool leaHasOne = false;

  static const _lea = PasscodeVerifier(
    salt: 's',
    verifier: 'v',
    algorithm: 'hmac-sha256-v1',
    imageSet: 'v1',
  );

  @override
  Future<PasscodeState?> fetch({required String accessToken}) async =>
      leaHasOne && accessToken == 'access-tok-k2'
          ? const HasPasscode(_lea)
          : const NoPasscode();

  @override
  Future<PasscodeVerifyResult> verify({
    required String accessToken,
    required List<int> sequence,
  }) async =>
      sequence.join() == '056'
          ? const PasscodeVerified(accessToken: 'verified-k2', expiresIn: 900)
          : const PasscodeWrong();
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

ProviderContainer _container(
  SessionStore store,
  _Api api, {
  _PasscodeApi? passcodes,
}) {
  final db = LocalDatabase.memory();
  final c = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      sessionAutoRefreshProvider.overrideWithValue(false),
      outboxFlusherAutoStartProvider.overrideWithValue(false),
      notificationsPollingProvider.overrideWithValue(false),
      assignmentsPollingProvider.overrideWithValue(false),
      recoveryRetriesProvider.overrideWithValue(false),
      localDatabaseProvider.overrideWithValue(db),
      curriculumApiProvider.overrideWithValue(_OfflineCurriculumApi()),
      contentApiProvider.overrideWithValue(_OfflineContentApi()),
      passcodeApiProvider.overrideWithValue(passcodes ?? _PasscodeApi()),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return c;
}

Widget _app(
  ProviderContainer c, {
  Size size = const Size(1280, 900),
  bool still = true,
}) => UncontrolledProviderScope(
  container: c,
  child: MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: still),
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

  testWidgets('a kid with a passcode taps it on launch, even the last one '
      'who played', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _container(
      await _storeWith([('k1', 'Yelhan'), ('k2', 'Léa')]),
      _Api(),
      passcodes: _PasscodeApi()..leaHasOne = true,
    );
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);
    // The picker's sync has learned Léa's passcode by now.
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('who-kid-k2')));
    await tester.pumpAndSettle();
    expect(find.byType(PasscodeEntryScreen), findsOneWidget);
    expect(find.byType(VillageShell), findsNothing);

    for (final i in [0, 5, 6]) {
      await tester.tap(find.byKey(ValueKey('passcode-picture-$i')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(VillageShell), findsOneWidget);
    expect(c.read(sessionControllerProvider).kid!.id, 'k2');
    expect(c.read(sessionControllerProvider).accessToken, 'verified-k2');
  });

  testWidgets('pairing a second kid offers the guardian picture codes', (
    tester,
  ) async {
    final c = _container(await _storeWith([('k1', 'Yelhan')]), _Api());
    await tester.pumpWidget(_app(c));
    await _toWelcome(tester);
    await tester.tap(find.text(fr.welcomePlay));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('passcode-offer')), findsNothing);

    await c.read(sessionControllerProvider.notifier).pair('ABC234');
    await tester.pumpAndSettle();
    // A5: no parent PIN on this device yet, so it is offered first.
    expect(find.text(fr.pinGateAfterPairing), findsOneWidget);
    expect(find.byKey(const ValueKey('passcode-offer')), findsNothing);
    await tester.tap(find.text(fr.later));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('passcode-offer')), findsOneWidget);
    expect(find.text(fr.passcodePromptTitle), findsOneWidget);

    await tester.tap(find.text(fr.passcodePromptLater));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('passcode-offer')), findsNothing);
    expect(c.read(sessionControllerProvider).kid!.id, 'k3');
  });

  group('the profile menu (ADR 0123)', () {
    final menu = find.byKey(const ValueKey('profile-menu'));
    final identity = find.byKey(const ValueKey('header-identity'));

    /// In the Village as Yelhan, with [kids] on the device.
    Future<ProviderContainer> inTheVillage(
      WidgetTester tester, {
      List<(String, String)> kids = const [('k1', 'Yelhan'), ('k2', 'Léa')],
      _PasscodeApi? passcodes,
      Size size = const Size(1280, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _container(
        await _storeWith(kids),
        _Api(),
        passcodes: passcodes,
      );
      await tester.pumpWidget(_app(c, size: size));
      await _toWelcome(tester);
      await tester.tap(
        kids.length > 1
            ? find.byKey(const ValueKey('who-kid-k1'))
            : find.text(fr.welcomePlay),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VillageShell), findsOneWidget);
      return c;
    }

    testWidgets('the avatar opens it in place, not "Qui joue ?"', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();

      expect(menu, findsOneWidget);
      expect(find.text(fr.whoIsPlaying), findsNothing);
      expect(c.read(sessionControllerProvider).stage, ProfileStage.none);
      // Every kid with their grade, and the current one marked.
      expect(
        find.descendant(of: menu, matching: find.text('Yelhan')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text('Léa')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(fr.gradeLabel(1))),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-menu-kid-k1')),
          matching: find.byKey(const ValueKey('profile-menu-current')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-menu-add')), findsOneWidget);
      // It hangs under the header's avatar.
      final card = tester.getTopLeft(menu);
      final anchor = tester.getBottomLeft(identity);
      expect(card.dy, greaterThanOrEqualTo(anchor.dy - 8));
      expect((card.dx - anchor.dx).abs(), lessThan(24));
    });

    testWidgets('only the avatar, name and chevron open it', (tester) async {
      // Hafid, 2026-11-10: "anywhere I click it opens the switch". The tap
      // target filled the header's whole Expanded middle.
      await inTheVillage(tester, size: const Size(1440, 900));
      final target = tester.getRect(identity);
      final header = tester.getRect(find.byType(VillageHeader));
      expect(target.width, lessThan(header.width / 3));

      // The header's empty middle, just past the chevron, the page, the
      // sidebar and the quest panel.
      for (final point in [
        header.center,
        Offset(target.right + 12, target.center.dy),
        const Offset(700, 500),
        const Offset(40, 700),
        const Offset(1300, 600),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(menu, findsNothing, reason: 'tapped at $point');
      }

      await tester.tap(find.text('Yelhan').first);
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
    });

    testWidgets('a tap outside closes it, and it stays closed', (
      tester,
    ) async {
      await inTheVillage(tester, size: const Size(1440, 900));
      await tester.tap(identity);
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);

      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      // And in the header's empty middle, where it used to reopen.
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getRect(find.byType(VillageHeader)).center);
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
    });

    testWidgets('a screen reader can pick a row', (tester) async {
      final semantics = tester.ensureSemantics();
      await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('profile-menu-kid-k2'))),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Léa, ${fr.gradeLabel(1)}',
        ),
      );
      semantics.dispose();
    });

    testWidgets('one tap plays as the other kid, on their token', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-kid-k2')));
      await tester.pumpAndSettle();

      expect(menu, findsNothing);
      expect(c.read(sessionControllerProvider).kid!.id, 'k2');
      expect(c.read(sessionControllerProvider).accessToken, 'access-tok-k2');
      expect(find.byType(VillageShell), findsOneWidget);
    });

    testWidgets('tapping the kid already playing just closes it', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-kid-k1')));
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');
    });

    testWidgets('a kid with a passcode taps it first, as from the picker', (
      tester,
    ) async {
      final c = await inTheVillage(
        tester,
        passcodes: _PasscodeApi()..leaHasOne = true,
      );
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-kid-k2')));
      await tester.pumpAndSettle();
      expect(find.byType(PasscodeEntryScreen), findsOneWidget);
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');

      for (final i in [0, 5, 6]) {
        await tester.tap(find.byKey(ValueKey('passcode-picture-$i')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.read(sessionControllerProvider).kid!.id, 'k2');
      expect(c.read(sessionControllerProvider).accessToken, 'verified-k2');
    });

    testWidgets('with one kid it still opens, and offers a second', (
      tester,
    ) async {
      await inTheVillage(tester, kids: const [('k1', 'Yelhan')]);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-menu-kid-k1')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-menu-add')), findsOneWidget);
    });

    testWidgets('"Ajouter un profil" pairs, and backing out returns here', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-add')));
      await tester.pumpAndSettle();
      expect(find.byType(PairingScreen), findsOneWidget);
      expect(c.read(sessionControllerProvider).stage, ProfileStage.adding);

      c.read(sessionControllerProvider.notifier).cancelAdding();
      await tester.pumpAndSettle();
      expect(find.byType(VillageShell), findsOneWidget);
      expect(find.text(fr.whoIsPlaying), findsNothing);
    });

    testWidgets('from launch, backing out of adding is still "Qui joue ?"', (
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
      c.read(sessionControllerProvider.notifier).cancelAdding();
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsPlaying), findsOneWidget);
    });

    testWidgets('Esc and a tap outside close it, switching nobody', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(menu, findsNothing);

      await tester.tap(identity);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1200, 800));
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');
    });

    testWidgets('the keyboard walks it: arrow down, then Enter', (
      tester,
    ) async {
      final c = await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pumpAndSettle();
      // Focus starts on the kid playing, the first row here.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.read(sessionControllerProvider).kid!.id, 'k2');
    });

    /// How far the card has grown.
    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.ancestor(of: menu, matching: find.byType(ScaleTransition)).first,
        )
        .scale
        .value;

    testWidgets('reduced motion: there at once, at full size', (tester) async {
      await inTheVillage(tester);
      await tester.tap(identity);
      await tester.pump();
      await tester.pump();
      expect(scale(tester), 1);
    });

    testWidgets('with motion: it grows in', (tester) async {
      final c = await inTheVillage(tester);
      // Motion back on only now: the launch flow never settles with it.
      await tester.pumpWidget(_app(c, still: false));
      await tester.tap(identity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(scale(tester), lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(scale(tester), 1);
    });

    testWidgets('on a phone it is a bottom sheet that fits', (tester) async {
      await inTheVillage(
        tester,
        size: const Size(360, 640),
        kids: const [('k1', 'Yelhan'), ('k2', 'Léa'), ('k3', 'Noé')],
      );
      await tester.tap(identity);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-menu-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
