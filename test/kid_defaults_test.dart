import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/profile_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/kid_defaults.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// `GET /me/profile`, answered in place.
ProfileApi apiServing(Map<String, Object?> body) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: body),
        ),
      ),
    );
  return ProfileApi(dio: dio);
}

void main() {
  late LocalDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = LocalDatabase.memory();
    container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        activeKidIdProvider.overrideWithValue('kid-lea'),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Boots the settings, as the app's first read does.
  Future<SettingsController> boot() async {
    container.listen(settingsControllerProvider, (_, _) {});
    await settle();
    return container.read(settingsControllerProvider.notifier);
  }

  /// What a profile fetch does when the guardian's answers changed.
  Future<void> serve(KidDefaults defaults) async {
    await KidDefaultsStore(db, kidId: 'kid-lea').adopt(defaults);
    container.invalidate(storedKidDefaultsProvider);
    await settle();
  }

  AppSettings settings() => container.read(settingsControllerProvider);

  group('the contract (backend ADR 0220)', () {
    test('a key is read only if it is present and allowed', () {
      final all = KidDefaults.fromJson(const {
        'auto_read_prompts': true,
        'session_minutes': 15,
        'first_subject': 'FR',
        'reduce_motion': true,
        'music': false,
        'sound_effects': false,
        'from_a_newer_backend': 1,
      });
      expect(all.autoReadPrompts, isTrue);
      expect(all.sessionMinutes, 15);
      expect(all.firstSubject, 'FR');
      expect(all.reduceMotion, isTrue);
      expect(all.music, isFalse);
      expect(all.soundEffects, isFalse);

      final none = KidDefaults.fromJson(const {
        'session_minutes': 7,
        'reduce_motion': false,
        'music': true,
        'sound_effects': true,
        'first_subject': '',
      });
      expect(jsonEncode(none.toJson()), '{}');
    });

    test('auto_read_prompts false is an answer, not a missing key', () {
      expect(
        KidDefaults.fromJson(const {'auto_read_prompts': false})
            .autoReadPrompts,
        isFalse,
      );
    });

    test('the profile read carries the block', () async {
      final profile = await apiServing(const {
        'avatar_key': '',
        'defaults': {'session_minutes': 5},
      }).fetchProfile(accessToken: 't');
      expect(profile?.defaults?.sessionMinutes, 5);
    });

    test(
      'a backend without the block says nothing, unlike an empty one',
      () async {
        final older = await apiServing(const {'avatar_key': ''})
            .fetchProfile(accessToken: 't');
        expect(older?.defaults, isNull);

        final empty = await apiServing(const {
          'avatar_key': '',
          'defaults': <String, Object?>{},
        }).fetchProfile(accessToken: 't');
        expect(empty?.defaults, isNotNull);
      },
    );
  });

  group('held per kid', () {
    test('a sibling on the same tablet gets none of it', () async {
      await KidDefaultsStore(
        db,
        kidId: 'kid-lea',
      ).adopt(const KidDefaults(autoReadPrompts: true));

      final lea = await KidDefaultsStore(db, kidId: 'kid-lea').read();
      final sam = await KidDefaultsStore(db, kidId: 'kid-sam').read();
      expect(lea.autoReadPrompts, isTrue);
      expect(sam.autoReadPrompts, isNull);
    });

    test(
      'an answer the guardian removed goes, and only a change counts',
      () async {
        final store = KidDefaultsStore(db, kidId: 'kid-lea');
        expect(await store.adopt(KidDefaults.none), isFalse);
        expect(await store.adopt(const KidDefaults(sessionMinutes: 5)), isTrue);
        expect(
          await store.adopt(const KidDefaults(sessionMinutes: 5)),
          isFalse,
        );
        expect(await store.adopt(KidDefaults.none), isTrue);
        expect((await store.read()).sessionMinutes, isNull);
      },
    );
  });

  group('device choice, else defaults, else the app', () {
    test('a default reaches a setting nobody touched', () async {
      await boot();
      await serve(
        const KidDefaults(
          music: false,
          soundEffects: false,
          reduceMotion: true,
        ),
      );
      expect(settings().music, isFalse);
      expect(settings().soundEffects, isFalse);
      expect(settings().reduceMotion, isTrue);
    });

    test(
      'what the family set wins, now and after a later portal edit',
      () async {
        final controller = await boot();
        await serve(const KidDefaults(music: false));
        await controller.setMusic(true);
        expect(settings().music, isTrue);

        await serve(const KidDefaults(music: false, soundEffects: false));
        expect(
          settings().music,
          isTrue,
          reason: 'the family turned it back on',
        );
        expect(settings().soundEffects, isFalse);
      },
    );

    test('a choice outlives a restart', () async {
      final controller = await boot();
      await serve(const KidDefaults(music: false));
      await controller.setMusic(true);

      final stored = await AppSettingsStore(db, kidId: 'kid-lea').read();
      final after = applyKidDefaults(stored, const KidDefaults(music: false));
      expect(after.music, isTrue);
    });

    test('changing the volume does not freeze the music setting', () async {
      final controller = await boot();
      await controller.setVolume(40);

      await serve(const KidDefaults(music: false));
      expect(settings().music, isFalse);
      expect(settings().volume, 40);
    });

    test('a default is never written down as a setting', () async {
      final controller = await boot();
      await serve(const KidDefaults(music: false));
      await controller.setVolume(40);

      await serve(KidDefaults.none);
      expect(settings().music, isTrue, reason: 'the guardian took it back');
      final stored = await AppSettingsStore(db, kidId: 'kid-lea').read();
      expect(stored.chosen, isEmpty);
    });

    test('the sibling keeps their own settings under one set of defaults', () {
      const chosen = AppSettings(
        music: true,
        chosen: {DefaultableSetting.music},
      );
      final applied = applyKidDefaults(
        chosen,
        const KidDefaults(music: false, reduceMotion: true),
      );
      expect(applied.music, isTrue);
      expect(applied.reduceMotion, isTrue);
      expect(
        applyKidDefaults(applied, KidDefaults.none).reduceMotion,
        isFalse,
        reason: 'running it again on its own result lets go',
      );
    });
  });

  group('settings saved before stored keys meant anything (ADR 0125)', () {
    Future<void> legacy(Map<String, String> rows) async {
      for (final MapEntry(:key, :value) in rows.entries) {
        await db
            .into(db.appStateTable)
            .insert(
              AppStateTableCompanion.insert(
                kidId: 'kid-lea',
                key: 'settings.$key',
                value: value,
                updatedAt: DateTime(2026),
              ),
            );
      }
    }

    test('a value repeating the app default was never a choice', () async {
      await legacy({'music': 'true', 'sound_effects': 'true', 'volume': '40'});
      final stored = await AppSettingsStore(db, kidId: 'kid-lea').read();
      expect(stored.chosen, isEmpty);
      expect(stored.volume, 40);
    });

    test('a value that differs from it can only be a choice', () async {
      await legacy({'music': 'false', 'reduce_motion': 'true'});
      final stored = await AppSettingsStore(db, kidId: 'kid-lea').read();
      expect(stored.chosen, {
        DefaultableSetting.music,
        DefaultableSetting.reduceMotion,
      });
      expect(stored.music, isFalse);
      expect(stored.reduceMotion, isTrue);
    });

    test('once sorted, turning music back on stays a choice', () async {
      await legacy({'music': 'false'});
      final store = AppSettingsStore(db, kidId: 'kid-lea');
      final before = await store.read();
      await store.writeChanges(before, before.copyWith(music: true));

      final after = await store.read();
      expect(after.music, isTrue);
      expect(after.chosen, {DefaultableSetting.music});
    });
  });

  group('"Joue N minutes"', () {
    const paid = QuestDefinitionDto(kind: 'minutes', target: 10, xp: 15);

    DailyQuestItem quest({
      int? sessionMinutes,
      int msToday = 0,
      List<QuestDefinitionDto>? served,
    }) => buildDailyQuests(
      challenge: null,
      lessonsToday: 0,
      msToday: msToday,
      served: served,
      sessionMinutes: sessionMinutes,
    ).firstWhere((q) => q.kind == QuestKind.minutes);

    test('the guardian\'s session length sets the target', () {
      expect(quest().target, 10);
      final short = quest(sessionMinutes: 5, msToday: 5 * 60000);
      expect(short.target, 5);
      expect(short.done, isTrue);
      expect(quest(sessionMinutes: 15, msToday: 10 * 60000).done, isFalse);
    });

    test('no XP chip where the backend pays on another target', () {
      expect(quest(served: const [paid]).xpReward, 15);
      expect(quest(served: const [paid], sessionMinutes: 10).xpReward, 15);
      expect(quest(served: const [paid], sessionMinutes: 5).xpReward, isNull);
      expect(quest(served: const [paid], sessionMinutes: 15).xpReward, isNull);
    });
  });
}
