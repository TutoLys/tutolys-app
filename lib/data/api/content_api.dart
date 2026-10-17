import 'package:dio/dio.dart';

/// One manifest entry: enough to decide whether the cached copy is stale,
/// without downloading anything.
class ManifestEntry {
  const ManifestEntry({
    required this.exerciseId,
    required this.version,
    required this.contentHash,
    required this.engineKey,
    required this.engineMinVersion,
    required this.skillNodeId,
    required this.subject,
    required this.grade,
    required this.rank,
  });

  factory ManifestEntry.fromJson(Map<String, Object?> json) {
    return ManifestEntry(
      exerciseId: json['exercise_id'] as String,
      version: json['version'] as int,
      contentHash: json['content_hash'] as String,
      engineKey: json['engine_key'] as String,
      engineMinVersion: json['engine_min_version'] as int,
      skillNodeId: json['skill_node_id'] as String,
      subject: json['subject'] as String,
      grade: json['grade'] as int,
      rank: json['rank'] as int,
    );
  }

  final String exerciseId;
  final int version;

  /// What the diff compares. One changed exercise changes only this.
  final String contentHash;

  final String engineKey;
  final int engineMinVersion;
  final String skillNodeId;
  final String subject;
  final int grade;
  final int rank;
}

class ContentManifest {
  const ContentManifest({
    required this.grade,
    required this.manifestHash,
    required this.entries,
  });

  final int grade;
  final String manifestHash;
  final List<ManifestEntry> entries;
}

sealed class ManifestResult {
  const ManifestResult();
}

class ManifestFetched extends ManifestResult {
  const ManifestFetched(this.manifest);
  final ContentManifest manifest;
}

class ManifestOffline extends ManifestResult {
  const ManifestOffline();
}

class ManifestUnauthorized extends ManifestResult {
  const ManifestUnauthorized();
}

class ManifestFailed extends ManifestResult {
  const ManifestFailed(this.detail);
  final String detail;
}

sealed class ExercisesResult {
  const ExercisesResult();
}

class ExercisesFetched extends ExercisesResult {
  const ExercisesFetched({required this.envelopes, required this.unavailable});

  final List<Map<String, Object?>> envelopes;

  /// Asked for but not served — retired, or gone. Reported so the app stops
  /// asking rather than retrying forever.
  final List<String> unavailable;
}

class ExercisesOffline extends ExercisesResult {
  const ExercisesOffline();
}

class ExercisesFailed extends ExercisesResult {
  const ExercisesFailed(this.detail);
  final String detail;
}

/// Reads the content the backend serves to a paired device.
class ContentApi {
  ContentApi({required this.dio});

  final Dio dio;

  /// The server caps a request at 200 ids; 25 keeps each round trip small
  /// enough to finish on a weak connection and to resume cheaply if it fails.
  static const fetchChunkSize = 25;

  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/content/manifest',
        queryParameters: {'subject': ?subject},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data!;
      final entries = ((body['exercises'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(ManifestEntry.fromJson)
          .toList(growable: false);

      return ManifestFetched(
        ContentManifest(
          grade: body['grade'] as int,
          manifestHash: body['manifest_hash'] as String,
          entries: entries,
        ),
      );
    } on DioException catch (error) {
      if (_isOffline(error)) return const ManifestOffline();
      if (error.response?.statusCode == 401) {
        return const ManifestUnauthorized();
      }
      return ManifestFailed(error.message ?? 'manifest fetch failed');
    }
  }

  Future<ExercisesResult> fetchExercises({
    required List<String> ids,
    required String accessToken,
  }) async {
    if (ids.isEmpty) {
      return const ExercisesFetched(envelopes: [], unavailable: []);
    }

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/content/exercises',
        queryParameters: {'ids': ids.join(',')},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data!;
      return ExercisesFetched(
        envelopes: ((body['exercises'] as List?) ?? const [])
            .cast<Map<String, Object?>>()
            .toList(growable: false),
        unavailable: ((body['unavailable'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );
    } on DioException catch (error) {
      if (_isOffline(error)) return const ExercisesOffline();
      return ExercisesFailed(error.message ?? 'exercise fetch failed');
    }
  }

  /// `dart:io` is unavailable on web, so this reads the Dio type rather than
  /// catching `SocketException`.
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
