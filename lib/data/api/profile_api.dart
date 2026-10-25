import 'package:dio/dio.dart';

import '../../features/profile/avatars.dart' show KidSex;

/// What `GET /me/profile` says about the paired kid.
class RemoteProfile {
  const RemoteProfile({required this.avatarKey, required this.sex});

  /// `''` when unset.
  final String avatarKey;

  /// Set by an adult in the portal, read-only here. A backend that
  /// doesn't send it yet reads as [KidSex.unspecified].
  final KidSex sex;
}

/// `GET` / `PATCH /api/v1/me/profile`: the paired kid's own avatar and sex
/// (`Platforms/BACKEND_WORKORDER_PROFILE.md`, P1).
///
/// Both calls are best effort and never throw. The avatar is cosmetic and
/// local-first, so offline, an error, or a backend that doesn't serve the
/// endpoint yet (404) all leave the app on its local choice.
class ProfileApi {
  ProfileApi({required this.dio});

  final Dio dio;

  static const _path = '/api/v1/me/profile';

  /// The kid's profile, or null when it can't be read.
  Future<RemoteProfile?> fetchProfile({required String accessToken}) async {
    try {
      final response = await dio.get<Map<String, Object?>>(
        _path,
        options: _auth(accessToken),
      );
      final data = response.data;
      if (data == null) return null;
      return RemoteProfile(
        avatarKey: data['avatar_key'] as String? ?? '',
        sex: KidSex.parse(data['sex'] as String?),
      );
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
