import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';

void main() {
  late LocalDatabase db;

  const lea = 'kid-lea';
  const noah = 'kid-noah';

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  group('defaults', () {
    test('match the design, including read-aloud ON', () async {
      final settings = await AppSettingsStore(db, kidId: lea).read();

      expect(settings.volume, 70, reason: "the design labels it '70 %'");
      expect(settings.music, isTrue);
      expect(settings.soundEffects, isTrue);
      expect(
        settings.readAloud,
        isTrue,
        reason: 'a grade-1 reader cannot read the question unaided',
      );
      expect(settings.english, isFalse, reason: 'French first');
      expect(settings.darkTheme, isFalse);
      expect(settings.reduceMotion, isFalse);
    });

    test('an unwritten store reads defaults rather than failing', () async {
      expect(
        () => AppSettingsStore(db, kidId: 'never-written').read(),
        returnsNormally,
      );
    });
  });

  group('persistence', () {
    test('a written value survives a re-read', () async {
      final store = AppSettingsStore(db, kidId: lea);
      await store.write(const AppSettings(volume: 25, music: false));

      final back = await store.read();
      expect(back.volume, 25);
      expect(back.music, isFalse);
    });

    test('false is stored, not treated as absent', () async {
      // The trap in a key/value store: a false flag and a missing key look
      // the same if absence is tested instead of the value.
      final store = AppSettingsStore(db, kidId: lea);
      await store.write(const AppSettings(readAloud: false));

      expect(
        (await store.read()).readAloud,
        isFalse,
        reason: 'defaulting this back to true would re-enable audio a '
            'parent deliberately turned off',
      );
    });

    test('writing twice replaces rather than duplicates', () async {
      final store = AppSettingsStore(db, kidId: lea);
      await store.write(const AppSettings(volume: 10));
      await store.write(const AppSettings(volume: 90));

      expect((await store.read()).volume, 90);
      final rows = await db.select(db.appStateTable).get();
      expect(rows.where((r) => r.key == 'settings.volume'), hasLength(1));
    });
  });

  group('kid scoping', () {
    test("one sibling's settings do not move the other's", () async {
      await AppSettingsStore(db, kidId: lea)
          .write(const AppSettings(volume: 10, readAloud: false));

      final noahSettings = await AppSettingsStore(db, kidId: noah).read();
      expect(noahSettings.volume, 70);
      expect(
        noahSettings.readAloud,
        isTrue,
        reason: 'an older sibling turning read-aloud off must not take it '
            'from a younger one who still needs it',
      );
    });

    test('both kids keep their own values at once', () async {
      await AppSettingsStore(db, kidId: lea).write(const AppSettings(volume: 10));
      await AppSettingsStore(db, kidId: noah).write(const AppSettings(volume: 90));

      expect((await AppSettingsStore(db, kidId: lea).read()).volume, 10);
      expect((await AppSettingsStore(db, kidId: noah).read()).volume, 90);
    });

    test('settings keys never land on the device scope', () async {
      await AppSettingsStore(db, kidId: lea).write(const AppSettings());

      final rows = await db.select(db.appStateTable).get();
      final settingsRows = rows.where((r) => r.key.startsWith('settings.'));
      expect(settingsRows, isNotEmpty);
      expect(
        settingsRows.every((r) => r.kidId == lea),
        isTrue,
        reason: 'these belong to a kid, not to the tablet',
      );
    });
  });

  group('copyWith', () {
    test('changes one field and leaves the rest', () {
      const original = AppSettings(volume: 42, readAloud: false);
      final next = original.copyWith(volume: 7);

      expect(next.volume, 7);
      expect(next.readAloud, isFalse);
      expect(next.music, original.music);
    });
  });

  group('language', () {
    test('every settings string exists in both locales', () {
      // The whole point of the sealed-class-per-locale shape: a missing
      // French string is a bug, not a fallback. This catches an English
      // getter added without its French twin at test time rather than
      // leaving a kid staring at an empty row.
      const fr = Strings.fr;
      const en = Strings.en;

      final pairs = <String, List<String>>{
        'settingsTitle': [fr.settingsTitle, en.settingsTitle],
        'settingsSound': [fr.settingsSound, en.settingsSound],
        'settingsReadAloud': [fr.settingsReadAloud, en.settingsReadAloud],
        'settingsReadAloudSub': [
          fr.settingsReadAloudSub,
          en.settingsReadAloudSub,
        ],
        'settingsParentZoneBody': [
          fr.settingsParentZoneBody,
          en.settingsParentZoneBody,
        ],
        'navCarte': [fr.navCarte, en.navCarte],
        'navQuetes': [fr.navQuetes, en.navQuetes],
      };

      pairs.forEach((key, values) {
        expect(values[0], isNotEmpty, reason: '$key has no French');
        expect(values[1], isNotEmpty, reason: '$key has no English');
      });
    });

    test('English is genuinely translated, not French echoed back', () {
      expect(Strings.en.navCarte, isNot(Strings.fr.navCarte));
      expect(Strings.en.settingsTitle, isNot(Strings.fr.settingsTitle));
      expect(Strings.en.settingsSound, isNot(Strings.fr.settingsSound));
    });

    test('resolution is French-first: anything not English falls to French',
        () {
      expect(Strings.of(const Locale('fr', 'CA')).navCarte, 'Carte');
      expect(Strings.of(const Locale('en', 'CA')).navCarte, 'Map');
      expect(
        Strings.of(const Locale('es')).navCarte,
        'Carte',
        reason: 'French is the default, never English',
      );
    });
  });
}
