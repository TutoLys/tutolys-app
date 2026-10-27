import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// What the device caches to check a kid's picture passcode offline
/// (`GET /me/passcode`, backend `apps.passcodes`).
///
/// Never the sequence itself: a per-kid salt and an HMAC over the kid id and
/// the sequence. A new salt comes with every change, so a cached verifier
/// for an old passcode simply stops matching.
class PasscodeVerifier {
  const PasscodeVerifier({
    required this.salt,
    required this.verifier,
    required this.algorithm,
    required this.imageSet,
  });

  factory PasscodeVerifier.fromJson(Map<String, Object?> json) =>
      PasscodeVerifier(
        salt: json['salt']! as String,
        verifier: json['verifier']! as String,
        algorithm: json['algorithm']! as String,
        imageSet: json['image_set']! as String,
      );

  final String salt;
  final String verifier;
  final String algorithm;

  /// Which nine pictures the indexes mean. The app knows only `v1`
  /// (`passcode_pictures.dart`).
  final String imageSet;

  static const supportedAlgorithm = 'hmac-sha256-v1';
  static const supportedImageSet = 'v1';

  /// Whether this app can check it. One it can't (a newer backend) is
  /// still a passcode: it is asked for, and only checked online.
  bool get isCheckable =>
      algorithm == supportedAlgorithm && imageSet == supportedImageSet;

  /// The backend's `compute`: hex of HMAC-SHA256 keyed on the salt, over
  /// `"<kid id>:<a>-<b>-<c>"`.
  bool matches(String kidId, List<int> sequence) {
    if (!isCheckable) return false;
    final mac = Hmac(sha256, utf8.encode(salt))
        .convert(utf8.encode('$kidId:${sequence.join('-')}'))
        .toString();
    return mac == verifier;
  }

  Map<String, Object?> toJson() => {
        'salt': salt,
        'verifier': verifier,
        'algorithm': algorithm,
        'image_set': imageSet,
      };
}

/// What the server says about a kid's passcode: none, or its verifier.
sealed class PasscodeState {
  const PasscodeState();
}

class NoPasscode extends PasscodeState {
  const NoPasscode();
}

class HasPasscode extends PasscodeState {
  const HasPasscode(this.verifier);
  final PasscodeVerifier verifier;
}

/// The answer to `POST /me/passcode/verify`.
sealed class PasscodeVerifyResult {
  const PasscodeVerifyResult();
}

/// It matched: a fresh access token for that kid.
class PasscodeVerified extends PasscodeVerifyResult {
  const PasscodeVerified({required this.accessToken, required this.expiresIn});
  final String accessToken;
  final int expiresIn;
}

class PasscodeWrong extends PasscodeVerifyResult {
  const PasscodeWrong();
}

/// The kid has no passcode (any more): cleared in the portal, say.
class PasscodeNotSet extends PasscodeVerifyResult {
  const PasscodeNotSet();
}

/// Ten tries a minute, a hundred a day, per kid.
class PasscodeRateLimited extends PasscodeVerifyResult {
  const PasscodeRateLimited();
}

/// Offline, or anything else that isn't an answer.
class PasscodeUnreachable extends PasscodeVerifyResult {
  const PasscodeUnreachable();
}

/// The device's picture-passcode endpoints (B-A0.5). Every call is made
/// with *that kid's* access token, and none throws.
class PasscodeApi {
  PasscodeApi({required this.dio});

  final Dio dio;

  static const _path = '/api/v1/me/passcode';

  /// The kid's passcode state, or null when it can't be read.
  Future<PasscodeState?> fetch({required String accessToken}) async {
    try {
      final response = await dio.get<Map<String, Object?>>(
        _path,
        options: _auth(accessToken),
      );
      return _state(response.data);
    } on DioException {
      return null;
    }
  }

  /// Sets or changes it. The new state, or null when it wasn't saved.
  Future<PasscodeState?> save({
    required String accessToken,
    required List<int> sequence,
  }) async {
    try {
      final response = await dio.put<Map<String, Object?>>(
        _path,
        data: {'sequence': sequence},
        options: _auth(accessToken),
      );
      return _state(response.data);
    } on DioException {
      return null;
    }
  }

  /// Whether it's gone.
  Future<bool> clear({required String accessToken}) async {
    try {
      await dio.delete<Object?>(_path, options: _auth(accessToken));
      return true;
    } on DioException catch (error) {
      return error.response?.statusCode == 404;
    }
  }

  Future<PasscodeVerifyResult> verify({
    required String accessToken,
    required List<int> sequence,
  }) async {
    try {
      final response = await dio.post<Map<String, Object?>>(
        '$_path/verify',
        data: {'sequence': sequence},
        options: _auth(accessToken),
      );
      final body = response.data!;
      return PasscodeVerified(
        accessToken: body['access_token']! as String,
        expiresIn: body['expires_in']! as int,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      return switch (error.response?.statusCode) {
        403 when code == 'wrong_passcode' => const PasscodeWrong(),
        404 when code == 'no_passcode' => const PasscodeNotSet(),
        429 => const PasscodeRateLimited(),
        _ => const PasscodeUnreachable(),
      };
    } on Object {
      return const PasscodeUnreachable();
    }
  }

  static PasscodeState? _state(Map<String, Object?>? data) {
    if (data == null) return null;
    if (data['is_set'] != true) return const NoPasscode();
    try {
      return HasPasscode(PasscodeVerifier.fromJson(data));
    } on Object {
      return null;
    }
  }

  static Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});
}
