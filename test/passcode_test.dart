import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/api/passcode_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/who_is_playing_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_entry_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_pictures.dart';
import 'package:tutolys_app/features/passcode/passcode_service.dart';
import 'package:tutolys_app/features/passcode/passcode_setup_screen.dart';

/// A verifier computed by the backend's own `compute`, in Python:
/// `hmac.new(salt, "<kid>:4-0-7", sha256).hexdigest()`.
const _kid = '11111111-2222-3333-4444-555555555555';
const _salt = '0123456789abcdef0123456789abcdef';
const _backendVerifier =
    '8b84eaef87f5004b6aa4639ec0a6b227e014ab8887cdc85ef7beae8f51267f2d';

const _verifier = PasscodeVerifier(
  salt: _salt,
  verifier: _backendVerifier,
  algorithm: 'hmac-sha256-v1',
  imageSet: 'v1',
);

class _PairingApi extends PairingApi {
  _PairingApi() : super(dio: Dio());

  bool offline = false;

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async =>
      offline
          ? const RefreshOffline()
          : RefreshSucceeded(accessToken: 'access-$deviceToken', expiresIn: 900);
}

/// The server, per access token: which sequence each kid has, if any.
class _PasscodeApi extends PasscodeApi {
  _PasscodeApi() : super(dio: Dio());

  /// Access token → (sequence, verifier) for kids who have one.
  final codes = <String, (List<int>, PasscodeVerifier)>{};
  final verifyCalls = <(String, List<int>)>[];
  final saves = <(String, List<int>)>[];
  bool rateLimited = false;
  bool saveFails = false;

  @override
  Future<PasscodeState?> fetch({required String accessToken}) async {
    final code = codes[accessToken];
    return code == null ? const NoPasscode() : HasPasscode(code.$2);
  }

  @override
  Future<PasscodeVerifyResult> verify({
    required String accessToken,
    required List<int> sequence,
  }) async {
    verifyCalls.add((accessToken, sequence));
    if (rateLimited) return const PasscodeRateLimited();
    final code = codes[accessToken];
    if (code == null) return const PasscodeNotSet();
    if (code.$1.join() != sequence.join()) return const PasscodeWrong();
    return const PasscodeVerified(accessToken: 'verified', expiresIn: 600);
  }

  @override
  Future<PasscodeState?> save({
    required String accessToken,
    required List<int> sequence,
  }) async {
    saves.add((accessToken, sequence));
    if (saveFails) return null;
    final v = PasscodeVerifier(
      salt: 's',
      verifier: 'v-${sequence.join()}',
      algorithm: 'hmac-sha256-v1',
      imageSet: 'v1',
    );
    codes[accessToken] = (sequence, v);
    return HasPasscode(v);
  }

  @override
  Future<bool> clear({required String accessToken}) async {
    codes.remove(accessToken);
    return true;
  }
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

Widget _app(
  ProviderContainer c,
  Widget home, {
  String locale = 'fr',
  bool reduceMotion = false,
}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: TutolysTheme.learner(),
        locale: Locale(locale, 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => reduceMotion
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : child!,
        home: home,
      ),
    );

Future<void> _tapPictures(WidgetTester tester, List<int> sequence) async {
  for (final i in sequence) {
    await tester.tap(find.byKey(ValueKey('passcode-picture-$i')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('PasscodeVerifier', () {
    test('matches what the backend computes, and nothing else', () {
      expect(_verifier.matches(_kid, [4, 0, 7]), isTrue);
      expect(_verifier.matches(_kid, [4, 7, 0]), isFalse);
      expect(_verifier.matches('another-kid', [4, 0, 7]), isFalse);
    });

    test('one from an unknown algorithm or image set is not checkable', () {
      for (final v in [
        const PasscodeVerifier(
          salt: _salt,
          verifier: _backendVerifier,
          algorithm: 'argon2-v9',
          imageSet: 'v1',
        ),
        const PasscodeVerifier(
          salt: _salt,
          verifier: _backendVerifier,
          algorithm: 'hmac-sha256-v1',
          imageSet: 'v2',
        ),
      ]) {
        expect(v.isCheckable, isFalse);
        expect(v.matches(_kid, [4, 0, 7]), isFalse);
      }
    });
  });

  test('the nine pictures keep their indexes 0-8, each a distinct asset', () {
    expect([for (final p in passcodePictures) p.index], List.generate(9, (i) => i));
    expect({for (final p in passcodePictures) p.asset}, hasLength(9));
  });

  group('SessionStore passcode cache', () {
    test('keeps each kid apart, and forgets a removed kid', () async {
      final store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      expect(await store.passcodeFor('k1'), isNull);

      await store.savePasscode('k1', const HasPasscode(_verifier));
      await store.savePasscode('k2', const NoPasscode());
      final k1 = await store.passcodeFor('k1');
      expect(k1, isA<HasPasscode>());
      expect((k1! as HasPasscode).verifier.verifier, _backendVerifier);
      expect(await store.passcodeFor('k2'), isA<NoPasscode>());

      await store.setActiveKid('k1');
      await store.clearPairing();
      expect(await store.passcodeFor('k1'), isNull);
      expect(await store.passcodeFor('k2'), isA<NoPasscode>());
    });
  });

  group('PasscodeService', () {
    late SessionStore store;
    late _PairingApi pairing;
    late _PasscodeApi api;
    late PasscodeService service;

    setUp(() async {
      store = await _storeWith([(_kid, 'Yelhan'), ('k2', 'Lina')]);
      pairing = _PairingApi();
      api = _PasscodeApi()..codes['access-tok-$_kid'] = ([4, 0, 7], _verifier);
      service = PasscodeService(store: store, pairingApi: pairing, api: api);
    });

    test('syncAll learns every kid, with that kid\'s own token', () async {
      await service.syncAll();
      expect(await service.isRequired(_kid), isTrue);
      expect(await service.isRequired('k2'), isFalse);
      expect(await store.passcodeFor('k2'), isA<NoPasscode>());
    });

    test('online: the server decides, and a match brings a token', () async {
      final ok = await service.check(_kid, [4, 0, 7]);
      expect(ok, isA<PasscodeAccepted>());
      expect((ok as PasscodeAccepted).accessToken, 'verified');
      expect(api.verifyCalls.single.$1, 'access-tok-$_kid');

      expect(await service.check(_kid, [0, 4, 7]), isA<PasscodeRejected>());
    });

    test('a wrong try online re-learns a passcode changed in the portal',
        () async {
      await store.savePasscode(
        _kid,
        const HasPasscode(
          PasscodeVerifier(
            salt: 'old',
            verifier: 'old',
            algorithm: 'hmac-sha256-v1',
            imageSet: 'v1',
          ),
        ),
      );
      await service.check(_kid, [1, 2, 3]);
      final cached = await store.passcodeFor(_kid);
      expect((cached! as HasPasscode).verifier.verifier, _backendVerifier);
    });

    test('offline: checked against the cached verifier', () async {
      await store.savePasscode(_kid, const HasPasscode(_verifier));
      pairing.offline = true;
      expect(await service.check(_kid, [4, 0, 7]), isA<PasscodeAccepted>());
      expect(await service.check(_kid, [7, 0, 4]), isA<PasscodeRejected>());
      expect(api.verifyCalls, isEmpty);
    });

    test('offline with a verifier it cannot check lets the child through',
        () async {
      await store.savePasscode(
        _kid,
        const HasPasscode(
          PasscodeVerifier(
            salt: _salt,
            verifier: _backendVerifier,
            algorithm: 'something-newer',
            imageSet: 'v1',
          ),
        ),
      );
      pairing.offline = true;
      expect(await service.check(_kid, [1, 2, 3]), isA<PasscodeAccepted>());
    });

    test('a passcode removed on the server is accepted and forgotten',
        () async {
      await store.savePasscode('k2', const HasPasscode(_verifier));
      final result = await service.check('k2', [1, 2, 3]);
      expect(result, isA<PasscodeAccepted>());
      expect(await store.passcodeFor('k2'), isA<NoPasscode>());
    });

    test('too many tries says so, and is not a wrong answer', () async {
      api.rateLimited = true;
      expect(await service.check(_kid, [4, 0, 7]), isA<PasscodeTooManyTries>());
    });

    test('saving needs the server, and caches what it returns', () async {
      expect(await service.save('k2', [1, 2, 3]), isTrue);
      expect(api.saves.single.$1, 'access-tok-k2');
      expect(api.saves.single.$2, [1, 2, 3]);
      expect(await service.isRequired('k2'), isTrue);

      pairing.offline = true;
      expect(await service.save('k2', [3, 2, 1]), isFalse);
      expect(api.saves, hasLength(1));
    });

    test('clearing makes choosing the kid a tap again', () async {
      await service.syncAll();
      expect(await service.clear(_kid), isTrue);
      expect(await service.isRequired(_kid), isFalse);
    });
  });

  group('screens', () {
    late SessionStore store;
    late _PasscodeApi api;
    late ProviderContainer c;

    Future<void> setUpWith(WidgetTester tester) async {
      // A tablet in portrait: the whole pad fits without scrolling.
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store = await _storeWith([('k1', 'Yelhan'), ('k2', 'Lina')]);
      await store.setActiveKid('k1');
      api = _PasscodeApi()
        ..codes['access-tok-k2'] = (
          [2, 5, 8],
          const PasscodeVerifier(
            salt: 's',
            verifier: 'x',
            algorithm: 'hmac-sha256-v1',
            imageSet: 'v1',
          ),
        );
      await store.savePasscode('k2', HasPasscode(api.codes['access-tok-k2']!.$2));
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      c = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          pairingApiProvider.overrideWithValue(_PairingApi()),
          passcodeApiProvider.overrideWithValue(api),
          sessionAutoRefreshProvider.overrideWithValue(false),
          localDatabaseProvider.overrideWithValue(db),
          recoveryRetriesProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.notifier).restore();
    }

    testWidgets('a kid with a code taps it before playing as them',
        (tester) async {
      await setUpWith(tester);
      await tester.pumpWidget(_app(c, const WhoIsPlayingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('who-kid-k2')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.fr.passcodeIsItYou('Lina')), findsOneWidget);
      expect(find.text(Strings.fr.notMe), findsOneWidget);

      // Wrong: a message, the slots empty again, and still Yelhan.
      await _tapPictures(tester, [8, 5, 2]);
      expect(find.text(Strings.fr.passcodeWrong), findsOneWidget);
      expect(find.byKey(const ValueKey('passcode-slot-1-8')), findsNothing);
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');

      await _tapPictures(tester, [2, 5, 8]);
      expect(c.read(sessionControllerProvider).kid!.id, 'k2');
      // The verified token is used as is, not refreshed again.
      expect(c.read(sessionControllerProvider).accessToken, 'verified');
    });

    testWidgets('"Ce n\'est pas moi" goes back and switches nobody',
        (tester) async {
      await setUpWith(tester);
      await tester.pumpWidget(_app(c, const WhoIsPlayingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('who-kid-k2')));
      await tester.pumpAndSettle();
      await _tapPictures(tester, [2]);
      await tester.tap(find.byKey(const ValueKey('passcode-not-me')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.fr.whoIsPlaying), findsOneWidget);
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');
    });

    testWidgets('a picture already picked can\'t be picked twice, and undo '
        'takes the last one back', (tester) async {
      await setUpWith(tester);
      await tester.pumpWidget(
        _app(c, PasscodeEntryScreen(kid: (await store.pairedKids()).last)),
      );
      await tester.pumpAndSettle();

      await _tapPictures(tester, [2, 2]);
      expect(find.byKey(const ValueKey('passcode-slot-1-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('passcode-slot-2-2')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('passcode-undo')));
      await tester.pump();
      expect(find.byKey(const ValueKey('passcode-slot-1-2')), findsNothing);
      expect(api.verifyCalls, isEmpty);
    });

    for (final reduce in [false, true]) {
      testWidgets(
          reduce
              ? 'with reduced motion a wrong try doesn\'t shake'
              : 'a wrong try shakes the slots', (tester) async {
        await setUpWith(tester);
        final kid = (await store.pairedKids()).last;
        await tester.pumpWidget(
          _app(c, PasscodeEntryScreen(kid: kid), reduceMotion: reduce),
        );
        await tester.pumpAndSettle();
        for (final i in [8, 5, 2]) {
          await tester.tap(find.byKey(ValueKey('passcode-picture-$i')));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text(Strings.fr.passcodeWrong), findsOneWidget);
        final shake = tester.widget<Transform>(
          find
              .descendant(
                of: find.byKey(const ValueKey('passcode-shake-1')),
                matching: find.byType(Transform),
              )
              .first,
        );
        final dx = shake.transform.getTranslation().x;
        expect(dx == 0, reduce);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('in English', (tester) async {
      await setUpWith(tester);
      final kid = (await store.pairedKids()).last;
      await tester.pumpWidget(
        _app(c, PasscodeEntryScreen(kid: kid), locale: 'en'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Is that you, Lina?'), findsOneWidget);
      expect(find.text(Strings.en.passcodePrompt), findsOneWidget);
      expect(find.text(Strings.en.notMe), findsOneWidget);
    });

    testWidgets('the guardian picks three, confirms them, and it is saved',
        (tester) async {
      await setUpWith(tester);
      await tester.pumpWidget(_app(c, const PasscodesScreen()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('passcode-state-k1'))).data,
        Strings.fr.passcodeNotSet,
      );

      await tester.tap(find.byKey(const ValueKey('passcode-set-k1')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.fr.passcodeSetupPick), findsOneWidget);

      await _tapPictures(tester, [0, 3, 6]);
      expect(find.text(Strings.fr.passcodeSetupConfirm), findsOneWidget);
      // A different order starts over.
      await _tapPictures(tester, [6, 3, 0]);
      expect(find.text(Strings.fr.passcodeSetupMismatch), findsOneWidget);
      expect(find.text(Strings.fr.passcodeSetupPick), findsOneWidget);
      expect(api.saves, isEmpty);

      await _tapPictures(tester, [0, 3, 6]);
      await _tapPictures(tester, [0, 3, 6]);
      // Past the "Code enregistré" toast.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(api.saves.single.$1, 'access-tok-k1');
      expect(api.saves.single.$2, [0, 3, 6]);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('passcode-state-k1'))).data,
        Strings.fr.passcodeIsSet,
      );
    });

    testWidgets('a save that can\'t reach the server says so', (tester) async {
      await setUpWith(tester);
      api.saveFails = true;
      final kid = (await store.pairedKids()).first;
      await tester.pumpWidget(_app(c, PasscodeSetupScreen(kid: kid)));
      await tester.pumpAndSettle();
      await _tapPictures(tester, [1, 4, 7]);
      await _tapPictures(tester, [1, 4, 7]);
      expect(find.text(Strings.fr.passcodeNeedsInternet), findsOneWidget);
      expect(await store.passcodeFor('k1'), isNull);
    });
  });
}
