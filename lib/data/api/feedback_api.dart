import 'package:dio/dio.dart';

/// What a send came to.
enum FeedbackSendResult {
  /// The backend stored it. Drop it from the queue.
  sent,

  /// Offline, a server error, throttled, or a backend that doesn't serve
  /// the endpoint yet (404). Keep it and try again later.
  retryLater,

  /// The backend refused the message itself (400, 413…). Retrying the same
  /// bytes can never succeed, so it is dropped rather than kept forever.
  rejected,
}

/// `POST /api/v1/feedback` from a paired device
/// (`Platforms/BACKEND_WORKORDER_FEEDBACK.md`, F1/F3; app ADR 0104).
///
/// **The body is provisional** until Backend sends the contract: `kind`,
/// `text`, `context` (the allowlist below), and `client_id`, which lets the
/// backend ignore a retry of a message it already stored.
///
/// Never throws.
class FeedbackApi {
  FeedbackApi({required this.dio});

  final Dio dio;

  static const path = '/api/v1/feedback';

  Future<FeedbackSendResult> send({
    required String accessToken,
    required Map<String, Object?> body,
  }) async {
    try {
      await dio.post<Object?>(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return FeedbackSendResult.sent;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only a refusal of the message itself is final. Anything else (an
      // expired token, a seat check, a 404 before the endpoint is deployed,
      // throttling, a server error) may pass on a later try.
      return const {400, 413, 422}.contains(status)
          ? FeedbackSendResult.rejected
          : FeedbackSendResult.retryLater;
    }
  }
}
