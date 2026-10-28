import 'package:dio/dio.dart';

/// Outcome of a pairing attempt.
///
/// Modelled as a sealed type rather than exceptions-plus-strings so the UI has
/// to handle each case: "the code was wrong" and "there is no Wi-Fi" need
/// different words for a child, and a generic failure message for both is how
/// you end up with a kid retyping a perfectly good code.
sealed class PairingResult {
  const PairingResult();
}

class PairingSucceeded extends PairingResult {
  const PairingSucceeded({
    required this.deviceToken,
    required this.accessToken,
    required this.expiresIn,
    required this.kidId,
    required this.kidDisplayName,
    required this.gradeLevel,
  });

  final String deviceToken;
  final String accessToken;
  final int expiresIn;
  final String kidId;
  final String kidDisplayName;
  final int gradeLevel;
}

/// The code is wrong, expired, revoked or already used.
///
/// The server deliberately does not distinguish these, so neither do we:
/// telling a caller which codes exist is information it should not have.
class PairingCodeRejected extends PairingResult {
  const PairingCodeRejected(this.message);
  final String message;
}

class PairingRateLimited extends PairingResult {
  const PairingRateLimited({this.retryAfterSeconds});
  final int? retryAfterSeconds;
}

class PairingOffline extends PairingResult {
  const PairingOffline();
}

class PairingFailed extends PairingResult {
  const PairingFailed(this.detail);
  final String detail;
}

/// The class a shared classroom tablet was paired for (O8, backend
/// ADR 0125).
class Classroom {
  const Classroom({
    required this.classId,
    required this.className,
    required this.organizationName,
  });

  factory Classroom.fromJson(Map<String, Object?> json) => Classroom(
        classId: json['class_id']! as String,
        className: json['class_name'] as String? ?? '',
        organizationName: json['organization_name'] as String? ?? '',
      );

  final String classId;
  final String className;
  final String organizationName;

  Map<String, Object?> toJson() => {
        'class_id': classId,
        'class_name': className,
        'organization_name': organizationName,
      };
}

/// One learner of a class, paired on this tablet: a normal pairing, plus
/// whether they have a picture passcode yet.
class ClassKid {
  const ClassKid({
    required this.kidId,
    required this.displayName,
    required this.gradeLevel,
    required this.deviceToken,
    required this.hasPasscode,
    this.avatarKey = '',
    this.sex = '',
  });

  final String kidId;
  final String displayName;
  final int gradeLevel;
  final String deviceToken;
  final bool hasPasscode;

  /// The learner's own avatar and sex, as the backend keeps them: shown on
  /// "Qui joue ?" before anyone is chosen, so a class of children doesn't
  /// see one face repeated.
  final String avatarKey;
  final String sex;
}

/// A class code worked: one pairing per consented learner.
class ClassPairingSucceeded extends PairingResult {
  const ClassPairingSucceeded({required this.classroom, required this.kids});
  final Classroom classroom;
  final List<ClassKid> kids;
}

/// A valid class code for a class with no learners yet.
class ClassIsEmpty extends PairingResult {
  const ClassIsEmpty();
}

/// The school isn't entitled (no agreement, or it lapsed).
class ClassNotEntitled extends PairingResult {
  const ClassNotEntitled();
}

/// Result of refreshing an access token from a stored device token.
sealed class RefreshResult {
  const RefreshResult();
}

class RefreshSucceeded extends RefreshResult {
  const RefreshSucceeded({required this.accessToken, required this.expiresIn});
  final String accessToken;
  final int expiresIn;
}

/// The device was revoked, or the kid was archived.
///
/// This is the signal to return to the pairing screen — the one case where the
/// app must forget its stored credential.
///
/// [reason] is set only when the server says *why* in the body's `reason`
/// field. Only then does the app erase the kid's local data (ADR 0037): a
/// bare or unknown 401 might be a backend fault, and a fault must cost a
/// re-pair, never a child's unsent results.
class RefreshRejected extends RefreshResult {
  const RefreshRejected({this.reason});

  final RejectionReason? reason;
}

/// Why the server rejected a kid's credential, when it says.
enum RejectionReason {
  revoked,
  archived,
  erased;

  /// Null for anything but an exact, known value.
  static RejectionReason? parse(Object? raw) {
    for (final reason in values) {
      if (reason.name == raw) return reason;
    }
    return null;
  }
}

class RefreshOffline extends RefreshResult {
  const RefreshOffline();
}

class RefreshFailed extends RefreshResult {
  const RefreshFailed(this.detail);
  final String detail;
}

/// Talks to the backend's pairing endpoints.
///
/// Hand-written for now. Once the backend's OpenAPI contract settles this is
/// the file a generated client replaces, which is why nothing else in the app
/// constructs these requests.
class PairingApi {
  PairingApi({required this.dio});

  final Dio dio;

  Future<PairingResult> exchangeCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/pairing/exchange',
        data: {
          'code': code,
          'device_id': deviceId,
          'platform': platform,
          'app_version': appVersion,
        },
      );

      final body = response.data!;
      return PairingSucceeded(
        deviceToken: body['device_token'] as String,
        accessToken: body['access_token'] as String,
        expiresIn: body['expires_in'] as int,
        kidId: body['kid_id'] as String,
        kidDisplayName: body['kid_display_name'] as String,
        gradeLevel: body['grade_level'] as int,
      );
    } on DioException catch (error) {
      return _mapPairingError(error);
    }
  }

  /// A teacher's class code: pairs this tablet for every consented learner
  /// of the class at once (`POST /pairing/class-exchange`).
  Future<PairingResult> exchangeClassCode({
    required String code,
    required String deviceId,
    required String platform,
    required String appVersion,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/pairing/class-exchange',
        data: {
          'code': code,
          'device_id': deviceId,
          'platform': platform,
          'app_version': appVersion,
        },
      );
      final body = response.data!.cast<String, Object?>();
      return ClassPairingSucceeded(
        classroom: Classroom.fromJson(body),
        kids: [
          for (final raw in body['kids']! as List<dynamic>)
            if (raw case final Map<dynamic, dynamic> k)
              ClassKid(
                kidId: k['kid_id']! as String,
                displayName: k['display_name']! as String,
                gradeLevel: k['grade_level'] as int? ?? 1,
                deviceToken: k['device_token']! as String,
                hasPasscode: k['has_passcode'] == true,
                avatarKey: k['avatar_key'] as String? ?? '',
                sex: k['sex'] as String? ?? '',
              ),
        ],
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      if (error.response?.statusCode == 400 && code == 'empty_class') {
        return const ClassIsEmpty();
      }
      if (error.response?.statusCode == 403 &&
          code == 'organization_not_entitled') {
        return const ClassNotEntitled();
      }
      return _mapPairingError(error);
    }
  }

  Future<RefreshResult> refresh({required String deviceToken}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/pairing/refresh',
        data: {'device_token': deviceToken},
      );
      final body = response.data!;
      return RefreshSucceeded(
        accessToken: body['access_token'] as String,
        expiresIn: body['expires_in'] as int,
      );
    } on DioException catch (error) {
      if (_isOffline(error)) return const RefreshOffline();
      if (error.response?.statusCode == 401) {
        // Revoked or archived. The caller must clear the stored token.
        final data = error.response?.data;
        return RefreshRejected(
          reason: data is Map ? RejectionReason.parse(data['reason']) : null,
        );
      }
      return RefreshFailed(error.message ?? 'refresh failed');
    }
  }

  PairingResult _mapPairingError(DioException error) {
    if (_isOffline(error)) return const PairingOffline();

    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] as String? : null;

    return switch (status) {
      400 => PairingCodeRejected(detail ?? 'invalid code'),
      429 => PairingRateLimited(
          retryAfterSeconds: int.tryParse(
            error.response?.headers.value('retry-after') ?? '',
          ),
        ),
      _ => PairingFailed(detail ?? error.message ?? 'pairing failed'),
    };
  }

  /// Distinguish "no network" from "the server said no".
  ///
  /// Worth the care: a child shown "your code is wrong" when the Wi-Fi is off
  /// will keep retyping a code that was never the problem.
  ///
  /// Checked via [DioExceptionType] rather than `SocketException`, because
  /// `dart:io` does not exist on web and importing it would break that build.
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
