import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/data/sync/content_sync.dart';
import 'package:tutolys_app/features/path/offline_window.dart';

import 'content_sync_test.dart' show FakeContentServer;

/// The offline window (ADR 0093): which leaves a kid needs, the union a
/// family device keeps, prefetch as the frontier moves, and eviction that
/// is counted and never takes what a kid is in the middle of.
void main() {
  group('computeOfflineWindow', () {
    final order = [for (var i = 0; i < 40; i++) 'n$i'];
    final all = order.toSet();

    test('a new kid: the first 25 playable leaves', () {
      final w = computeOfflineWindow(order: order, playable: all);
      expect(w, {for (var i = 0; i < 25; i++) 'n$i'});
      expect(offlineWindowLeaves, inInclusiveRange(20, 30));
    });

    test('mid-path: 3 behind the frontier and 25 from it', () {
      final w = computeOfflineWindow(
        order: order,
        playable: all,
        done: {for (var i = 0; i < 10; i++) 'n$i'},
      );
      expect(w, {for (var i = 7; i < 35; i++) 'n$i'});
    });

    test('everything done: the end of the path', () {
      final w = computeOfflineWindow(order: order, playable: all, done: all);
      expect(w, {'n36', 'n37', 'n38', 'n39'});
    });

    test('skills with no lesson take no slot', () {
      final playable = {for (var i = 0; i < 40; i += 2) 'n$i'};
      final w = computeOfflineWindow(order: order, playable: playable);
      expect(w, playable, reason: '20 playable leaves, all inside 25');
    });

    test('review leaves always ride along', () {
      final w = computeOfflineWindow(
        order: order,
        playable: all,
        review: {'prior-grade-leaf'},
      );
      expect(w, contains('prior-grade-leaf'));
      expect(w, hasLength(26));
    });

    test('no curriculum order: nothing but review', () {
      expect(computeOfflineWindow(order: const [], playable: all), isEmpty);
    });
  });

  group('the windowed sync', () {
    late LocalDatabase db;
    late FakeContentServer server;
    late ContentSync sync;
    late List<PairedKid> kids;
    late String active;

    const leaves = 40;
    String node(int i) => 'n$i';
    String ex(int i) => 'ex$i';

    Map<String, Object?> exercise(int i, {List<Object?> assets = const []}) => {
      'schema_version': 1,
      'exercise_id': ex(i),
      'version': 1,
      'engine_key': 'mcq',
      'engine_min_version': 1,
      'skill_node_id': node(i),
      'subject': 'MATH',
      'grade': 1,
      'rank': 0,
      'locale': 'fr-CA',
      'prompt': {'text': 'Q$i', 'audio_ref': null, 'image_ref': null},
      'config': {
        'options': [
          {'id': 'a', 'label': '4'},
        ],
        'correct': 'a',
      },
      'assets': assets,
    };

    Future<void> seedCurriculum() async {
      for (var i = 0; i < leaves; i++) {
        await db
            .into(db.skillNodeTable)
            .insert(
              SkillNodeTableCompanion.insert(
                id: node(i),
                labelFr: 'Feuille $i',
                labelEn: 'Leaf $i',
                stableKey: 'math:s:$i',
                subject: 'MATH',
                grade: 1,
                docOrder: Value(i),
                areaLabelFr: const Value('Arithmétique'),
                areaOrdinal: const Value(0),
              ),
            );
      }
    }

    Future<void> complete(String kid, int upTo) async {
      final progress = NodeProgressLocal(db, kidId: kid);
      for (var i = 0; i < upTo; i++) {
        await progress.recordCompleted(
          node(i),
          perfect: true,
          exerciseId: ex(i),
        );
      }
    }

    Future<Set<String>> cachedNodes() async => {
      for (final row in await db.select(db.exerciseCacheTable).get())
        row.skillNodeId,
    };

    Set<String> range(int from, int to) => {
      for (var i = from; i < to && i < leaves; i++) node(i),
    };

    ContentSync windowed() => ContentSync(
      db: db,
      api: server,
      accessToken: () => 'token',
      planWindow: OfflineWindowPlanner(
        db: db,
        kids: () async => kids,
        activeKidId: () => active,
      ).plan,
    );

    setUp(() async {
      db = LocalDatabase.memory();
      server = FakeContentServer();
      for (var i = 0; i < leaves; i++) {
        server.content[ex(i)] = exercise(i);
      }
      kids = const [PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1)];
      active = 'lea';
      await seedCurriculum();
      sync = windowed();
    });

    tearDown(() => db.close());

    test('a fresh device downloads the window, and knows the rest', () async {
      final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(report.isOk, isTrue);
      expect(report.downloaded, offlineWindowLeaves);
      expect(await cachedNodes(), range(0, 25));
      expect(
        await db.select(db.manifestEntryTable).get(),
        hasLength(leaves),
        reason: 'every published lesson is known, downloaded or not',
      );
    });

    test(
      'the frontier moves: the window follows, evictions are counted',
      () async {
        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        await complete('lea', 5);

        final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(report.downloaded, 5, reason: 'n25..n29 join the window');
        expect(report.evicted, 2, reason: 'n0, n1 fall 4+ behind the frontier');
        expect(await cachedNodes(), range(2, 30));

        final stats = await sync.offlineStats();
        expect(stats.evictedTotal, 2);
        expect(stats.lastEvictedAt, isNotNull);
        expect(stats.bySubject['MATH']!.leaves, 28);
      },
    );

    test('siblings at one grade: the device keeps the union', () async {
      kids = const [
        PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1),
        PairedKid(id: 'noah', displayName: 'Noah', gradeLevel: 1),
      ];
      // Noah plays first, from the start of the path.
      active = 'noah';
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await cachedNodes(), range(0, 25));

      // Léa is far ahead. Her sync downloads her window and evicts
      // nothing Noah is still inside.
      await complete('lea', 20);
      active = 'lea';
      final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(report.evicted, 0);
      expect(await cachedNodes(), {...range(0, 25), ...range(17, 45)});
    });

    test(
      'a sibling with no stored window is guessed from their own record',
      () async {
        kids = const [
          PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1),
          PairedKid(id: 'noah', displayName: 'Noah', gradeLevel: 1),
        ];
        await complete('noah', 10); // Noah never synced on this build
        await complete('lea', 30);
        // A device that held the whole grade: what stays is the union.
        await ContentSync(
          db: db,
          api: server,
          accessToken: () => 't',
        ).sync(subject: 'MATH', locale: 'fr-CA');
        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(await cachedNodes(), {...range(7, 35), ...range(27, 45)});
      },
    );

    test('another grade\'s sibling is never touched', () async {
      await db
          .into(db.exerciseCacheTable)
          .insert(
            ExerciseCacheTableCompanion.insert(
              exerciseId: 'g3',
              version: 1,
              payload: '{}',
              contentHash: 'h',
              engineKey: 'mcq',
              skillNodeId: 'grade-3-node',
              subject: 'MATH',
              grade: 3,
              rank: 0,
              cachedAt: DateTime.utc(2026),
            ),
          );
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await cachedNodes(), contains('grade-3-node'));
    });

    group('eviction never takes', () {
      setUp(() async {
        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        await complete('lea', 10); // n0..n6 fall out of the window
      });

      test('a lesson with an unfinished game', () async {
        await db
            .into(db.activitySessionTable)
            .insert(
              ActivitySessionTableCompanion.insert(
                activitySessionId: 's1',
                kidId: 'lea',
                exerciseId: ex(0),
                snapshot: '{}',
                updatedAt: DateTime.utc(2026, 10, 29),
              ),
            );
        final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(report.evicted, 6);
        expect(await cachedNodes(), contains(node(0)));
      });

      test('the lesson on screen', () async {
        sync.inUse.hold(ex(3));
        final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(report.evicted, 6);
        expect(await cachedNodes(), contains(node(3)));

        sync.inUse.release(ex(3));
        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(await cachedNodes(), isNot(contains(node(3))));
      });

      test('anything, when the sync goes offline', () async {
        server.offline = true;
        final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(report.offline, isTrue);
        expect(await cachedNodes(), range(0, 25));
      });

      test('anything, when the prefetch fails halfway', () async {
        server.failFetchAfter = 0;
        final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
        expect(report.error, isNotNull);
        expect(await cachedNodes(), range(0, 25), reason: 'old cache intact');
        expect((await sync.offlineStats()).evictedTotal, 0);
      });
    });

    test('an interrupted prefetch resumes where it stopped', () async {
      // No curriculum, so the whole grade: 40 lessons, 25 per request. The
      // second request fails.
      await db.delete(db.skillNodeTable).go();
      server.failFetchAfter = 25;
      final first = await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(first.error, isNotNull);
      expect(await cachedNodes(), hasLength(25), reason: 'first chunk kept');

      server.failFetchAfter = null;
      server.requestedIds.clear();
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(server.requestedIds, hasLength(15), reason: 'only the rest');
      expect(await cachedNodes(), range(0, leaves));
    });

    test('a shared picture goes with the last lesson using it', () async {
      final png = Uint8List.fromList([1, 2, 3]);
      final sha = bytesSha256(png);
      final asset = {
        'ref': 'img',
        'url': 'http://x/p.png',
        'sha256': sha,
        'media_type': 'image/png',
      };
      server.content[ex(0)] = exercise(0, assets: [asset]);
      server.content[ex(5)] = exercise(5, assets: [asset]);
      server.audio['http://x/p.png'] = png; // pictures share the fake's map

      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      await complete('lea', 5); // n0, n1 leave; n5 stays
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await db.select(db.assetCacheTable).get(), hasLength(1));

      await complete('lea', 12); // n5 leaves too
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await db.select(db.assetCacheTable).get(), isEmpty);
    });

    test('audio goes with its lesson, and a known clip is copied', () async {
      final clip = Uint8List.fromList([9, 9, 9]);
      final sha = bytesSha256(clip);
      Map<String, Object?> audio(String url) => {
        'ref': 'audio',
        'url': url,
        'sha256': sha,
        'media_type': 'audio/wav',
      };
      server.content[ex(0)] = exercise(0, assets: [audio('http://x/a.wav')]);
      server.content[ex(1)] = exercise(1, assets: [audio('http://x/b.wav')]);
      server.audio['http://x/a.wav'] = clip;
      server.audio['http://x/b.wav'] = clip;

      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await db.select(db.audioCacheTable).get(), hasLength(2));
      expect(server.audioRequestedUrls, hasLength(1), reason: 'copied once');

      await complete('lea', 5); // n0, n1 leave
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await db.select(db.audioCacheTable).get(), isEmpty);
      expect((await sync.offlineStats()).audioRemovedTotal, 2);
    });

    test('a device holding the whole grade shrinks on its first sync, '
        'keeping the game in progress', () async {
      // Before the window: everything.
      final old = ContentSync(db: db, api: server, accessToken: () => 't');
      await old.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await cachedNodes(), range(0, leaves));
      await db
          .into(db.activitySessionTable)
          .insert(
            ActivitySessionTableCompanion.insert(
              activitySessionId: 's1',
              kidId: 'lea',
              exerciseId: ex(33),
              snapshot: '{}',
              updatedAt: DateTime.utc(2026, 10, 29),
            ),
          );

      final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(report.downloaded, 0, reason: 'nothing new to fetch');
      expect(report.evicted, leaves - 25 - 1);
      expect(await cachedNodes(), {...range(0, 25), node(33)});
    });

    test('a tap downloads one leaf outside the window', () async {
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(await cachedNodes(), isNot(contains(node(30))));

      final result = await sync.downloadNode(
        skillNodeId: node(30),
        grade: 1,
        askedLocale: 'fr-CA',
      );
      expect(result, NodeDownload.done);
      expect(await cachedNodes(), contains(node(30)));

      server.offline = true;
      expect(
        await sync.downloadNode(
          skillNodeId: node(31),
          grade: 1,
          askedLocale: 'fr-CA',
        ),
        NodeDownload.offline,
      );
    });

    test('no cached curriculum: the whole grade, as before', () async {
      await db.delete(db.skillNodeTable).go();
      final report = await sync.sync(subject: 'MATH', locale: 'fr-CA');
      expect(report.downloaded, leaves);
      expect(report.evicted, 0);
    });
  });
}
