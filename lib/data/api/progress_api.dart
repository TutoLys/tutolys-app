import 'package:dio/dio.dart';

/// One skill's mastery, as the backend serves it
/// (`apps.progress.views.SkillMasterySerializer`).
class SkillMasteryDto {
  const SkillMasteryDto({
    required this.skillNodeId,
    required this.masteryPct,
    required this.isMastered,
    this.status,
  });

  factory SkillMasteryDto.fromJson(Map<String, Object?> json) {
    return SkillMasteryDto(
      skillNodeId: json['skill_node'] as String,
      masteryPct: (json['mastery_pct'] as num).toDouble(),
      isMastered: json['is_mastered'] as bool,
      status: json['status'] as String?,
    );
  }

  final String skillNodeId;
  final double masteryPct;
  final bool isMastered;

  /// The §5.9 classifier's verdict (`struggling`, `watch`, `learning`,
  /// `mastered`, `not_started`), or null while the backend doesn't serve
  /// it. Feeds the Carte's « Révision » row (OW3, ADR 0111).
  final String? status;

  Map<String, Object?> toJson() => {
    'skill_node': skillNodeId,
    'mastery_pct': masteryPct,
    'is_mastered': isMastered,
    if (status != null) 'status': status,
  };
}

/// Today's daily-challenge progress
/// (`apps.progress.views.DailyQuestSerializer`) — "N correct answers in a
/// row", target configured backend-side (`settings.DAILY_QUEST_TARGET`).
class DailyQuestDto {
  const DailyQuestDto({
    required this.target,
    required this.progress,
    required this.completed,
  });

  factory DailyQuestDto.fromJson(Map<String, Object?> json) {
    return DailyQuestDto(
      target: json['target'] as int,
      progress: json['progress'] as int,
      completed: json['completed'] as bool,
    );
  }

  final int target;
  final int progress;
  final bool completed;

  Map<String, Object?> toJson() => {
    'target': target,
    'progress': progress,
    'completed': completed,
  };
}

/// A quest the backend both measures and pays
/// (`apps.progress.views.QuestDefinitionSerializer`, backend ADR 0154):
/// `kind` is `daily_challenge` or `exercises` today. A quest the backend
/// can't pay yet is simply absent, so the app shows no reward for it.
class QuestDefinitionDto {
  const QuestDefinitionDto({
    required this.kind,
    required this.target,
    required this.xp,
  });

  factory QuestDefinitionDto.fromJson(Map<String, Object?> json) {
    return QuestDefinitionDto(
      kind: json['kind'] as String,
      target: json['target'] as int,
      xp: json['xp'] as int,
    );
  }

  final String kind;
  final int target;
  final int xp;

  Map<String, Object?> toJson() => {'kind': kind, 'target': target, 'xp': xp};
}

/// The shield card's facts (`StreakFreezeSerializer`, backend ADR 0153).
///
/// [balance] is a local row on the backend and never degrades.
/// [nextGrantAt] is null once it's in the past. [earnedSinceLastGrant] is
/// null when telemetry couldn't be read: unknown, never "hasn't played".
class StreakFreezeDto {
  const StreakFreezeDto({
    required this.balance,
    required this.maxBalance,
    this.lastGrantedAt,
    this.nextGrantAt,
    this.earnedSinceLastGrant,
  });

  factory StreakFreezeDto.fromJson(Map<String, Object?> json) {
    DateTime? at(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.tryParse(v);
    }

    return StreakFreezeDto(
      balance: json['balance'] as int,
      maxBalance: json['max_balance'] as int,
      lastGrantedAt: at('last_granted_at'),
      nextGrantAt: at('next_grant_at'),
      earnedSinceLastGrant: json['earned_since_last_grant'] as bool?,
    );
  }

  final int balance;
  final int maxBalance;
  final DateTime? lastGrantedAt;
  final DateTime? nextGrantAt;
  final bool? earnedSinceLastGrant;

  /// The same facts with "earned" unknown, for a cached read.
  StreakFreezeDto withoutEarned() => StreakFreezeDto(
    balance: balance,
    maxBalance: maxBalance,
    lastGrantedAt: lastGrantedAt,
    nextGrantAt: nextGrantAt,
  );

  Map<String, Object?> toJson() => {
    'balance': balance,
    'max_balance': maxBalance,
    'last_granted_at': lastGrantedAt?.toUtc().toIso8601String(),
    'next_grant_at': nextGrantAt?.toUtc().toIso8601String(),
    'earned_since_last_grant': earnedSinceLastGrant,
  };
}

/// One finished league week (`league.last_week`, backend ADR 0207).
/// [division] is the division the week left the kid in; [outcome] is
/// `placed`, `promoted`, `held` or `demoted`.
class LeagueWeekDto {
  const LeagueWeekDto({
    required this.weekStart,
    required this.division,
    required this.outcome,
    required this.xp,
  });

  factory LeagueWeekDto.fromJson(Map<String, Object?> json) => LeagueWeekDto(
    weekStart: json['week_start'] as String,
    division: json['division'] as String,
    outcome: json['outcome'] as String,
    xp: json['xp'] as int,
  );

  /// `yyyy-mm-dd`, the Monday of that Québec week.
  final String weekStart;
  final String division;
  final String outcome;
  final int xp;

  Map<String, Object?> toJson() => {
    'week_start': weekStart,
    'division': division,
    'outcome': outcome,
    'xp': xp,
  };
}

/// The kid's personal league (`league`, backend ADR 0207): a weekly goal
/// against their own XP, never against other children. Never null on a
/// backend that serves it.
///
/// Null means "doesn't exist here", never zero: [promoteAtXp] and
/// [xpToPromote] at `diamond`, [keepAtXp] at `bronze`.
class LeagueDto {
  const LeagueDto({
    required this.division,
    required this.weekStart,
    required this.xpThisWeek,
    this.weekEnd,
    this.promoteAtXp,
    this.xpToPromote,
    this.keepAtXp,
    this.lastWeek,
  });

  factory LeagueDto.fromJson(Map<String, Object?> json) {
    final last = json['last_week'] as Map<String, Object?>?;
    final end = json['week_end'] as String?;
    return LeagueDto(
      division: json['division'] as String,
      weekStart: json['week_start'] as String,
      weekEnd: end == null ? null : DateTime.tryParse(end),
      xpThisWeek: json['xp_this_week'] as int,
      promoteAtXp: json['promote_at_xp'] as int?,
      xpToPromote: json['xp_to_promote'] as int?,
      keepAtXp: json['keep_at_xp'] as int?,
      lastWeek: last == null ? null : LeagueWeekDto.fromJson(last),
    );
  }

  /// `bronze`, `silver`, `gold` or `diamond`; the app owns the names.
  final String division;

  /// `yyyy-mm-dd`, the Monday of this Québec week.
  final String weekStart;

  /// The instant the week ends (next Monday 00:00 in Montréal). Null from a
  /// backend that doesn't send it yet; then [weekStart] + 7 days.
  final DateTime? weekEnd;

  final int xpThisWeek;
  final int? promoteAtXp;
  final int? xpToPromote;
  final int? keepAtXp;

  /// Null until the kid's first week has been judged.
  final LeagueWeekDto? lastWeek;

  Map<String, Object?> toJson() => {
    'division': division,
    'week_start': weekStart,
    'week_end': weekEnd?.toUtc().toIso8601String(),
    'xp_this_week': xpThisWeek,
    'promote_at_xp': promoteAtXp,
    'xp_to_promote': xpToPromote,
    'keep_at_xp': keepAtXp,
    'last_week': lastWeek?.toJson(),
  };
}

/// The anonymous effort percentile (`effort_percentile`, backend ADR 0207):
/// more weekly XP than [percentile] % of the kids of [grade] **who played
/// that week**. On the device it is only ever served at or above the median;
/// null means "show the kid's own progress instead".
class EffortPercentileDto {
  const EffortPercentileDto({
    required this.percentile,
    required this.grade,
    required this.weekStart,
  });

  factory EffortPercentileDto.fromJson(Map<String, Object?> json) =>
      EffortPercentileDto(
        percentile: json['percentile'] as int,
        grade: json['grade'] as int,
        weekStart: json['week_start'] as String,
      );

  final int percentile;
  final int grade;
  final String weekStart;

  Map<String, Object?> toJson() => {
    'percentile': percentile,
    'grade': grade,
    'week_start': weekStart,
  };
}

/// `GET /api/v1/me/progress`'s full body — mastery per skill, the kid's
/// current streak-with-freeze, their spendable freeze balance, and
/// today's daily-challenge progress, all read live from telemetry on the
/// backend's side (never cached there either, see backend ADR 0009/0018).
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.masteries,
    required this.currentStreakDays,
    this.freezesAvailable,
    this.dailyQuest,
    this.streakFreeze,
    this.quests,
    this.totalXp = 0,
    this.level,
    this.skillsCompleted,
    this.skillsTotal,
    this.league,
    this.effortPercentile,
  });

  factory ProgressSnapshot.fromJson(Map<String, Object?> json) {
    final dailyQuestJson = json['daily_quest'] as Map<String, Object?>?;
    final freezeJson = json['streak_freeze'] as Map<String, Object?>?;
    final questsJson = json['quests'] as List?;
    final leagueJson = json['league'] as Map<String, Object?>?;
    final effortJson = json['effort_percentile'] as Map<String, Object?>?;
    return ProgressSnapshot(
      masteries: ((json['masteries'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(SkillMasteryDto.fromJson)
          .toList(growable: false),
      currentStreakDays: json['current_streak_days'] as int?,
      freezesAvailable: json['freezes_available'] as int?,
      dailyQuest: dailyQuestJson == null
          ? null
          : DailyQuestDto.fromJson(dailyQuestJson),
      streakFreeze: freezeJson == null
          ? null
          : StreakFreezeDto.fromJson(freezeJson),
      quests: questsJson
          ?.cast<Map<String, Object?>>()
          .map(QuestDefinitionDto.fromJson)
          .toList(growable: false),
      // Unlike streak/daily-quest, this is never null-means-unknown — the
      // backend reads it from its own local XPAward ledger, not live
      // telemetry, so it's always a real number (0 for a kid who hasn't
      // earned any yet), even when the rest of the payload degrades.
      totalXp: json['total_xp'] as int? ?? 0,
      // A backend from before grade levels sent an XP level under the same
      // name; `skills_total` is what marks the new meaning, so without it
      // the level is ignored rather than mistaken for a grade level.
      level: json['skills_total'] == null ? null : json['level'] as int?,
      skillsCompleted: json['skills_completed'] as int?,
      skillsTotal: json['skills_total'] as int?,
      league: leagueJson == null ? null : LeagueDto.fromJson(leagueJson),
      effortPercentile: effortJson == null
          ? null
          : EffortPercentileDto.fromJson(effortJson),
    );
  }

  final List<SkillMasteryDto> masteries;

  /// Null means telemetry couldn't be reached for this read (backend's own
  /// degrade-gracefully behaviour) — distinct from a real `0`.
  final int? currentStreakDays;

  /// Same null-means-unknown rule as [currentStreakDays] — both come from
  /// the same telemetry read on the backend's side.
  final int? freezesAvailable;

  /// Null for the same reason, or for a kid who's never played at all —
  /// telemetry still answers "0 correct so far", but a never-paired read
  /// has nothing to show yet either way.
  final DailyQuestDto? dailyQuest;

  /// Null from a backend older than ADR 0153.
  final StreakFreezeDto? streakFreeze;

  /// The quests the backend pays, with their targets and rewards. Null
  /// from a backend older than ADR 0154; then no reward is shown.
  final List<QuestDefinitionDto>? quests;

  /// From `manage.py award_xp`'s ledger — see backend ADR 0022. Earned per
  /// question completed, so a multi-question exercise naturally earns
  /// more than a single-question one with no special handling needed here.
  final int totalXp;

  /// The school year's level, 1–99, from the share of the grade's skills
  /// completed (app ADR 0033). Null from a backend that doesn't send it.
  final int? level;

  /// Skills of the kid's grade with every published lesson finished, and
  /// all skills of the grade: the level's numerator and denominator.
  final int? skillsCompleted;
  final int? skillsTotal;

  /// Null only from a backend older than ADR 0207.
  final LeagueDto? league;

  /// Null whenever there's nothing kind and true to say (ADR 0207).
  final EffortPercentileDto? effortPercentile;

  int get masteredCount => masteries.where((m) => m.isMastered).length;

  /// The same shape [ProgressSnapshot.fromJson] reads, for the device's
  /// copy of the last good read (`ProgressCache`).
  Map<String, Object?> toJson() => {
    'masteries': [for (final m in masteries) m.toJson()],
    'current_streak_days': currentStreakDays,
    'freezes_available': freezesAvailable,
    'daily_quest': dailyQuest?.toJson(),
    'streak_freeze': streakFreeze?.toJson(),
    'quests': quests?.map((q) => q.toJson()).toList(),
    'total_xp': totalXp,
    'level': level,
    'skills_completed': skillsCompleted,
    'skills_total': skillsTotal,
    'league': league?.toJson(),
    'effort_percentile': effortPercentile?.toJson(),
  };
}

sealed class ProgressResult {
  const ProgressResult();
}

class ProgressFetched extends ProgressResult {
  const ProgressFetched(this.snapshot);
  final ProgressSnapshot snapshot;
}

class ProgressOffline extends ProgressResult {
  const ProgressOffline();
}

class ProgressUnauthorized extends ProgressResult {
  const ProgressUnauthorized();
}

class ProgressFailed extends ProgressResult {
  const ProgressFailed(this.detail);
  final String detail;
}

/// Reads the paired device's own progress —
/// `GET /api/v1/me/progress` (no kid id in the URL at all: the backend
/// derives it from the device token, same reasoning as `CurriculumApi`
/// deriving grade server-side rather than trusting a parameter).
class ProgressApi {
  ProgressApi({required this.dio});

  final Dio dio;

  Future<ProgressResult> fetchMyProgress({required String accessToken}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/me/progress',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return ProgressFetched(ProgressSnapshot.fromJson(response.data!));
    } on DioException catch (error) {
      if (_isOffline(error)) return const ProgressOffline();
      if (error.response?.statusCode == 401) {
        return const ProgressUnauthorized();
      }
      return ProgressFailed(error.message ?? 'progress fetch failed');
    }
  }

  /// Mirrors `CurriculumApi`'s own check — `dart:io` is unavailable on web.
  bool _isOffline(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
  }
}
