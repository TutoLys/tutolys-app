import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/path/path_screen.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeCurriculumApi extends CurriculumApi {
  _FakeCurriculumApi(this.leaves) : super(dio: Dio());
  final List<CurriculumLeaf> leaves;

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async => CurriculumTreeFetched(leaves);
}

class _FakeContentApi extends ContentApi {
  _FakeContentApi(this.content) : super(dio: Dio());
  final Map<String, Map<String, Object?>> content;

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
  }) async {
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
      unavailable: const [],
    );
  }
}

Map<String, Object?> exercise({
  required String id,
  required String skillNodeId,
}) {
  return {
    'exercise_id': id,
    'version': 1,
    'engine_key': 'mcq',
    'engine_min_version': 1,
    'skill_node_id': skillNodeId,
    'subject': 'MATH',
    'grade': 1,
    'rank': 0,
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

Widget appUnder({
  required List<CurriculumLeaf> leaves,
  required Map<String, Map<String, Object?>> content,
}) {
  final router = buildPairedRouter();
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
      curriculumApiProvider.overrideWithValue(_FakeCurriculumApi(leaves)),
      contentApiProvider.overrideWithValue(_FakeContentApi(content)),
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(
          const SessionState(
            status: SessionStatus.paired,
            kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1),
            accessToken: 'token',
          ),
        ),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp.router(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  testWidgets('an available node navigates to play when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      appUnder(
        leaves: const [
          CurriculumLeaf(
            id: 'leaf-1',
            labelFr: 'Compter',
            labelEn: '',
            stableKey: 'math/1',
          ),
        ],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compter'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

    await tester.tap(find.text('Compter'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('a locked node (no synced exercise) cannot be tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      appUnder(
        leaves: const [
          CurriculumLeaf(
            id: 'leaf-1',
            labelFr: 'Compter',
            labelEn: '',
            stableKey: 'math/1',
          ),
        ],
        content: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text('Compter'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsNothing);
    expect(find.byType(PathScreen), findsOneWidget);
  });

  testWidgets('shows the empty state when there is nothing synced', (
    tester,
  ) async {
    await tester.pumpWidget(appUnder(leaves: const [], content: const {}));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });
}
