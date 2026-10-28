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
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/no_seat_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_screen.dart';

const _seat = {'detail': "Demande à un parent de t'ajouter.", 'code': 'seat_required'};

class _Canned implements HttpClientAdapter {
  _Canned(this.status, this.body);
  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

PairingApi _answering(int status, Object body) => PairingApi(
  dio: Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = _Canned(status, body),
);

/// Refresh answers in order; the last repeats.
class _Api extends PairingApi {
  _Api(this.answers) : super(dio: Dio());
  final List<RefreshResult> answers;
  int calls = 0;
  PairingResult exchange = const PairingNoSeat();

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    final a = answers[calls.clamp(0, answers.length - 1)];
    calls++;
    return a;
  }

  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async => exchange;
}

const _ok = RefreshSucceeded(accessToken: 'fresh', expiresIn: 900);

Future<SessionStore> _store(List<String> ids) async {
  final store = SessionStore();
  for (final id in ids) {
    await store.savePairing(
      deviceToken: 'tok-$id',
      kidId: id,
      kidDisplayName: id,
      gradeLevel: 1,
    );
  }
  return store;
}

ProviderContainer _container(SessionStore store, PairingApi api) {
  final db = LocalDatabase.memory();
  final c = ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      sessionAutoRefreshProvider.overrideWithValue(false),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
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

  group('PairingApi reads seat_required', () {
    test('a refresh refused for no seat is not a lost pairing', () async {
      expect(
        await _answering(403, _seat).refresh(deviceToken: 'd'),
        isA<RefreshNoSeat>(),
      );
      expect(
        await _answering(403, {'detail': 'x'}).refresh(deviceToken: 'd'),
        isA<RefreshFailed>(),
        reason: 'only the exact code means no seat',
      );
    });

    test('a good code for a kid with no seat says so', () async {
      expect(
        await _answering(403, _seat).exchangeCode(
          code: 'ABC234',
          deviceId: 'd',
          platform: 'linux',
          appVersion: '0',
        ),
        isA<PairingNoSeat>(),
      );
    });
  });

  group('SessionController', () {
    test('no seat at launch: paired, no token, the pairing kept', () async {
      final store = await _store(['lea']);
      final c = _container(store, _Api([const RefreshNoSeat()]));
      await c.read(sessionControllerProvider.notifier).restore();
      final s = c.read(sessionControllerProvider);
      expect(s.status, SessionStatus.paired);
      expect(s.noSeat, isTrue);
      expect(s.accessToken, isNull);
      expect(s.kid!.id, 'lea');
      expect(await store.deviceToken(), 'tok-lea', reason: 'kept for later');
    });

    test('a seat back: the next check lets them in', () async {
      final api = _Api([const RefreshNoSeat(), _ok]);
      final c = _container(await _store(['lea']), api);
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.restore();
      await ctrl.ensureFreshToken();
      final s = c.read(sessionControllerProvider);
      expect(s.noSeat, isFalse);
      expect(s.accessToken, 'fresh');
    });

    test('a seat gone mid-session: one 403 moves the state', () async {
      final api = _Api([_ok, const RefreshNoSeat()]);
      final c = _container(await _store(['lea']), api);
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.restore();
      expect(c.read(sessionControllerProvider).noSeat, isFalse);
      ctrl.onSeatRequired();
      ctrl.onSeatRequired(); // a burst of 403s shares one refresh
      await ctrl.ensureFreshToken();
      expect(c.read(sessionControllerProvider).noSeat, isTrue);
      expect(api.calls, 2);
    });

    test('coming back to the app checks again', () async {
      final api = _Api([const RefreshNoSeat(), _ok]);
      final c = _container(await _store(['lea']), api);
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.restore();
      ctrl.noteBack(DateTime.now());
      await ctrl.ensureFreshToken();
      expect(c.read(sessionControllerProvider).noSeat, isFalse);
    });

    test('switching to a kid with no seat', () async {
      final api = _Api([_ok, const RefreshNoSeat()]);
      final c = _container(await _store(['lea', 'noah']), api);
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.restore();
      await ctrl.switchTo('noah');
      final s = c.read(sessionControllerProvider);
      expect(s.kid!.id, 'noah');
      expect(s.noSeat, isTrue);
      expect(s.accessToken, isNull);
    });

    test('pairing a kid with no seat is its own error, not a bad code', () async {
      final c = _container(SessionStore(), _Api([_ok]));
      await c.read(sessionControllerProvider.notifier).restore();
      expect(
        await c.read(sessionControllerProvider.notifier).pair('ABC234'),
        PairingError.noSeat,
      );
    });
  });

  group('the Dio check', () {
    test('a kid call answered seat_required asks the session to check', () async {
      final api = _Api([_ok, const RefreshNoSeat()]);
      final c = _container(await _store(['lea']), api);
      await c.read(sessionControllerProvider.notifier).restore();
      final dio = c.read(dioProvider)..httpClientAdapter = _Canned(403, _seat);
      await expectLater(
        dio.get<Object>(
          '/api/v1/me/progress',
          options: Options(headers: {'Authorization': 'Bearer fresh'}),
        ),
        throwsA(isA<DioException>()),
      );
      await c.read(sessionControllerProvider.notifier).ensureFreshToken();
      expect(c.read(sessionControllerProvider).noSeat, isTrue);
    });

    test('an unauthenticated call (exchange, refresh) never does', () async {
      final api = _Api([_ok]);
      final c = _container(await _store(['lea']), api);
      await c.read(sessionControllerProvider.notifier).restore();
      final dio = c.read(dioProvider)..httpClientAdapter = _Canned(403, _seat);
      await expectLater(
        dio.post<Object>('/api/v1/pairing/exchange', data: {}),
        throwsA(isA<DioException>()),
      );
      expect(api.calls, 1, reason: 'no extra refresh');
    });
  });

  group('the screens', () {
    testWidgets('asks a parent, never mentions money, retries', (tester) async {
      final api = _Api([const RefreshNoSeat(), _ok]);
      final c = _container(await _store(['lea']), api);
      await c.read(sessionControllerProvider.notifier).restore();
      await tester.pumpWidget(_app(c, const NoSeatScreen()));
      await tester.pump();

      expect(find.text(fr.noSeatTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('no-seat-who')), findsNothing);
      for (final t in [fr, Strings.en]) {
        expect(
          '${t.noSeatTitle} ${t.noSeatBody} ${t.pairingNoSeat}'.toLowerCase(),
          isNot(matches(RegExp(r'\$|prix|price|plan|abonnement|subscri|pay|achet|buy'))),
        );
      }

      await tester.tap(find.byKey(const ValueKey('no-seat-retry')));
      await tester.pump();
      await tester.pump();
      expect(c.read(sessionControllerProvider).noSeat, isFalse);
    });

    testWidgets('with siblings, one of them can play meanwhile', (tester) async {
      final api = _Api([const RefreshNoSeat()]);
      final c = _container(await _store(['lea', 'noah']), api);
      await c.read(sessionControllerProvider.notifier).restore();
      await tester.pumpWidget(_app(c, const NoSeatScreen()));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('no-seat-who')));
      await tester.pump();
      expect(c.read(sessionControllerProvider).stage, ProfileStage.choosing);
    });

    testWidgets('the pairing screen says "ask a parent" for no seat', (
      tester,
    ) async {
      final c = _container(SessionStore(), _Api([_ok]));
      await c.read(sessionControllerProvider.notifier).restore();
      await tester.pumpWidget(_app(c, const PairingScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'ABC234');
      await tester.pumpAndSettle();
      expect(find.text(fr.pairingNoSeat), findsOneWidget);

      // Amber, never red: the design's "almost" state, for a child.
      final amber = VillagePalette.light.retry;
      expect(tester.widget<Text>(find.text(fr.pairingNoSeat)).style?.color, amber);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        amber,
      );
      final digit = tester.widget<Text>(find.text('A'));
      expect(digit.style?.color, amber);
    });
  });
}
