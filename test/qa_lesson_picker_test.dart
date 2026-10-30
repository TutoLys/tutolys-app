import 'package:design_system/design_system.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/about/about_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/qa/qa_lesson_picker.dart';
import 'package:tutolys_app/features/play/play_screen.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'dart:convert';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    accessToken: 't',
    kid: PairedKid(id: 'k1', displayName: 'Léa', gradeLevel: 1),
  );
}

/// The QA lesson picker (ADR 0100): never in a release build.
void main() {
  test('a release build never has it, whatever its defines', () {
    expect(qaToolsFor(release: true, define: true), isFalse);
    expect(qaToolsFor(release: true, define: false), isFalse);
    expect(qaToolsFor(release: false, define: false), isFalse);
    expect(qaToolsFor(release: false, define: true), isTrue);
    expect(qaToolsEnabled, isFalse, reason: 'tests build without QA_TOOLS');
  });

  Future<void> openLog(WidgetTester tester, {required bool qa}) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    await tester.runAsync(() async {
      for (final (id, subject, engine) in [
        ('e1', 'MATH', 'pair_match'),
        ('e2', 'MATH', 'speed_tap'),
        ('e3', 'FR', 'compose_build'),
      ]) {
        await db
            .into(db.manifestEntryTable)
            .insert(
              ManifestEntryTableCompanion.insert(
                askedLocale: 'fr-CA',
                exerciseId: id,
                skillNodeId: 'n-$id',
                subject: subject,
                grade: 1,
                rank: 0,
                engineKey: engine,
                contentHash: 'h',
                locale: 'fr-CA',
                lessonGroup: const Value(null),
              ),
            );
      }
      final envelope = {
        'schema_version': 1,
        'exercise_id': 'e1',
        'version': 1,
        'engine_key': 'mcq',
        'engine_min_version': 1,
        'skill_node_id': 'n-e1',
        'subject': 'MATH',
        'grade': 1,
        'rank': 0,
        'locale': 'fr-CA',
        'prompt': {'text': 'Invente ta phrase', 'audio_ref': null},
        'config': {
          'options': [
            {'id': 'a', 'label': '4'},
            {'id': 'b', 'label': '5'},
          ],
          'correct': 'a',
        },
        'assets': const <Object?>[],
      };
      await db
          .into(db.exerciseCacheTable)
          .insert(
            ExerciseCacheTableCompanion.insert(
              exerciseId: 'e1',
              version: 1,
              payload: jsonEncode(envelope),
              contentHash: contentSha256(envelope),
              engineKey: 'mcq',
              skillNodeId: 'n-e1',
              subject: 'MATH',
              grade: 1,
              rank: 0,
              cachedAt: DateTime.utc(2026, 10, 29),
            ),
          );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(_Session.new),
          sessionStoreProvider.overrideWithValue(SessionStore()),
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTechnicalLog(context, qaTools: qa),
              child: const Text('log'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('log'));
    await tester.pumpAndSettle();
  }

  testWidgets('without QA tools the log has no way in', (tester) async {
    await openLog(tester, qa: false);
    expect(find.byKey(const ValueKey('qa-open-picker')), findsNothing);
  });

  testWidgets('with QA tools: every published lesson, by subject and '
      'engine', (tester) async {
    await openLog(tester, qa: true);
    await tester.tap(find.byKey(const ValueKey('qa-open-picker')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa-lesson-picker')), findsOneWidget);
    for (final id in ['e1', 'e2', 'e3']) {
      expect(find.byKey(ValueKey('qa-lesson-$id')), findsOneWidget);
    }
    expect(find.textContaining('pair_match'), findsOneWidget);
    expect(find.textContaining('speed_tap'), findsOneWidget);
  });

  testWidgets('a row opens its lesson, titled by its prompt, as practice', (
    tester,
  ) async {
    await openLog(tester, qa: true);
    await tester.tap(find.byKey(const ValueKey('qa-open-picker')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Invente ta phrase'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa-lesson-e1')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    // A game's animations never settle: pump frames instead.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(play.practice, isTrue);
    expect(play.envelope['exercise_id'], 'e1');
  });
}
