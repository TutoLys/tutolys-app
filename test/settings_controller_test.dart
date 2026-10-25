import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

/// Stands in for the session: null until "restored", like a real boot.
class _Kid extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final _kidProvider = NotifierProvider<_Kid, String?>(_Kid.new);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late LocalDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = LocalDatabase.memory();
    container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        activeKidIdProvider.overrideWith((ref) => ref.watch(_kidProvider)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('settings saved for a kid come back after a restart', () async {
    // The app reads settings at boot, before the session has restored the
    // paired kid. They must reload once the kid is known, or every refresh
    // falls back to the defaults (dark mode lost on reload).
    await AppSettingsStore(db, kidId: 'kid-lea')
        .write(const AppSettings(darkTheme: true, volume: 30));

    container.listen(settingsControllerProvider, (_, _) {});
    await settle();
    expect(container.read(settingsControllerProvider).darkTheme, isFalse,
        reason: 'nobody is paired yet');

    container.read(_kidProvider.notifier).set('kid-lea');
    await settle();
    await settle();

    final settings = container.read(settingsControllerProvider);
    expect(settings.darkTheme, isTrue);
    expect(settings.volume, 30);
  });

  test('a change after the kid is known is saved under that kid', () async {
    container.read(_kidProvider.notifier).set('kid-lea');
    container.listen(settingsControllerProvider, (_, _) {});
    await settle();

    await container
        .read(settingsControllerProvider.notifier)
        .setDarkTheme(true);

    expect((await AppSettingsStore(db, kidId: 'kid-lea').read()).darkTheme,
        isTrue);
  });

  test('not ready until the kid\'s stored settings have been read', () async {
    // AppShell keeps the splash up on this, so the first frame is already
    // in the kid's theme instead of light-then-dark.
    await AppSettingsStore(db, kidId: 'kid-lea')
        .write(const AppSettings(darkTheme: true));
    container.listen(settingsReadyProvider, (_, _) {});
    await settle();

    container.read(_kidProvider.notifier).set('kid-lea');
    expect(container.read(settingsReadyProvider), isFalse,
        reason: 'the new kid\'s settings are still being read');
    expect(container.read(settingsControllerProvider).darkTheme, isFalse);

    await settle();
    await settle();
    expect(container.read(settingsReadyProvider), isTrue);
    expect(container.read(settingsControllerProvider).darkTheme, isTrue,
        reason: 'ready means the real value is already in place');
  });

  test('a change is not reverted by a later rebuild', () async {
    container.read(_kidProvider.notifier).set('kid-lea');
    container.listen(settingsControllerProvider, (_, _) {});
    await settle();
    await settle();

    await container.read(settingsControllerProvider.notifier).setVolume(15);
    await settle();
    expect(container.read(settingsControllerProvider).volume, 15);
  });
}
