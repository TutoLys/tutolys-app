import 'package:dio/dio.dart';

/// One skill's mastery, as the backend serves it
/// (`apps.progress.views.SkillMasterySerializer`).
class SkillMasteryDto {
  const SkillMasteryDto({
    required this.skillNodeId,
    required this.masteryPct,
    required this.isMastered,
  });

  factory SkillMasteryDto.fromJson(Map<String, Object?> json) {
    return SkillMasteryDto(
      skillNodeId: json['skill_node'] as String,
      masteryPct: (json['mastery_pct'] as num).toDouble(),
      isMastered: json['is_mastered'] as bool,
    );
  }

  final String skillNodeId;
  final double masteryPct;
  final bool isMastered;
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
    this.totalXp = 0,
  });

  factory ProgressSnapshot.fromJson(Map<String, Object?> json) {
    final dailyQuestJson = json['daily_quest'] as Map<String, Object?>?;
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
      // Unlike streak/daily-quest, this is never null-means-unknown — the
      // backend reads it from its own local XPAward ledger, not live
      // telemetry, so it's always a real number (0 for a kid who hasn't
      // earned any yet), even when the rest of the payload degrades.
      totalXp: json['total_xp'] as int? ?? 0,
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

  /// From `manage.py award_xp`'s ledger — see backend ADR 0022. Earned per
  /// question completed, so a multi-question exercise naturally earns
  /// more than a single-question one with no special handling needed here.
  final int totalXp;

  int get masteredCount => masteries.where((m) => m.isMastered).length;
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
