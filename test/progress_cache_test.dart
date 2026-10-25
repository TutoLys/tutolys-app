import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/progress/progress_cache.dart';

void main() {
  late LocalDatabase db;
  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  const snapshot = ProgressSnapshot(
    masteries: [
      SkillMasteryDto(skillNodeId: 'a', masteryPct: 62.5, isMastered: false),
    ],
    currentStreakDays: 3,
    freezesAvailable: 2,
    dailyQuest: DailyQuestDto(target: 3, progress: 1, completed: false),
    totalXp: 120,
    level: 4,
    skillsCompleted: 17,
    skillsTotal: 526,
  );

  test('round-trips every field, per kid', () async {
    final day = DateTime(2026, 10, 25, 9);
    await ProgressCache(db, kidId: 'k1', clock: () => day).write(snapshot);

    final back = (await ProgressCache(
      db,
      kidId: 'k1',
      clock: () => day,
    ).read())!;
    expect(back.toJson(), snapshot.toJson());
    expect(await ProgressCache(db, kidId: 'k2').read(), isNull);
  });

  test('yesterday\'s daily challenge is not shown as today\'s', () async {
    await ProgressCache(
      db,
      kidId: 'k1',
      clock: () => DateTime(2026, 10, 24, 20),
    ).write(snapshot);

    final back = (await ProgressCache(
      db,
      kidId: 'k1',
      clock: () => DateTime(2026, 10, 25, 8),
    ).read())!;
    expect(back.dailyQuest, isNull);
    expect(back.totalXp, 120, reason: 'everything else still stands');
  });

  test('an older backend\'s read keeps the cached grade level', () {
    final merged = mergeWithCached(
      const ProgressSnapshot(masteries: [], currentStreakDays: 3),
      snapshot,
    );
    expect((merged.level, merged.skillsTotal), (4, 526));
  });
}
