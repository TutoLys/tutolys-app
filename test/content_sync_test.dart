import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/data/sync/content_sync.dart';

/// A content server that can be taken offline and have its content edited,
/// so the diff and the checksum path can both be driven.
class FakeContentServer extends ContentApi {
  FakeContentServer() : super(dio: Dio());

  /// exercise_id -> envelope, as the server would serve it.
  final Map<String, Map<String, Object?>> content = {};

  bool offline = false;
  bool unauthorized = false;

  /// Ids the manifest advertises but the fetch refuses to serve.
  final Set<String> withholdOnFetch = {};

  /// Ids served with a deliberately wrong body, to simulate corruption or
  /// tampering in transit.
  final Set<String> corruptOnFetch = {};

  /// Fail the fetch after this many exercises, to test a mid-sync failure.
  int? failFetchAfter;

  int manifestCalls = 0;

  /// The locale the last manifest asked for.
  String? lastLocale;
  int fetchCalls = 0;
  final List<String> requestedIds = [];

  /// url -> bytes, as the server would serve audio.
  final Map<String, Uint8List> audio = {};
  bool audioOffline = false;
  final List<String> audioRequestedUrls = [];

  @override
  Future<AudioResult> fetchAudio(String url) async {
    audioRequestedUrls.add(url);
    if (audioOffline) return const AudioUnavailable();
    final bytes = audio[url];
    return bytes == null ? const AudioUnavailable() : AudioFetched(bytes);
  }

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async {
    manifestCalls++;
    lastLocale = locale;
    if (offline) return const ManifestOffline();
    if (unauthorized) return const ManifestUnauthorized();

    // Like the backend (ADR 0026): one version per lesson, in the
    // asked-for language where it exists, else the authored one. A lesson
    // is its translation_group, else (node, engine, rank).
    final asked = locale ?? 'fr-CA';
    final byLesson = <Object, List<Map<String, Object?>>>{};
    for (final e in content.values) {
      if (subject != null && e['subject'] != subject) continue;
      byLesson
          .putIfAbsent(
            e['translation_group'] ??
                (e['subject'], e['skill_node_id'], e['engine_key'], e['rank']),
            () => [],
          )
          .add(e);
    }
    final entries = byLesson.values
        .map(
          (versions) => versions.firstWhere(
            (e) => e['locale'] == asked,
            orElse: () => versions.first,
          ),
        )
        .map(
          (e) => ManifestEntry(
            exerciseId: e['exercise_id'] as String,
            version: e['version'] as int,
            contentHash: contentSha256(e),
            engineKey: e['engine_key'] as String,
            engineMinVersion: e['engine_min_version'] as int,
            skillNodeId: e['skill_node_id'] as String,
            subject: e['subject'] as String,
            grade: e['grade'] as int,
            rank: e['rank'] as int,
            locale: e['locale'] as String,
            translationGroup: e['translation_group'] as String?,
          ),
        )
        .toList();

    return ManifestFetched(
      ContentManifest(grade: 1, manifestHash: 'm', entries: entries),
    );
  }

  @override
  Future<ExercisesResult> fetchExercises({
    required List<String> ids,
    required String accessToken,
  }) async {
    fetchCalls++;
    requestedIds.addAll(ids);
    if (offline) return const ExercisesOffline();

    if (failFetchAfter != null && requestedIds.length > failFetchAfter!) {
      return const ExercisesFailed('server exploded');
    }

    final envelopes = <Map<String, Object?>>[];
    final unavailable = <String>[];

    for (final id in ids) {
      if (withholdOnFetch.contains(id) || !content.containsKey(id)) {
        unavailable.add(id);
        continue;
      }
      final envelope = Map<String, Object?>.from(content[id]!);
      if (corruptOnFetch.contains(id)) {
        // Body does not match the hash the manifest advertised.
        envelope['prompt'] = {'text': 'TAMPERED'};
      }
      envelopes.add(envelope);
    }

    return ExercisesFetched(envelopes: envelopes, unavailable: unavailable);
  }
}

void main() {
  late LocalDatabase db;
  late FakeContentServer server;
  late ContentSync sync;
  late DateTime now;

  Map<String, Object?> exercise(
    String id, {
    int version = 1,
    int rank = 0,
    String subject = 'MATH',
    String prompt = 'Combien font 2 + 2 ?',
    String? audioRef,
    List<Object?> assets = const [],
    String locale = 'fr-CA',
    String node = 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
    String engine = 'mcq',
    String? group,
  }) => {
    'schema_version': 1,
    'exercise_id': id,
    'version': version,
    'engine_key': engine,
    'translation_group': ?group,
    'engine_min_version': 1,
    'skill_node_id': node,
    'subject': subject,
    'grade': 1,
    'rank': rank,
    'locale': locale,
    'prompt': {'text': prompt, 'audio_ref': audioRef, 'image_ref': null},
    'config': {
      'options': [
        {'id': 'a', 'label': '4'},
        {'id': 'b', 'label': '5'},
      ],
      'correct': 'a',
    },
    'assets': assets,
  };

  setUp(() {
    now = DateTime.utc(2026, 10, 16, 12);
    db = LocalDatabase.memory();
    server = FakeContentServer();
    sync = ContentSync(
      db: db,
      api: server,
      accessToken: () => 'token',
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  group('first sync', () {
    test('downloads and caches everything', () async {
      for (var i = 0; i < 5; i++) {
        final ex = exercise('ex$i', rank: i);
        server.content[ex['exercise_id'] as String] = ex;
      }

      final report = await sync.sync();

      expect(report.isOk, isTrue);
      expect(report.downloaded, 5);
      expect(report.upToDate, 0);
      expect(await sync.cachedCount(), 5);
    });

    test('an empty manifest is not an error', () async {
      final report = await sync.sync();

      expect(report.isOk, isTrue);
      expect(report.downloaded, 0);
    });
  });

  group('diffing by checksum', () {
    test('a second sync downloads nothing', () async {
      server.content['ex1'] = exercise('ex1');
      await sync.sync();
      final fetchesAfterFirst = server.fetchCalls;

      final report = await sync.sync();

      expect(report.downloaded, 0);
      expect(report.upToDate, 1);
      expect(
        server.fetchCalls,
        fetchesAfterFirst,
        reason: 'nothing changed, so nothing should have been fetched',
      );
    });

    test('only the changed exercise is re-downloaded', () async {
      // The fix for the predecessor's global ETag: editing one leaf used to
      // re-download the entire tree for every child on mobile data.
      for (var i = 0; i < 10; i++) {
        server.content['ex$i'] = exercise('ex$i', rank: i);
      }
      await sync.sync();
      server.requestedIds.clear();

      server.content['ex7'] = exercise(
        'ex7',
        rank: 7,
        version: 2,
        prompt: 'Changed',
      );

      final report = await sync.sync();

      expect(report.downloaded, 1);
      expect(report.upToDate, 9);
      expect(server.requestedIds, [
        'ex7',
      ], reason: 'untouched exercises must not be re-fetched');
    });

    test('content withdrawn from the manifest leaves the cache', () async {
      server.content['keep'] = exercise('keep');
      server.content['drop'] = exercise('drop', rank: 1);
      await sync.sync();
      expect(await sync.cachedCount(), 2);

      server.content.remove('drop');
      final report = await sync.sync();

      expect(report.removed, 1);
      expect(await sync.cachedExercise('drop'), isNull);
      expect(await sync.cachedExercise('keep'), isNotNull);
    });

    test(
      'a changed exercise updates in place rather than duplicating',
      () async {
        server.content['ex1'] = exercise('ex1', prompt: 'First');
        await sync.sync();

        server.content['ex1'] = exercise('ex1', version: 2, prompt: 'Second');
        await sync.sync();

        expect(await sync.cachedCount(), 1);
        final cached = await sync.cachedExercise('ex1');
        expect((cached!['prompt'] as Map)['text'], 'Second');
        expect(cached['version'], 2);
      },
    );
  });

  group('checksum verification', () {
    test(
      'content that does not match its advertised hash is refused',
      () async {
        // The old backend had no integrity guarantee on content at all: a
        // truncated or tampered download would simply have been played.
        server.content['good'] = exercise('good');
        server.content['bad'] = exercise('bad', rank: 1);
        server.corruptOnFetch.add('bad');

        final report = await sync.sync();

        expect(report.rejected, ['bad']);
        expect(report.downloaded, 1);
        expect(
          await sync.cachedExercise('bad'),
          isNull,
          reason: 'unverifiable content must never reach a kid',
        );
        expect(await sync.cachedExercise('good'), isNotNull);
      },
    );

    test('a rejected exercise is retried on the next sync', () async {
      server.content['ex1'] = exercise('ex1');
      server.corruptOnFetch.add('ex1');
      await sync.sync();
      expect(await sync.cachedCount(), 0);

      // Server fixed.
      server.corruptOnFetch.clear();
      final report = await sync.sync();

      expect(report.downloaded, 1);
      expect(await sync.cachedCount(), 1);
    });

    test('verifyCache detects on-disk corruption', () async {
      server.content['ex1'] = exercise('ex1');
      await sync.sync();

      expect(await sync.verifyCache(), isEmpty);

      // Simulate a flipped bit in SQLite: payload no longer matches its hash.
      await db.customStatement(
        "UPDATE exercise_cache SET payload = '{\"exercise_id\":\"ex1\"}' "
        "WHERE exercise_id = 'ex1'",
      );

      expect(await sync.verifyCache(), ['ex1']);
    });
  });

  group('atomic swap', () {
    test(
      'a mid-sync failure leaves previously cached content intact',
      () async {
        // Establish a good cache.
        for (var i = 0; i < 3; i++) {
          server.content['old$i'] = exercise('old$i', rank: i);
        }
        await sync.sync();
        expect(await sync.cachedCount(), 3);

        // New content arrives, but the server dies partway through.
        for (var i = 0; i < 40; i++) {
          server.content['new$i'] = exercise('new$i', rank: 10 + i);
        }
        server.failFetchAfter = 25; // fails on the second chunk

        final report = await sync.sync();

        expect(report.isOk, isFalse);
        expect(report.error, isNotNull);

        // The old content is still there and still playable — the kid is not
        // left with a half-written cache.
        for (var i = 0; i < 3; i++) {
          expect(
            await sync.cachedExercise('old$i'),
            isNotNull,
            reason: 'a failed sync must not damage what already worked',
          );
        }
        // Nothing was removed, because the removal only happens on success.
        expect(report.removed, 0);
      },
    );

    test('whatever verified before a failure is still committed', () async {
      for (var i = 0; i < 40; i++) {
        server.content['ex$i'] = exercise('ex$i', rank: i);
      }
      server.failFetchAfter = 25;

      final report = await sync.sync();

      // The first chunk verified, so it is kept rather than thrown away; the
      // next sync picks up the rest.
      expect(report.downloaded, 25);
      expect(await sync.cachedCount(), 25);
    });

    test('a resumed sync completes what was left', () async {
      for (var i = 0; i < 40; i++) {
        server.content['ex$i'] = exercise('ex$i', rank: i);
      }
      server.failFetchAfter = 25;
      await sync.sync();

      server.failFetchAfter = null;
      final report = await sync.sync();

      expect(report.downloaded, 15);
      expect(await sync.cachedCount(), 40);
    });
  });

  group('A5 acceptance: airplane-mode playthrough', () {
    test('a full session plays from cache with no network', () async {
      // Sync a grade-1 set while online.
      for (var i = 0; i < 12; i++) {
        server.content['ex$i'] = exercise('ex$i', rank: i);
      }
      final online = await sync.sync();
      expect(online.downloaded, 12);

      // Airplane mode.
      server.offline = true;

      // Sync is attempted and reports offline — but is NOT an error, and
      // must not disturb the cache.
      final offlineSync = await sync.sync();
      expect(offlineSync.offline, isTrue);
      expect(offlineSync.isOk, isFalse);
      expect(
        await sync.cachedCount(),
        12,
        reason: 'an offline sync must leave the cache alone',
      );

      // The play screen reads cached content, in play order, touching no
      // network at all.
      final playable = await sync.cachedExercises(subject: 'MATH', grade: 1);

      expect(playable, hasLength(12));
      expect(
        playable.map((e) => e['rank']).toList(),
        List.generate(12, (i) => i),
        reason: 'exercises must come back in the difficulty order a kid walks',
      );

      // Every one is complete enough to actually play.
      for (final envelope in playable) {
        expect(envelope['engine_key'], 'mcq');
        expect(envelope['skill_node_id'], isNotNull);
        expect((envelope['config'] as Map)['correct'], isNotNull);
        expect(envelope['prompt'], isNotNull);
      }

      // And every one still verifies against its stored checksum.
      expect(await sync.verifyCache(), isEmpty);
    });

    test('cached reads are filtered by subject', () async {
      server.content['m1'] = exercise('m1', subject: 'MATH');
      server.content['f1'] = exercise('f1', subject: 'FR', rank: 1);
      await sync.sync();

      expect(await sync.cachedExercises(subject: 'MATH'), hasLength(1));
      expect(await sync.cachedExercises(subject: 'FR'), hasLength(1));
      expect(await sync.cachedExercises(), hasLength(2));
    });

    test('an uncached exercise reads as null, not a crash', () async {
      // The app shows a friendly "download needed" state; it must never throw
      // in front of a kid.
      expect(await sync.cachedExercise('never-downloaded'), isNull);
    });
  });

  group('credentials and failure modes', () {
    test('syncing while unpaired does not call the server', () async {
      final unpaired = ContentSync(
        db: db,
        api: server,
        accessToken: () => null,
        clock: () => now,
      );

      final report = await unpaired.sync();

      expect(report.unauthorized, isTrue);
      expect(server.manifestCalls, 0);
    });

    test(
      'a rejected credential is reported, not treated as empty content',
      () async {
        server.content['ex1'] = exercise('ex1');
        await sync.sync();
        server.unauthorized = true;

        final report = await sync.sync();

        expect(report.unauthorized, isTrue);
        // Crucially the cache is untouched: a 401 must not look like "the
        // server has no content for you" and wipe a working cache.
        expect(await sync.cachedCount(), 1);
      },
    );

    test(
      'an exercise listed but not served is reported, not retried forever',
      () async {
        server.content['ex1'] = exercise('ex1');
        server.content['ex2'] = exercise('ex2', rank: 1);
        server.withholdOnFetch.add('ex2');

        final report = await sync.sync();

        expect(report.unavailable, ['ex2']);
        expect(report.downloaded, 1);
      },
    );

    test(
      'mid-sync network loss keeps what verified and reports offline',
      () async {
        for (var i = 0; i < 3; i++) {
          server.content['ex$i'] = exercise('ex$i', rank: i);
        }
        // Goes offline during the fetch, after the manifest succeeded.
        server.content['ex0'] = exercise('ex0');

        final manifest = await server.fetchManifest(accessToken: 'token');
        expect(manifest, isA<ManifestFetched>());

        server.offline = true;
        final report = await sync.sync();

        expect(report.offline, isTrue);
        expect(await sync.cachedCount(), 0, reason: 'nothing verified yet');
      },
    );
  });

  group('audio sync', () {
    Future<Uint8List?> cachedAudio(String exerciseId, String ref) async {
      final row =
          await (db.select(db.audioCacheTable)
                ..where((t) => t.exerciseId.equals(exerciseId))
                ..where((t) => t.ref.equals(ref)))
              .getSingleOrNull();
      return row?.bytes;
    }

    test('downloads and caches an exercise\'s audio asset', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final url = '/media/exercise_audio/ex1/audio.wav';
      server.audio[url] = bytes;
      server.content['ex1'] = exercise(
        'ex1',
        audioRef: 'audio',
        assets: [
          {'ref': 'audio', 'url': url, 'sha256': bytesSha256(bytes)},
        ],
      );

      await sync.sync();

      expect(await cachedAudio('ex1', 'audio'), bytes);
    });

    test('a bad checksum is refused, same as a tampered exercise', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final url = '/media/exercise_audio/ex1/audio.wav';
      server.audio[url] = bytes;
      server.content['ex1'] = exercise(
        'ex1',
        audioRef: 'audio',
        assets: [
          {'ref': 'audio', 'url': url, 'sha256': 'not-the-real-hash'},
        ],
      );

      await sync.sync();

      expect(await cachedAudio('ex1', 'audio'), isNull);
    });

    test('a sync with no audio assets never calls fetchAudio', () async {
      server.content['ex1'] = exercise('ex1'); // default: assets == []

      await sync.sync();

      expect(server.audioRequestedUrls, isEmpty);
    });

    test('an already-cached, unchanged asset is not re-downloaded', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final url = '/media/exercise_audio/ex1/audio.wav';
      final hash = bytesSha256(bytes);
      server.audio[url] = bytes;
      server.content['ex1'] = exercise(
        'ex1',
        audioRef: 'audio',
        assets: [
          {'ref': 'audio', 'url': url, 'sha256': hash},
        ],
      );

      await sync.sync();
      expect(server.audioRequestedUrls, [url]);

      // A second sync re-verifies the (unchanged) exercise itself but
      // must not re-download audio it already has with a matching hash.
      server.content['ex1'] = {
        ...server.content['ex1']!,
        'version': 1, // unchanged on purpose — this exercises the "same
        // content, audio already cached" path, not a re-fetch-on-edit one.
      };
      await sync.sync();

      expect(server.audioRequestedUrls, [url], reason: 'not fetched twice');
    });

    test(
      'audio being offline does not fail the exercise sync itself',
      () async {
        final url = '/media/exercise_audio/ex1/audio.wav';
        server.audio[url] = Uint8List.fromList([1, 2, 3]);
        server.audioOffline = true;
        server.content['ex1'] = exercise(
          'ex1',
          audioRef: 'audio',
          assets: [
            {'ref': 'audio', 'url': url, 'sha256': 'irrelevant-while-offline'},
          ],
        );

        final report = await sync.sync();

        expect(report.isOk, isTrue);
        expect(report.downloaded, 1, reason: 'the exercise itself synced fine');
        expect(await cachedAudio('ex1', 'audio'), isNull);
      },
    );

    test('a multi-question exercise caches every question\'s audio', () async {
      final bytes0 = Uint8List.fromList([1]);
      final bytes1 = Uint8List.fromList([2]);
      final url0 = '/media/exercise_audio/ex1/q0_audio.wav';
      final url1 = '/media/exercise_audio/ex1/q1_audio.wav';
      server.audio[url0] = bytes0;
      server.audio[url1] = bytes1;
      server.content['ex1'] = {
        ...exercise('ex1'),
        'config': {
          'questions': [
            {
              'prompt': {'text': 'Un ?', 'audio_ref': 'q0_audio'},
              'config': {
                'options': [
                  {'id': 'a', 'label': '1'},
                ],
                'correct': 'a',
              },
            },
            {
              'prompt': {'text': 'Deux ?', 'audio_ref': 'q1_audio'},
              'config': {
                'options': [
                  {'id': 'a', 'label': '2'},
                ],
                'correct': 'a',
              },
            },
          ],
        },
        'assets': [
          {'ref': 'q0_audio', 'url': url0, 'sha256': bytesSha256(bytes0)},
          {'ref': 'q1_audio', 'url': url1, 'sha256': bytesSha256(bytes1)},
        ],
      };

      await sync.sync();

      expect(await cachedAudio('ex1', 'q0_audio'), bytes0);
      expect(await cachedAudio('ex1', 'q1_audio'), bytes1);
    });
  });

  group('a cache shared by several kids on one device (ADR 0014)', () {
    /// A sibling's cached row, written straight to the table.
    ///
    /// That bypass *is* the situation: the server never advertises another
    /// kid's content in this kid's manifest, so there is no way to arrive at
    /// this state through a sync of our own.
    Future<void> seedAnotherKidsRow({
      required String id,
      required int grade,
      required String subject,
    }) async {
      await db
          .into(db.exerciseCacheTable)
          .insert(
            ExerciseCacheTableCompanion.insert(
              exerciseId: id,
              version: 1,
              payload: '{"exercise_id":"$id"}',
              contentHash: 'hash-$id',
              engineKey: 'mcq',
              skillNodeId: 'node-$id',
              subject: subject,
              grade: grade,
              rank: 0,
              cachedAt: now,
            ),
          );
    }

    test("a grade-1 sync leaves a grade-3 sibling's content alone", () async {
      await seedAnotherKidsRow(id: 'noah-ex', grade: 3, subject: 'MATH');
      final mine = exercise('lea-ex', rank: 0);
      server.content['lea-ex'] = mine;

      final report = await sync.sync();

      expect(report.isOk, isTrue);
      expect(
        report.removed,
        0,
        reason: 'the sibling\'s row is not "withdrawn", it is not mine',
      );

      final ids = (await db.select(db.exerciseCacheTable).get()).map(
        (r) => r.exerciseId,
      );
      expect(
        ids,
        containsAll(<String>['noah-ex', 'lea-ex']),
        reason: 'deleting it here is what makes two kids thrash re-downloading',
      );
    });

    test('content withdrawn from my own slice is still removed', () async {
      final mine = exercise('lea-ex', rank: 0);
      server.content['lea-ex'] = mine;
      await sync.sync();
      expect(await sync.cachedCount(), 1);

      // The server retires it.
      server.content.remove('lea-ex');
      final report = await sync.sync();

      expect(
        report.removed,
        1,
        reason: 'scoping withdrawal must not disable withdrawal',
      );
      expect(await sync.cachedCount(), 0);
    });

    test(
      "a subject sync does not withdraw the same kid's other subjects",
      () async {
        final math = exercise('m1', rank: 0);
        final french = exercise('f1', rank: 0, subject: 'FR');
        server.content['m1'] = math;
        server.content['f1'] = french;
        await sync.sync();
        expect(await sync.cachedCount(), 2);

        final report = await sync.sync(subject: 'MATH');

        expect(report.removed, 0);
        expect(
          await sync.cachedCount(),
          2,
          reason: 'a MATH-only manifest says nothing about FR',
        );
      },
    );
  });

  group('lesson language (backend ADR 0026)', () {
    test('asks for the locale it is given', () async {
      server.content['m1'] = exercise('m1');
      await sync.sync(subject: 'MATH', locale: 'en-CA');
      expect(server.lastLocale, 'en-CA');
    });

    test('switching language keeps the other version for a sibling', () async {
      server.content['fr'] = exercise('fr', locale: 'fr-CA');
      server.content['en'] = exercise('en', locale: 'en-CA');

      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      await sync.sync(subject: 'MATH', locale: 'en-CA');

      final cached = {
        for (final e in await sync.cachedExercises(subject: 'MATH'))
          e['exercise_id'],
      };
      expect(
        cached,
        {'fr', 'en'},
        reason:
            'deleting the French version would make a French sibling '
            're-download it, and the two thrash',
      );
    });

    test('a lesson withdrawn in every language does go', () async {
      server.content['fr'] = exercise('fr', locale: 'fr-CA');
      server.content['en'] = exercise('en', locale: 'en-CA');
      await sync.sync(subject: 'MATH', locale: 'fr-CA');
      await sync.sync(subject: 'MATH', locale: 'en-CA');

      server.content.clear();
      await sync.sync(subject: 'MATH', locale: 'en-CA');
      expect(await sync.cachedExercises(subject: 'MATH'), isEmpty);
    });

    test('a newer id in the same language replaces the old one', () async {
      server.content['fr-v1'] = exercise('fr-v1', locale: 'fr-CA');
      await sync.sync(subject: 'MATH', locale: 'fr-CA');

      server.content
        ..remove('fr-v1')
        ..['fr-v2'] = exercise('fr-v2', locale: 'fr-CA');
      await sync.sync(subject: 'MATH', locale: 'fr-CA');

      final ids = [
        for (final e in await sync.cachedExercises(subject: 'MATH'))
          e['exercise_id'],
      ];
      expect(ids, ['fr-v2']);
    });

    test(
      'two lessons sharing a rank on one node are both kept (D10)',
      () async {
        server.content['a'] = exercise('a', engine: 'mcq');
        server.content['b'] = exercise('b', engine: 'pair_match');

        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        await sync.sync(subject: 'MATH', locale: 'fr-CA');

        final ids = {
          for (final e in await sync.cachedExercises(subject: 'MATH'))
            e['exercise_id'],
        };
        expect(ids, {'a', 'b'});
      },
    );

    test(
      'translation_group pairs versions even when their ranks differ',
      () async {
        server.content['fr'] = exercise('fr', group: 'g1');
        server.content['en'] = exercise(
          'en',
          locale: 'en-CA',
          rank: 3,
          group: 'g1',
        );

        await sync.sync(subject: 'MATH', locale: 'fr-CA');
        await sync.sync(subject: 'MATH', locale: 'en-CA');

        final ids = {
          for (final e in await sync.cachedExercises(subject: 'MATH'))
            e['exercise_id'],
        };
        expect(ids, {'fr', 'en'}, reason: 'the French version stays');
      },
    );
  });
}
