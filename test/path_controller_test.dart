import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeCurriculumApi extends CurriculumApi {
  _FakeCurriculumApi() : super(dio: Dio());

  List<CurriculumLeaf> leaves = const [];
  bool offline = false;

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    if (offline) return const CurriculumTreeOffline();
    return CurriculumTreeFetched(leaves);
  }
}

class _FakeContentApi extends ContentApi {
  _FakeContentApi() : super(dio: Dio());

  /// exercise_id -> envelope.
  final Map<String, Map<String, Object?>> content = {};

  /// Every (subject, locale) a manifest was asked for, in order.
  final List<(String?, String?)> asked = [];

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async {
    asked.add((subject, locale));
    final entries = content.values
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
    return ExercisesFetched(
      envelopes: ids.map((id) => content[id]!).toList(),
      unavailable: ids.where((id) => !content.containsKey(id)).toList(),
    );
  }
}

Map<String, Object?> exercise({
  required String id,
  required String skillNodeId,
  int rank = 0,
}) {
  return {
    'exercise_id': id,
    'version': 1,
    'engine_key': 'mcq',
    'engine_min_version': 1,
    'skill_node_id': skillNodeId,
    'subject': 'MATH',
    'grade': 1,
    'rank': rank,
    'locale': 'fr-CA',
    'prompt': {
      'text': 'Combien font 2 + 2 ?',
      'audio_ref': null,
      'image_ref': null,
    },
    'config': const {
      'options': [
        {'id': 'a', 'label': '4'},
      ],
      'correct': 'a',
    },
    'assets': const <Object?>[],
  };
}

void main() {
  late ProviderContainer container;
  late _FakeCurriculumApi curriculumApi;
  late _FakeContentApi contentApi;

  ProviderContainer build({SessionState? session, bool prefetch = false}) {
    curriculumApi = _FakeCurriculumApi();
    contentApi = _FakeContentApi();
    return ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
        curriculumApiProvider.overrideWithValue(curriculumApi),
        contentApiProvider.overrideWithValue(contentApi),
        offlinePrefetchProvider.overrideWithValue(prefetch),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(
            session ??
                const SessionState(
                  status: SessionStatus.paired,
                  kid: PairedKid(
                    id: 'k1',
                    displayName: 'Yelhan',
                    gradeLevel: 1,
                  ),
                  accessToken: 'token',
                ),
          ),
        ),
      ],
    );
  }

  tearDown(() async {
    // `build()` itself kicks off a `_load` via an unawaited microtask (same
    // fire-and-forget deferral `SessionController.build()` already uses) —
    // on top of this test's own explicit, awaited `refresh()` call. Without
    // draining the queue first, that first call can still be mid-flight
    // when `dispose()` runs, which throws ("Cannot use the Ref... after it
    // has been disposed") rather than a clean no-op.
    await pumpEventQueue();
    container.dispose();
  });

  test('an available leaf is one with a synced exercise', () async {
    container = build();
    curriculumApi.leaves = const [
      CurriculumLeaf(
        id: 'leaf-1',
        labelFr: 'Compter',
        labelEn: '',
        stableKey: 'math/1',
      ),
      CurriculumLeaf(
        id: 'leaf-2',
        labelFr: 'Additionner',
        labelEn: '',
        stableKey: 'math/2',
      ),
    ];
    final ex = exercise(id: 'ex-1', skillNodeId: 'leaf-1');
    contentApi.content[ex['exercise_id'] as String] = ex;

    await container.read(pathControllerProvider.notifier).refresh();

    final state = container.read(pathControllerProvider);
    expect(state.loading, isFalse);
    expect(state.leaves.map((l) => l.id).toSet(), {'leaf-1', 'leaf-2'});
    expect(
      state.isAvailable(state.leaves.firstWhere((l) => l.id == 'leaf-1')),
      isTrue,
    );
    expect(
      state.isAvailable(state.leaves.firstWhere((l) => l.id == 'leaf-2')),
      isFalse,
    );
  });

  test('a node keeps all its lessons, the lowest rank first', () async {
    container = build();
    curriculumApi.leaves = const [
      CurriculumLeaf(
        id: 'leaf-1',
        labelFr: 'Compter',
        labelEn: '',
        stableKey: 'math/1',
      ),
    ];
    contentApi.content['ex-2'] = exercise(
      id: 'ex-2',
      skillNodeId: 'leaf-1',
      rank: 2,
    );
    contentApi.content['ex-1'] = exercise(
      id: 'ex-1',
      skillNodeId: 'leaf-1',
      rank: 0,
    );

    await container.read(pathControllerProvider.notifier).refresh();

    final state = container.read(pathControllerProvider);
    expect(state.exerciseByNodeId['leaf-1']!['exercise_id'], 'ex-1');
    expect(state.lessonsByNodeId['leaf-1']!.map((e) => e['exercise_id']), [
      'ex-1',
      'ex-2',
    ], reason: 'every lesson on the node stays reachable, in rank order');
  });

  test(
    'no paired kid: stays non-loading with nothing to show, no network calls',
    () async {
      container = build(session: const SessionState.unpaired());

      await container.read(pathControllerProvider.notifier).refresh();

      final state = container.read(pathControllerProvider);
      expect(state.loading, isFalse);
      expect(state.leaves, isEmpty);
    },
  );

  test('offline sync still surfaces whatever was cached before', () async {
    container = build();
    curriculumApi.leaves = const [
      CurriculumLeaf(
        id: 'leaf-1',
        labelFr: 'Compter',
        labelEn: '',
        stableKey: 'math/1',
      ),
    ];
    await container.read(pathControllerProvider.notifier).refresh();

    curriculumApi.offline = true;
    await container.read(pathControllerProvider.notifier).refresh();

    final state = container.read(pathControllerProvider);
    expect(state.offline, isTrue);
    expect(state.leaves.map((l) => l.id), [
      'leaf-1',
    ], reason: 'offline must not clear the cache');
  });

  test('a first load online prefetches every other subject, once', () async {
    container = build(prefetch: true);
    await container.read(pathControllerProvider.notifier).refresh();
    await pumpEventQueue(times: 200);

    expect(
      contentApi.asked.map((a) => a.$1).toSet(),
      pathSubjects.toSet(),
      reason: 'the whole village plays offline (ADR 0095)',
    );
    final count = contentApi.asked.length;
    await container.read(pathControllerProvider.notifier).refresh();
    await pumpEventQueue(times: 200);
    expect(contentApi.asked.length, count + 1, reason: 'only MATH again');
  });

  group('lesson language', () {
    test(
      'maths asks for the app\'s language, and re-syncs when it changes',
      () async {
        container = build();
        await container.read(pathControllerProvider.notifier).refresh();
        expect(contentApi.asked.last, ('MATH', 'fr-CA'));

        container.listen(pathControllerProvider, (_, _) {});
        await container
            .read(settingsControllerProvider.notifier)
            .setEnglish(true);
        await pumpEventQueue();

        expect(contentApi.asked.last, (
          'MATH',
          'en-CA',
        ), reason: 'a language change is a new manifest');
      },
    );

    test(
      'Français stays French in an English app, and needs no re-sync',
      () async {
        container = build();
        container.listen(pathControllerProvider, (_, _) {});
        await container
            .read(settingsControllerProvider.notifier)
            .setEnglish(true);
        await container
            .read(pathControllerProvider.notifier)
            .selectSubject('FR');
        expect(contentApi.asked.last, ('FR', 'fr-CA'));

        final before = contentApi.asked.length;
        await container
            .read(settingsControllerProvider.notifier)
            .setEnglish(false);
        await pumpEventQueue();
        expect(
          contentApi.asked.length,
          before,
          reason: 'Français asks for French either way',
        );
      },
    );
  });

  group('why the Carte is empty', () {
    const leaf = CachedSkillNode(
      id: 'leaf-1',
      labelFr: 'Compter',
      labelEn: '',
      stableKey: 'math/1',
      subject: 'MATH',
      grade: 1,
    );

    test('nothing to say while loading, or once a lesson is playable', () {
      expect(carteGapOf(const PathState()), isNull);
      expect(
        carteGapOf(
          PathState(
            loading: false,
            leaves: const [leaf],
            lessonsByNodeId: {
              'leaf-1': [exercise(id: 'ex-1', skillNodeId: 'leaf-1')],
            },
          ),
        ),
        isNull,
      );
    });

    test('no skills at this grade is not the same as no lessons yet', () {
      expect(
        carteGapOf(const PathState(loading: false)),
        CarteGap.noSkillsAtGrade,
      );
      expect(
        carteGapOf(const PathState(loading: false, leaves: [leaf])),
        CarteGap.noLessonsYet,
      );
    });

    test('offline with nothing cached says offline, not "no content"', () {
      expect(
        carteGapOf(const PathState(loading: false, offline: true)),
        CarteGap.offline,
      );
      expect(
        carteGapOf(const PathState(loading: false, error: 'boom')),
        CarteGap.offline,
      );
    });

    test('the grade is named in both languages', () {
      expect(
        Strings.fr.pathEmptyAtGrade(3),
        "Il n'y a rien dans cette matière pour la 3e année.",
      );
      expect(
        Strings.fr.pathEmptyAtGrade(1),
        "Il n'y a rien dans cette matière pour la 1re année.",
      );
      expect(
        Strings.en.pathEmptyAtGrade(3),
        "There's nothing in this subject for Grade 3.",
      );
    });
  });
}
