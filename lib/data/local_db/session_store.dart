import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persistent credential storage for a paired device.
///
/// The device token is a long-lived credential. It goes in the platform secure
/// store — Keychain, libsecret, DPAPI, WebCrypto-backed storage on web — and
/// never into shared preferences, where any other process could read it.
///
/// The kid never retypes the pairing code: this is what makes that true.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _deviceTokenKey = 'device_token';
  static const _deviceIdKey = 'device_id';
  static const _kidIdKey = 'kid_id';
  static const _kidNameKey = 'kid_display_name';
  static const _gradeKey = 'grade_level';

  /// The installation's stable id, created once and kept.
  ///
  /// Stable across restarts so re-pairing updates the existing device row
  /// rather than accumulating one row per launch — which is what makes
  /// "revoke this device" mean something to a parent.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<String?> deviceToken() => _storage.read(key: _deviceTokenKey);

  Future<bool> get isPaired async {
    final token = await deviceToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> savePairing({
    required String deviceToken,
    required String kidId,
    required String kidDisplayName,
    required int gradeLevel,
  }) async {
    await Future.wait([
      _storage.write(key: _deviceTokenKey, value: deviceToken),
      _storage.write(key: _kidIdKey, value: kidId),
      _storage.write(key: _kidNameKey, value: kidDisplayName),
      _storage.write(key: _gradeKey, value: gradeLevel.toString()),
    ]);
  }

  Future<PairedKid?> pairedKid() async {
    final id = await _storage.read(key: _kidIdKey);
    final name = await _storage.read(key: _kidNameKey);
    final grade = await _storage.read(key: _gradeKey);
    if (id == null || name == null) return null;
    return PairedKid(
      id: id,
      displayName: name,
      gradeLevel: int.tryParse(grade ?? '') ?? 1,
    );
  }

  /// Forget the credential and return to an unpaired state.
  ///
  /// Called when the server rejects a refresh — the device was revoked or the
  /// kid archived. The `device_id` is deliberately kept: re-pairing the same
  /// installation should reuse its identity rather than create a second row.
  Future<void> clearPairing() async {
    await Future.wait([
      _storage.delete(key: _deviceTokenKey),
      _storage.delete(key: _kidIdKey),
      _storage.delete(key: _kidNameKey),
      _storage.delete(key: _gradeKey),
    ]);
  }
}

class PairedKid {
  const PairedKid({
    required this.id,
    required this.displayName,
    required this.gradeLevel,
  });

  final String id;
  final String displayName;
  final int gradeLevel;
}
