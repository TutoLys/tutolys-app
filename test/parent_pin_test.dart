import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/profile/pin_gate.dart';

/// A5: whoever taps first must not become "the parent".
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Widget host(
    SessionStore store,
    Future<void> Function(BuildContext, WidgetRef) onTap,
  ) => ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      adultCheckFactsProvider.overrideWithValue(() => (7, 8)),
    ],
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
            onPressed: () => onTap(context, ref),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );

  final fr = Strings.fr;

  group('creating a PIN outside pairing', () {
    testWidgets('asks the adult check first; a wrong answer goes no further', (
      tester,
    ) async {
      final store = SessionStore();
      bool? allowed;
      await tester.pumpWidget(
        host(store, (c, r) async => allowed = await requireGuardianPin(c, r)),
      );
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('adult-check')), findsOneWidget);
      expect(find.text(fr.adultCheckSubtitle(7, 8)), findsOneWidget);
      expect(find.text(fr.pinGateCreateTitle), findsNothing);

      await tester.enterText(find.byType(TextField), '54');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();
      expect(find.text(fr.adultCheckWrong), findsOneWidget);
      expect(find.text(fr.pinGateCreateTitle), findsNothing);

      await tester.tap(find.text(fr.cancel));
      await tester.pumpAndSettle();
      expect(allowed, isFalse);
      expect(await store.hasGuardianPin(), isFalse);
    });

    testWidgets('the right answer leads to creating it', (tester) async {
      final store = SessionStore();
      bool? allowed;
      await tester.pumpWidget(
        host(store, (c, r) async => allowed = await requireGuardianPin(c, r)),
      );
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '56');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();

      expect(find.text(fr.pinGateCreateTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '135790');
      await tester.enterText(find.byType(TextField).at(1), '135790');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();
      expect(allowed, isTrue);
      expect(await store.verifyGuardianPin('135790'), isTrue);
    });
  });

  testWidgets('after pairing: offered without the check, in "vous", with '
      '« Plus tard »', (tester) async {
    final store = SessionStore();
    await tester.pumpWidget(host(store, offerGuardianPinAfterPairing));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adult-check')), findsNothing);
    expect(find.text(fr.pinGateAfterPairing), findsOneWidget);
    await tester.tap(find.text(fr.later));
    await tester.pumpAndSettle();
    expect(await store.hasGuardianPin(), isFalse);
  });

  test('a pairing raises the offer once', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(guardianPinOfferProvider), isFalse);
    c.read(guardianPinOfferProvider.notifier).offer();
    expect(c.read(guardianPinOfferProvider), isTrue);
    c.read(guardianPinOfferProvider.notifier).taken();
    expect(c.read(guardianPinOfferProvider), isFalse);
  });

  group('wrong PINs', () {
    test('three free tries, then a wait that doubles, and the right PIN '
        'clears it', () async {
      var now = DateTime.utc(2026, 10, 29, 12);
      final store = SessionStore(clock: () => now);
      await store.setGuardianPin('246810');

      for (var i = 0; i < 2; i++) {
        expect(await store.verifyGuardianPin('000000'), isFalse);
        expect(await store.guardianPinLockedUntil(), isNull);
      }
      expect(await store.verifyGuardianPin('000000'), isFalse);
      expect(
        await store.guardianPinLockedUntil(),
        now.add(const Duration(seconds: 30)),
      );
      expect(
        await store.verifyGuardianPin('246810'),
        isFalse,
        reason: 'refused unchecked while it waits',
      );

      now = now.add(const Duration(seconds: 31));
      expect(await store.verifyGuardianPin('000000'), isFalse);
      expect(
        await store.guardianPinLockedUntil(),
        now.add(const Duration(seconds: 60)),
      );

      now = now.add(const Duration(seconds: 61));
      expect(await store.verifyGuardianPin('246810'), isTrue);
      expect(await store.verifyGuardianPin('000000'), isFalse);
      expect(await store.guardianPinLockedUntil(), isNull, reason: 'reset');
    });

    test('the wait is capped at 15 minutes', () {
      expect(SessionStore.guardianPinBackoff(2), Duration.zero);
      expect(SessionStore.guardianPinBackoff(3), const Duration(seconds: 30));
      expect(SessionStore.guardianPinBackoff(40), const Duration(minutes: 15));
    });
  });

  test('adult-facing PIN copy says "vous", never "tu"', () {
    for (final line in [
      fr.pinGateCreateSubtitle,
      fr.pinGateConfirmPinLabel,
      fr.pinGateUpgradeTitle,
      fr.pinGateUpgradeSubtitle,
      fr.remindersPinCreate,
      fr.passcodesPinCreate,
      fr.pinGateAfterPairing,
      fr.pinGateLocked(30),
    ]) {
      expect(
        line,
        isNot(matches(RegExp(r"\b(Crée|Confirme|Choisis|Choisis-en|tu)\b"))),
        reason: line,
      );
    }
  });
}
