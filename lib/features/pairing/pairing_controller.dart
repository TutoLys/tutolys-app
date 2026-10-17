import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/pairing_api.dart';
import '../../data/local_db/session_store.dart';

/// Where the app is, credential-wise.
enum SessionStatus {
  /// Still reading the secure store on launch.
  checking,

  /// No device token: show the pairing screen.
  unpaired,

  /// Paired and holding a valid access token.
  paired,
}

@immutable
class SessionState {
  const SessionState({
    required this.status,
    this.kid,
    this.accessToken,
  });

  const SessionState.checking() : this._(SessionStatus.checking);
  const SessionState.unpaired() : this._(SessionStatus.unpaired);

  const SessionState._(this.status)
      : kid = null,
        accessToken = null;

  final SessionStatus status;
  final PairedKid? kid;
  final String? accessToken;

  SessionState copyWith({
    SessionStatus? status,
    PairedKid? kid,
    String? accessToken,
  }) {
    return SessionState(
      status: status ?? this.status,
      kid: kid ?? this.kid,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

/// What the pairing screen is currently doing.
@immutable
class PairingUiState {
  const PairingUiState({
    this.isSubmitting = false,
    this.error,
  });

  final bool isSubmitting;

  /// Which failure to show. Kept as a kind rather than a string so the view
  /// picks the localised wording.
  final PairingError? error;

  PairingUiState copyWith({bool? isSubmitting, PairingError? error}) {
    return PairingUiState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

enum PairingError { invalidCode, offline, rateLimited, unexpected }

/// Owns the session: pairing, refreshing, and forgetting a revoked device.
class SessionController extends Notifier<SessionState> {
  late final SessionStore _store;
  late final PairingApi _api;

  Timer? _refreshTimer;

  /// The in-flight refresh, if any.
  ///
  /// This is the single-flight mutex the client census flagged as a hard
  /// requirement. Without it, two concurrent 401 retries both refresh; the
  /// loser presents an already-rotated token and the session is dropped. That
  /// exact bug was in the previous app.
  Future<void>? _inFlightRefresh;

  /// Whether to arm a background timer after each successful refresh.
  ///
  /// Always on in the app. Tests that drive `ensureFreshToken` directly turn
  /// it off, because a pending long-lived timer fails a widget test — and
  /// rather than suppress that check, the schedule is made explicit.
  late final bool _autoRefresh;

  @override
  SessionState build() {
    _store = ref.watch(sessionStoreProvider);
    _api = ref.watch(pairingApiProvider);
    _autoRefresh = ref.watch(sessionAutoRefreshProvider);

    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    });

    // Deliberately not awaited here: build must be synchronous. `restore()` is
    // kicked off by the app shell so the first frame can show a splash.
    return const SessionState.checking();
  }

  /// Keep the access token fresh for as long as the app is open.
  ///
  /// Access tokens live 15 minutes. Without this the app holds exactly one
  /// token and every content call starts failing a quarter of an hour into a
  /// session — which is to say, in the middle of a kid playing.
  void _scheduleRefresh(int expiresInSeconds) {
    _refreshTimer?.cancel();
    if (!_autoRefresh) return;

    // Refresh at ~80% of the lifetime, so a slow network has room to retry
    // before anything expires. The floor stops a short or zero lifetime from
    // turning into a busy loop.
    final seconds = max(30, (expiresInSeconds * 0.8).round());
    _refreshTimer = Timer(Duration(seconds: seconds), ensureFreshToken);
  }

  /// Refresh now, coalescing concurrent callers onto one request.
  Future<void> ensureFreshToken() {
    return _inFlightRefresh ??= _refreshOnce().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<void> _refreshOnce() async {
    final token = await _store.deviceToken();
    if (token == null || token.isEmpty) {
      state = const SessionState.unpaired();
      return;
    }

    final result = await _api.refresh(deviceToken: token);
    switch (result) {
      case RefreshSucceeded(:final accessToken, :final expiresIn):
        state = state.copyWith(
          status: SessionStatus.paired,
          accessToken: accessToken,
        );
        _scheduleRefresh(expiresIn);
      case RefreshRejected():
        await _store.clearPairing();
        _refreshTimer?.cancel();
        state = const SessionState.unpaired();
      case RefreshOffline() || RefreshFailed():
        // Stay paired and try again later. Offline play continues from the
        // cache; dropping the credential here would be the wrong trade.
        _scheduleRefresh(60);
    }
  }

  /// On launch: if a device token exists, trade it for an access token.
  ///
  /// This is the moment revocation takes effect. The server rejects the
  /// refresh, the stored credential is dropped, and the app returns to pairing.
  Future<void> restore() async {
    final token = await _store.deviceToken();
    if (token == null || token.isEmpty) {
      state = const SessionState.unpaired();
      return;
    }

    final result = await _api.refresh(deviceToken: token);
    switch (result) {
      case RefreshSucceeded(:final accessToken, :final expiresIn):
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
          accessToken: accessToken,
        );
        _scheduleRefresh(expiresIn);
      case RefreshRejected():
        // Revoked or archived: forget the credential.
        await _store.clearPairing();
        state = const SessionState.unpaired();
      case RefreshOffline():
        // Offline is NOT a reason to un-pair. The kid should keep playing
        // cached content; dropping the credential here would force a parent
        // to generate a new code every time the Wi-Fi drops.
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
        );
      case RefreshFailed():
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
        );
    }
  }

  /// Exchange a typed code. Returns the error kind, or null on success.
  Future<PairingError?> pair(String code) async {
    final deviceId = await _store.deviceId();

    final result = await _api.exchangeCode(
      code: code,
      deviceId: deviceId,
      platform: currentPlatform(),
      appVersion: appVersion,
    );

    switch (result) {
      case PairingSucceeded():
        await _store.savePairing(
          deviceToken: result.deviceToken,
          kidId: result.kidId,
          kidDisplayName: result.kidDisplayName,
          gradeLevel: result.gradeLevel,
        );
        state = SessionState(
          status: SessionStatus.paired,
          kid: PairedKid(
            id: result.kidId,
            displayName: result.kidDisplayName,
            gradeLevel: result.gradeLevel,
          ),
          accessToken: result.accessToken,
        );
        _scheduleRefresh(result.expiresIn);
        return null;
      case PairingCodeRejected():
        return PairingError.invalidCode;
      case PairingOffline():
        return PairingError.offline;
      case PairingRateLimited():
        return PairingError.rateLimited;
      case PairingFailed():
        return PairingError.unexpected;
    }
  }

  /// Unpair on this device, at the kid's or a parent's request.
  Future<void> forget() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _store.clearPairing();
    state = const SessionState.unpaired();
  }
}

/// Drives the pairing screen.
class PairingFormController extends Notifier<PairingUiState> {
  @override
  PairingUiState build() => const PairingUiState();

  Future<void> submit(String code) async {
    state = state.copyWith(isSubmitting: true, error: null);
    final error = await ref.read(sessionControllerProvider.notifier).pair(code);
    state = PairingUiState(isSubmitting: false, error: error);
  }

  void clearError() => state = state.copyWith(error: null);
}

// --- providers ------------------------------------------------------------

/// Base URL of the backend.
///
/// Defaults to the dev-stack address. Overridden at build time with
/// `--dart-define=TUTOLYS_API_BASE=https://api.tutolys.ca`.
const apiBaseUrl = String.fromEnvironment(
  'TUTOLYS_API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
);

const appVersion = '0.1.0';

String currentPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'linux',
  };
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      contentType: 'application/json',
      // Left at the default (2xx only) on purpose: PairingApi classifies
      // failures from the DioException, so a 400 or 429 must raise rather
      // than fall through to the success path and crash parsing a body that
      // has no device_token in it.
    ),
  );
});

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Whether the session keeps itself refreshed with a background timer.
///
/// True in the app. Overridden to false in widget tests, where an armed
/// 12-minute timer would (correctly) fail the pending-timer check.
final sessionAutoRefreshProvider = Provider<bool>((ref) => true);

final pairingApiProvider = Provider<PairingApi>(
  (ref) => PairingApi(dio: ref.watch(dioProvider)),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final pairingFormProvider =
    NotifierProvider<PairingFormController, PairingUiState>(
  PairingFormController.new,
);
