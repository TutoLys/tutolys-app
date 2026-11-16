import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_sync.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/qa/qa_lesson_picker.dart';

/// The QA picker reaches every published lesson at the kid's grade, not
/// only the offline window (play-test A2, 2026-11-16): it lists the stored
/// manifest, and a lesson outside the window downloads on tap. The window
/// itself stays as narrow as it is for real kids.
class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
    status: SessionStatus.paired,
    accessToken: 't',
    kid: PairedKid(id: 'qa', displayName: 'QA', gradeLevel: 1),
  );
}

class _Sync extends ContentSync {
  _Sync(LocalDatabase db)
    : super(
        db: db,
        api: ContentApi(dio: Dio()),
        accessToken: () => 't',
      );
  final downloads = <String>[];

  @override
  Future<NodeDownload> downloadNode({
    required String skillNodeId,
    required int grade,
    required String askedLocale,
  }) async {
    downloads.add('$skillNodeId@$grade/$askedLocale');
    return NodeDownload.failed;
  }

  @override
  Future<Map<String, Object?>?> cachedExercise(String exerciseId) async => null;
}

ManifestEntryTableCompanion _entry(String id, String node, String engine) =>
    ManifestEntryTableCompanion.insert(
      askedLocale: 'en-CA',
      exerciseId: id,
      skillNodeId: node,
      subject: 'EN',
      grade: 1,
      rank: 1,
      engineKey: engine,
      contentHash: 'h-$id',
      locale: 'en-CA',
      lessonGroup: const Value(null),
    );

void main() {
  testWidgets('a lesson outside the window is listed and downloads on tap', (
    tester,
  ) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    // Nothing cached: both lessons are outside the window.
    await db.batch((b) {
      b.insertAll(db.manifestEntryTable, [
        _entry('ex-mcq', 'node-a', 'mcq'),
        _entry('ex-122', 'node-122', 'mail_studio'),
      ]);
    });
    final sync = _Sync(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(_Session.new),
          contentSyncProvider.overrideWithValue(sync),
        ],
        child: const MaterialApp(
          locale: Locale('fr', 'CA'),
          supportedLocales: [Locale('fr', 'CA'), Locale('en', 'CA')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: QaLessonPicker(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('qa-lesson-ex-122'));
    expect(row, findsOneWidget);
    expect(
      find.textContaining('mail_studio · rank 1 · en-CA · not downloaded'),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    // Only that lesson's node is fetched: the window isn't widened.
    expect(sync.downloads, ['node-122@1/en-CA']);
    expect(find.text('Not available offline.'), findsOneWidget);
  });
}
