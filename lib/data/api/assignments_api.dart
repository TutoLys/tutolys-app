import 'package:dio/dio.dart';

/// One piece of work a teacher gave this kid (backend ADR 0123).
///
/// Carries the organization's name and the work, never another child: the
/// backend pins that shape (#12).
class AssignmentDto {
  const AssignmentDto({
    required this.id,
    required this.title,
    required this.fromName,
    required this.skillNodeId,
    required this.exerciseId,
    required this.dueOn,
    required this.done,
  });

  factory AssignmentDto.fromJson(Map<String, Object?> json) => AssignmentDto(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    fromName: json['from_name'] as String? ?? '',
    skillNodeId: json['skill_node_id'] as String? ?? '',
    exerciseId: json['exercise_id'] as String?,
    dueOn: DateTime.tryParse(json['due_on'] as String? ?? ''),
    done: json['done'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String fromName;
  final String skillNodeId;
  final String? exerciseId;
  final DateTime? dueOn;

  /// The server's answer, which lags a finished lesson by up to 15 minutes.
  final bool done;
}

/// `GET /api/v1/me/assignments`. No kid id in the URL: the backend reads it
/// from the device token, like `/me/progress`. Null means "couldn't ask",
/// so the caller keeps what it had rather than showing an empty list.
class AssignmentsApi {
  AssignmentsApi({required this.dio});

  final Dio dio;

  Future<List<AssignmentDto>?> fetch({required String accessToken}) async {
    try {
      final response = await dio.get<List<dynamic>>(
        '/api/v1/me/assignments',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return (response.data ?? const [])
          .cast<Map<String, Object?>>()
          .map(AssignmentDto.fromJson)
          .toList(growable: false);
    } on DioException {
      return null;
    }
  }
}
