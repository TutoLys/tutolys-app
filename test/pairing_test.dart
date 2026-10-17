import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';

import 'package:tutolys_app/core/routing/app_shell.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_screen.dart';
import 'package:tutolys_app/features/path/path_screen.dart';

/// In-memory stand-ins. Hand-written rather than generated: there are two of
/// them and the behaviour under test is the state machine, not the transport.
class FakeSessionStore extends SessionStore {
  FakeSessionStore({this.storedToken});

  String? storedToken;
  String? savedKidName;
  bool cleared = false;

  @override
  Future<String> deviceId() async => 'test-device';

  @override
  Future<String?> deviceToken() async => storedToken;

  @override
  Future<void> savePairing({
    required String deviceToken,
    required String kidId,
    required String kidDisplayName,
    required int gradeLevel,
  }) async {
    storedToken = deviceToken;
    savedKidName = kidDisplayName;
  }

  @override
  Future<PairedKid?> pairedKid() async => savedKidName == null
      ? const PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1)
      : PairedKid(id: 'k1', displayName: savedKidName!, gradeLevel: 1);

  @override
  Future<void> clearPairing() async {
    cleared = true;
    storedToken = null;
  }
}

class FakePairingApi extends PairingApi {
  FakePairingApi({
    required this.exchangeResult,
    required this.refreshResult,
  }) : super(dio: _unusedDio);

  final PairingResult exchangeResult;
  final RefreshResult refreshResult;
  int exchangeCalls = 0;

  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    exchangeCalls++;
    return exchangeResult;
  }

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async =>
      refreshResult;
}

class CountingPairingApi extends FakePairingApi {
  CountingPairingApi({
    required super.exchangeResult,
    required super.refreshResult,
  });

  int refreshCalls = 0;

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    refreshCalls++;
    // Yield, so concurrent callers genuinely overlap and the mutex is tested
    // rather than accidentally satisfied by synchronous completion.
    await Future<void>.delayed(Duration.zero);
    return super.refresh(deviceToken: deviceToken);
  }
}

final _unusedDio = Dio();

const _success = PairingSucceeded(
  deviceToken: 'device-token-1',
  accessToken: 'access-token-1',
  expiresIn: 900,
  kidId: 'k1',
  kidDisplayName: 'Yelhan',
  gradeLevel: 1,
);

ProviderContainer containerWith({
  required FakeSessionStore store,
  required FakePairingApi api,
}) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      // No background timer in tests: an armed 12-minute timer fails the
      // pending-timer check, and these tests drive refresh explicitly.
      sessionAutoRefreshProvider.overrideWithValue(false),
    ],
  );
}

Widget appUnder(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      // Reduce motion in tests. The mascot's idle breath repeats forever
      // otherwise, and `pumpAndSettle` would never settle. Honouring the flag
      // is also the accessibility behaviour we want in production.
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
        theme: TutolysTheme.learner(),
        home: child,
      ),
    ),
  );
}

void main() {
  group('session state machine', () {
    test('no stored token means unpaired', () async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'a',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
    });

    test('a stored token that still refreshes means paired', () async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'fresh',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.paired);
      expect(state.accessToken, 'fresh');
    });

    test(
      'A2 acceptance: a device revoked on the server returns to pairing',
      () async {
        final store = FakeSessionStore(storedToken: 'stored');
        final container = containerWith(
          store: store,
          // 401 from the server: revoked or the kid was archived.
          api: FakePairingApi(
            exchangeResult: _success,
            refreshResult: const RefreshRejected(),
          ),
        );
        addTearDown(container.dispose);

        await container.read(sessionControllerProvider.notifier).restore();

        expect(
          container.read(sessionControllerProvider).status,
          SessionStatus.unpaired,
        );
        expect(store.cleared, isTrue, reason: 'the credential must be dropped');
        expect(store.storedToken, isNull);
      },
    );

    test('offline does NOT un-pair the device', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshOffline(),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      // Dropping the credential when the Wi-Fi blips would force a parent to
      // generate a new code every time, and would break offline play.
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.paired,
      );
      expect(store.cleared, isFalse);
      expect(store.storedToken, 'stored');
    });

    test('pairing stores the device token and goes paired', () async {
      final store = FakeSessionStore();
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      final error =
          await container.read(sessionControllerProvider.notifier).pair('ZF23XU');

      expect(error, isNull);
      expect(store.storedToken, 'device-token-1');
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.paired,
      );
    });

    test('each failure maps to its own error kind', () async {
      Future<PairingError?> attempt(PairingResult result) async {
        final container = containerWith(
          store: FakeSessionStore(),
          api: FakePairingApi(
            exchangeResult: result,
            refreshResult: const RefreshRejected(),
          ),
        );
        addTearDown(container.dispose);
        return container.read(sessionControllerProvider.notifier).pair('ZF23XU');
      }

      expect(
        await attempt(const PairingCodeRejected('nope')),
        PairingError.invalidCode,
      );
      expect(await attempt(const PairingOffline()), PairingError.offline);
      expect(await attempt(const PairingRateLimited()), PairingError.rateLimited);
      expect(await attempt(const PairingFailed('boom')), PairingError.unexpected);
    });

    test('forget unpairs on request', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'a',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).forget();

      expect(store.cleared, isTrue);
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
    });
  });

  group('pairing screen', () {
    testWidgets('shows the French title and hint by default', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      expect(find.text('Salut !'), findsOneWidget);
      expect(find.text('Entre ton code pour commencer'), findsOneWidget);
      expect(
        find.text('Demande ton code à un adulte. Il a six caractères.'),
        findsOneWidget,
      );
    });

    testWidgets('the connect button is disabled until six characters', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button().onPressed, isNull, reason: 'empty code');

      await tester.enterText(find.byType(TextField), 'ZF23');
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'four characters');

      await tester.enterText(find.byType(TextField), 'ZF23XU');
      await tester.pump();
      expect(button().onPressed, isNotNull, reason: 'six characters');
    });

    testWidgets('characters outside the code alphabet never appear', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      // 0, O, 1, I and L are excluded, so a mistyped character is visibly
      // ignored rather than silently mapped onto a different code.
      await tester.enterText(find.byType(TextField), '0OIL1Z');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Z');
    });

    testWidgets('lower case is upper-cased as it is typed', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      await tester.enterText(find.byType(TextField), 'zf23xu');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ZF23XU');
    });

    testWidgets('a wrong code shows the kid-facing message', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingCodeRejected('invalid'),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Ce code ne fonctionne pas. Demande-en un nouveau à un adulte.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('being offline says so, rather than blaming the code', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingOffline(),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZF23XU');
      await tester.pumpAndSettle();

      // A child told "wrong code" when the Wi-Fi is off will retype a code
      // that was never the problem.
      expect(
        find.text("Pas de connexion Internet. Vérifie le Wi-Fi et réessaie."),
        findsOneWidget,
      );
    });

    testWidgets('editing after an error clears it', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingCodeRejected('invalid'),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ZZZZZ');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('app shell', () {
    testWidgets('an unpaired device lands on the pairing screen', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(PathScreen), findsNothing);
    });

    testWidgets('a paired device goes straight past pairing', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'fresh',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(PathScreen), findsOneWidget);
      expect(find.byType(PairingScreen), findsNothing);
    });

    testWidgets('a revoked device is sent back to pairing on launch', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'revoked-token'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
    });
  });

  group('token refresh (review findings)', () {
    test('concurrent refreshes coalesce into one request', () async {
      /// The single-flight mutex. Two concurrent 401 retries both refreshing
      /// means the loser presents an already-rotated token and the session is
      /// dropped — the exact bug the client census found in the old app.
      final api = CountingPairingApi(
        exchangeResult: _success,
        refreshResult: const RefreshSucceeded(accessToken: 'a', expiresIn: 900),
      );
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: api,
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await Future.wait([
        controller.ensureFreshToken(),
        controller.ensureFreshToken(),
        controller.ensureFreshToken(),
      ]);

      expect(api.refreshCalls, 1, reason: 'refreshes did not coalesce');
    });

    test('a later refresh still works after the first completes', () async {
      final api = CountingPairingApi(
        exchangeResult: _success,
        refreshResult: const RefreshSucceeded(accessToken: 'a', expiresIn: 900),
      );
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: api,
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await controller.ensureFreshToken();
      await controller.ensureFreshToken();

      expect(api.refreshCalls, 2, reason: 'the mutex must not latch');
    });

    test('a refresh updates the held access token', () async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'second-token',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).ensureFreshToken();

      expect(
        container.read(sessionControllerProvider).accessToken,
        'second-token',
      );
    });

    test('a rejected refresh unpairs and stops the timer', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).ensureFreshToken();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
      expect(store.cleared, isTrue);
    });

    test('an offline refresh keeps the session', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshOffline(),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).ensureFreshToken();

      expect(store.cleared, isFalse);
      expect(store.storedToken, 'stored');
    });
  });
}
