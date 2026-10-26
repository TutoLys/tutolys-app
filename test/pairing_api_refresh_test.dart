import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';

/// Answers every request with one canned status and body.
class _Canned implements HttpClientAdapter {
  _Canned(this.status, this.body);

  final int status;
  final Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// A refresh 401 names its reason only when the body says exactly
/// `revoked`, `archived` or `erased` (ADR 0037). Anything else is bare, so
/// the app keeps the kid's local data.
void main() {
  Future<RefreshResult> refreshWith(int status, Object? body) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _Canned(status, body);
    return PairingApi(dio: dio).refresh(deviceToken: 'tok');
  }

  for (final reason in RejectionReason.values) {
    test('a 401 with reason "${reason.name}" carries it', () async {
      final result = await refreshWith(401, {
        'detail': 'x',
        'reason': reason.name,
      });
      expect((result as RefreshRejected).reason, reason);
    });
  }

  for (final body in <Object?>[
    null,
    {'detail': 'Invalid token.'},
    {'reason': 'expired'},
    {'reason': 'REVOKED'},
    {'reason': 1},
    'not json object',
  ]) {
    test('a 401 with body $body is bare', () async {
      final result = await refreshWith(401, body);
      expect(result, isA<RefreshRejected>());
      expect((result as RefreshRejected).reason, isNull);
    });
  }
}
