import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sentry/sentry.dart' show Breadcrumb, Sentry;
import 'package:uuid/uuid.dart';

import 'diag_log.dart';

/// Whether the web build sends `X-Request-ID`.
///
/// A custom header makes the browser preflight every request, and until both
/// services list `X-Request-ID` in their CORS allow-list (work order P2,
/// B1/T1) that preflight fails and every request with it. So the web build
/// sends it only when built with `--dart-define=TUTOLYS_REQUEST_ID_ON_WEB=true`.
/// The id is still made and recorded locally either way (ADR 0052).
const requestIdOnWeb = bool.fromEnvironment('TUTOLYS_REQUEST_ID_ON_WEB');

/// Gives every request a fresh `X-Request-ID` (uuid v4), and records each
/// failure to the on-device diag log: method, path without its query, status,
/// the id and the error type. No bodies, no headers (work order P2, A1).
///
/// One per Dio instance: [service] says which (`api` or `telemetry`).
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({
    required this.service,
    DiagLog? log,
    bool? sendHeader,
    String Function()? newId,
  }) : _log = log, // ignore: prefer_initializing_formals
       sendHeader = sendHeader ?? (!kIsWeb || requestIdOnWeb),
       _newId = newId ?? const Uuid().v4;

  static const header = 'X-Request-ID';
  static const _extraKey = 'request_id';

  final String service;
  final bool sendHeader;
  final DiagLog? _log;
  final String Function() _newId;

  /// The id of the last request that failed, app-wide: crash reports carry
  /// it as a tag, so a crash can be matched to the server's log line.
  static String? lastFailedId;

  DiagLog get _diag => _log ?? DiagLog.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _newId();
    options.extra[_extraKey] = id;
    if (sendHeader) options.headers[header] = id;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final status = response.statusCode;
    if (status != null && status >= 400) {
      // Only reached when a caller accepts 4xx/5xx as a response.
      _fail(o, status, 'HttpStatus');
    } else {
      _breadcrumb(o, status);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _fail(
      err.requestOptions,
      status,
      status == null ? 'DioException.${err.type.name}' : 'HttpStatus',
    );
    handler.next(err);
  }

  void _fail(RequestOptions o, int? status, String errorType) {
    final id = o.extra[_extraKey] as String?;
    lastFailedId = id;
    _diag.recordRequestFailure(
      service: service,
      method: o.method,
      path: o.uri.path,
      status: status,
      requestId: id,
      errorType: errorType,
    );
    _breadcrumb(o, status);
  }

  /// For crash reports: method, path and status only. A no-op when crash
  /// reporting is off.
  static void _breadcrumb(RequestOptions o, int? status) {
    if (!Sentry.isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb.http(
        url: Uri(path: o.uri.path),
        method: o.method,
        statusCode: status,
      ),
    );
  }
}
