import 'package:dio/dio.dart';

/// What the telemetry service said about a batch.
sealed class UploadResult {
  const UploadResult();
}

/// The server processed the batch and reported a per-event outcome.
///
/// `accepted` and `duplicate` are both successes from the outbox's point of
/// view: a duplicate means the server already has it, so the local row can be
/// cleared. Treating duplicates as failures is how an outbox gets stuck
/// forever re-sending events that already landed.
class UploadProcessed extends UploadResult {
  const UploadProcessed({
    required this.delivered,
    required this.rejected,
  });

  /// Event ids the server now holds (accepted or already had).
  final List<String> delivered;

  /// Event ids the server refused, with the reason. These will never succeed,
  /// so retrying them forever is pointless — they are surfaced instead.
  final Map<String, String> rejected;
}

/// No network. Not a failure of the events; try again later.
class UploadOffline extends UploadResult {
  const UploadOffline();
}

/// The device credential is no longer valid.
class UploadUnauthorized extends UploadResult {
  const UploadUnauthorized();
}

/// The server could not store them right now (503) or failed unexpectedly.
class UploadRetryable extends UploadResult {
  const UploadRetryable(this.detail);
  final String detail;
}

/// Uploads batches of play events.
class TelemetryApi {
  TelemetryApi({required this.dio});

  final Dio dio;

  /// Hard server limit is 200; 50 keeps a single request small enough to
  /// finish on a weak connection.
  static const maxBatchSize = 50;

  Future<UploadResult> uploadBatch({
    required List<Map<String, Object?>> events,
    required String accessToken,
  }) async {
    if (events.isEmpty) {
      return const UploadProcessed(delivered: [], rejected: {});
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/v1/events/batch',
        data: {'events': events},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final results = (response.data?['results'] as List?) ?? const [];

      final delivered = <String>[];
      final rejected = <String, String>{};

      for (final entry in results) {
        if (entry is! Map) continue;
        final id = entry['event_id'] as String?;
        if (id == null) continue;

        switch (entry['outcome']) {
          case 'accepted' || 'duplicate':
            delivered.add(id);
          case 'rejected':
            rejected[id] = (entry['reason'] as String?) ?? 'rejected';
        }
      }

      return UploadProcessed(delivered: delivered, rejected: rejected);
    } on DioException catch (error) {
      return _classify(error);
    }
  }

  UploadResult _classify(DioException error) {
    final offline = switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
    if (offline) return const UploadOffline();

    final status = error.response?.statusCode;
    if (status == 401) return const UploadUnauthorized();

    // 503 explicitly means "retry; duplicates are discarded", and 413 means
    // the batch was too large — both are the client's problem to retry with a
    // smaller batch rather than events to discard.
    return UploadRetryable('HTTP $status: ${error.message}');
  }
}
