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
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/features/play/play_screen.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class FakeCurriculumApi extends CurriculumApi {
  FakeCurriculumApi(this.bySubject) : super(dio: Dio());
  final Map<String, List<CurriculumLeaf>> bySubject;
  final requested = <String>[];

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    requested.add(subject);
    return CurriculumTreeFetched(bySubject[subject] ?? const []);
  }
}

class _FixedProgress extends ProgressController {
  _FixedProgress(this._state);
  final ProgressState _state;

  @override
  ProgressState build() => _state;

  @override
  Future<void> refresh() async {}
}

class _FakeContentApi extends ContentApi {
  _FakeContentApi(this.content) : super(dio: Dio());
  final Map<String, Map<String, Object?>> content;

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
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
  Map<String, List<CurriculumLeaf>> otherSubjects = const {},
  List<SkillMasteryDto> masteries = const [],
  FakeCurriculumApi? curriculum,
}) {
  final router = buildPairedRouter();
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
      curriculumApiProvider.overrideWithValue(
        curriculum ?? FakeCurriculumApi({'MATH': leaves, ...otherSubjects}),
      ),
      progressControllerProvider.overrideWith(
        () =>
            _FixedProgress(ProgressState(loading: false, masteries: masteries)),
      ),
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

const _compter = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);

Future<void> openCarte(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  // The shell starts on Village; the design names this destination Carte.
  await tester.tap(find.text('Carte'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first playable node is active and plays when tapped', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );

    // Titled by its learning area, not a generic heading.
    expect(find.text('Arithmétique'), findsOneWidget);
    // Never played: the card says so rather than showing "0 %".
    expect(find.text('À DÉCOUVRIR'), findsOneWidget);

    // The design plays on the orb itself.
    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('the active card\'s Continuer plays the same node', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );

    await tester.tap(find.text('Continuer →'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('the active card shows the real mastery from /me/progress', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
        masteries: const [
          SkillMasteryDto(
            skillNodeId: 'leaf-1',
            masteryPct: 60,
            isMastered: false,
          ),
        ],
      ),
    );

    expect(find.text('EN COURS · 60 % MAÎTRISÉ'), findsOneWidget);
  });

  testWidgets('a subject pill switches the map to that subject', (
    tester,
  ) async {
    final curriculum = FakeCurriculumApi({
      'MATH': const [_compter],
      'FR': const [
        CurriculumLeaf(
          id: 'fr-1',
          labelFr: 'Lire des syllabes',
          labelEn: '',
          stableKey: 'francais-langue/lire/b:A/o:1',
        ),
      ],
    });
    await openCarte(
      tester,
      appUnder(leaves: const [], content: const {}, curriculum: curriculum),
    );
    expect(find.text('Compter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('subject-pill-FR')));
    await tester.pumpAndSettle();

    expect(curriculum.requested.last, 'FR');
    expect(find.text('Lire des syllabes'), findsOneWidget);
    expect(find.text('Compter'), findsNothing);
  });

  testWidgets('a locked node (no synced exercise) has no way to play', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(leaves: const [_compter], content: const {}),
    );

    // Nothing playable means no active node, so no Continuer card either.
    expect(find.text('Continuer →'), findsNothing);

    // A locked orb has no handler at all, so tapping it cannot play.
    await tester.tap(
      find.byKey(const ValueKey('path-orb-leaf-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsNothing);
    expect(find.byType(PathScreen), findsOneWidget);
  });

  testWidgets('a subject with no skills at this grade says so', (tester) async {
    await openCarte(tester, appUnder(leaves: const [], content: const {}));

    expect(find.byType(PlayScreen), findsNothing);
    expect(
      find.text("Il n'y a rien dans cette matière pour la 1re année."),
      findsOneWidget,
    );
    // The pills stay, so a kid can still go to a subject that has content.
    expect(find.byKey(const ValueKey('subject-pill-FR')), findsOneWidget);
  });

  testWidgets('skills with no lessons yet: "en préparation", map locked', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(leaves: const [_compter], content: const {}),
    );

    expect(
      find.byKey(const ValueKey('carte-gap-noLessonsYet')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Les activités de cette matière sont en préparation. Reviens bientôt !',
      ),
      findsOneWidget,
    );
    // The skill still shows, so the kid sees what's coming.
    expect(find.byKey(ValueKey('path-orb-${_compter.id}')), findsOneWidget);
  });
}
