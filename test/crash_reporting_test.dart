import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:tutolys_app/core/diagnostics/crash_reporting.dart';
import 'package:tutolys_app/core/diagnostics/diag_log.dart';
import 'package:tutolys_app/core/diagnostics/request_id.dart';

const _dsn = 'http://key@127.0.0.1:8084/3';
const _jwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJraWQifQ.c2lnbmF0dXJlLXNpZ25hdHVyZQ';

void main() {
  group('off unless built with a DSN', () {
    test('no DSN: init is never called and nothing is forwarded', () async {
      var calls = 0;
      final log = DiagLog();
      await startCrashReporting(
        dsn: '',
        log: log,
        init: (_) async => calls++,
      );
      expect(calls, 0);
      expect(log.reporter, isNull);
    });

    test('the build itself has no DSN unless one is defined', () {
      expect(sentryDsn, isEmpty);
    });

    test('with a DSN: init runs, and the P1 hooks forward to it', () async {
      final log = DiagLog();
      SentryOptions? seen;
      await startCrashReporting(
        dsn: _dsn,
        log: log,
        init: (configure) async {
          final o = SentryOptions(dsn: _dsn);
          await configure(o);
          seen = o;
        },
      );
      expect(seen, isNotNull);
      expect(log.reporter, isNotNull);
    });
  });

  group('the options', () {
    late SentryOptions o;
    setUp(() {
      o = SentryOptions(dsn: _dsn);
      configureCrashReporting(o, dsn: _dsn);
    });

    test('no PII, no tracing, our scrubbers', () {
      expect(o.dsn, _dsn);
      expect(o.sendDefaultPii, isFalse);
      expect(o.tracesSampleRate, isNull);
      expect(o.beforeSend, same(scrubCrashReport));
      expect(o.beforeBreadcrumb, same(filterBreadcrumb));
      expect(o.release, startsWith('tutolys-app@'));
    });

    test("Sentry's own isolate hook is removed: one set of hooks", () {
      final withIt = SentryOptions(dsn: _dsn)
        ..addIntegration(IsolateErrorIntegration());
      configureCrashReporting(withIt, dsn: _dsn);
      expect(withIt.integrations.whereType<IsolateErrorIntegration>(), isEmpty);
    });
  });

  group('beforeSend', () {
    test('strips a JWT, an email and the user; drops the request', () {
      final event = SentryEvent(
        message: SentryMessage('login failed for lea@example.com with $_jwt'),
        exceptions: [
          SentryException(type: 'StateError', value: 'Bearer $_jwt'),
        ],
        user: SentryUser(id: 'kid-123'),
        request: SentryRequest(url: 'http://api.test/x?kid=1'),
        serverName: 'leas-laptop',
      );
      final out = scrubCrashReport(event, Hint())!;
      expect(out.user, isNull);
      expect(out.request, isNull);
      expect(out.serverName, isNull);
      expect(out.message!.formatted, isNot(contains('@example.com')));
      expect(out.message!.formatted, isNot(contains('eyJ')));
      expect(out.exceptions!.single.value, isNot(contains('eyJ')));
    });

    test('a pairing code in an error is scrubbed', () {
      final event = SentryEvent(
        exceptions: [SentryException(type: 'X', value: 'code K7M2QX refused')],
      );
      expect(
        scrubCrashReport(event, Hint())!.exceptions!.single.value,
        isNot(contains('K7M2QX')),
      );
    });

    test('carries the last failed request id as a tag', () {
      RequestIdInterceptor.lastFailedId = 'abc-123';
      addTearDown(() => RequestIdInterceptor.lastFailedId = null);
      final out = scrubCrashReport(SentryEvent(), Hint())!;
      expect(out.tags!['request_id'], 'abc-123');
    });
  });

  group('beforeBreadcrumb', () {
    test('drops console and log breadcrumbs', () {
      expect(
        filterBreadcrumb(Breadcrumb(category: 'console', message: 'Léa'), Hint()),
        isNull,
      );
      expect(filterBreadcrumb(Breadcrumb(category: 'ui.click'), Hint()), isNull);
      expect(filterBreadcrumb(Breadcrumb.console(message: 'x'), Hint()), isNull);
    });

    test('an HTTP breadcrumb keeps method, path and status only', () {
      final crumb = filterBreadcrumb(
        Breadcrumb.http(
          url: Uri.parse('http://api.test/api/v1/me/progress?kid=1#f'),
          method: 'GET',
          statusCode: 500,
          requestBodySize: 12,
        ),
        Hint(),
      )!;
      expect(crumb.data, {
        'url': '/api/v1/me/progress',
        'method': 'GET',
        'status_code': 500,
      });
    });

    test('a navigation breadcrumb keeps route names only', () {
      final crumb = filterBreadcrumb(
        Breadcrumb(
          category: 'navigation',
          message: 'Léa opened the map',
          data: {'from': '/village', 'to': '/carte', 'arguments': 'kid-1'},
        ),
        Hint(),
      )!;
      expect(crumb.message, isNull);
      expect(crumb.data, {'from': '/village', 'to': '/carte'});
    });
  });

  group('the P1 hooks', () {
    test('forward uncaught errors only, not caught or HTTP ones', () {
      final log = DiagLog();
      final got = <Object>[];
      log.reporter = (e, _) => got.add(e);
      log.record('flutter', StateError('a'));
      log.record('platform', StateError('b'));
      log.record('zone', StateError('c'));
      log.record('caught:sync', StateError('d'));
      log.recordRequestFailure(
        service: 'api',
        method: 'GET',
        path: '/x',
        status: 500,
        requestId: 'r',
        errorType: 'HttpStatus',
      );
      expect(got.map((e) => '$e'), [
        'Bad state: a',
        'Bad state: b',
        'Bad state: c',
      ]);
      expect(log.entries, hasLength(5), reason: 'all still logged locally');
    });

    test('a failing reporter never breaks the hooks', () {
      final log = DiagLog()..reporter = (_, _) => throw Exception('down');
      expect(() => log.record('zone', StateError('x')), returnsNormally);
      expect(log.entries, hasLength(1));
    });
  });
}
