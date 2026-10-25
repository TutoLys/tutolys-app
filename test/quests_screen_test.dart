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
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';
import 'package:tutolys_app/features/quests/quests_model.dart';
import 'package:tutolys_app/features/quests/quests_screen.dart';

class _FixedSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1),
    accessToken: 'token',
  );
}

class _FakeProgressApi extends ProgressApi {
  _FakeProgressApi(this.result) : super(dio: Dio());
  final ProgressResult result;

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async =>
      result;
}

/// Thursday 2026-10-22, like the design's "J" outlined.
final _today = DateTime(2026, 10, 22);

ProgressResult _snapshot({
  int? streak = 4,
  int? freezes,
  DailyQuestDto? quest,
}) => ProgressFetched(
  ProgressSnapshot(
    masteries: const [],
    currentStreakDays: streak,
    freezesAvailable: freezes,
    dailyQuest: quest,
  ),
);

QuestBoard _board({
  List<DailyQuestItem>? quests,
  int week = 0,
  Map<String, String> unlocked = const {},
}) => QuestBoard(
  quests:
      quests ??
      buildDailyQuests(challenge: null, exercisesToday: 0, msToday: 0),
  weekCompleted: week,
  unlocked: unlocked,
  today: _today,
);

Widget _app({
  required ProgressResult progress,
  Set<DateTime>? played,
  QuestBoard? board,
  VoidCallback? onOpenPath,
}) {
  final days =
      played ??
      {
        for (final d in [19, 20, 21, 22]) DateTime(2026, 10, d),
      };
  return ProviderScope(
    overrides: [
      progressApiProvider.overrideWithValue(_FakeProgressApi(progress)),
      sessionControllerProvider.overrideWith(_FixedSessionController.new),
      playedDaysProvider.overrideWith(
        (ref) async => PlayedDays(today: _today, days: days),
      ),
      questBoardProvider.overrideWith((ref) async => board ?? _board()),
    ],
    // Inside the app, not around it: a bare MediaQueryData has zero size,
    // which would send every test down the phone layout.
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      theme: TutolysTheme.learner(),
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: QuestsScreen(onOpenPath: onOpenPath)),
    ),
  );
}

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final fr = Strings.fr;

void main() {
  group('streak card', () {
    testWidgets('the real streak, and "tomorrow" once today is played', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();

      expect(find.text(fr.questsTitle), findsOneWidget);
      expect(find.text(fr.questsStreakDays(4)), findsOneWidget);
      expect(find.text(fr.questsStreakNextTomorrow(5)), findsOneWidget);
    });

    testWidgets('says "today" when today is not played yet', (tester) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(streak: 3),
          played: {
            for (final d in [19, 20, 21]) DateTime(2026, 10, d),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(fr.questsStreakNextToday(4)), findsOneWidget);
    });

    testWidgets('an unknown streak is a dash, never zero', (tester) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot(streak: null)));
      await tester.pumpAndSettle();

      expect(find.text('–'), findsWidgets);
      expect(find.text(fr.questsStreakUnknown), findsOneWidget);
      expect(find.text(fr.questsStreakDays(0)), findsNothing);
    });

    testWidgets('the week strip marks played days and rings today', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();

      for (final d in [19, 20, 21, 22]) {
        expect(find.byKey(ValueKey('week-$d-done')), findsOneWidget);
      }
      for (final d in [23, 24, 25]) {
        expect(find.byKey(ValueKey('week-$d-open')), findsOneWidget);
      }
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('week-22-done')),
          matching: find.byKey(const ValueKey('today')),
        ),
        findsOneWidget,
      );
    });
  });

  group('quêtes du jour', () {
    testWidgets('three quests, each with its progress and XP reward', (
      tester,
    ) async {
      _wide(tester);
      var opened = 0;
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          board: _board(
            quests: buildDailyQuests(
              challenge: const DailyQuestDto(
                target: 3,
                progress: 2,
                completed: false,
              ),
              exercisesToday: 3,
              msToday: 4 * 60000,
            ),
          ),
          onOpenPath: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(fr.streakQuestTitle(3)), findsOneWidget);
      expect(find.text(fr.questExercisesTitle(5)), findsOneWidget);
      expect(find.text(fr.questMinutesTitle(10)), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
      expect(find.text('4 / 10'), findsOneWidget);
      expect(find.byKey(const ValueKey('quest-reward')), findsNWidgets(3));
      expect(find.text(fr.questRewardXp(20)), findsOneWidget);

      await tester.tap(find.text(fr.streakQuestTitle(3)));
      expect(opened, 1);
    });

    testWidgets('a finished quest is checked, struck and loses its track', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          board: _board(
            quests: buildDailyQuests(
              challenge: null,
              exercisesToday: 5,
              msToday: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quest-check-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('quest-check-open')), findsOneWidget);
      expect(find.text('5 / 5'), findsNothing);
    });

    testWidgets('the weekly badge counts this week\'s quests', (tester) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot(), board: _board(week: 7)));
      await tester.pumpAndSettle();

      expect(find.text(fr.weeklyBadgeTitle), findsOneWidget);
      expect(find.text(fr.weeklyBadgeBody(15)), findsOneWidget);
      expect(find.text(fr.weeklyBadgeProgress(7, 15)), findsOneWidget);
    });

    testWidgets('an earned weekly badge says so', (tester) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          board: _board(
            week: 15,
            unlocked: {weeklyBadgeKey(_today): '2026-10-22'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(fr.weeklyBadgeEarned), findsOneWidget);
    });

    testWidgets('recent achievements: earned first, newest first, then locked', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          board: _board(
            unlocked: {'streak3': '2026-10-20', 'questMaster': '2026-10-21'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(fr.recentTitle), findsOneWidget);
      final master = tester.getTopLeft(find.byKey(const ValueKey('recent-questMaster')));
      final streak = tester.getTopLeft(find.byKey(const ValueKey('recent-streak3')));
      expect(master.dx, lessThan(streak.dx));
      for (final i in [2, 3, 4]) {
        expect(find.byKey(ValueKey('recent-locked-$i')), findsOneWidget);
      }
    });

    testWidgets('lays out on a phone without overflow', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          board: _board(
            quests: buildDailyQuests(
              challenge: const DailyQuestDto(target: 3, progress: 1, completed: false),
              exercisesToday: 1,
              msToday: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(fr.weeklyBadgeTitle), findsOneWidget);
    });
  });

  group('streak detail', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text(fr.questsStreakDays(4)));
      await tester.pumpAndSettle();
    }

    testWidgets('opens as a page in the tab, not a dialog, and goes back', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.byType(Dialog), findsNothing);
      // Same screen, other view: nothing was pushed over it.
      expect(find.byType(QuestsScreen), findsOneWidget);
      expect(find.text(fr.villageQuestsTitle), findsNothing);
      expect(find.text(fr.streakDetailHeadline(4)), findsOneWidget);
      expect(find.text(fr.monthYear(2026, 10).toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-4-7')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('streak-detail-back')));
      await tester.pumpAndSettle();
      expect(find.text(fr.villageQuestsTitle), findsOneWidget);
      expect(find.text(fr.streakDetailHeadline(4)), findsNothing);
    });

    testWidgets('wide: calendar beside the goal and rewards', (tester) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      final cal = tester.getTopLeft(find.text(fr.streakDetailCalendar));
      final goal = tester.getTopLeft(find.text(fr.streakDetailGoal));
      expect(goal.dx, greaterThan(cal.dx));
      expect(goal.dy, closeTo(cal.dy, 1));
    });

    testWidgets('phone: one column, no overflow', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(fr.streakDetailHeadline(4)), findsOneWidget);
      final cal = tester.getTopLeft(find.text(fr.streakDetailCalendar));
      await tester.scrollUntilVisible(
        find.text(fr.streakDetailGoal),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final goal = tester.getTopLeft(find.text(fr.streakDetailGoal));
      expect(goal.dx, closeTo(cal.dx, 1));
    });

    testWidgets('the nudge appears only while today is unplayed, and leads '
        'to the Carte', (tester) async {
      _wide(tester);
      var opened = 0;
      await tester.pumpWidget(
        _app(
          progress: _snapshot(streak: 3),
          played: {
            for (final d in [19, 20, 21]) DateTime(2026, 10, d),
          },
          onOpenPath: () => opened++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.questsStreakDays(3)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('streak-nudge')), findsOneWidget);
      await tester.tap(find.text(fr.streakDetailNudgeCta.toUpperCase()));
      await tester.pumpAndSettle();
      expect(opened, 1);
      // Leaving for the Carte resets the tab to its quest list.
      expect(find.text(fr.villageQuestsTitle), findsOneWidget);
    });

    testWidgets('no nudge once today is played', (tester) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.byKey(const ValueKey('streak-nudge')), findsNothing);
    });

    testWidgets('the calendar golds played days and pages back, not forward', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(),
          played: {
            DateTime(2026, 9, 30),
            for (final d in [19, 20, 21, 22]) DateTime(2026, 10, d),
          },
        ),
      );
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.byKey(const ValueKey('cal-20-played')), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-24-open')), findsOneWidget);

      IconButton arrow(String key) =>
          tester.widget<IconButton>(find.byKey(ValueKey(key)));
      expect(arrow('cal-next').onPressed, isNull);
      expect(arrow('cal-prev').onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('cal-prev')));
      await tester.pumpAndSettle();
      expect(find.text(fr.monthYear(2026, 9).toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-30-played')), findsOneWidget);
      // September is the first month played here — nothing earlier to show.
      expect(arrow('cal-prev').onPressed, isNull);
      expect(arrow('cal-next').onPressed, isNotNull);
    });

    testWidgets('the streak shield shows the real freeze balance', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot(freezes: 2)));
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.text(fr.streakShieldTitle), findsOneWidget);
      expect(
        find.text(fr.streakShieldBalance(2).toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('no shield section when the balance is unknown', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.text(fr.streakShieldTitle), findsNothing);
      // The other two rewards stay.
      expect(find.byKey(const ValueKey('reward-chest')), findsOneWidget);
    });

    testWidgets('Personnelle is active; Entre amis is a greyed label only', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);

      expect(find.text(fr.streakTabPersonal), findsOneWidget);
      expect(find.text(fr.streakTabFriends), findsOneWidget);
      expect(find.text(fr.comingSoonShort), findsOneWidget);
      final friends = tester.widget<Opacity>(
        find.byKey(const ValueKey('streak-tab-friends')),
      );
      expect(friends.opacity, 0.55);
      // Nothing behind it (#12): no handler anywhere above the label.
      expect(
        find.ancestor(
          of: find.text(fr.streakTabFriends),
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector || w is InkWell,
          ),
        ),
        findsNothing,
      );

      // Tapping it changes nothing.
      await tester.tap(find.text(fr.streakTabFriends), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(fr.streakDetailCalendar), findsOneWidget);
    });

    testWidgets('the tab row fits the full-screen phone layout', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(progress: _snapshot()));
      await tester.pumpAndSettle();
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(fr.streakTabFriends), findsOneWidget);
    });

    testWidgets('chest and title: pending until the streak earns them', (
      tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(_app(progress: _snapshot(streak: 2)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.questsStreakDays(2)));
      await tester.pumpAndSettle();

      expect(find.text(fr.chestBodyLocked), findsOneWidget);
      expect(find.text(fr.rewardDaysLeft(1).toUpperCase()), findsOneWidget);
      expect(find.text(fr.rewardDaysLeft(5).toUpperCase()), findsOneWidget);
    });

    testWidgets('chest obtained and title active once earned', (tester) async {
      _wide(tester);
      await tester.pumpWidget(
        _app(
          progress: _snapshot(streak: 8),
          board: _board(
            unlocked: {'streak3': '2026-10-17', 'streak7': '2026-10-21'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.questsStreakDays(8)));
      await tester.pumpAndSettle();

      expect(find.text(fr.chestBody), findsOneWidget);
      expect(find.text(fr.rewardObtained.toUpperCase()), findsOneWidget);
      expect(find.text(fr.rewardActive.toUpperCase()), findsOneWidget);
    });
  });
}
