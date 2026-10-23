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

/// `GET /api/v1/me/progress`'s full body — mastery per skill plus the
/// kid's current day-streak, read live from telemetry on the backend's
/// side (never cached there either, see backend ADR 0009).
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.masteries,
    required this.currentStreakDays,
  });

  factory ProgressSnapshot.fromJson(Map<String, Object?> json) {
    return ProgressSnapshot(
      masteries: ((json['masteries'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(SkillMasteryDto.fromJson)
          .toList(growable: false),
      currentStreakDays: json['current_streak_days'] as int?,
    );
  }

  final List<SkillMasteryDto> masteries;

  /// Null means telemetry couldn't be reached for this read (backend's own
  /// degrade-gracefully behaviour) — distinct from a real `0`.
  final int? currentStreakDays;

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
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
  }
}
