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
import 'package:tutolys_app/data/api/feedback_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/feedback_queue.dart';
import 'package:tutolys_app/data/local_db/kid_local_data.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/feedback/feedback_card.dart';
import 'package:tutolys_app/features/feedback/feedback_sender.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';

/// « Une idée ? Un problème ? » (work order F3, app ADR 0104).
void main() {
  late LocalDatabase db;
  var ids = 0;
  setUp(() {
    ids = 0;
    db = LocalDatabase.memory();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  const ctx = FeedbackContext(
    appVersion: '1.2.3',
    platform: 'linux',
    locale: 'fr',
    route: 'aide',
  );

  FeedbackSender sender(
    FeedbackApi api, {
    String kid = 'kid-a',
    String? Function()? token,
  }) => FeedbackSender(
    queue: FeedbackQueue(db, kidId: kid),
    api: api,
    accessToken: token ?? () => 'access',
    newId: () => 'id-${ids++}',
    clock: () => DateTime.utc(2026, 10, 31, 9),
  );

  group('the queue', () {
    test('keeps messages per kid, oldest first', () async {
      final a = FeedbackQueue(db, kidId: 'a');
      final b = FeedbackQueue(db, kidId: 'b');
      await a.add(_item('1'));
      await a.add(_item('2'));
      await b.add(_item('3'));
      expect((await a.pending()).map((i) => i.clientId), ['1', '2']);
      expect((await b.pending()).map((i) => i.clientId), ['3']);
    });

    test('past the cap the oldest goes, and is counted', () async {
      final q = FeedbackQueue(db, kidId: 'a');
      for (var i = 0; i < FeedbackQueue.maxQueued + 2; i++) {
        await q.add(_item('$i'));
      }
      final left = await q.pending();
      expect(left, hasLength(FeedbackQueue.maxQueued));
      expect(left.first.clientId, '2');
      expect(await q.evictedTotal(), 2);
    });

    test(
      'removing a kid from the device erases their unsent messages',
      () async {
        await FeedbackQueue(db, kidId: 'a').add(_item('1'));
        await FeedbackQueue(db, kidId: 'b').add(_item('2'));
        await KidLocalData(db, kidId: 'a').wipe();
        expect(await FeedbackQueue(db, kidId: 'a').pending(), isEmpty);
        expect(await FeedbackQueue(db, kidId: 'b').pending(), hasLength(1));
      },
    );

    test('the kind goes out as feature or bug, never idea', () {
      expect(FeedbackKind.values.map((k) => k.wire), ['feature', 'bug']);
    });

    test('a message queued under the old name still reads', () async {
      await db
          .into(db.appStateTable)
          .insert(
            AppStateTableCompanion.insert(
              kidId: 'a',
              key: 'feedback.queue',
              value:
                  '[{"client_id":"1","kind":"idea","text":"t",'
                  '"context":{},"created_at":"2026-10-31T00:00:00Z"}]',
              updatedAt: DateTime.utc(2026, 10, 31),
            ),
          );
      final item = (await FeedbackQueue(db, kidId: 'a').pending()).single;
      expect(item.kind, FeedbackKind.feature);
      expect(item.toBody()['kind'], 'feature');
    });

    test('never touches the telemetry outbox', () async {
      await FeedbackQueue(db, kidId: 'a').add(_item('1'));
      expect(await db.select(db.eventOutboxTable).get(), isEmpty);
    });
  });

  group('sending', () {
    test('online: sent, and the queue is empty', () async {
      final api = _FakeApi([FeedbackSendResult.sent]);
      final s = sender(api);
      final outcome = await s.submit(
        kind: FeedbackKind.bug,
        text: '  Le son ne marche pas  ',
        context: ctx,
      );
      expect(outcome, FeedbackOutcome.sent);
      expect(await s.queue.pending(), isEmpty);
      expect(api.bodies.single, {
        'client_id': 'id-0',
        'kind': 'bug',
        'text': 'Le son ne marche pas',
        'context': {
          'app_version': '1.2.3',
          'platform': 'linux',
          'locale': 'fr',
          'route': 'aide',
        },
      });
      expect(api.tokens.single, 'access');
    });

    test('the context is the allowlist and nothing else', () {
      expect(ctx.toJson().keys, {'app_version', 'platform', 'locale', 'route'});
    });

    test('offline: queued, then sent by a later flush', () async {
      final api = _FakeApi([
        FeedbackSendResult.retryLater,
        FeedbackSendResult.sent,
      ]);
      final s = sender(api);
      expect(
        await s.submit(
          kind: FeedbackKind.feature,
          text: 'Des dinos',
          context: ctx,
        ),
        FeedbackOutcome.queued,
      );
      expect(await s.queue.pending(), hasLength(1));
      await s.flush();
      expect(await s.queue.pending(), isEmpty);
      expect(api.bodies.map((b) => b['client_id']), ['id-0', 'id-0']);
    });

    test('no token: kept, nothing sent', () async {
      final api = _FakeApi([]);
      final s = sender(api, token: () => null);
      expect(
        await s.submit(kind: FeedbackKind.feature, text: 'x', context: ctx),
        FeedbackOutcome.queued,
      );
      expect(api.bodies, isEmpty);
    });

    test('a refused message is dropped; the next one still goes', () async {
      await FeedbackQueue(db, kidId: 'kid-a').add(_item('old'));
      final api = _FakeApi([
        FeedbackSendResult.rejected,
        FeedbackSendResult.sent,
      ]);
      final s = sender(api);
      await s.submit(kind: FeedbackKind.feature, text: 'new', context: ctx);
      expect(await s.queue.pending(), isEmpty);
      expect(api.bodies.map((b) => b['client_id']), ['old', 'id-0']);
    });

    test('a waiting message holds back the ones after it', () async {
      await FeedbackQueue(db, kidId: 'kid-a').add(_item('old'));
      final api = _FakeApi([FeedbackSendResult.retryLater]);
      final s = sender(api);
      await s.submit(kind: FeedbackKind.feature, text: 'new', context: ctx);
      expect(api.bodies, hasLength(1));
      expect((await s.queue.pending()).map((i) => i.clientId), ['old', 'id-0']);
    });

    test('two flushes at once send each message once', () async {
      await FeedbackQueue(db, kidId: 'kid-a').add(_item('one'));
      final api = _FakeApi([FeedbackSendResult.sent]);
      final s = sender(api);
      await Future.wait([s.flush(), s.flush()]);
      expect(api.bodies, hasLength(1));
    });

    test('empty or over 4,000 characters is refused before queuing', () async {
      final s = sender(_FakeApi([]));
      expect(
        () => s.submit(kind: FeedbackKind.feature, text: '   ', context: ctx),
        throwsArgumentError,
      );
      expect(
        () => s.submit(
          kind: FeedbackKind.feature,
          text: 'a' * (feedbackMaxLength + 1),
          context: ctx,
        ),
        throwsArgumentError,
      );
      expect(await s.queue.pending(), isEmpty);
    });

    test('the limit counts code points, like the backend', () {
      expect(feedbackLength('🦊🦊'), 2);
      expect(feedbackLength(' é '), 1);
    });
  });

  group('the endpoint', () {
    Future<FeedbackSendResult> sendWith(int? status) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _Adapter(status);
      return FeedbackApi(dio: dio).send(accessToken: 't', body: {});
    }

    test('2xx is sent', () async {
      expect(await sendWith(201), FeedbackSendResult.sent);
    });

    test('a refusal of the message itself is final', () async {
      for (final s in [400, 413, 422]) {
        expect(await sendWith(s), FeedbackSendResult.rejected, reason: '$s');
      }
    });

    test(
      'offline, auth, 404 before deployment, throttling, 5xx: retry later',
      () async {
        for (final s in [null, 401, 403, 404, 429, 500, 503]) {
          expect(
            await sendWith(s),
            FeedbackSendResult.retryLater,
            reason: '$s',
          );
        }
      },
    );

    test('the token rides the header, never the body', () async {
      final adapter = _Adapter(201);
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      await FeedbackApi(dio: dio).send(accessToken: 'secret', body: {'a': 1});
      expect(adapter.lastHeaders?['Authorization'], 'Bearer secret');
      expect(adapter.lastBody, isNot(contains('secret')));
    });
  });

  group('the form', () {
    final fr = Strings.fr;

    Future<(_FakeApi, SessionStore)> pump(
      WidgetTester tester, {
      List<FeedbackSendResult> results = const [FeedbackSendResult.sent],
    }) async {
      final api = _FakeApi([...results]);
      final store = SessionStore();
      await store.setGuardianPin('135790');
      final s = sender(api);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(store),
            feedbackSenderProvider.overrideWithValue(s),
          ],
          child: MaterialApp(
            theme: TutolysTheme.village(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: FeedbackCard()),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('feedback-open')));
      await tester.pumpAndSettle();
      return (api, store);
    }

    Finder send() => find.byKey(const ValueKey('feedback-send'));

    bool sendEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(send()).onPressed != null;

    testWidgets('says what it is, and asks not to write personal details', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(fr.feedbackKindFeature), findsOneWidget);
      expect(find.text(fr.feedbackKindBug), findsOneWidget);
      expect(find.text(fr.feedbackPrivacyNote), findsOneWidget);
      expect(sendEnabled(tester), isFalse, reason: 'nothing written yet');
    });

    testWidgets('the two kinds stack full width, neither cut (AM12)', (
      tester,
    ) async {
      await pump(tester);
      final feature = tester.getRect(
        find.byKey(const ValueKey('feedback-kind-feature')),
      );
      final bug = tester.getRect(find.byKey(const ValueKey('feedback-kind-bug')));
      expect(feature.width, closeTo(bug.width, 0.5));
      expect(bug.top, greaterThan(feature.bottom));
      expect(feature.height, greaterThanOrEqualTo(48));
      expect(find.text(Strings.fr.feedbackKindFeature), findsOneWidget);
    });

    testWidgets('over 4,000 characters cannot be sent', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-text')),
        'a' * (feedbackMaxLength + 1),
      );
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('sending asks for the PIN; backing out sends nothing', (
      tester,
    ) async {
      final (api, _) = await pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-text')),
        'Mon nom est…',
      );
      await tester.pump();
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(find.text(fr.feedbackPinEnter), findsOneWidget);

      await tester.tap(find.text(fr.cancel).last);
      await tester.pumpAndSettle();
      expect(api.bodies, isEmpty);
      expect(await FeedbackQueue(db, kidId: 'kid-a').pending(), isEmpty);
      expect(find.byType(FeedbackDialog), findsOneWidget, reason: 'text kept');
    });

    testWidgets('with the PIN: a bug report goes, and the form closes', (
      tester,
    ) async {
      final (api, _) = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('feedback-kind-bug')));
      await tester.enterText(
        find.byKey(const ValueKey('feedback-text')),
        'Le bouton saute',
      );
      await tester.pump();
      await tester.tap(send());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '135790');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();

      expect(api.bodies.single['kind'], 'bug');
      expect(api.bodies.single['text'], 'Le bouton saute');
      expect((api.bodies.single['context']! as Map).keys, {
        'app_version',
        'platform',
        'locale',
        'route',
      });
      expect(find.byType(FeedbackDialog), findsNothing);
      expect(find.text(fr.feedbackSent), findsOneWidget);
      await tester.pump(VillageToast.visibleFor);
    });

    testWidgets('offline: thanked, and told it will go later', (tester) async {
      await pump(tester, results: [FeedbackSendResult.retryLater]);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-text')),
        'Des dinosaures !',
      );
      await tester.pump();
      await tester.tap(send());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '135790');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();

      expect(find.text(fr.feedbackQueued), findsOneWidget);
      expect(await FeedbackQueue(db, kidId: 'kid-a').pending(), hasLength(1));
      await tester.pump(VillageToast.visibleFor);
    });
  });
}

QueuedFeedback _item(String id) => QueuedFeedback(
  clientId: id,
  kind: FeedbackKind.feature,
  text: 'text $id',
  context: const {'locale': 'fr'},
  createdAt: DateTime.utc(2026, 10, 31),
);

class _FakeApi extends FeedbackApi {
  _FakeApi(this.results) : super(dio: Dio());

  final List<FeedbackSendResult> results;
  final bodies = <Map<String, Object?>>[];
  final tokens = <String>[];

  @override
  Future<FeedbackSendResult> send({
    required String accessToken,
    required Map<String, Object?> body,
  }) async {
    tokens.add(accessToken);
    bodies.add(body);
    return results.isEmpty
        ? FeedbackSendResult.retryLater
        : results.removeAt(0);
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int? status;
  Map<String, dynamic>? lastHeaders;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = Map.of(options.headers);
    lastBody = jsonEncode(options.data);
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
