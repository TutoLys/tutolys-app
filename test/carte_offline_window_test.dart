import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

import 'path_screen_test.dart'
    show FakeContentApi, appUnder, exercise, openCarte;

/// A server that can drop off the network, manifest and lessons alike.
class _Flaky extends FakeContentApi {
  _Flaky(super.content);
  bool offline = true;

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async => offline
      ? const ManifestOffline()
      : super.fetchManifest(
          accessToken: accessToken,
          subject: subject,
          locale: locale,
        );

  @override
  Future<ExercisesResult> fetchExercises({
    required List<String> ids,
    required String accessToken,
  }) async => offline
      ? const ExercisesOffline()
      : super.fetchExercises(ids: ids, accessToken: accessToken);
}

const _one = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);
const _two = CurriculumLeaf(
  id: 'leaf-2',
  labelFr: 'Comparer',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:2',
);

/// The Carte with the offline window (ADR 0095): a leaf whose lesson is
/// published but not on the device keeps its real state, wears a cloud
/// offline, and says kindly that it needs the Internet; online, a tap
/// downloads it and plays.
void main() {
  late LocalDatabase db;
  late _Flaky api;
  final content = {
    'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1'),
    'ex-2': exercise(id: 'ex-2', skillNodeId: 'leaf-2'),
  };

  setUp(() async {
    db = LocalDatabase.memory();
    api = _Flaky(content);
    // The device as an earlier, online sync left it: leaf-1 downloaded and
    // finished, leaf-2 known from the manifest but outside the window.
    final one = content['ex-1']!;
    await db
        .into(db.exerciseCacheTable)
        .insert(
          ExerciseCacheTableCompanion.insert(
            exerciseId: 'ex-1',
            version: 1,
            payload: jsonEncode(one),
            contentHash: contentSha256(one),
            engineKey: 'mcq',
            skillNodeId: 'leaf-1',
            subject: 'MATH',
            grade: 1,
            rank: 0,
            cachedAt: DateTime.utc(2026, 10, 29),
          ),
        );
    for (final e in content.values) {
      await db
          .into(db.manifestEntryTable)
          .insert(
            ManifestEntryTableCompanion.insert(
              askedLocale: 'fr-CA',
              exerciseId: e['exercise_id'] as String,
              skillNodeId: e['skill_node_id'] as String,
              subject: 'MATH',
              grade: 1,
              rank: 0,
              engineKey: 'mcq',
              contentHash: contentSha256(e),
              locale: 'fr-CA',
              lessonGroup: const Value(null),
            ),
          );
    }
    await NodeProgressLocal(
      db,
      kidId: 'k1',
    ).recordCompleted('leaf-1', perfect: true, exerciseId: 'ex-1');
  });

  tearDown(() => db.close());

  testWidgets('offline: not downloaded, never locked, a kind word on tap', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_one, _two],
        content: content,
        db: db,
        contentApi: api,
      ),
    );

    expect(
      find.byKey(const ValueKey('not-downloaded-leaf-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('not-downloaded-leaf-1')), findsNothing);
    // It's the frontier: the active card, not a lock or "soon".
    expect(find.text('À DÉCOUVRIR'), findsOneWidget);
    expect(find.byKey(const ValueKey('soon-tag-leaf-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-2')));
    await tester.pumpAndSettle();
    expect(find.text(Strings.fr.pathNotDownloadedOffline), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });

  testWidgets('online: a tap downloads the leaf, then plays it', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_one, _two],
        content: content,
        db: db,
        contentApi: api,
      ),
    );
    api.offline = false;

    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-2')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
    final cached = await tester.runAsync(
      () => db.select(db.exerciseCacheTable).get(),
    );
    expect(cached!.map((r) => r.exerciseId), containsAll(['ex-1', 'ex-2']));
  });

  test('the words are a child\'s, in both languages', () {
    for (final t in [Strings.fr, Strings.en]) {
      expect(t.pathNotDownloaded, isNotEmpty);
      expect(
        t.pathNotDownloadedOffline.toLowerCase(),
        isNot(matches(RegExp(r'erreur|error|cache|sync|réseau|network'))),
      );
    }
  });
}
