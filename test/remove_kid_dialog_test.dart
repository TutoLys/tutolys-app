import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/telemetry_api.dart';
import 'package:tutolys_app/data/local_db/creation_store.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/sync/drift_event_outbox.dart';
import 'package:tutolys_app/data/sync/outbox_flusher.dart';
import 'package:tutolys_app/data/sync/outbox_flusher_provider.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/settings/remove_kid_dialog.dart';

class _Server extends TelemetryApi {
  _Server() : super(dio: Dio());

  bool offline = false;
  final stored = <String>{};

  @override
  Future<UploadResult> uploadBatch({
    required List<Map<String, Object?>> events,
    required String accessToken,
  }) async {
    if (offline) return const UploadOffline();
    final ids = [for (final e in events) e['event_id'] as String];
    stored.addAll(ids);
    return UploadProcessed(delivered: ids, rejected: const {});
  }
}

/// Hafid: "ask first". Before a kid is removed, the guardian is told what's
/// stored and chooses (ADR 0037).
void main() {
  late LocalDatabase db;
  late _Server server;
  bool? answer;

  setUp(() {
    db = LocalDatabase.memory();
    server = _Server();
    answer = null;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> open(WidgetTester tester, {int unsent = 2}) async {
    await tester.runAsync(() async {
      final outbox = DriftEventOutbox(db, kidId: 'lea');
      for (var i = 0; i < unsent; i++) {
        await outbox.add({'event_id': 'ev-$i'});
      }
      await CreationStore(db, kidId: 'lea').save(
        engineKey: 'compose_build',
        exerciseId: 'ex-1',
        payload: {'words': <String>[]},
      );
    });
    final outbox = DriftEventOutbox(db, kidId: 'lea');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('lea'),
          outboxFlusherProvider.overrideWithValue(
            OutboxFlusher(
              outbox: outbox,
              api: server,
              accessToken: () => 'token',
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr', 'CA'),
          supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await confirmRemoveKid(context, kidName: 'Léa'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('says what is stored, in plain words', (tester) async {
    await open(tester);
    expect(find.text('Retirer Léa de l’appareil ?'), findsOneWidget);
    expect(
      find.textContaining('2 résultats de jeu pas encore envoyés'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 création dans « Mes créations »'),
      findsOneWidget,
    );
    expect(find.text('Envoyer puis effacer'), findsOneWidget);
    expect(find.text('Effacer maintenant'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(answer, isFalse);
  });

  testWidgets('erase now goes ahead without sending', (tester) async {
    await open(tester);
    await tester.tap(find.text('Effacer maintenant'));
    await settle(tester);
    expect(answer, isTrue);
    expect(server.stored, isEmpty);
  });

  testWidgets('send then erase uploads first, then goes ahead', (tester) async {
    await open(tester);
    await tester.tap(find.text('Envoyer puis effacer'));
    await settle(tester);
    expect(server.stored, {'ev-0', 'ev-1'});
    expect(answer, isTrue);
  });

  testWidgets('a failed send says so, and offers retry or erase anyway', (
    tester,
  ) async {
    server.offline = true;
    await open(tester);
    await tester.tap(find.text('Envoyer puis effacer'));
    await settle(tester);

    expect(answer, isNull);
    expect(find.textContaining('L’envoi n’a pas marché'), findsOneWidget);
    expect(find.text('Effacer quand même'), findsOneWidget);

    server.offline = false;
    await tester.tap(find.text('Réessayer'));
    await settle(tester);
    expect(server.stored, hasLength(2));
    expect(answer, isTrue);
  });

  testWidgets('with nothing unsent there is nothing to send', (tester) async {
    await open(tester, unsent: 0);
    expect(find.textContaining('déjà été envoyés'), findsOneWidget);
    expect(find.text('Envoyer puis effacer'), findsNothing);
    expect(find.text('Effacer maintenant'), findsOneWidget);
  });
}
