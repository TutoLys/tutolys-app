import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/home_stats.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/home/home_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _EmptyCurriculumApi extends CurriculumApi {
  _EmptyCurriculumApi() : super(dio: Dio());

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async => const CurriculumTreeFetched([]);
}

class _EmptyContentApi extends ContentApi {
  _EmptyContentApi() : super(dio: Dio());

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
  }) async => ManifestFetched(ContentManifest(grade: 1, manifestHash: 'm', entries: const []));

  @override
  Future<ExercisesResult> fetchExercises({
    required List<String> ids,
    required String accessToken,
  }) async => const ExercisesFetched(envelopes: [], unavailable: []);
}

Widget appUnder(LocalDatabase db) {
  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      curriculumApiProvider.overrideWithValue(_EmptyCurriculumApi()),
      contentApiProvider.overrideWithValue(_EmptyContentApi()),
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(
          const SessionState(
            status: SessionStatus.paired,
            kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 3),
            accessToken: 'token',
          ),
        ),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('greets the paired kid by name', (tester) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(appUnder(db));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.homeGreeting('Yelhan')), findsOneWidget);
  });

  testWidgets('shows the empty continue-learning state when nothing is synced', (
    tester,
  ) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(appUnder(db));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.pathEmpty), findsOneWidget);
    expect(find.text(Strings.fr.homePlay), findsNothing);
  });

  testWidgets("today's real stats render, not zero when something was recorded", (
    tester,
  ) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    await HomeStats(db, clock: DateTime.now)
        .recordExerciseCompleted(elapsedMs: 120000);

    await tester.pumpWidget(appUnder(db));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget); // exercises today
    expect(find.text('2'), findsOneWidget); // minutes today (120000ms)
  });
}
