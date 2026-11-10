import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/weather_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/home/village3d/village_weather.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';

/// The real weather in the 3D village (ADR 0126, Hafid: "we need to follow
/// the real weather").
class _Canned implements HttpClientAdapter {
  _Canned(this.status, [this.body]);
  int status;
  Object? body;
  var calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Session extends SessionController {
  _Session([this.kid = 'lea']);
  final String kid;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.paired,
    accessToken: 'token',
    kid: PairedKid(id: kid, displayName: 'x', gradeLevel: 1),
  );
}

const _snow = {
  'condition': 'snow',
  'temp_c': -4.5,
  'is_day': true,
  'region': 'montreal',
  'observed_at': '2026-11-10T11:00:00Z',
};

WeatherApi _api(_Canned adapter) => WeatherApi(
  dio: Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter,
);

void main() {
  group('the endpoint', () {
    test('an observation becomes the bridge object, region left out', () async {
      final w = await _api(_Canned(200, _snow)).fetch(accessToken: 't');
      expect(w!.toJson(), {
        'condition': 'snow',
        'temp_c': -4.5,
        'observed_at': '2026-11-10T11:00:00Z',
        'is_day': true,
      });
    });

    test('204, 404, offline or a bad body: nothing new', () async {
      expect(await _api(_Canned(204)).fetch(accessToken: 't'), isNull);
      expect(
        await _api(_Canned(404, {'detail': 'x'})).fetch(accessToken: 't'),
        isNull,
      );
      expect(await _api(_Canned(0)).fetch(accessToken: 't'), isNull);
      expect(
        await _api(_Canned(200, {'condition': 'snow'})).fetch(accessToken: 't'),
        isNull,
        reason: 'no observed_at: the scene could not judge freshness',
      );
      expect(
        await _api(_Canned(200, {'condition': 1, 'observed_at': 'x'}))
            .fetch(accessToken: 't'),
        isNull,
      );
    });
  });

  group('the held value', () {
    late _Canned adapter;
    late LocalDatabase db;

    ProviderContainer container({String kid = 'lea'}) {
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(() => _Session(kid)),
          weatherApiProvider.overrideWithValue(_api(adapter)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      adapter = _Canned(200, _snow);
      db = LocalDatabase.memory();
      addTearDown(db.close);
    });

    test('a fetch is kept, and survives the next launch offline', () async {
      final first = container();
      first.read(villageWeatherProvider);
      await first.read(villageWeatherProvider.notifier).refresh();
      expect(first.read(villageWeatherProvider)?.condition, 'snow');

      adapter.status = 0;
      final next = container();
      next.read(villageWeatherProvider);
      await pumpEventQueue();
      expect(next.read(villageWeatherProvider)?.condition, 'snow');
    });

    test('nothing new keeps what it had', () async {
      final c = container();
      c.read(villageWeatherProvider);
      final weather = c.read(villageWeatherProvider.notifier);
      await weather.refresh(now: DateTime(2026, 11, 10, 8));
      adapter.status = 204;
      await weather.refresh(now: DateTime(2026, 11, 10, 9));
      expect(c.read(villageWeatherProvider)?.condition, 'snow');
    });

    test('opening the Village again soon does not ask again', () async {
      final c = container();
      c.read(villageWeatherProvider);
      final weather = c.read(villageWeatherProvider.notifier);
      await weather.refresh(now: DateTime(2026, 11, 10, 8));
      await weather.refresh(now: DateTime(2026, 11, 10, 8, 5));
      expect(adapter.calls, 1);
      await weather.refresh(now: DateTime(2026, 11, 10, 8, 11));
      expect(adapter.calls, 2);
    });

    test('per kid: a sibling does not get it', () async {
      final lea = container();
      lea.read(villageWeatherProvider);
      await lea.read(villageWeatherProvider.notifier).refresh();
      final sam = container(kid: 'sam');
      sam.read(villageWeatherProvider);
      await pumpEventQueue();
      expect(sam.read(villageWeatherProvider), isNull);
    });
  });

  group('the poller', () {
    late _Canned adapter;

    Widget poller({bool visible = true, bool enabled = true}) => ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
        sessionControllerProvider.overrideWith(_Session.new),
        weatherApiProvider.overrideWithValue(_api(adapter)),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Visibility(
          visible: visible,
          maintainState: true,
          child: VillageWeatherPoller(
            enabled: enabled,
            child: const SizedBox(),
          ),
        ),
      ),
    );

    setUp(() => adapter = _Canned(200, _snow));

    testWidgets('asks on show, then every 30 minutes while shown', (
      tester,
    ) async {
      await tester.pumpWidget(poller());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(adapter.calls, 1);
      await tester.pump(villageWeatherEvery);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(adapter.calls, 2);
    });

    testWidgets('asks nothing while hidden or where no 3D shows', (
      tester,
    ) async {
      await tester.pumpWidget(poller(visible: false));
      await tester.pump(villageWeatherEvery * 2);
      expect(adapter.calls, 0);
      await tester.pumpWidget(poller(enabled: false));
      await tester.pump(villageWeatherEvery * 2);
      expect(adapter.calls, 0);
    });
  });
}
