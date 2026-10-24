import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/startup/release_config_guard.dart';

void main() {
  group('assertReleaseConfigIsReal', () {
    test('does nothing outside release mode, however misconfigured', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: false,
          apiBaseUrl: 'http://127.0.0.1:8000',
          telemetryBaseUrl: 'http://127.0.0.1:8001',
        ),
        returnsNormally,
      );
    });

    test('does nothing in release mode when both URLs are real', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'https://api.tutolys.ca',
          telemetryBaseUrl: 'https://telemetry.tutolys.ca',
        ),
        returnsNormally,
      );
    });

    test('throws in release mode when the API base is still loopback', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'http://127.0.0.1:8000',
          telemetryBaseUrl: 'https://telemetry.tutolys.ca',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('TUTOLYS_API_BASE'),
          ),
        ),
      );
    });

    test('throws in release mode when the telemetry base is still loopback', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'https://api.tutolys.ca',
          telemetryBaseUrl: 'http://127.0.0.1:8001',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('TUTOLYS_TELEMETRY_BASE'),
          ),
        ),
      );
    });

    test('reports both when both are still loopback', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'http://127.0.0.1:8000',
          telemetryBaseUrl: 'http://127.0.0.1:8001',
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('TUTOLYS_API_BASE'))
              .having((e) => e.message, 'message', contains('TUTOLYS_TELEMETRY_BASE')),
        ),
      );
    });

    test('also catches "localhost", not just the 127.0.0.1 literal', () {
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'http://localhost:8000',
          telemetryBaseUrl: 'https://telemetry.tutolys.ca',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a real host that merely contains "localhost" is not flagged', () {
      // Guards against an overly broad substring match.
      expect(
        () => assertReleaseConfigIsReal(
          isReleaseMode: true,
          apiBaseUrl: 'https://not-localhost.example.com',
          telemetryBaseUrl: 'https://telemetry.tutolys.ca',
        ),
        returnsNormally,
      );
    });
  });

  group('releaseConfigError (the form main() uses)', () {
    test('returns null when the configuration is real', () {
      expect(
        releaseConfigError(
          isReleaseMode: true,
          apiBaseUrl: 'https://api.tutolys.ca',
          telemetryBaseUrl: 'https://telemetry.tutolys.ca',
        ),
        isNull,
      );
    });

    test('returns null outside release mode, whatever the urls', () {
      expect(
        releaseConfigError(
          isReleaseMode: false,
          apiBaseUrl: 'http://127.0.0.1:8000',
          telemetryBaseUrl: 'http://127.0.0.1:8001',
        ),
        isNull,
      );
    });

    test('names every misconfigured define, so one fix is not two builds', () {
      final message = releaseConfigError(
        isReleaseMode: true,
        apiBaseUrl: 'http://127.0.0.1:8000',
        telemetryBaseUrl: 'http://127.0.0.1:8001',
      );

      expect(message, isNotNull);
      expect(message, contains('TUTOLYS_API_BASE'));
      expect(message, contains('TUTOLYS_TELEMETRY_BASE'));
    });

    test('reports a value rather than throwing, so main can render it', () {
      // The whole point: `main` cannot show a message it never receives,
      // and on web a thrown error leaves the splash screen up forever.
      expect(
        () => releaseConfigError(
          isReleaseMode: true,
          apiBaseUrl: 'http://localhost:8000',
          telemetryBaseUrl: 'http://localhost:8001',
        ),
        returnsNormally,
      );
    });
  });
}
