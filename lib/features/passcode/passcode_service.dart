import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/pairing_api.dart';
import '../../data/api/passcode_api.dart';
import '../../data/local_db/session_store.dart';
import '../pairing/pairing_controller.dart';

/// How a kid's passcode check came out.
sealed class PasscodeCheck {
  const PasscodeCheck();
}

/// It's them. [accessToken] is set when the server confirmed it, so the
/// switch needn't refresh again; null when it was checked offline or the
/// kid turned out to have no passcode.
class PasscodeAccepted extends PasscodeCheck {
  const PasscodeAccepted({this.accessToken, this.expiresIn});
  final String? accessToken;
  final int? expiresIn;
}

class PasscodeRejected extends PasscodeCheck {
  const PasscodeRejected();
}

/// Too many tries for now; the server asks to wait.
class PasscodeTooManyTries extends PasscodeCheck {
  const PasscodeTooManyTries();
}

/// The picture passcode (B-A0.5): "who's playing?" on a shared device.
///
/// It is not security. It exists so a sibling's play doesn't land on
/// another kid's mastery data, so wherever a check can't be made, it lets
/// the child through rather than lock anyone out of playing: offline with
/// nothing cached, or with a verifier this app can't compute.
///
/// Every call uses the kid's *own* credential: their device token is
/// refreshed into an access token for that kid, which is what the
/// endpoints are scoped by.
class PasscodeService {
  PasscodeService({
    required this.store,
    required this.pairingApi,
    required this.api,
  });

  final SessionStore store;
  final PairingApi pairingApi;
  final PasscodeApi api;

  /// Whether choosing [kidId] asks for a passcode, by what this device
  /// last learned. A kid it never learned about isn't asked.
  Future<bool> isRequired(String kidId) async =>
      await store.passcodeFor(kidId) is HasPasscode;

  /// Re-reads every paired kid's passcode from the server and caches it.
  ///
  /// Run whenever "Qui joue ?" opens, so a passcode a teacher or parent set
  /// in the portal is asked for from the next choice on. Best effort: a kid
  /// whose state can't be read keeps what was cached.
  Future<void> syncAll() async {
    for (final pairing in await store.pairings()) {
      final token = await _accessTokenFor(pairing.kid.id);
      if (token == null) continue;
      final state = await api.fetch(accessToken: token);
      if (state != null) await store.savePasscode(pairing.kid.id, state);
    }
  }

  /// Checks [sequence] for [kidId]: with the server when it answers, else
  /// against the cached verifier.
  Future<PasscodeCheck> check(String kidId, List<int> sequence) async {
    final token = await _accessTokenFor(kidId);
    if (token != null) {
      switch (await api.verify(accessToken: token, sequence: sequence)) {
        case PasscodeVerified(:final accessToken, :final expiresIn):
          return PasscodeAccepted(accessToken: accessToken, expiresIn: expiresIn);
        case PasscodeWrong():
          // Maybe changed in the portal since it was cached: learn the new
          // one, so the next offline check uses it.
          final state = await api.fetch(accessToken: token);
          if (state != null) await store.savePasscode(kidId, state);
          return const PasscodeRejected();
        case PasscodeNotSet():
          await store.savePasscode(kidId, const NoPasscode());
          return PasscodeAccepted(accessToken: token);
        case PasscodeRateLimited():
          return const PasscodeTooManyTries();
        case PasscodeUnreachable():
          break;
      }
    }
    return switch (await store.passcodeFor(kidId)) {
      HasPasscode(:final verifier) when verifier.isCheckable =>
        verifier.matches(kidId, sequence)
            ? const PasscodeAccepted()
            : const PasscodeRejected(),
      _ => const PasscodeAccepted(),
    };
  }

  /// Sets or changes [kidId]'s passcode. Needs the server: a passcode the
  /// server doesn't have would be asked for here and nowhere else. Returns
  /// whether it was saved.
  Future<bool> save(String kidId, List<int> sequence) async {
    final token = await _accessTokenFor(kidId);
    if (token == null) return false;
    final state = await api.save(accessToken: token, sequence: sequence);
    if (state == null) return false;
    await store.savePasscode(kidId, state);
    return true;
  }

  /// Removes [kidId]'s passcode, so choosing them is a tap again.
  Future<bool> clear(String kidId) async {
    final token = await _accessTokenFor(kidId);
    if (token == null) return false;
    if (!await api.clear(accessToken: token)) return false;
    await store.savePasscode(kidId, const NoPasscode());
    return true;
  }

  Future<String?> _accessTokenFor(String kidId) async {
    final deviceToken = await store.deviceTokenFor(kidId);
    if (deviceToken == null) return null;
    return switch (await pairingApi.refresh(deviceToken: deviceToken)) {
      RefreshSucceeded(:final accessToken) => accessToken,
      _ => null,
    };
  }
}

/// Whether pickers refresh every kid's passcode from the server as they
/// open. On in the app; widget tests that don't fake the passcode API turn
/// it off, like the outbox flusher's auto-start.
final passcodeSyncEnabledProvider = Provider<bool>((ref) => true);

final passcodeApiProvider = Provider<PasscodeApi>(
  (ref) => PasscodeApi(dio: ref.watch(dioProvider)),
);

final passcodeServiceProvider = Provider<PasscodeService>(
  (ref) => PasscodeService(
    store: ref.watch(sessionStoreProvider),
    pairingApi: ref.watch(pairingApiProvider),
    api: ref.watch(passcodeApiProvider),
  ),
);

/// Whether each paired kid has a passcode, by this device's cache. Read by
/// the guardian's list; invalidated after a change.
final kidHasPasscodeProvider = FutureProvider.family<bool, String>(
  (ref, kidId) => ref.watch(passcodeServiceProvider).isRequired(kidId),
);
