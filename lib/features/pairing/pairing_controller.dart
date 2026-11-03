import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/boot_log.dart';
import '../../data/api/pairing_api.dart';
import '../../data/local_db/database.dart';
import '../../data/local_db/kid_local_data.dart';
import '../../data/local_db/session_store.dart';
import '../../core/diagnostics/request_id.dart';
import '../profile/avatars.dart' show AvatarStore, KidSex, isKnownAvatar;
import '../../core/diagnostics/diag_log.dart' show recordCaught;

/// Where the app is, credential-wise.
enum SessionStatus {
  /// Still reading the secure store on launch.
  checking,

  /// No device token: show the pairing screen.
  unpaired,

  /// Paired and holding a valid access token.
  paired,
}

/// What the paired shell is showing on top of the app, if anything.
enum ProfileStage {
  /// The app itself.
  none,

  /// "Qui joue ?": on launch when several kids share this device, and
  /// whenever the app must ask who's there (ADR 0123).
  choosing,

  /// The pairing-code screen, adding another kid to this device.
  adding,
}

@immutable
class SessionState {
  const SessionState({
    required this.status,
    this.kid,
    this.accessToken,
    this.kids = const [],
    this.stage = ProfileStage.none,
    this.classroom,
    this.confirmEveryone = false,
    this.noSeat = false,
  });

  const SessionState.checking() : this._(SessionStatus.checking);
  const SessionState.unpaired() : this._(SessionStatus.unpaired);

  const SessionState._(this.status)
      : kid = null,
        accessToken = null,
        kids = const [],
        stage = ProfileStage.none,
        classroom = null,
        confirmEveryone = false,
        noSeat = false;

  final SessionStatus status;

  /// The kid playing now.
  final PairedKid? kid;
  final String? accessToken;

  /// Every kid paired on this device, [kid] included.
  final List<PairedKid> kids;
  final ProfileStage stage;

  /// Set on a classroom tablet paired with a class code (O8).
  final Classroom? classroom;

  /// "Qui joue ?" asks every kid for their passcode, the one already
  /// playing included, and offers no way back: after a pause past the
  /// threshold, and always on a class tablet. Nobody holding the device
  /// has said who they are yet.
  final bool confirmEveryone;

  /// The playing kid is paired but holds no seat right now (403
  /// `seat_required`): the app shows "Demande à un parent de t'ajouter"
  /// instead of the village, keeps the pairing, and checks again on return
  /// and on "Réessayer" (ADR 0037, revision 2026-10-28). No access token.
  final bool noSeat;

  bool get hasSeveralKids => kids.length > 1;
  bool get isClassroom => classroom != null;

  /// Whether this device asks who's playing: several kids, or a class.
  bool get choosesWhoPlays => hasSeveralKids || isClassroom;

  /// [confirmEveryone], or a class tablet, where it always holds.
  bool get mustConfirm => confirmEveryone || isClassroom;

  SessionState copyWith({
    SessionStatus? status,
    PairedKid? kid,
    String? accessToken,
    List<PairedKid>? kids,
    ProfileStage? stage,
    bool? confirmEveryone,
    bool? noSeat,
  }) {
    return SessionState(
      status: status ?? this.status,
      kid: kid ?? this.kid,
      accessToken: accessToken ?? this.accessToken,
      kids: kids ?? this.kids,
      stage: stage ?? this.stage,
      classroom: classroom,
      confirmEveryone: confirmEveryone ?? this.confirmEveryone,
      noSeat: noSeat ?? this.noSeat,
    );
  }

  /// This state for a kid without a seat: still paired, no token.
  SessionState withoutSeat() => SessionState(
    status: SessionStatus.paired,
    kid: kid,
    kids: kids,
    stage: stage,
    classroom: classroom,
    confirmEveryone: confirmEveryone,
    noSeat: true,
  );
}

/// What the pairing screen is currently doing.
@immutable
class PairingUiState {
  const PairingUiState({this.isSubmitting = false, this.error});

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

enum PairingError {
  invalidCode,
  offline,
  rateLimited,
  unexpected,

  /// A class code for a class with no learners yet.
  emptyClass,

  /// The school isn't entitled to class tablets.
  classNotEntitled,

  /// A good code, but the kid holds no seat: "ask a parent".
  noSeat,
}

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

  /// How often a kid without a seat is checked again on their own, besides
  /// on return to the app and on "Réessayer".
  static const seatRecheckSeconds = 300;

  /// A device endpoint answered 403 `seat_required` mid-session: the seat
  /// went while the token was still good. The refresh says so for certain
  /// and moves the state; concurrent calls share one refresh.
  void onSeatRequired() {
    if (state.status != SessionStatus.paired || state.noSeat) return;
    ensureFreshToken().ignore();
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

    final RefreshResult result;
    try {
      result = await _api.refresh(deviceToken: token);
    } catch (e) {
      // A malformed answer is a failure to retry, never a reason to stop
      // refreshing for the rest of the session.
      _scheduleRefresh(60);
      return;
    }
    switch (result) {
      case RefreshSucceeded(:final accessToken, :final expiresIn):
        state = state.copyWith(
          status: SessionStatus.paired,
          accessToken: accessToken,
          noSeat: false,
        );
        _scheduleRefresh(expiresIn);
      case RefreshNoSeat():
        state = state.withoutSeat();
        _scheduleRefresh(seatRecheckSeconds);
      case RefreshRejected(:final reason):
        _refreshTimer?.cancel();
        await _forgetActiveKid(erase: reason != null);
        // This *is* the in-flight refresh: the next kid's switch must not
        // wait on it, or it waits on itself forever.
        await _resumeWithRemaining(fromRefresh: true);
      case RefreshOffline() || RefreshFailed():
        // Stay paired and try again later. Offline play continues from the
        // cache; dropping the credential here would be the wrong trade.
        _scheduleRefresh(60);
    }
  }

  /// On launch: if a device token exists, trade it for an access token.
  ///
  /// This is the moment revocation takes effect. The server rejects the
  /// refresh, that kid's stored credential is dropped, and the app moves on
  /// to the next kid paired here, or back to pairing if there is none.
  ///
  /// With several kids on the device it opens on "Qui joue ?", so a sibling
  /// never plays on the last kid's profile by default.
  Future<void> restore() async {
    final kids = await _store.pairedKids();
    final token = await _store.deviceToken();
    if (token == null || token.isEmpty) {
      state = const SessionState.unpaired();
      return;
    }
    final classroom = await _store.classroom();
    final stage = kids.length > 1 || classroom != null
        ? ProfileStage.choosing
        : ProfileStage.none;

    RefreshResult result;
    try {
      result = await BootLog.instance.run(
        'pairing_refresh',
        () => _api.refresh(deviceToken: token),
        timeout: BootLog.networkTimeout,
      );
    } on TimeoutException {
      // Treated like offline: stay paired, play from the cache, retry.
      result = const RefreshOffline();
    }
    switch (result) {
      case RefreshSucceeded(:final accessToken, :final expiresIn):
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
          accessToken: accessToken,
          kids: kids,
          stage: stage,
          classroom: classroom,
        );
        _scheduleRefresh(expiresIn);
      case RefreshNoSeat():
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
          kids: kids,
          stage: stage,
          classroom: classroom,
          noSeat: true,
        );
        _scheduleRefresh(seatRecheckSeconds);
      case RefreshRejected(:final reason):
        // Revoked or archived: forget that kid's credential.
        await _forgetActiveKid(erase: reason != null);
        await _resumeWithRemaining();
      case RefreshOffline() || RefreshFailed():
        // Offline is NOT a reason to un-pair. The kid should keep playing
        // cached content; dropping the credential here would force a parent
        // to generate a new code every time the Wi-Fi drops.
        state = SessionState(
          status: SessionStatus.paired,
          kid: await _store.pairedKid(),
          kids: kids,
          stage: stage,
          classroom: classroom,
        );
        // And keep trying: without this, an app opened while the server
        // was down stayed tokenless, so every read skipped its request
        // for good (Hafid's 40-minute freeze).
        _scheduleRefresh(60);
    }
  }

  /// After a kid's pairing is dropped: the next kid paired here, or
  /// unpaired when there is none.
  /// Forgets the active kid's credential and, when [erase], everything of
  /// theirs on this device (ADR 0037). A guardian chose to erase after
  /// being told what's stored. A rejected credential erases only when the
  /// server named why (revoked, archived, erased); a bare 401 keeps the
  /// data, so a backend fault costs a re-pair and nothing more.
  Future<void> _forgetActiveKid({bool erase = true}) async {
    final kid = await _store.pairedKid();
    await _store.clearPairing();
    if (erase && kid != null) {
      await KidLocalData(ref.read(localDatabaseProvider), kidId: kid.id).wipe();
    }
  }

  ///
  /// With several kids left, or on a class tablet, it opens "Qui joue ?"
  /// asking everyone, because the next kid was picked by the app, not by
  /// whoever is holding the device.
  ///
  /// [fromRefresh] when called by the in-flight refresh itself, which the
  /// switch would otherwise wait on (a deadlock found live, 2026-10-28,
  /// retiring a class tablet mid-session).
  Future<void> _resumeWithRemaining({bool fromRefresh = false}) async {
    final kids = await _store.pairedKids();
    final next = kids.isEmpty ? null : await _store.pairedKid();
    if (next == null) {
      state = const SessionState.unpaired();
      return;
    }
    await switchTo(next.id, kids: kids, waitForRefresh: !fromRefresh);
    if (state.status == SessionStatus.paired && state.choosesWhoPlays) {
      state = state.copyWith(
        stage: ProfileStage.choosing,
        confirmEveryone: true,
      );
    }
  }

  /// Play as [kidId], another kid paired on this device.
  ///
  /// Switching kid switches token: the access token is refreshed with that
  /// kid's own device token *before* the state changes, so nothing loads
  /// for the new kid with the old kid's credential. Offline, the switch
  /// still happens, with no access token, like an offline launch.
  ///
  /// A passcode check that the server confirmed already brought an access
  /// token for that kid ([accessToken], [expiresIn]), so it isn't
  /// refreshed a second time.
  Future<void> switchTo(
    String kidId, {
    List<PairedKid>? kids,
    String? accessToken,
    int? expiresIn,
    bool waitForRefresh = true,
  }) async {
    final token = await _store.deviceTokenFor(kidId);
    if (token == null) {
      // Not paired here (any more): nothing to switch to.
      if ((await _store.pairedKids()).isEmpty) {
        state = const SessionState.unpaired();
      }
      return;
    }
    _refreshTimer?.cancel();
    await _store.setActiveKid(kidId);
    final all = kids ?? await _store.pairedKids();
    final kid = all.firstWhere((k) => k.id == kidId);
    // A refresh for the previous kid may still be in flight; it must not
    // land on this one. Unless that refresh is the caller.
    if (waitForRefresh) await _inFlightRefresh;

    final result = accessToken != null
        ? RefreshSucceeded(accessToken: accessToken, expiresIn: expiresIn ?? 900)
        : await _api.refresh(deviceToken: token);
    switch (result) {
      case RefreshSucceeded(:final accessToken, :final expiresIn):
        state = SessionState(
          status: SessionStatus.paired,
          kid: kid,
          accessToken: accessToken,
          kids: all,
          classroom: await _store.classroom(),
        );
        _scheduleRefresh(expiresIn);
      case RefreshNoSeat():
        state = SessionState(
          status: SessionStatus.paired,
          kid: kid,
          kids: all,
          classroom: await _store.classroom(),
          noSeat: true,
        );
        _scheduleRefresh(seatRecheckSeconds);
      case RefreshRejected(:final reason):
        await _forgetActiveKid(erase: reason != null);
        // Still inside the caller's refresh when that is what sent us here.
        await _resumeWithRemaining(fromRefresh: !waitForRefresh);
      case RefreshOffline() || RefreshFailed():
        state = SessionState(
          status: SessionStatus.paired,
          kid: kid,
          kids: all,
          classroom: await _store.classroom(),
        );
        _scheduleRefresh(60);
    }
  }

  /// Open "Qui joue ?".
  void chooseProfile() {
    if (state.status != SessionStatus.paired) return;
    state = state.copyWith(stage: ProfileStage.choosing);
  }

  /// How long the app may be away before "Qui joue ?" asks again: long
  /// enough for a kid to answer the door, short enough that a sibling who
  /// picks the device up later is asked. Shorter on a class tablet, which
  /// changes hands between activities.
  static const resumeLockAfter = Duration(minutes: 10);
  static const classroomResumeLockAfter = Duration(minutes: 2);

  DateTime? _awaySince;

  /// The app went to the background (or was hidden) at [at].
  void noteAway(DateTime at) => _awaySince ??= at;

  /// The app is back at [at]: past the threshold, [lockForResume].
  void noteBack(DateTime at) {
    // Maybe a parent added them while the app was away.
    if (state.noSeat) ensureFreshToken().ignore();
    final since = _awaySince;
    _awaySince = null;
    if (since == null) return;
    final limit =
        state.isClassroom ? classroomResumeLockAfter : resumeLockAfter;
    if (at.difference(since) >= limit) lockForResume();
  }

  /// After the app was away past the threshold: "Qui joue ?", asking
  /// everyone, so a sibling who picks the device up can't carry on as the
  /// kid who put it down. Ignored where only one kid plays.
  void lockForResume() {
    if (state.status != SessionStatus.paired || !state.choosesWhoPlays) return;
    state = state.copyWith(stage: ProfileStage.choosing, confirmEveryone: true);
  }

  /// Open the pairing-code screen to add another kid. [fromApp]: from the
  /// profile menu, so backing out returns to the app, not to "Qui joue ?".
  void addProfile({bool fromApp = false}) {
    if (state.status != SessionStatus.paired) return;
    _addingFromApp = fromApp;
    state = state.copyWith(stage: ProfileStage.adding);
  }

  bool _addingFromApp = false;

  /// Backs out of the pairing-code screen, to wherever it was opened from.
  void cancelAdding() =>
      _addingFromApp ? closeProfileStage() : chooseProfile();

  /// Back to the app, as the current kid.
  void closeProfileStage() {
    if (state.status != SessionStatus.paired) return;
    state = state.copyWith(stage: ProfileStage.none);
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
        await _adopt(result);
        // The adult who typed the code is here now: offer the parent PIN
        // once the shell is up (A5).
        ref.read(guardianPinOfferProvider.notifier).offer();
        return null;
      default:
        return _pairingError(result);
    }
  }

  /// Store a good kid code's pairing and make that kid the active one.
  Future<void> _adopt(PairingSucceeded result) async {
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
      kids: await _store.pairedKids(),
      classroom: await _store.classroom(),
    );
    _scheduleRefresh(result.expiresIn);
  }

  /// « NIP oublié ? » (option A, Hafid 2026-10-31; ADR 0109). A fresh pairing
  /// code from the portal proves an adult who holds the account is here, so
  /// a good one clears the parent PIN. It's exchanged like any kid code: it
  /// re-pairs that kid on this device, or adds them. The kid who was playing
  /// stays the active one. Returns the error, or null on success.
  Future<PairingError?> resetGuardianPinWithCode(String code) async {
    // A refresh still running on the old token must not land after the new
    // one and drop the kid as revoked.
    await _inFlightRefresh;
    final activeId = state.kid?.id;
    final result = await _api.exchangeCode(
      code: code,
      deviceId: await _store.deviceId(),
      platform: currentPlatform(),
      appVersion: appVersion,
    );
    if (result is! PairingSucceeded) return _pairingError(result);
    await _store.clearGuardianPin();
    if (activeId == null || activeId == result.kidId) {
      await _adopt(result);
    } else {
      await _store.savePairing(
        deviceToken: result.deviceToken,
        kidId: result.kidId,
        kidDisplayName: result.kidDisplayName,
        gradeLevel: result.gradeLevel,
      );
      await _store.setActiveKid(activeId);
      state = state.copyWith(kids: await _store.pairedKids());
    }
    return null;
  }

  PairingError _pairingError(PairingResult result) {
    switch (result) {
      case PairingCodeRejected():
        return PairingError.invalidCode;
      case PairingNoSeat():
        return PairingError.noSeat;
      case PairingOffline():
        return PairingError.offline;
      case PairingRateLimited():
        return PairingError.rateLimited;
      case PairingSucceeded() ||
            PairingFailed() ||
            ClassPairingSucceeded() ||
            ClassIsEmpty() ||
            ClassNotEntitled():
        return PairingError.unexpected;
    }
  }

  /// Exchange a teacher's class code: this tablet is paired for every
  /// learner of the class, and opens on "Qui joue ?" with nobody chosen.
  Future<PairingError?> pairClass(String code) async {
    final result = await _api.exchangeClassCode(
      code: code,
      deviceId: await _store.deviceId(),
      platform: currentPlatform(),
      appVersion: appVersion,
    );
    switch (result) {
      case ClassPairingSucceeded(:final classroom, :final kids):
        await _store.saveClassPairings(classroom, kids);
        await _rememberClassAvatars(kids);
        // Someone must be "active" for the state to be paired; nothing of
        // theirs loads while the picker is up, and the picker asks first.
        final current = await _store.pairedKid();
        _refreshTimer?.cancel();
        state = SessionState(
          status: SessionStatus.paired,
          kid: current,
          kids: await _store.pairedKids(),
          stage: ProfileStage.choosing,
          classroom: classroom,
          confirmEveryone: true,
        );
        return null;
      case PairingCodeRejected():
        return PairingError.invalidCode;
      case ClassIsEmpty():
        return PairingError.emptyClass;
      case ClassNotEntitled():
        return PairingError.classNotEntitled;
      case PairingNoSeat():
        return PairingError.noSeat;
      case PairingOffline():
        return PairingError.offline;
      case PairingRateLimited():
        return PairingError.rateLimited;
      case PairingSucceeded() || PairingFailed():
        return PairingError.unexpected;
    }
  }

  /// Each learner's avatar and sex from the class code's answer, so "Qui
  /// joue ?" shows every child their own face before anyone is chosen.
  /// Until now only the active kid synced theirs, which on a class tablet,
  /// where nobody is chosen, drew one default face for the whole class.
  /// Best effort: a failed write keeps the default face, nothing else.
  Future<void> _rememberClassAvatars(List<ClassKid> kids) async {
    try {
      final db = ref.read(localDatabaseProvider);
      for (final k in kids) {
        final store = AvatarStore(db, kidId: k.kidId);
        final sex = KidSex.parse(k.sex);
        if (sex != KidSex.unspecified) await store.setSex(sex);
        if (isKnownAvatar(k.avatarKey)) await store.select(k.avatarKey);
      }
    } on Object catch (e, s) {
      recordCaught('class_avatars', e, s);
    }
  }

  /// Remove the current kid from this device, at a guardian's request,
  /// erasing their local data. The confirmation in front of it
  /// (`RemoveKidDialog`) offers to upload their unsent results first.
  /// Other kids paired here stay; "Qui joue ?" opens if several remain.
  Future<void> forget() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _forgetActiveKid();
    final kids = await _store.pairedKids();
    if (kids.isEmpty) {
      state = const SessionState.unpaired();
      return;
    }
    await _resumeWithRemaining();
    if (kids.length > 1) chooseProfile();
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

  /// A teacher's class code instead of a kid's.
  Future<void> submitClass(String code) async {
    state = state.copyWith(isSubmitting: true, error: null);
    final error =
        await ref.read(sessionControllerProvider.notifier).pairClass(code);
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

const appVersion = '0.2.0';

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
  // X-Request-ID on every request, failures to the diag log (ADR 0052).
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
  )
    ..interceptors.add(RequestIdInterceptor(service: 'api'))
    // A seat that goes mid-session shows up on the next content or
    // progress call; only a kid's own calls (they carry a token) count.
    ..interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (isSeatRequired(error) &&
              error.requestOptions.headers.containsKey('Authorization')) {
            ref.read(sessionControllerProvider.notifier).onSeatRequired();
          }
          handler.next(error);
        },
      ),
    );
});

/// The on-disk database, opened once at app startup (`main.dart`) and
/// provided from there via `overrideWithValue` — opening it needs an
/// `await` (the platform's application-support directory), which a
/// `Provider`'s synchronous `create` cannot do itself. Every test that
/// touches a screen reading this overrides it with `LocalDatabase.memory()`.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError(
    'localDatabaseProvider must be overridden — main.dart does this after '
    'opening the real database; tests override it with LocalDatabase.memory().',
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

/// The kid whose rows the local database reads and writes right now
/// (ADR 0014).
///
/// One accessor rather than five reaches into `SessionState`: it is the
/// seam the "Qui joue ?" switcher turns. It means the selected kid, and
/// everything that watches it resets when the kid changes.
final activeKidIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionControllerProvider).kid?.id,
);

/// Owner for kid-scoped stores built before anyone has paired.
///
/// The flusher is constructed at boot, which on a fresh install happens
/// while the pairing screen is still showing. Nothing can have written rows
/// yet — the play screen is unreachable unpaired — so an outbox bound to
/// this sentinel is inert: it matches no row, because a real owner is
/// always a server-issued UUID. Deliberately not [deviceScope], which means
/// "belongs to the device" rather than "belongs to nobody yet".
const String unpairedKidId = '__unpaired__';

final pairingFormProvider =
    NotifierProvider<PairingFormController, PairingUiState>(
      PairingFormController.new,
    );

/// Raised by a kid's pairing so the shell offers the parent PIN to the
/// adult who just typed the code (A5). Cleared once offered.
class GuardianPinOffer extends Notifier<bool> {
  @override
  bool build() => false;

  void offer() => state = true;

  void taken() => state = false;
}

final guardianPinOfferProvider = NotifierProvider<GuardianPinOffer, bool>(
  GuardianPinOffer.new,
);
