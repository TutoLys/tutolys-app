import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/app_settings.dart';
import '../pairing/pairing_controller.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(
    ref.watch(localDatabaseProvider),
    kidId: ref.watch(activeKidIdProvider) ?? unpairedKidId,
  );
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
    // Watched, not read: the app builds this at boot, before the session
    // has restored the paired kid, so the first store is the unpaired one.
    // Rebuilding when the kid arrives is what makes settings survive a
    // restart; reading once loaded defaults on every launch.
    final store = ref.watch(appSettingsStoreProvider);
    // Defaults first, real values as soon as the read lands — the screen
    // renders immediately rather than flashing a spinner over nine rows.
    _load(store);
    return const AppSettings();
  }

  Future<void> _load(AppSettingsStore store) async {
    final loaded = await store.read();
    // A stale read (the kid changed meanwhile) lands on an unmounted ref.
    if (ref.mounted) state = loaded;
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
