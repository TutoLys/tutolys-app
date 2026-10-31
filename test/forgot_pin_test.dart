import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/profile/pin_gate.dart';

/// « NIP oublié ? », option A (ADR 0109): a fresh pairing code from the
/// portal clears the parent PIN.
class _Api extends PairingApi {
  _Api() : super(dio: Dio());
  PairingResult exchange = const PairingCodeRejected('invalid');
  int exchanges = 0;

  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    exchanges++;
    return exchange;
  }

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async =>
      const RefreshSucceeded(accessToken: 'access', expiresIn: 900);
}

PairingSucceeded _good(String kid) => PairingSucceeded(
  deviceToken: 'new-$kid',
  accessToken: 'access-$kid',
  expiresIn: 900,
  kidId: kid,
  kidDisplayName: kid,
  gradeLevel: 1,
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final fr = Strings.fr;

  Future<(ProviderContainer, SessionStore, _Api)> paired(
    List<String> kids,
  ) async {
    final store = SessionStore();
    for (final id in kids.reversed) {
      await store.savePairing(
        deviceToken: 'tok-$id',
        kidId: id,
        kidDisplayName: id,
        gradeLevel: 1,
      );
    }
    await store.setGuardianPin('111111');
    final api = _Api();
    final db = LocalDatabase.memory();
    final c = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWithValue(store),
        pairingApiProvider.overrideWithValue(api),
        sessionAutoRefreshProvider.overrideWithValue(false),
        adultCheckFactsProvider.overrideWithValue(() => (7, 8)),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    await c.read(sessionControllerProvider.notifier).restore();
    return (c, store, api);
  }

  test('clearGuardianPin forgets the PIN and the wait', () async {
    final store = SessionStore();
    await store.setGuardianPin('246810');
    for (var i = 0; i < 3; i++) {
      await store.verifyGuardianPin('000000');
    }
    expect(await store.guardianPinLockedUntil(), isNotNull);
    await store.clearGuardianPin();
    expect(await store.hasGuardianPin(), isFalse);
    expect(await store.guardianPinLockedUntil(), isNull);
  });

  group('resetGuardianPinWithCode', () {
    test('a rejected code keeps the PIN', () async {
      final (c, store, _) = await paired(['a']);
      final error = await c
          .read(sessionControllerProvider.notifier)
          .resetGuardianPinWithCode('ZZZZZZ');
      expect(error, PairingError.invalidCode);
      expect(await store.verifyGuardianPin('111111'), isTrue);
    });

    test('a code for the kid playing clears the PIN and renews their '
        'token', () async {
      final (c, store, api) = await paired(['a']);
      api.exchange = _good('a');
      final error = await c
          .read(sessionControllerProvider.notifier)
          .resetGuardianPinWithCode('ABC234');
      expect(error, isNull);
      expect(await store.hasGuardianPin(), isFalse);
      expect(await store.deviceTokenFor('a'), 'new-a');
      expect(c.read(sessionControllerProvider).kid?.id, 'a');
    });

    test('a code for another child adds them; the kid playing stays',
        () async {
      final (c, store, api) = await paired(['a']);
      api.exchange = _good('b');
      await c
          .read(sessionControllerProvider.notifier)
          .resetGuardianPinWithCode('ABC234');
      expect(await store.hasGuardianPin(), isFalse);
      expect(c.read(sessionControllerProvider).kid?.id, 'a');
      expect((await store.pairedKid())?.id, 'a');
      expect(
        c.read(sessionControllerProvider).kids.map((k) => k.id),
        containsAll(['a', 'b']),
      );
    });
  });

  testWidgets('the gate: « NIP oublié ? », a code, then a new PIN', (
    tester,
  ) async {
    late ProviderContainer c;
    late SessionStore store;
    late _Api api;
    await tester.runAsync(() async {
      (c, store, api) = await paired(['a']);
    });
    api.exchange = _good('a');
    bool? allowed;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: TutolysTheme.village(),
          locale: const Locale('fr', 'CA'),
          supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('go'),
                onPressed: () async =>
                    allowed = await requireGuardianPin(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    expect(find.text(fr.pinForgot), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pin-forgot')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pin-forgot-dialog')), findsOneWidget);
    expect(find.text(fr.pinForgotBody), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.pumpAndSettle();

    expect(api.exchanges, 1);
    expect(find.text(fr.pinForgotNew), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '135790');
    await tester.enterText(find.byType(TextField).at(1), '135790');
    await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
    await tester.runAsync(() async {
      expect(await store.verifyGuardianPin('135790'), isTrue);
    });
  });
}
