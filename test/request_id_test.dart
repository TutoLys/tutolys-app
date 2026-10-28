import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/diagnostics/diag_log.dart';
import 'package:tutolys_app/core/diagnostics/request_id.dart';

/// Answers every request with [status] (or a connection error when null),
/// and keeps the last request's headers.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int? status;
  Map<String, dynamic>? lastHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = Map.of(options.headers);
    if (status == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      status!,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  var n = 0;
  String id() => 'id-${++n}';

  (Dio, _Adapter, DiagLog) make(int? status, {bool sendHeader = true}) {
    final log = DiagLog();
    final adapter = _Adapter(status);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        RequestIdInterceptor(
          service: 'api',
          log: log,
          sendHeader: sendHeader,
          newId: id,
        ),
      );
    return (dio, adapter, log);
  }

  test('every request carries a fresh X-Request-ID', () async {
    final (dio, adapter, log) = make(200);
    await dio.get<Object>('/api/v1/me/progress');
    final first = adapter.lastHeaders![RequestIdInterceptor.header];
    await dio.get<Object>('/api/v1/me/progress');
    final second = adapter.lastHeaders![RequestIdInterceptor.header];
    expect(first, isNotNull);
    expect(second, isNot(first));
    expect(log.entries, isEmpty, reason: 'a success records nothing');
  });

  test('the real ids are uuid v4', () async {
    final log = DiagLog();
    final adapter = _Adapter(200);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        RequestIdInterceptor(service: 'api', log: log, sendHeader: true),
      );
    await dio.get<Object>('/x');
    expect(
      adapter.lastHeaders![RequestIdInterceptor.header],
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('a failure lands in the diag log: method, path, status, id', () async {
    final (dio, adapter, log) = make(500);
    await expectLater(
      dio.get<Object>('/api/v1/me/progress?kid=secret&token=abc'),
      throwsA(isA<DioException>()),
    );
    final sent = adapter.lastHeaders![RequestIdInterceptor.header] as String;
    final entry = log.entries.single;
    expect(entry.kind, 'http:api');
    expect(entry.type, 'HttpStatus');
    expect(entry.message, 'GET /api/v1/me/progress → 500 · request_id $sent');
    expect(entry.message, isNot(contains('secret')), reason: 'no query');
    expect(RequestIdInterceptor.lastFailedId, sent);
  });

  test('a transport error is recorded with its type and no status', () async {
    final (dio, _, log) = make(null);
    await expectLater(
      dio.post<Object>('/api/v1/pairing/exchange', data: {'code': 'ABC234'}),
      throwsA(isA<DioException>()),
    );
    final entry = log.entries.single;
    expect(entry.type, 'DioException.connectionError');
    expect(entry.message, startsWith('POST /api/v1/pairing/exchange → no response'));
    expect(entry.message, isNot(contains('ABC234')), reason: 'no bodies');
  });

  test('without the header (web, before CORS allows it) the id is still '
      'recorded', () async {
    final (dio, adapter, log) = make(404, sendHeader: false);
    await expectLater(dio.get<Object>('/x'), throwsA(isA<DioException>()));
    expect(adapter.lastHeaders!.containsKey(RequestIdInterceptor.header), isFalse);
    expect(log.entries.single.message, contains('request_id id-'));
  });
}
