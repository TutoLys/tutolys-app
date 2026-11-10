import 'package:drift/drift.dart';

import 'database.dart';
import 'kid_defaults.dart';

/// The settings a guardian's answers can start off (backend ADR 0220).
enum DefaultableSetting { music, soundEffects, reduceMotion }

/// Everything Réglages owns, as one immutable value.
///
/// Defaults match the design's own rendering of the screen: volume at 70%,
/// sound and music on, read-aloud **on** (a grade-1 reader cannot read the
/// question — see ADR 0021), French, animations not reduced. Learning
/// reminders are **off** until a guardian turns them on (ADR 0053).
/// THE SWAP (ADR 0126). Whether the 3D village is on for a kid who hasn't
/// touched « Village en 3D ». False until Hafid says the 3D is ready
/// (2026-11-10: "everything keeps the 2d for now"). Flipping it reaches
/// every kid who never chose, because only a changed setting is stored
/// (`writeChanges`, ADR 0125). Linux has no 3D channel, so it stays 2D
/// whatever this says.
const village3dDefaultOn = false;

class AppSettings {
  const AppSettings({
    this.darkTheme = false,
    this.volume = 70,
    this.music = true,
    this.soundEffects = true,
    this.readAloud = true,
    this.english = false,
    this.reduceMotion = false,
    this.dailyReminders = false,
    this.reminderMinutes = 17 * 60,
    this.remindersOnSince,
    this.flameReminders = false,
    this.village3d = village3dDefaultOn,
    this.chosen = const {},
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

  /// "Rappels quotidiens": a local reminder on a day not yet played
  /// (ADR 0053). Turned on, and its time chosen, behind the guardian PIN.
  final bool dailyReminders;

  /// The reminder's time, in minutes after midnight (08:00–19:00).
  final int reminderMinutes;

  /// The day reminders were last turned on: the back-off counts from it
  /// for a kid who hasn't played since.
  final DateTime? remindersOnSince;

  /// "Ma flamme": the evening reminder when the streak is at risk
  /// (ADR 0053). Like [dailyReminders], turned on behind the guardian PIN.
  final bool flameReminders;

  /// « Village en 3D »: draw the Village as the 3D scene where the device
  /// can (ADR 0126). Off, or where it can't, the 2D village shows.
  /// Defaults to [village3dDefaultOn].
  final bool village3d;

  /// What the family set on this device. Anything else still follows the
  /// guardian's defaults ([applyKidDefaults]).
  final Set<DefaultableSetting> chosen;

  AppSettings copyWith({
    bool? darkTheme,
    int? volume,
    bool? music,
    bool? soundEffects,
    bool? readAloud,
    bool? english,
    bool? reduceMotion,
    bool? dailyReminders,
    int? reminderMinutes,
    DateTime? remindersOnSince,
    bool? flameReminders,
    bool? village3d,
    Set<DefaultableSetting>? chosen,
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
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      remindersOnSince: remindersOnSince ?? this.remindersOnSince,
      flameReminders: flameReminders ?? this.flameReminders,
      village3d: village3d ?? this.village3d,
      chosen: chosen ?? this.chosen,
    );
  }
}

/// What the family set on the device, else [defaults], else the app's own
/// default. Pure, and safe to run again on its own result: a setting nobody
/// chose is recomputed each time, so a default the guardian removes lets go.
AppSettings applyKidDefaults(AppSettings settings, KidDefaults defaults) {
  const app = AppSettings();
  bool pick(
    DefaultableSetting key,
    bool device,
    bool? guardian,
    bool fallback,
  ) => settings.chosen.contains(key) ? device : guardian ?? fallback;
  final music = pick(
    DefaultableSetting.music,
    settings.music,
    defaults.music,
    app.music,
  );
  final soundEffects = pick(
    DefaultableSetting.soundEffects,
    settings.soundEffects,
    defaults.soundEffects,
    app.soundEffects,
  );
  final reduceMotion = pick(
    DefaultableSetting.reduceMotion,
    settings.reduceMotion,
    defaults.reduceMotion,
    app.reduceMotion,
  );
  // The same value back when nothing moved: most kids have no defaults, and
  // a new instance would notify everything watching the settings.
  if (music == settings.music &&
      soundEffects == settings.soundEffects &&
      reduceMotion == settings.reduceMotion) {
    return settings;
  }
  return settings.copyWith(
    music: music,
    soundEffects: soundEffects,
    reduceMotion: reduceMotion,
  );
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
  // A new key, not `daily_reminders`: that flag defaulted to on while it did
  // nothing, so a stored "true" was never a guardian's choice and must not
  // start reminders now that they're real (ADR 0053).
  static const _dailyReminders = '${_prefix}reminders_on';
  static const _reminderMinutes = '${_prefix}reminder_minutes';
  static const _remindersOnSince = '${_prefix}reminders_on_since';
  // Replaces `quest_notifications` ("Nouvelles quêtes"), which defaulted to
  // on and did nothing; Hafid made it "Ma flamme" (2026-10-28).
  static const _flameReminders = '${_prefix}flame_reminders';
  static const _village3d = '${_prefix}village_3d';
  // Present once a stored key can be trusted to be a choice. Before it,
  // changing the volume saved every setting, so a stored "music on" proved
  // nothing (ADR 0125).
  static const _choicesOnly = '${_prefix}choices_only';

  static const _defaultableKeys = {
    _music: DefaultableSetting.music,
    _sfx: DefaultableSetting.soundEffects,
    _reduceMotion: DefaultableSetting.reduceMotion,
  };

  /// Drops the stored values that only repeat the app's default, the ones
  /// the old whole-value write left behind. A value that differs from the
  /// default can only be someone's choice, so it stays.
  Future<void> _keepOnlyChoices(Map<String, String> byKey) async {
    const app = AppSettings();
    final repeated = {
      _music: '${app.music}',
      _sfx: '${app.soundEffects}',
      _reduceMotion: '${app.reduceMotion}',
    }..removeWhere((key, value) => byKey[key] != value);
    await db.transaction(() async {
      await (db.delete(
        db.appStateTable,
      )..where((t) => t.kidId.equals(kidId) & t.key.isIn(repeated.keys))).go();
      await _put({_choicesOnly: 'true'}, DateTime.now());
    });
    byKey.removeWhere((key, _) => repeated.containsKey(key));
  }

  Future<AppSettings> read() async {
    final rows = await (db.select(db.appStateTable)
          ..where((t) => t.kidId.equals(kidId))
          ..where((t) => t.key.like('$_prefix%')))
        .get();
    final byKey = {for (final row in rows) row.key: row.value};
    if (!byKey.containsKey(_choicesOnly)) await _keepOnlyChoices(byKey);

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
      reminderMinutes:
          int.tryParse(byKey[_reminderMinutes] ?? '') ??
          defaults.reminderMinutes,
      remindersOnSince: DateTime.tryParse(byKey[_remindersOnSince] ?? ''),
      flameReminders: flag(_flameReminders, defaults.flameReminders),
      village3d: flag(_village3d, defaults.village3d),
      chosen: {
        for (final MapEntry(:key, :value) in _defaultableKeys.entries)
          if (byKey.containsKey(key)) value,
      },
    );
  }

  /// Writes the whole value in one batch, every field as a choice.
  Future<void> write(AppSettings settings, {DateTime? now}) =>
      _put(_values(settings), now ?? DateTime.now());

  /// Writes only what differs between [before] and [after], in one batch.
  ///
  /// A key is stored only once it's a choice: saving the volume must not
  /// freeze a music setting that still follows the guardian's defaults.
  Future<void> writeChanges(
    AppSettings before,
    AppSettings after, {
    DateTime? now,
  }) {
    final old = _values(before);
    return _put(
      _values(after)..removeWhere((key, value) => old[key] == value),
      now ?? DateTime.now(),
    );
  }

  Map<String, String> _values(AppSettings settings) {
    return <String, String>{
      _theme: '${settings.darkTheme}',
      _volume: '${settings.volume}',
      _music: '${settings.music}',
      _sfx: '${settings.soundEffects}',
      _readAloud: '${settings.readAloud}',
      _english: '${settings.english}',
      _reduceMotion: '${settings.reduceMotion}',
      _dailyReminders: '${settings.dailyReminders}',
      _reminderMinutes: '${settings.reminderMinutes}',
      if (settings.remindersOnSince case final since?)
        _remindersOnSince: since.toIso8601String().substring(0, 10),
      _flameReminders: '${settings.flameReminders}',
      _village3d: '${settings.village3d}',
    };
  }

  Future<void> _put(Map<String, String> values, DateTime stamp) async {
    await db.batch((batch) {
      for (final entry in {...values, _choicesOnly: 'true'}.entries) {
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
