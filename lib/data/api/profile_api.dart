import 'package:dio/dio.dart';

/// `GET` / `PATCH /api/v1/me/profile`: the paired kid's own avatar
/// (`Platforms/BACKEND_WORKORDER_PROFILE.md`, P1).
///
/// Both calls are best effort and never throw. The avatar is cosmetic and
/// local-first, so offline, an error, or a backend that doesn't serve the
/// endpoint yet (404) all leave the app on its local choice.
class ProfileApi {
  ProfileApi({required this.dio});

  final Dio dio;

  static const _path = '/api/v1/me/profile';

  /// The backend's `avatar_key`: `''` when unset, null when unknown.
  Future<String?> fetchAvatarKey({required String accessToken}) async {
    try {
      final response = await dio.get<Map<String, Object?>>(
        _path,
        options: _auth(accessToken),
      );
      return response.data?['avatar_key'] as String?;
    } on DioException {
      return null;
    }
  }

  /// Whether the backend stored it.
  Future<bool> saveAvatarKey({
    required String accessToken,
    required String avatarKey,
  }) async {
    try {
      await dio.patch<Object?>(
        _path,
        data: {'avatar_key': avatarKey},
        options: _auth(accessToken),
      );
      return true;
    } on DioException {
      return false;
    }
  }

  static Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});
}
