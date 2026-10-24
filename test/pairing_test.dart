import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';

import 'package:tutolys_app/core/routing/app_shell.dart';
import 'package:tutolys_app/core/routing/village_shell.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/api/pairing_api.dart';
import 'package:tutolys_app/data/api/telemetry_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/drift_event_outbox.dart';
import 'package:tutolys_app/data/sync/outbox_flusher.dart';
import 'package:tutolys_app/data/sync/outbox_flusher_provider.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_screen.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/path/path_screen.dart';

/// Neither the path screen's own data needs a real network in these
/// pairing-focused tests: both report offline immediately, so
/// `PathController` settles into its empty/offline state instead of
/// hanging on a real connection attempt to a dev-stack that isn't running.
class _OfflineCurriculumApi extends CurriculumApi {
  _OfflineCurriculumApi() : super(dio: Dio());

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async => const CurriculumTreeOffline();
}

class _OfflineContentApi extends ContentApi {
  _OfflineContentApi() : super(dio: Dio());

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
  }) async => const ManifestOffline();
}

/// In-memory stand-ins. Hand-written rather than generated: there are two of
/// them and the behaviour under test is the state machine, not the transport.
class FakeSessionStore extends SessionStore {
  FakeSessionStore({this.storedToken});

  String? storedToken;
  String? savedKidName;
  bool cleared = false;

  @override
  Future<String> deviceId() async => 'test-device';

  @override
  Future<String?> deviceToken() async => storedToken;

  @override
  Future<void> savePairing({
    required String deviceToken,
    required String kidId,
    required String kidDisplayName,
    required int gradeLevel,
  }) async {
    storedToken = deviceToken;
    savedKidName = kidDisplayName;
  }

  @override
  Future<PairedKid?> pairedKid() async => savedKidName == null
      ? const PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1)
      : PairedKid(id: 'k1', displayName: savedKidName!, gradeLevel: 1);

  @override
  Future<void> clearPairing() async {
    cleared = true;
    storedToken = null;
  }
}

class FakePairingApi extends PairingApi {
  FakePairingApi({required this.exchangeResult, required this.refreshResult})
    : super(dio: _unusedDio);

  final PairingResult exchangeResult;
  final RefreshResult refreshResult;
  int exchangeCalls = 0;

  @override
  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    exchangeCalls++;
    return exchangeResult;
  }

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async =>
      refreshResult;
}

class CountingPairingApi extends FakePairingApi {
  CountingPairingApi({
    required super.exchangeResult,
    required super.refreshResult,
  });

  int refreshCalls = 0;

  @override
  Future<RefreshResult> refresh({required String deviceToken}) async {
    refreshCalls++;
    // Yield, so concurrent callers genuinely overlap and the mutex is tested
    // rather than accidentally satisfied by synchronous completion.
    await Future<void>.delayed(Duration.zero);
    return super.refresh(deviceToken: deviceToken);
  }
}

final _unusedDio = Dio();

/// Records every batch it receives and accepts all of it — just enough to
/// prove an upload actually happened, not a full fake of the real service
/// (that's `FakeTelemetryServer` in `outbox_test.dart`, which already covers
/// OutboxFlusher's own retry/pause/backoff behaviour in isolation).
class _RecordingTelemetryServer extends TelemetryApi {
  _RecordingTelemetryServer() : super(dio: Dio());

  int uploadCalls = 0;
  final List<String> delivered = [];

  @override
  Future<UploadResult> uploadBatch({
    required List<Map<String, Object?>> events,
    required String accessToken,
  }) async {
    uploadCalls++;
    final ids = events.map((e) => e['event_id'] as String).toList();
    delivered.addAll(ids);
    return UploadProcessed(delivered: ids, rejected: const {});
  }
}

const _success = PairingSucceeded(
  deviceToken: 'device-token-1',
  accessToken: 'access-token-1',
  expiresIn: 900,
  kidId: 'k1',
  kidDisplayName: 'Yelhan',
  gradeLevel: 1,
);

ProviderContainer containerWith({
  required FakeSessionStore store,
  required FakePairingApi api,
}) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      pairingApiProvider.overrideWithValue(api),
      // No background timer in tests: an armed 12-minute timer fails the
      // pending-timer check, and these tests drive refresh explicitly.
      sessionAutoRefreshProvider.overrideWithValue(false),
      // Same reasoning: OutboxFlusher's 30s periodic timer would otherwise
      // fail the pending-timer check too.
      outboxFlusherAutoStartProvider.overrideWithValue(false),
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
      curriculumApiProvider.overrideWithValue(_OfflineCurriculumApi()),
      contentApiProvider.overrideWithValue(_OfflineContentApi()),
    ],
  );
}

Widget appUnder(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      // Reduce motion in tests. The mascot's idle breath repeats forever
      // otherwise, and `pumpAndSettle` would never settle. Honouring the flag
      // is also the accessibility behaviour we want in production.
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: TutolysTheme.learner(),
        home: child,
      ),
    ),
  );
}

void main() {
  group('session state machine', () {
    test('no stored token means unpaired', () async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'a',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
    });

    test('a stored token that still refreshes means paired', () async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'fresh',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.paired);
      expect(state.accessToken, 'fresh');
    });

    test(
      'A2 acceptance: a device revoked on the server returns to pairing',
      () async {
        final store = FakeSessionStore(storedToken: 'stored');
        final container = containerWith(
          store: store,
          // 401 from the server: revoked or the kid was archived.
          api: FakePairingApi(
            exchangeResult: _success,
            refreshResult: const RefreshRejected(),
          ),
        );
        addTearDown(container.dispose);

        await container.read(sessionControllerProvider.notifier).restore();

        expect(
          container.read(sessionControllerProvider).status,
          SessionStatus.unpaired,
        );
        expect(store.cleared, isTrue, reason: 'the credential must be dropped');
        expect(store.storedToken, isNull);
      },
    );

    test('offline does NOT un-pair the device', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshOffline(),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).restore();

      // Dropping the credential when the Wi-Fi blips would force a parent to
      // generate a new code every time, and would break offline play.
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.paired,
      );
      expect(store.cleared, isFalse);
      expect(store.storedToken, 'stored');
    });

    test('pairing stores the device token and goes paired', () async {
      final store = FakeSessionStore();
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      final error = await container
          .read(sessionControllerProvider.notifier)
          .pair('ZF23XU');

      expect(error, isNull);
      expect(store.storedToken, 'device-token-1');
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.paired,
      );
    });

    test('each failure maps to its own error kind', () async {
      Future<PairingError?> attempt(PairingResult result) async {
        final container = containerWith(
          store: FakeSessionStore(),
          api: FakePairingApi(
            exchangeResult: result,
            refreshResult: const RefreshRejected(),
          ),
        );
        addTearDown(container.dispose);
        return container
            .read(sessionControllerProvider.notifier)
            .pair('ZF23XU');
      }

      expect(
        await attempt(const PairingCodeRejected('nope')),
        PairingError.invalidCode,
      );
      expect(await attempt(const PairingOffline()), PairingError.offline);
      expect(
        await attempt(const PairingRateLimited()),
        PairingError.rateLimited,
      );
      expect(
        await attempt(const PairingFailed('boom')),
        PairingError.unexpected,
      );
    });

    test('forget unpairs on request', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'a',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).forget();

      expect(store.cleared, isTrue);
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
    });
  });

  group('pairing screen', () {
    testWidgets('shows the French title and hint by default', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      expect(find.text('Salut !'), findsOneWidget);
      expect(find.text('Entre ton code pour commencer'), findsOneWidget);
      expect(
        find.text('Demande ton code à un adulte. Il a six caractères.'),
        findsOneWidget,
      );
    });

    testWidgets('the connect button is disabled until six characters', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button().onPressed, isNull, reason: 'empty code');

      await tester.enterText(find.byType(TextField), 'ZF23');
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'four characters');

      await tester.enterText(find.byType(TextField), 'ZF23XU');
      await tester.pump();
      expect(button().onPressed, isNotNull, reason: 'six characters');
    });

    testWidgets('characters outside the code alphabet never appear', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      // 0, O, 1, I and L are excluded, so a mistyped character is visibly
      // ignored rather than silently mapped onto a different code.
      await tester.enterText(find.byType(TextField), '0OIL1Z');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Z');
    });

    testWidgets('lower case is upper-cased as it is typed', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));

      await tester.enterText(find.byType(TextField), 'zf23xu');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ZF23XU');
    });

    testWidgets('a wrong code shows the kid-facing message', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingCodeRejected('invalid'),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Ce code ne fonctionne pas. Demande-en un nouveau à un adulte.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('being offline says so, rather than blaming the code', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingOffline(),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZF23XU');
      await tester.pumpAndSettle();

      // A child told "wrong code" when the Wi-Fi is off will retype a code
      // that was never the problem.
      expect(
        find.text("Pas de connexion Internet. Vérifie le Wi-Fi et réessaie."),
        findsOneWidget,
      );
    });

    testWidgets('editing after an error clears it', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: const PairingCodeRejected('invalid'),
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const PairingScreen()));
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ZZZZZ');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('app shell', () {
    testWidgets('an unpaired device lands on the pairing screen', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(PathScreen), findsNothing);
    });

    testWidgets('a paired device goes straight past pairing', (tester) async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'fresh',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(VillageShell), findsOneWidget);
      expect(find.byType(PairingScreen), findsNothing);
    });

    testWidgets('a revoked device is sent back to pairing on launch', (
      tester,
    ) async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'revoked-token'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
    });
  });

  group('outbox flusher wiring', () {
    // Unlike every other test in this file, `outboxFlusherAutoStartProvider`
    // is deliberately left at its real default (true) here — proving AppShell
    // actually starts the flusher is the entire point. A short interval
    // override keeps the periodic tick inside a fast test.
    testWidgets(
      'AppShell boots a running flusher that uploads a queued event '
      'with no manual intervention',
      (tester) async {
        final db = LocalDatabase.memory();
        final outbox = DriftEventOutbox(db, kidId: 'kid-1');
        final server = _RecordingTelemetryServer();

        final container = ProviderContainer(
          overrides: [
            sessionStoreProvider.overrideWithValue(
              FakeSessionStore(storedToken: 'stored'),
            ),
            pairingApiProvider.overrideWithValue(
              FakePairingApi(
                exchangeResult: _success,
                refreshResult: const RefreshSucceeded(
                  accessToken: 'fresh',
                  expiresIn: 900,
                ),
              ),
            ),
            sessionAutoRefreshProvider.overrideWithValue(false),
            localDatabaseProvider.overrideWithValue(db),
            curriculumApiProvider.overrideWithValue(_OfflineCurriculumApi()),
            contentApiProvider.overrideWithValue(_OfflineContentApi()),
            eventOutboxProvider.overrideWithValue(outbox),
            outboxFlusherProvider.overrideWithValue(
              OutboxFlusher(
                outbox: outbox,
                api: server,
                accessToken: () => 'fresh',
                interval: const Duration(seconds: 1),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // As if an exercise had already been played before this boot.
        await outbox.add({
          'schema_version': 1,
          'event_id': 'evt-1',
          'event_ts': DateTime.utc(2026, 10, 23).toIso8601String(),
          'session_id': 'session-1',
          'event_type': 'exercise_complete',
          'app_version': '0.1.0',
        });

        await tester.pumpWidget(appUnder(container, const AppShell()));
        // initState runs on the first frame, which is what starts the timer.
        await tester.pump();
        expect(
          server.uploadCalls,
          0,
          reason: 'nothing should upload before the first tick',
        );

        // No pumpAndSettle: a live periodic timer would never let it settle.
        await tester.pump(const Duration(seconds: 2));

        expect(server.uploadCalls, greaterThan(0));
        expect(server.delivered, contains('evt-1'));
        expect(await outbox.pending(limit: 10), isEmpty);
      },
    );
  });

  group('token refresh (review findings)', () {
    test('concurrent refreshes coalesce into one request', () async {
      /// The single-flight mutex. Two concurrent 401 retries both refreshing
      /// means the loser presents an already-rotated token and the session is
      /// dropped — the exact bug the client census found in the old app.
      final api = CountingPairingApi(
        exchangeResult: _success,
        refreshResult: const RefreshSucceeded(accessToken: 'a', expiresIn: 900),
      );
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: api,
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await Future.wait([
        controller.ensureFreshToken(),
        controller.ensureFreshToken(),
        controller.ensureFreshToken(),
      ]);

      expect(api.refreshCalls, 1, reason: 'refreshes did not coalesce');
    });

    test('a later refresh still works after the first completes', () async {
      final api = CountingPairingApi(
        exchangeResult: _success,
        refreshResult: const RefreshSucceeded(accessToken: 'a', expiresIn: 900),
      );
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: api,
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await controller.ensureFreshToken();
      await controller.ensureFreshToken();

      expect(api.refreshCalls, 2, reason: 'the mutex must not latch');
    });

    test('a refresh updates the held access token', () async {
      final container = containerWith(
        store: FakeSessionStore(storedToken: 'stored'),
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshSucceeded(
            accessToken: 'second-token',
            expiresIn: 900,
          ),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(sessionControllerProvider.notifier)
          .ensureFreshToken();

      expect(
        container.read(sessionControllerProvider).accessToken,
        'second-token',
      );
    });

    test('a rejected refresh unpairs and stops the timer', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshRejected(),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(sessionControllerProvider.notifier)
          .ensureFreshToken();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.unpaired,
      );
      expect(store.cleared, isTrue);
    });

    test('an offline refresh keeps the session', () async {
      final store = FakeSessionStore(storedToken: 'stored');
      final container = containerWith(
        store: store,
        api: FakePairingApi(
          exchangeResult: _success,
          refreshResult: const RefreshOffline(),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(sessionControllerProvider.notifier)
          .ensureFreshToken();

      expect(store.cleared, isFalse);
      expect(store.storedToken, 'stored');
    });
  });
}
