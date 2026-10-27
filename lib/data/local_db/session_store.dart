import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../api/pairing_api.dart' show ClassKid, Classroom;
import '../api/passcode_api.dart';

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

  // The four single-pairing keys from before multi-kid. Read only by the
  // migration in [pairings].
  static const _deviceTokenKey = 'device_token';
  static const _deviceIdKey = 'device_id';
  static const _kidIdKey = 'kid_id';
  static const _kidNameKey = 'kid_display_name';
  static const _gradeKey = 'grade_level';
  static const _pairingsKey = 'pairings';
  static const _activeKidKey = 'active_kid_id';
  static const _guardianPinSaltKey = 'guardian_pin_salt';
  static const _guardianPinHashKey = 'guardian_pin_hash';
  static const _guardianPinDigitsKey = 'guardian_pin_digits';
  static const _passcodeKeyPrefix = 'passcode_';
  static const _classroomKey = 'classroom';

  /// How many digits a new guardian PIN has. It was 4 before 2026-10-26;
  /// a PIN set then still opens the gate once, then must be replaced.
  static const guardianPinLength = 6;

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

  /// Every kid paired on this installation, in pairing order.
  ///
  /// One device token per kid, so attribution rides the credential, not the
  /// UI: switching kid switches token. The backend keys `Device` on
  /// `(kid, device_id)`, so pairing a second kid here leaves the first
  /// one's row alone (BACKEND_WORKORDER_PROFILE.md, P3).
  ///
  /// Kept as one JSON list in the secure store, since it holds the tokens.
  /// An installation from before multi-kid has the old single-pairing keys,
  /// and they're migrated on first read.
  Future<List<StoredPairing>> pairings() async {
    final raw = await _storage.read(key: _pairingsKey);
    if (raw != null) {
      return [
        for (final e in jsonDecode(raw) as List<dynamic>)
          StoredPairing.fromJson((e as Map).cast<String, Object?>()),
      ];
    }
    return _migrateLegacy();
  }

  Future<List<StoredPairing>> _migrateLegacy() async {
    final token = await _storage.read(key: _deviceTokenKey);
    final id = await _storage.read(key: _kidIdKey);
    final name = await _storage.read(key: _kidNameKey);
    if (token == null || token.isEmpty || id == null || name == null) {
      return [];
    }
    final grade = await _storage.read(key: _gradeKey);
    final migrated = [
      StoredPairing(
        kid: PairedKid(
          id: id,
          displayName: name,
          gradeLevel: int.tryParse(grade ?? '') ?? 1,
        ),
        deviceToken: token,
      ),
    ];
    // Written before the old keys go, so a crash in between leaves the
    // pairing readable either way.
    await _writePairings(migrated);
    await _storage.write(key: _activeKidKey, value: id);
    await Future.wait([
      _storage.delete(key: _deviceTokenKey),
      _storage.delete(key: _kidIdKey),
      _storage.delete(key: _kidNameKey),
      _storage.delete(key: _gradeKey),
    ]);
    return migrated;
  }

  Future<void> _writePairings(List<StoredPairing> list) => _storage.write(
        key: _pairingsKey,
        value: jsonEncode([for (final p in list) p.toJson()]),
      );

  /// Every paired kid, without their tokens.
  Future<List<PairedKid>> pairedKids() async =>
      [for (final p in await pairings()) p.kid];

  /// The kid playing now: the last one chosen, else the first paired.
  Future<StoredPairing?> _active() async {
    final all = await pairings();
    if (all.isEmpty) return null;
    final id = await _storage.read(key: _activeKidKey);
    return all.firstWhere((p) => p.kid.id == id, orElse: () => all.first);
  }

  /// Make [kidId] the active kid. Ignored for a kid not paired here.
  Future<void> setActiveKid(String kidId) async {
    if ((await pairings()).any((p) => p.kid.id == kidId)) {
      await _storage.write(key: _activeKidKey, value: kidId);
    }
  }

  /// The active kid's device token.
  Future<String?> deviceToken() async => (await _active())?.deviceToken;

  Future<String?> deviceTokenFor(String kidId) async {
    for (final p in await pairings()) {
      if (p.kid.id == kidId) return p.deviceToken;
    }
    return null;
  }

  Future<bool> get isPaired async {
    final token = await deviceToken();
    return token != null && token.isNotEmpty;
  }

  /// Adds a kid, or replaces their token when re-paired, and makes them
  /// the active kid. Other kids' pairings are untouched.
  Future<void> savePairing({
    required String deviceToken,
    required String kidId,
    required String kidDisplayName,
    required int gradeLevel,
  }) async {
    final all = await pairings();
    final next = StoredPairing(
      kid: PairedKid(
        id: kidId,
        displayName: kidDisplayName,
        gradeLevel: gradeLevel,
      ),
      deviceToken: deviceToken,
    );
    final i = all.indexWhere((p) => p.kid.id == kidId);
    if (i < 0) {
      all.add(next);
    } else {
      all[i] = next;
    }
    await _writePairings(all);
    await _storage.write(key: _activeKidKey, value: kidId);
  }

  /// The active kid.
  Future<PairedKid?> pairedKid() async => (await _active())?.kid;

  /// The class this tablet was paired for with a class code, or null on a
  /// family device (O8). A class tablet asks every kid for their picture
  /// passcode, always.
  Future<Classroom?> classroom() async {
    final raw = await _storage.read(key: _classroomKey);
    if (raw == null) return null;
    try {
      return Classroom.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  /// Stores a class code's pairings: every learner of [classroom], added
  /// or re-tokened, and the tablet marked as that class's. A kid's
  /// passcode state is cached as "none" when the server says so; one who
  /// has a passcode is left for the next sync to fetch its verifier.
  ///
  /// Doesn't choose an active kid: on a class tablet, nobody is anyone
  /// until they tap their pictures.
  Future<void> saveClassPairings(
    Classroom classroom,
    List<ClassKid> kids,
  ) async {
    final all = await pairings();
    for (final k in kids) {
      final next = StoredPairing(
        kid: PairedKid(
          id: k.kidId,
          displayName: k.displayName,
          gradeLevel: k.gradeLevel,
        ),
        deviceToken: k.deviceToken,
      );
      final i = all.indexWhere((p) => p.kid.id == k.kidId);
      if (i < 0) {
        all.add(next);
      } else {
        all[i] = next;
      }
      if (!k.hasPasscode) await savePasscode(k.kidId, const NoPasscode());
    }
    await _writePairings(all);
    await _storage.write(
      key: _classroomKey,
      value: jsonEncode(classroom.toJson()),
    );
  }

  /// Forget the active kid's credential. Other kids stay paired, and the
  /// next one becomes active.
  ///
  /// Called when the server rejects a refresh — that kid's device was
  /// revoked or the kid archived — and when a guardian removes the profile.
  /// The `device_id` is deliberately kept: re-pairing the same installation
  /// should reuse its identity rather than create a second row. Once the
  /// last kid goes, the guardian PIN goes too — it protects *this* family's
  /// pairings, and the next family to pair this device should set their
  /// own rather than inherit one they never chose.
  Future<void> clearPairing() async {
    final active = await _active();
    final rest = [
      for (final p in await pairings())
        if (p.kid.id != active?.kid.id) p,
    ];
    if (active != null) {
      await _storage.delete(key: '$_passcodeKeyPrefix${active.kid.id}');
    }
    if (rest.isNotEmpty) {
      await _writePairings(rest);
      await _storage.write(key: _activeKidKey, value: rest.first.kid.id);
      return;
    }
    await Future.wait([
      _storage.delete(key: _pairingsKey),
      _storage.delete(key: _activeKidKey),
      _storage.delete(key: _classroomKey),
      _storage.delete(key: _guardianPinSaltKey),
      _storage.delete(key: _guardianPinHashKey),
      _storage.delete(key: _guardianPinDigitsKey),
    ]);
  }

  /// Whether a guardian has set a PIN on this device yet.
  Future<bool> hasGuardianPin() async {
    final hash = await _storage.read(key: _guardianPinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// How many digits the stored PIN has, or null when none is set.
  ///
  /// A PIN set before the move to 6 digits stored no count, and every PIN
  /// then had 4, so a missing count means 4.
  Future<int?> guardianPinDigits() async {
    if (!await hasGuardianPin()) return null;
    final raw = await _storage.read(key: _guardianPinDigitsKey);
    return int.tryParse(raw ?? '') ?? 4;
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
      _storage.write(key: _guardianPinDigitsKey, value: '${pin.length}'),
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

  /// What this device last learned about [kidId]'s picture passcode, or
  /// null when it never has (B-A0.5).
  ///
  /// Kept per kid so "Qui joue ?" can ask for it offline. Only the
  /// server's verifier is kept, never the sequence.
  Future<PasscodeState?> passcodeFor(String kidId) async {
    final raw = await _storage.read(key: '$_passcodeKeyPrefix$kidId');
    if (raw == null) return null;
    if (raw == 'none') return const NoPasscode();
    try {
      return HasPasscode(
        PasscodeVerifier.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        ),
      );
    } on Object {
      return null;
    }
  }

  Future<void> savePasscode(String kidId, PasscodeState state) =>
      _storage.write(
        key: '$_passcodeKeyPrefix$kidId',
        value: switch (state) {
          NoPasscode() => 'none',
          HasPasscode(:final verifier) => jsonEncode(verifier.toJson()),
        },
      );

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

/// One kid's pairing on this installation: who, and their device token.
class StoredPairing {
  const StoredPairing({required this.kid, required this.deviceToken});

  factory StoredPairing.fromJson(Map<String, Object?> json) => StoredPairing(
        kid: PairedKid(
          id: json['kid_id']! as String,
          displayName: json['display_name']! as String,
          gradeLevel: json['grade_level'] as int? ?? 1,
        ),
        deviceToken: json['device_token']! as String,
      );

  final PairedKid kid;
  final String deviceToken;

  Map<String, Object?> toJson() => {
        'kid_id': kid.id,
        'display_name': kid.displayName,
        'grade_level': kid.gradeLevel,
        'device_token': deviceToken,
      };
}
