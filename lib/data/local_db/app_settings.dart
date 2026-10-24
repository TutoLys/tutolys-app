import 'package:drift/drift.dart';

import 'database.dart';

/// Everything Réglages owns, as one immutable value.
///
/// Defaults match the design's own rendering of the screen: volume at 70%,
/// sound and music on, read-aloud **on** (a grade-1 reader cannot read the
/// question — see ADR 0021), French, animations not reduced, notifications
/// on.
class AppSettings {
  const AppSettings({
    this.darkTheme = false,
    this.volume = 70,
    this.music = true,
    this.soundEffects = true,
    this.readAloud = true,
    this.english = false,
    this.reduceMotion = false,
    this.dailyReminders = true,
    this.questNotifications = true,
  });

  final bool darkTheme;

  /// 0-100, as the design labels it ("70 %").
  final int volume;

  final bool music;
  final bool soundEffects;

  /// "Lire les questions à voix haute". Plays the Piper-generated audio
  /// cached by `ContentSync`; never the answer choices, only the question
  /// (Hafid's explicit correction, recorded in the design's Decision Log).
  final bool readAloud;

  /// The design offers Français / English. French is the default and a
  /// missing French string is a bug, not a fallback (`Strings`).
  final bool english;

  final bool reduceMotion;
  final bool dailyReminders;
  final bool questNotifications;

  AppSettings copyWith({
    bool? darkTheme,
    int? volume,
    bool? music,
    bool? soundEffects,
    bool? readAloud,
    bool? english,
    bool? reduceMotion,
    bool? dailyReminders,
    bool? questNotifications,
  }) {
    return AppSettings(
      darkTheme: darkTheme ?? this.darkTheme,
      volume: volume ?? this.volume,
      music: music ?? this.music,
      soundEffects: soundEffects ?? this.soundEffects,
      readAloud: readAloud ?? this.readAloud,
      english: english ?? this.english,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      questNotifications: questNotifications ?? this.questNotifications,
    );
  }
}

/// Reads and writes [AppSettings] against the kid-scoped `app_state` table.
///
/// A key/value store rather than a table of its own: these are a handful of
/// scalars with no relationships, and `app_state` already carries exactly
/// this kind of per-kid bookkeeping (ADR 0014). A dedicated table would be a
/// migration for nine columns that are never queried together with anything
/// else.
///
/// Per kid, not per device, for the same reason every other kid-scoped store
/// is: two siblings on one tablet should not share a volume setting, and one
/// of them turning read-aloud off must not take it away from a younger
/// sibling who still needs it.
class AppSettingsStore {
  const AppSettingsStore(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _prefix = 'settings.';
  static const _theme = '${_prefix}dark_theme';
  static const _volume = '${_prefix}volume';
  static const _music = '${_prefix}music';
  static const _sfx = '${_prefix}sound_effects';
  static const _readAloud = '${_prefix}read_aloud';
  static const _english = '${_prefix}english';
  static const _reduceMotion = '${_prefix}reduce_motion';
  static const _dailyReminders = '${_prefix}daily_reminders';
  static const _questNotifications = '${_prefix}quest_notifications';

  Future<AppSettings> read() async {
    final rows = await (db.select(db.appStateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..where((t) => t.key.like('$_prefix%')))
        .get();
    final byKey = {for (final row in rows) row.key: row.value};

    bool flag(String key, bool fallback) =>
        byKey.containsKey(key) ? byKey[key] == 'true' : fallback;

    const defaults = AppSettings();
    return AppSettings(
      darkTheme: flag(_theme, defaults.darkTheme),
      volume: int.tryParse(byKey[_volume] ?? '') ?? defaults.volume,
      music: flag(_music, defaults.music),
      soundEffects: flag(_sfx, defaults.soundEffects),
      readAloud: flag(_readAloud, defaults.readAloud),
      english: flag(_english, defaults.english),
      reduceMotion: flag(_reduceMotion, defaults.reduceMotion),
      dailyReminders: flag(_dailyReminders, defaults.dailyReminders),
      questNotifications:
          flag(_questNotifications, defaults.questNotifications),
    );
  }

  /// Writes the whole value in one batch.
  ///
  /// Whole-value rather than per-key: a kid dragging the volume slider emits
  /// a change per frame, and nine tiny transactions per drag is how a cheap
  /// tablet starts to stutter.
  Future<void> write(AppSettings settings, {DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    final values = <String, String>{
      _theme: '${settings.darkTheme}',
      _volume: '${settings.volume}',
      _music: '${settings.music}',
      _sfx: '${settings.soundEffects}',
      _readAloud: '${settings.readAloud}',
      _english: '${settings.english}',
      _reduceMotion: '${settings.reduceMotion}',
      _dailyReminders: '${settings.dailyReminders}',
      _questNotifications: '${settings.questNotifications}',
    };

    await db.batch((batch) {
      for (final entry in values.entries) {
        batch.insert(
          db.appStateTable,
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: entry.key,
            value: entry.value,
            updatedAt: stamp,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
