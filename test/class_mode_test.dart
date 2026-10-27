import 'dart:convert';
import 'dart:typed_data';

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
import 'package:tutolys_app/features/pairing/pairing_screen.dart';
import 'package:tutolys_app/features/pairing/who_is_playing_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_entry_screen.dart';
import 'package:tutolys_app/features/passcode/passcode_service.dart';

/// Answers one request with a canned status and JSON body.
class _Canned implements HttpClientAdapter {
  _Canned(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PairingApi _apiAnswering(int status, Object body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = _Canned(status, body);
  return PairingApi(dio: dio);
}

const _classroom = Classroom(
  classId: 'c1',
  className: '1re année B',
  organizationName: 'École des Pins',
);

ClassKid _kid(String id, String name, {bool hasPasscode = true}) => ClassKid(
      kidId: id,
      displayName: name,
      gradeLevel: 1,
      deviceToken: 'tok-$id',
      hasPasscode: hasPasscode,
    );

/// Class exchange and refresh, scriptable per test.
class _Api extends PairingApi {
  _Api() : super(dio: Dio());

  PairingResult classResult = ClassPairingSucceeded(
    classroom: _classroom,
    kids: [_kid('k1', 'Amira'), _kid('k2', 'Noé', hasPasscode: false)],
  );
  final rejected = <String>{};
  String? lastClassCode;

  @override
  Future<PairingResult> exchangeClassCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    lastClassCode = code;
    return classResult;
  }

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async =>
      rejected.contains(deviceToken)
          ? const RefreshRejected(reason: RejectionReason.revoked)
          : RefreshSucceeded(accessToken: 'access-$deviceToken', expiresIn: 900);
}

/// Amira's code is the coin, the bell, the target; Noé has none.
class _PasscodeApi extends PasscodeApi {
  _PasscodeApi() : super(dio: Dio());

  final codes = <String, List<int>>{'access-tok-k1': [2, 3, 4]};

  static const _v = PasscodeVerifier(
    salt: 's',
    verifier: 'v',
    algorithm: 'hmac-sha256-v1',
    imageSet: 'v1',
  );

  @override
  Future<PasscodeState?> fetch({required String accessToken}) async =>
      codes.containsKey(accessToken) ? const HasPasscode(_v) : const NoPasscode();

  @override
  Future<PasscodeVerifyResult> verify({
    required String accessToken,
    required List<int> sequence,
  }) async {
    final code = codes[accessToken];
    if (code == null) return const PasscodeNotSet();
    return code.join() == sequence.join()
        ? const PasscodeVerified(accessToken: 'verified', expiresIn: 900)
        : const PasscodeWrong();
  }
}

ProviderContainer _container(SessionStore store, _Api api, LocalDatabase db) {
  final c = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      passcodeApiProvider.overrideWithValue(_PasscodeApi()),
      sessionAutoRefreshProvider.overrideWithValue(false),
      localDatabaseProvider.overrideWithValue(db),
      recoveryRetriesProvider.overrideWithValue(false),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
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
        home: home,
      ),
    );

void main() {
  final fr = Strings.fr;

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('PairingApi.exchangeClassCode', () {
    test('reads the class and one pairing per learner', () async {
      final api = _apiAnswering(200, {
        'mode': 'class',
        'class_id': 'c1',
        'class_name': '1re année B',
        'organization_name': 'École des Pins',
        'passcode_required': true,
        'kids': [
          {
            'kid_id': 'k1',
            'display_name': 'Amira',
            'grade_level': 1,
            'avatar_key': 'lea',
            'sex': 'girl',
            'has_passcode': true,
            'device_token': 'dt1',
            'access_token': 'at1',
            'expires_in': 900,
          },
        ],
      });
      final result = await api.exchangeClassCode(
        code: 'ABC234',
        deviceId: 'd',
        platform: 'linux',
        appVersion: '0',
      );
      result as ClassPairingSucceeded;
      expect(result.classroom.className, '1re année B');
      expect(result.kids.single.deviceToken, 'dt1');
      expect(result.kids.single.hasPasscode, isTrue);
      expect(result.kids.single.avatarKey, 'lea');
    });

    test('names an empty class, a school that is not entitled, a bad code',
        () async {
      Future<PairingResult> answer(int status, Object body) =>
          _apiAnswering(status, body).exchangeClassCode(
            code: 'X',
            deviceId: 'd',
            platform: 'linux',
            appVersion: '0',
          );
      expect(
        await answer(400, {'detail': 'x', 'code': 'empty_class'}),
        isA<ClassIsEmpty>(),
      );
      expect(
        await answer(403, {'detail': 'x', 'code': 'organization_not_entitled'}),
        isA<ClassNotEntitled>(),
      );
      expect(await answer(400, {'detail': 'x'}), isA<PairingCodeRejected>());
    });
  });

  group('SessionStore class pairings', () {
    test('adds every learner, marks the class, and caches "no passcode"',
        () async {
      final store = SessionStore();
      await store.saveClassPairings(
        _classroom,
        [_kid('k1', 'Amira'), _kid('k2', 'Noé', hasPasscode: false)],
      );
      expect([for (final k in await store.pairedKids()) k.id], ['k1', 'k2']);
      expect((await store.classroom())!.className, '1re année B');
      expect(await store.passcodeFor('k1'), isNull);
      expect(await store.passcodeFor('k2'), isA<NoPasscode>());
      expect(await store.deviceTokenFor('k2'), 'tok-k2');

      // The last learner gone, the tablet is no class's any more.
      await store.clearPairing();
      await store.clearPairing();
      expect(await store.classroom(), isNull);
    });
  });

  group('SessionController', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    test('a class code opens "Qui joue ?" with nobody chosen', () async {
      final api = _Api();
      final c = _container(SessionStore(), api, db);
      final error =
          await c.read(sessionControllerProvider.notifier).pairClass('ABC234');
      expect(error, isNull);
      expect(api.lastClassCode, 'ABC234');
      final s = c.read(sessionControllerProvider);
      expect(s.status, SessionStatus.paired);
      expect(s.isClassroom, isTrue);
      expect(s.stage, ProfileStage.choosing);
      expect(s.mustConfirm, isTrue);
      expect(s.accessToken, isNull);
      expect(s.kids, hasLength(2));
    });

    test('class code failures map to their own errors', () async {
      final api = _Api();
      final c = _container(SessionStore(), api, db);
      final notifier = c.read(sessionControllerProvider.notifier);
      api.classResult = const ClassIsEmpty();
      expect(await notifier.pairClass('X'), PairingError.emptyClass);
      api.classResult = const ClassNotEntitled();
      expect(await notifier.pairClass('X'), PairingError.classNotEntitled);
      api.classResult = const PairingCodeRejected('no');
      expect(await notifier.pairClass('X'), PairingError.invalidCode);
      api.classResult = const PairingOffline();
      expect(await notifier.pairClass('X'), PairingError.offline);
    });

    test('a kid the school revoked is forgotten, and the picker asks everyone',
        () async {
      final store = SessionStore();
      await store.saveClassPairings(
        _classroom,
        [_kid('k1', 'Amira'), _kid('k2', 'Noé'), _kid('k3', 'Léo')],
      );
      await store.setActiveKid('k1');
      final api = _Api()..rejected.add('tok-k1');
      final c = _container(store, api, db);
      await c.read(sessionControllerProvider.notifier).restore();

      final s = c.read(sessionControllerProvider);
      expect([for (final k in s.kids) k.id], ['k2', 'k3']);
      expect(await store.deviceTokenFor('k1'), isNull);
      expect(s.stage, ProfileStage.choosing);
      expect(s.mustConfirm, isTrue);
    });

    group('back after a pause', () {
      Future<ProviderContainer> paired(List<String> kids,
          {bool classroom = false}) async {
        final store = SessionStore();
        if (classroom) {
          await store.saveClassPairings(
            _classroom,
            [for (final k in kids) _kid(k, k)],
          );
        } else {
          for (final k in kids) {
            await store.savePairing(
              deviceToken: 'tok-$k',
              kidId: k,
              kidDisplayName: k,
              gradeLevel: 1,
            );
          }
        }
        final c = _container(store, _Api(), db);
        final n = c.read(sessionControllerProvider.notifier);
        await n.restore();
        await n.switchTo(kids.first);
        return c;
      }

      final t0 = DateTime(2026, 10, 27, 9);

      test('a family device asks again after 10 minutes, not before',
          () async {
        final c = await paired(['a', 'b']);
        final n = c.read(sessionControllerProvider.notifier);
        n.noteAway(t0);
        n.noteBack(t0.add(const Duration(minutes: 9)));
        expect(c.read(sessionControllerProvider).stage, ProfileStage.none);

        n.noteAway(t0);
        n.noteBack(t0.add(const Duration(minutes: 10)));
        final s = c.read(sessionControllerProvider);
        expect(s.stage, ProfileStage.choosing);
        expect(s.confirmEveryone, isTrue);
      });

      test('a class tablet asks again after 2 minutes', () async {
        final c = await paired(['a', 'b'], classroom: true);
        final n = c.read(sessionControllerProvider.notifier);
        n.noteAway(t0);
        n.noteBack(t0.add(const Duration(minutes: 2)));
        expect(c.read(sessionControllerProvider).stage, ProfileStage.choosing);
      });

      test('one kid on a family device is never asked', () async {
        final c = await paired(['a']);
        final n = c.read(sessionControllerProvider.notifier);
        n.noteAway(t0);
        n.noteBack(t0.add(const Duration(hours: 3)));
        expect(c.read(sessionControllerProvider).stage, ProfileStage.none);
      });
    });
  });

  group('screens', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    Future<ProviderContainer> classTablet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _container(SessionStore(), _Api(), db);
      await c.read(sessionControllerProvider.notifier).pairClass('ABC234');
      return c;
    }

    testWidgets('the class picker names the class and has no way back',
        (tester) async {
      final c = await classTablet(tester);
      await tester.pumpWidget(_app(c, const WhoIsPlayingScreen()));
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsPlayingClass('1re année B')), findsOneWidget);
      expect(find.byKey(const ValueKey('who-back')), findsNothing);
      expect(find.byKey(const ValueKey('who-kid-k1')), findsOneWidget);
      expect(find.byKey(const ValueKey('who-kid-k2')), findsOneWidget);
    });

    testWidgets('every kid taps their code, even the "current" one',
        (tester) async {
      final c = await classTablet(tester);
      // k1 is the store's active kid, but nobody has said who they are.
      expect(c.read(sessionControllerProvider).kid!.id, 'k1');
      await tester.pumpWidget(_app(c, const WhoIsPlayingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('who-kid-k1')));
      await tester.pumpAndSettle();
      expect(find.byType(PasscodeEntryScreen), findsOneWidget);
      for (final i in [2, 3, 4]) {
        await tester.tap(find.byKey(ValueKey('passcode-picture-$i')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final s = c.read(sessionControllerProvider);
      expect(s.kid!.id, 'k1');
      expect(s.accessToken, 'verified');
      expect(s.stage, ProfileStage.none);
    });

    testWidgets('a kid with no code waits for an adult, and plays nobody\'s '
        'profile', (tester) async {
      final c = await classTablet(tester);
      await tester.pumpWidget(_app(c, const WhoIsPlayingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('who-kid-k2')));
      await tester.pumpAndSettle();
      expect(find.text(fr.passcodeWaitTitle('Noé')), findsOneWidget);
      expect(find.byKey(const ValueKey('passcode-wait-adult')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('passcode-not-me')));
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsPlaying), findsOneWidget);
      expect(c.read(sessionControllerProvider).stage, ProfileStage.choosing);
    });

    testWidgets('the pairing screen takes a class code', (tester) async {
      final api = _Api();
      final c = _container(SessionStore(), api, db);
      await c.read(sessionControllerProvider.notifier).restore();
      await tester.pumpWidget(_app(c, const PairingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing-mode')));
      await tester.pumpAndSettle();
      expect(find.text(fr.pairingClassTitle), findsOneWidget);
      expect(find.text(fr.pairingKidLink), findsOneWidget);

      api.classResult = const ClassNotEntitled();
      await tester.enterText(find.byType(EditableText).first, 'ABC234');
      await tester.pumpAndSettle();
      expect(api.lastClassCode, 'ABC234');
      expect(find.text(fr.pairingClassNotEntitled), findsOneWidget);

      // Back to a kid's code: the words change back.
      await tester.tap(find.byKey(const ValueKey('pairing-mode')));
      await tester.pumpAndSettle();
      expect(find.text(fr.pairingTitle), findsOneWidget);
      expect(find.text(fr.pairingClassNotEntitled), findsNothing);
    });
  });
}
