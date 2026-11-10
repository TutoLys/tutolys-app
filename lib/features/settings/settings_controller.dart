import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/boot_log.dart';
import '../../data/local_db/app_settings.dart';
import '../../data/local_db/kid_defaults.dart';
import '../pairing/pairing_controller.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  );
});

final kidDefaultsStoreProvider = Provider<KidDefaultsStore>((ref) {
  return KidDefaultsStore(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  );
});

/// The active kid's held defaults, re-read when a profile fetch changes them
/// (`AvatarController`).
final storedKidDefaultsProvider = FutureProvider<KidDefaults>(
  (ref) => ref.watch(kidDefaultsStoreProvider).read(),
  retry: (_, _) => null,
);

/// The active kid's defaults; none until read, or if the read fails.
final kidDefaultsProvider = Provider<KidDefaults>(
  (ref) => ref.watch(storedKidDefaultsProvider).value ?? KidDefaults.none,
);

/// The active kid's settings as stored, read once per kid.
///
/// Watches the kid-scoped store: the app first builds this at boot, before
/// the session has restored the paired kid, so it re-reads when the kid
/// arrives. Reading only once loaded defaults on every launch.
///
/// The read is a boot step with a timeout (ADR 0038): it is the app's first
/// database query, and a database that never answers held every launch on
/// the loader forever (2026-10-26). Past the timeout it fails, which
/// [settingsReadyProvider] counts as ready, so the app opens on defaults.
///
/// No automatic retry: Riverpod 3 would otherwise re-run a timed-out read
/// every few seconds, each one another 10 s wait. One timeout means
/// defaults; the stuck screen's "Réessayer" reads again.
final storedSettingsProvider = FutureProvider<AppSettings>(
  (ref) {
    final store = ref.watch(appSettingsStoreProvider);
    return BootLog.instance.run('settings_read', store.read);
  },
  retry: (_, _) => null,
);

/// Whether the active kid's settings have been read.
///
/// `AppShell` holds the native splash until this is true, so the first
/// frame a kid sees is already in their theme and language. Without it the
/// app drew in the default light theme and switched to dark a moment later.
/// A failed read counts as ready: defaults beat a splash that never ends.
/// Under Riverpod 3 a failure can arrive as `AsyncLoading` *carrying* the
/// error, so `isLoading` alone isn't enough (ADR 0038). A reload for a new
/// kid is still not ready, even with the last kid's value in hand.
final settingsReadyProvider = Provider<bool>((ref) {
  final stored = ref.watch(storedSettingsProvider);
  return !stored.isLoading || stored.hasError;
});

/// Holds Réglages' state, writing through on every change.
///
/// No save button, deliberately: the design has none, and a child should not
/// have to understand that a toggle they flipped has not taken effect yet.
/// Every change is applied to the in-memory value immediately and persisted
/// behind it, so the UI never waits on disk.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Rebuilds only when the stored value is (re)read — on boot and when
    // the kid changes — never after a write, so a change made here is never
    // reverted by a stale read. Defaults stand in while the splash is up.
    //
    // A guardian's defaults arrive later and change only what the family
    // never set, so they land on the live value, not on a re-read.
    ref.listen(kidDefaultsProvider, (_, next) {
      state = applyKidDefaults(state, next);
    });
    return applyKidDefaults(
      ref.watch(storedSettingsProvider).value ?? const AppSettings(),
      ref.read(kidDefaultsProvider),
    );
  }

  Future<void> _apply(AppSettings next) async {
    final before = state;
    state = next.copyWith(
      chosen: {
        ...before.chosen,
        if (next.music != before.music) DefaultableSetting.music,
        if (next.soundEffects != before.soundEffects)
          DefaultableSetting.soundEffects,
        if (next.reduceMotion != before.reduceMotion)
          DefaultableSetting.reduceMotion,
      },
    );
    await ref.read(appSettingsStoreProvider).writeChanges(before, next);
  }

  Future<void> setDarkTheme(bool value) =>
      _apply(state.copyWith(darkTheme: value));

  Future<void> setVolume(int value) =>
      _apply(state.copyWith(volume: value.clamp(0, 100)));

  Future<void> setMusic(bool value) => _apply(state.copyWith(music: value));

  Future<void> setSoundEffects(bool value) =>
      _apply(state.copyWith(soundEffects: value));

  Future<void> setReadAloud(bool value) =>
      _apply(state.copyWith(readAloud: value));

  Future<void> setEnglish(bool value) => _apply(state.copyWith(english: value));

  Future<void> setReduceMotion(bool value) =>
      _apply(state.copyWith(reduceMotion: value));

  Future<void> setVillage3d(bool value) =>
      _apply(state.copyWith(village3d: value));

  Future<void> setSkyControls(bool value) =>
      _apply(state.copyWith(skyControls: value));

  Future<void> setQuestsFolded(bool value) =>
      _apply(state.copyWith(questsFolded: value));

  /// 0 open, 1 rail, 2 hidden (`AppSettings.navFold`).
  Future<void> setNavFold(int value) =>
      _apply(state.copyWith(navFold: value.clamp(0, 2)));

  /// Turning reminders on restarts the back-off from today (ADR 0053).
  Future<void> setDailyReminders(bool value, {DateTime? today}) => _apply(
    state.copyWith(
      dailyReminders: value,
      remindersOnSince: value ? (today ?? DateTime.now()) : null,
    ),
  );

  Future<void> setReminderMinutes(int minutes) =>
      _apply(state.copyWith(reminderMinutes: minutes));

  /// "Ma flamme". Turning it on restarts the back-off too.
  Future<void> setFlameReminders(bool value, {DateTime? today}) => _apply(
    state.copyWith(
      flameReminders: value,
      remindersOnSince: value ? (today ?? DateTime.now()) : null,
    ),
  );
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
