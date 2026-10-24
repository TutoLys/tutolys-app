import 'dart:convert';

import 'package:crypto/crypto.dart';
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
  static const _guardianPinSaltKey = 'guardian_pin_salt';
  static const _guardianPinHashKey = 'guardian_pin_hash';

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
  /// The guardian PIN is cleared too — it protects *this* pairing, and the
  /// next family to pair this device should set their own rather than
  /// inherit one they never chose.
  Future<void> clearPairing() async {
    await Future.wait([
      _storage.delete(key: _deviceTokenKey),
      _storage.delete(key: _kidIdKey),
      _storage.delete(key: _kidNameKey),
      _storage.delete(key: _gradeKey),
      _storage.delete(key: _guardianPinSaltKey),
      _storage.delete(key: _guardianPinHashKey),
    ]);
  }

  /// Whether a guardian has set a PIN on this device yet.
  Future<bool> hasGuardianPin() async {
    final hash = await _storage.read(key: _guardianPinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set (or replace) the guardian PIN.
  ///
  /// Stored as a salted hash, not plaintext — this is a friction gate
  /// against a kid tapping "sign out" by accident or on a whim, not a
  /// security boundary, but there's no reason to store it any less
  /// carefully than that distinction requires.
  Future<void> setGuardianPin(String pin) async {
    final salt = const Uuid().v4();
    await Future.wait([
      _storage.write(key: _guardianPinSaltKey, value: salt),
      _storage.write(key: _guardianPinHashKey, value: _hashPin(pin, salt)),
    ]);
  }

  /// Whether the given PIN matches the one stored on this device.
  ///
  /// Returns `false`, never throws, if no PIN has been set yet — the
  /// caller is expected to check [hasGuardianPin] first and offer to
  /// create one instead of asking for entry.
  Future<bool> verifyGuardianPin(String pin) async {
    final salt = await _storage.read(key: _guardianPinSaltKey);
    final storedHash = await _storage.read(key: _guardianPinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
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
