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

/// The kid's earned avatars as the backend keeps them (backend ADR 0064).
class RemoteAvatarUnlocks {
  const RemoteAvatarUnlocks({required this.unlocked, required this.drops});

  final Set<String> unlocked;

  /// Lesson (exercise id) → the rare character it revealed.
  final Map<String, String> drops;
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

  static const _unlocksPath = '/api/v1/me/avatar-unlocks';

  /// Merges this device's unlocks into the backend's copy and returns the
  /// merged state, or null when that fails (offline, an error, or a
  /// backend without the endpoint yet). The backend only ever adds, so
  /// posting can never remove an unlock another device recorded.
  ///
  /// Only UUID-shaped lesson ids are sent: the backend refuses the whole
  /// body over one that isn't, and such a drop stays on this device.
  Future<RemoteAvatarUnlocks?> mergeAvatarUnlocks({
    required String accessToken,
    required Set<String> unlocked,
    required Map<String, String> drops,
  }) async {
    try {
      final response = await dio.post<Map<String, Object?>>(
        _unlocksPath,
        data: {
          'unlocked': unlocked.toList()..sort(),
          'drops': {
            for (final MapEntry(:key, :value) in drops.entries)
              if (_uuid.hasMatch(key)) key: value,
          },
        },
        options: _auth(accessToken),
      );
      final data = response.data;
      if (data == null) return null;
      return RemoteAvatarUnlocks(
        unlocked: {
          for (final k in data['unlocked'] as List<Object?>? ?? const [])
            if (k is String) k,
        },
        drops: {
          for (final MapEntry(:key, :value)
              in (data['drops'] as Map<String, Object?>? ?? const {}).entries)
            if (value is String) key.toLowerCase(): value,
        },
      );
    } on DioException {
      return null;
    }
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});
}
