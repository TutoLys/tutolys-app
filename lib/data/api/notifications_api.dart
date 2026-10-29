import 'package:dio/dio.dart';

/// One row of the kid's in-app inbox (backend ADR 0024).
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.params = const {},
    this.local = false,
  });

  factory NotificationDto.fromJson(Map<String, Object?> json) {
    return NotificationDto(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      isRead: json['is_read'] as bool? ?? json['read_at'] != null,
    );
  }

  final String id;

  /// `daily_quest_completed` or `streak_freeze_spent` today. The app words
  /// known types itself, in the reader's language; [message] is the
  /// backend's French text, the fallback for a type this build doesn't know.
  final String type;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  /// What the app's own wording needs, for one it wrote itself (ADR 0097).
  final Map<String, Object?> params;

  /// Written on this device rather than served.
  final bool local;

  NotificationDto read() => NotificationDto(
    id: id,
    type: type,
    message: message,
    createdAt: createdAt,
    isRead: true,
    params: params,
    local: local,
  );
}

class NotificationInbox {
  const NotificationInbox({required this.unreadCount, required this.items});

  factory NotificationInbox.fromJson(Map<String, Object?> json) {
    return NotificationInbox(
      unreadCount: json['unread_count'] as int? ?? 0,
      items: ((json['notifications'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(NotificationDto.fromJson)
          .toList(growable: false),
    );
  }

  /// Of everything unread, not only of [items] (the backend caps the list).
  final int unreadCount;
  final List<NotificationDto> items;
}

sealed class NotificationsResult {
  const NotificationsResult();
}

class NotificationsFetched extends NotificationsResult {
  const NotificationsFetched(this.inbox);
  final NotificationInbox inbox;
}

/// Offline, unauthorized or failed alike: the bell just keeps what it had.
class NotificationsUnavailable extends NotificationsResult {
  const NotificationsUnavailable();
}

/// The paired device's inbox: `GET /api/v1/me/notifications` and
/// `POST /api/v1/me/notifications/read`. No kid id in either URL; the
/// backend reads it from the device token, like `/me/progress`.
class NotificationsApi {
  NotificationsApi({required this.dio});

  final Dio dio;

  Future<NotificationsResult> fetch({required String accessToken}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/me/notifications',
        options: _auth(accessToken),
      );
      return NotificationsFetched(NotificationInbox.fromJson(response.data!));
    } on DioException {
      return const NotificationsUnavailable();
    }
  }

  /// Marks everything unread as read (no `ids`: the backend's mark-all).
  /// Returns whether the server took it.
  Future<bool> markAllRead({required String accessToken}) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/me/notifications/read',
        data: const <String, Object?>{},
        options: _auth(accessToken),
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});
}
