import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/profile/profile_screen.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeProgressApi extends ProgressApi {
  _FakeProgressApi() : super(dio: Dio());

  ProgressResult result = const ProgressFetched(
    ProgressSnapshot(masteries: [], currentStreakDays: null),
  );

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async =>
      result;
}

Widget appUnder({ProgressApi? progressApi}) {
  return ProviderScope(
    overrides: [
      progressApiProvider.overrideWithValue(progressApi ?? _FakeProgressApi()),
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
        home: const ProfileScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the kid name and grade', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text('Yelhan'), findsOneWidget);
    expect(find.text(Strings.fr.profileGrade(3)), findsOneWidget);
  });

  testWidgets('a freshly-paired kid with no progress yet shows no summary card', (
    tester,
  ) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.profileSkillsMastered(0)), findsNothing);
  });

  testWidgets('shows real mastered-skill count and streak', (tester) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [
            SkillMasteryDto(skillNodeId: 'a', masteryPct: 95, isMastered: true),
            SkillMasteryDto(skillNodeId: 'b', masteryPct: 40, isMastered: false),
          ],
          currentStreakDays: 5,
        ),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget); // mastered count
    expect(find.text('5'), findsOneWidget); // streak
    expect(find.text(Strings.fr.profileSkillsMastered(1)), findsOneWidget);
    expect(find.text(Strings.fr.profileStreakDays(5)), findsOneWidget);
  });

  testWidgets('sign-out button is still present', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.profileSignOut), findsOneWidget);
  });
}
