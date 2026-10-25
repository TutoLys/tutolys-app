import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/app_settings.dart';
import '../pairing/pairing_controller.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  );
});

/// The active kid's settings as stored, read once per kid.
///
/// Watches the kid-scoped store: the app first builds this at boot, before
/// the session has restored the paired kid, so it re-reads when the kid
/// arrives. Reading only once loaded defaults on every launch.
final storedSettingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(appSettingsStoreProvider).read(),
);

/// Whether the active kid's settings have been read.
///
/// `AppShell` holds the native splash until this is true, so the first
/// frame a kid sees is already in their theme and language. Without it the
/// app drew in the default light theme and switched to dark a moment later.
/// A failed read counts as ready: defaults beat a splash that never ends.
final settingsReadyProvider = Provider<bool>(
  (ref) => !ref.watch(storedSettingsProvider).isLoading,
);

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
    return ref.watch(storedSettingsProvider).value ?? const AppSettings();
  }

  Future<void> _apply(AppSettings next) async {
    state = next;
    await ref.read(appSettingsStoreProvider).write(next);
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

  Future<void> setDailyReminders(bool value) =>
      _apply(state.copyWith(dailyReminders: value));

  Future<void> setQuestNotifications(bool value) =>
      _apply(state.copyWith(questNotifications: value));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
