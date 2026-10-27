import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/who_is_playing_screen.dart';

/// Refresh answers per device token, so a test can see which kid's
/// credential each call used.
class _TokenPairingApi extends PairingApi {
  _TokenPairingApi({
    this.rejected = const {},
    this.offline = false,
    this.reason,
  }) : super(dio: Dio());

  final Set<String> rejected;

  /// What a rejection says about why; null is a bare 401.
  final RejectionReason? reason;
  final bool offline;
  final refreshedWith = <String>[];
  PairingResult exchange = const PairingFailed('unused');

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    refreshedWith.add(deviceToken);
    if (offline) return const RefreshOffline();
    if (rejected.contains(deviceToken)) {
      return RefreshRejected(reason: reason);
    }
    return RefreshSucceeded(accessToken: 'access-$deviceToken', expiresIn: 900);
  }

  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async =>
      exchange;
}

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
  PairingApi api, {
  LocalDatabase? db,
}) =>
    ProviderContainer(
      overrides: [
        // Lazy, so only a test that forgets or revokes a kid opens one.
        localDatabaseProvider.overrideWith((ref) {
          if (db != null) return db;
          final memory = LocalDatabase.memory();
          ref.onDispose(memory.close);
          return memory;
        }),
        sessionStoreProvider.overrideWithValue(store),
        pairingApiProvider.overrideWithValue(api),
        sessionAutoRefreshProvider.overrideWithValue(false),
      ],
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('SessionStore', () {
    test('a pre-multi-kid install migrates its one pairing', () async {
      FlutterSecureStorage.setMockInitialValues({
        'device_id': 'dev-1',
        'device_token': 'old-token',
        'kid_id': 'k1',
        'kid_display_name': 'Yelhan',
        'grade_level': '2',
      });
      final store = SessionStore();

      final kids = await store.pairedKids();
      expect([for (final k in kids) k.id], ['k1']);
      expect(kids.single.gradeLevel, 2);
      expect(await store.deviceToken(), 'old-token');
      expect(await store.deviceId(), 'dev-1');
      // Migrated once: the old keys are gone, the new list stands alone.
      expect(await const FlutterSecureStorage().read(key: 'device_token'), isNull);
      expect(await store.pairedKid().then((k) => k?.displayName), 'Yelhan');
    });

    test('pairing a second kid keeps the first, and makes the new one active',
        () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);

      expect([for (final k in await store.pairedKids()) k.id], ['k1', 'k2']);
      expect((await store.pairedKid())!.id, 'k2');
      expect(await store.deviceTokenFor('k1'), 'tok-k1');
    });

    test('re-pairing a kid replaces only their token', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      await store.savePairing(
        deviceToken: 'new',
        kidId: 'k1',
        kidDisplayName: 'Yelhan',
        gradeLevel: 1,
      );

      expect(await store.pairedKids(), hasLength(2));
      expect(await store.deviceTokenFor('k1'), 'new');
      expect(await store.deviceTokenFor('k2'), 'tok-k2');
    });

    test('clearing removes the active kid only; the PIN goes with the last',
        () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      await store.setGuardianPin('123456');

      await store.clearPairing(); // k2, the active one
      expect([for (final k in await store.pairedKids()) k.id], ['k1']);
      expect((await store.pairedKid())!.id, 'k1');
      expect(await store.hasGuardianPin(), isTrue);

      await store.clearPairing();
      expect(await store.pairedKids(), isEmpty);
      expect(await store.isPaired, isFalse);
      expect(await store.hasGuardianPin(), isFalse);
    });

    test('a PIN stored before the move to 6 digits reads as 4 digits',
        () async {
      final store = await _storeWith([('k1', 'Yelhan')]);
      expect(await store.guardianPinDigits(), isNull);

      // The old code wrote only the salt and hash, never a digit count.
      await store.setGuardianPin('1234');
      await const FlutterSecureStorage().delete(key: 'guardian_pin_digits');
      expect(await store.guardianPinDigits(), 4);
      expect(await store.verifyGuardianPin('1234'), isTrue);

      await store.setGuardianPin('123456');
      expect(await store.guardianPinDigits(), 6);
      expect(await store.verifyGuardianPin('1234'), isFalse);

      await store.clearPairing();
      expect(await store.guardianPinDigits(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'guardian_pin_digits'),
        isNull,
      );
    });
  });

  group('SessionController', () {
    test('one kid launches straight into the app', () async {
      final store = await _storeWith([('k1', 'Yelhan')]);
      final c = _container(store, _TokenPairingApi());
      addTearDown(c.dispose);

      await c.read(sessionControllerProvider.notifier).restore();

      final s = c.read(sessionControllerProvider);
      expect(s.status, SessionStatus.paired);
      expect(s.stage, ProfileStage.none);
    });

    test('several kids launch on "Qui joue ?"', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      final c = _container(store, _TokenPairingApi());
      addTearDown(c.dispose);

      await c.read(sessionControllerProvider.notifier).restore();

      final s = c.read(sessionControllerProvider);
      expect(s.stage, ProfileStage.choosing);
      expect(s.kids, hasLength(2));
    });

    test('switching kid refreshes with that kid\'s own token', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      final api = _TokenPairingApi();
      final c = _container(store, api);
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.notifier).restore();

      await c.read(sessionControllerProvider.notifier).switchTo('k1');

      final s = c.read(sessionControllerProvider);
      expect(s.kid!.id, 'k1');
      expect(s.accessToken, 'access-tok-k1');
      expect(s.stage, ProfileStage.none);
      expect(c.read(activeKidIdProvider), 'k1');
      expect(api.refreshedWith.last, 'tok-k1');
      // Remembered for the next launch.
      expect((await store.pairedKid())!.id, 'k1');
    });

    test('offline, the switch still happens, with no access token', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      final c = _container(store, _TokenPairingApi(offline: true));
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.notifier).restore();

      await c.read(sessionControllerProvider.notifier).switchTo('k1');

      final s = c.read(sessionControllerProvider);
      expect(s.kid!.id, 'k1');
      expect(s.accessToken, isNull);
      expect(s.status, SessionStatus.paired);
    });

    test('a revoked kid is dropped and the sibling carries on', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      final c = _container(store, _TokenPairingApi(rejected: {'tok-k2'}));
      addTearDown(c.dispose);

      await c.read(sessionControllerProvider.notifier).restore();

      final s = c.read(sessionControllerProvider);
      expect(s.status, SessionStatus.paired);
      expect(s.kid!.id, 'k1');
      expect([for (final k in s.kids) k.id], ['k1']);
    });

    test('adding a profile pairs a second kid without dropping the first',
        () async {
      final store = await _storeWith([('k1', 'Yelhan')]);
      final api = _TokenPairingApi()
        ..exchange = const PairingSucceeded(
          deviceToken: 'tok-k2',
          accessToken: 'a2',
          expiresIn: 900,
          kidId: 'k2',
          kidDisplayName: 'Lina',
          gradeLevel: 1,
        );
      final c = _container(store, api);
      addTearDown(c.dispose);
      final n = c.read(sessionControllerProvider.notifier);
      await n.restore();

      n.addProfile();
      expect(c.read(sessionControllerProvider).stage, ProfileStage.adding);
      await n.pair('ABCDEF');

      final s = c.read(sessionControllerProvider);
      expect(s.kid!.id, 'k2');
      expect(s.stage, ProfileStage.none);
      expect([for (final k in s.kids) k.id], ['k1', 'k2']);
      expect(s.hasSeveralKids, isTrue);
    });

    test('forgetting one kid of two opens "Qui joue ?" on the other', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina'), ('k3', 'Sami')]);
      final c = _container(store, _TokenPairingApi());
      addTearDown(c.dispose);
      final n = c.read(sessionControllerProvider.notifier);
      await n.restore();

      await n.forget();

      final s = c.read(sessionControllerProvider);
      expect(s.status, SessionStatus.paired);
      expect([for (final k in s.kids) k.id], ['k1', 'k2']);
      expect(s.stage, ProfileStage.choosing);
    });

    group('a rejected credential (ADR 0037)', () {
      Future<LocalDatabase> seeded() async {
        final db = LocalDatabase.memory();
        addTearDown(db.close);
        await CreationStore(db, kidId: 'k2').save(
          engineKey: 'compose_build',
          exerciseId: 'ex-1',
          payload: {'words': <String>[]},
        );
        return db;
      }

      for (final reason in RejectionReason.values) {
        test('erases local data when the server says "${reason.name}"',
            () async {
          final db = await seeded();
          final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
          final c = _container(
            store,
            _TokenPairingApi(rejected: {'tok-k2'}, reason: reason),
            db: db,
          );
          addTearDown(c.dispose);

          await c.read(sessionControllerProvider.notifier).restore();

          expect(await CreationStore(db, kidId: 'k2').list(), isEmpty);
        });
      }

      test('a bare 401 drops the credential but keeps the data', () async {
        final db = await seeded();
        final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
        final c = _container(
          store,
          _TokenPairingApi(rejected: {'tok-k2'}),
          db: db,
        );
        addTearDown(c.dispose);

        await c.read(sessionControllerProvider.notifier).restore();

        final s = c.read(sessionControllerProvider);
        expect([for (final k in s.kids) k.id], ['k1']);
        expect(await CreationStore(db, kidId: 'k2').list(), hasLength(1));
      });
    });

    test('a kid who is forgotten or revoked takes their local data along',
        () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      for (final kid in ['k1', 'k2']) {
        await CreationStore(db, kidId: kid).save(
          engineKey: 'compose_build',
          exerciseId: 'ex-1',
          payload: {'words': ['Le', 'chat']},
        );
      }
      final c = _container(store, _TokenPairingApi(), db: db);
      addTearDown(c.dispose);
      final n = c.read(sessionControllerProvider.notifier);
      await n.restore();
      final active = c.read(sessionControllerProvider).kid!.id;

      await n.forget();

      expect(await CreationStore(db, kidId: active).list(), isEmpty);
      final other = active == 'k1' ? 'k2' : 'k1';
      expect(await CreationStore(db, kidId: other).list(), hasLength(1));
    });
  });

  group('WhoIsPlayingScreen', () {
    testWidgets('a tile per kid, and tapping one plays as them', (tester) async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          pairingApiProvider.overrideWithValue(_TokenPairingApi()),
          sessionAutoRefreshProvider.overrideWithValue(false),
          localDatabaseProvider.overrideWithValue(db),
          recoveryRetriesProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.notifier).restore();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: TutolysTheme.learner(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WhoIsPlayingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.fr.whoIsPlaying), findsOneWidget);
      expect(find.text('Yelhan'), findsOneWidget);
      expect(find.text('Lina'), findsOneWidget);
      expect(find.text(Strings.fr.addProfile), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('who-kid-k1')));
      await tester.pumpAndSettle();
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');
      expect(c.read(sessionControllerProvider).stage, ProfileStage.none);
    });
  });
}
