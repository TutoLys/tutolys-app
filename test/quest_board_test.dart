import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/quest_log.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';

void main() {
  group('buildDailyQuests', () {
    test('three quests when the daily challenge is known', () {
      final q = buildDailyQuests(
        challenge: const DailyQuestDto(target: 3, progress: 1, completed: false),
        lessonsToday: 2,
        msToday: 90 * 1000,
      );
      expect(q.map((e) => e.kind), QuestKind.values);
      expect(q[1].progress, 2);
      expect(q[2].progress, 1, reason: '90 s is one whole minute');
      expect(q.any((e) => e.done), isFalse);
    });

    test('without the challenge, the two local quests still stand', () {
      final q = buildDailyQuests(challenge: null, lessonsToday: 0, msToday: 0);
      expect(q.map((e) => e.kind), [QuestKind.exercises, QuestKind.minutes]);
    });

    test('progress caps at the target and marks the quest done', () {
      final q = buildDailyQuests(
        challenge: null,
        lessonsToday: 9,
        msToday: 25 * 60000,
      );
      expect(q[0].progress, exercisesQuestTarget);
      expect(q.every((e) => e.done), isTrue);
    });
  });

  group('served quest definitions', () {
    const served = [
      QuestDefinitionDto(kind: 'daily_challenge', target: 3, xp: 10),
      QuestDefinitionDto(kind: 'exercises', target: 5, xp: 10),
    ];

    test('targets and rewards come from the backend', () {
      final q = buildDailyQuests(
        challenge: const DailyQuestDto(target: 3, progress: 0, completed: false),
        lessonsToday: 0,
        msToday: 0,
        served: served,
      );
      expect([for (final e in q) e.xpReward], [10, 10, null]);
    });

    test('the minutes quest has no reward until the backend pays it', () {
      final q = buildDailyQuests(
        challenge: null,
        lessonsToday: 0,
        msToday: 0,
        served: [
          ...served,
          const QuestDefinitionDto(kind: 'minutes', target: 15, xp: 5),
        ],
      );
      expect(q[1].target, 15);
      expect(q[1].xpReward, 5);
    });

    test('nothing served: local targets, no rewards', () {
      final q = buildDailyQuests(challenge: null, lessonsToday: 0, msToday: 0);
      expect(q[0].target, exercisesQuestTarget);
      expect(q.every((e) => e.xpReward == null), isTrue);
    });

    test('a served target moves when the quest is done', () {
      final q = buildDailyQuests(
        challenge: null,
        lessonsToday: 3,
        msToday: 0,
        served: const [QuestDefinitionDto(kind: 'exercises', target: 3, xp: 10)],
      );
      expect(q[0].done, isTrue);
    });
  });

  group('earnedAchievements', () {
    Set<Achievement> earned({
      int? streak,
      int? level,
      Map<String, Set<String>> history = const {},
      Map<String, double> subjects = const {},
      Set<String> played = const {},
    }) => earnedAchievements(
      streak: streak,
      level: level,
      history: history,
      subjectProgress: subjects,
      playedSubjects: played,
    );

    test('nothing for a new kid, and unknown values earn nothing', () {
      expect(earned(), isEmpty);
    });

    test('streak and level thresholds', () {
      expect(earned(streak: 3), {Achievement.streak3});
      expect(earned(streak: 7), {Achievement.streak3, Achievement.streak7});
      expect(earned(level: 20), {Achievement.level10, Achievement.level20});
    });

    test('quest master needs every quest done on one day', () {
      expect(
        earned(history: {'2026-10-22': {'challenge', 'exercises'}}),
        isEmpty,
      );
      expect(
        earned(history: {'2026-10-22': {'challenge', 'exercises', 'minutes'}}),
        {Achievement.questMaster},
      );
    });

    test('50 quests counts across days', () {
      final history = {
        for (var d = 1; d <= 25; d++)
          '2026-09-${d.toString().padLeft(2, '0')}': {'exercises', 'minutes'},
      };
      expect(earned(history: history), contains(Achievement.quests50));
    });

    test('all subjects at 50 % needs all five measured', () {
      expect(earned(subjects: {'MATH': 1, 'FR': 1}), isEmpty);
      expect(
        earned(subjects: {for (final s in realSubjects) s: 0.5}),
        {Achievement.allSubjects50},
      );
    });

    test('explorer means a skill played in every subject', () {
      expect(earned(played: {'MATH', 'FR', 'EN', 'SCI'}), isEmpty);
      expect(earned(played: realSubjects), {Achievement.explorer});
    });
  });

  test('completedInWeek counts Monday to Sunday only', () {
    final history = {
      '2026-10-18': {'exercises'}, // the Sunday before
      '2026-10-19': {'exercises', 'minutes'}, // Monday
      '2026-10-22': {'challenge'}, // Thursday
      '2026-10-25': {'minutes'}, // Sunday
    };
    expect(completedInWeek(history, DateTime(2026, 10, 22)), 4);
    expect(weeklyBadgeKey(DateTime(2026, 10, 22)), 'week:2026-10-19');
  });

  test('recent lists the newest unlock first', () {
    final board = QuestBoard(
      quests: const [],
      weekCompleted: 0,
      unlocked: const {'streak3': '2026-10-01', 'week:2026-10-19': '2026-10-24'},
      today: DateTime(2026, 10, 24),
    );
    expect(board.recent.first.key, 'week:2026-10-19');
    expect(board.recent.first.achievement, isNull);
    expect(board.recent.last.achievement, Achievement.streak3);
    expect(board.weeklyBadgeEarned, isTrue);
  });

  group('QuestLog', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    test('completions merge per day and never shrink', () async {
      final log = QuestLog(db, kidId: 'kid-1');
      await log.recordCompleted('2026-10-22', ['exercises']);
      await log.recordCompleted('2026-10-22', ['minutes', 'exercises']);
      await log.recordCompleted('2026-10-22', []);
      expect(await log.completedByDay(), {
        '2026-10-22': {'exercises', 'minutes'},
      });
    });

    test('an unlock keeps its first date', () async {
      final log = QuestLog(db, kidId: 'kid-1');
      await log.recordUnlocked('2026-10-20', ['streak3']);
      final after = await log.recordUnlocked('2026-10-22', ['streak3', 'streak7']);
      expect(after, {'streak3': '2026-10-20', 'streak7': '2026-10-22'});
    });

    test('each kid has their own log', () async {
      await QuestLog(db, kidId: 'kid-1').recordUnlocked('2026-10-20', ['streak3']);
      expect(await QuestLog(db, kidId: 'kid-2').unlocked(), isEmpty);
      expect(await QuestLog(db, kidId: 'kid-2').completedByDay(), isEmpty);
    });
  });
}
