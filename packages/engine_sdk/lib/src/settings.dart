/// Per-engine settings.
///
/// LOCKED in the handoff plan: settings live in the app, never the backend.
/// Each engine ships a manifest of keys, types, defaults and FR/EN labels; the
/// kid's or parent's choices are stored locally. The backend neither stores
/// nor serves them, so a preference change needs no round trip and works
/// offline.
library;

enum SettingType { toggle, choice, number }

class SettingDefinition {
  const SettingDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    required this.labelFr,
    required this.labelEn,
    this.choices,
    this.min,
    this.max,
  });

  final String key;
  final SettingType type;
  final Object defaultValue;
  final String labelFr;
  final String labelEn;

  /// For [SettingType.choice].
  final List<String>? choices;

  /// For [SettingType.number].
  final num? min;
  final num? max;

  bool accepts(Object? value) {
    return switch (type) {
      SettingType.toggle => value is bool,
      SettingType.choice => value is String && (choices ?? const []).contains(value),
      SettingType.number =>
        value is num && (min == null || value >= min!) && (max == null || value <= max!),
    };
  }
}

/// An engine's declared settings.
class SettingsManifest {
  const SettingsManifest({required this.engineKey, required this.definitions});

  final String engineKey;
  final List<SettingDefinition> definitions;

  Map<String, Object> get defaults =>
      {for (final d in definitions) d.key: d.defaultValue};

  SettingDefinition? definitionFor(String key) {
    for (final d in definitions) {
      if (d.key == key) return d;
    }
    return null;
  }
}

/// Resolved settings: manifest defaults with the user's local overrides on top.
///
/// An override that does not match its definition is ignored rather than
/// applied. Stale local data from an older app version must not be able to
/// hand an engine a value of the wrong type.
class ResolvedSettings {
  ResolvedSettings({
    required SettingsManifest manifest,
    Map<String, Object?> overrides = const {},
  }) : _values = {
          ...manifest.defaults,
          for (final entry in overrides.entries)
            if (manifest.definitionFor(entry.key)?.accepts(entry.value) ?? false)
              entry.key: entry.value!,
        };

  final Map<String, Object> _values;

  Map<String, Object> get values => Map.unmodifiable(_values);

  bool toggle(String key, {bool fallback = false}) {
    final value = _values[key];
    return value is bool ? value : fallback;
  }

  String choice(String key, {String fallback = ''}) {
    final value = _values[key];
    return value is String ? value : fallback;
  }

  num number(String key, {num fallback = 0}) {
    final value = _values[key];
    return value is num ? value : fallback;
  }
}

/// Settings every engine has, so a kid is not offered "sound" in one game and
/// "audio" in the next.
const commonSettings = <SettingDefinition>[
  SettingDefinition(
    key: 'sound_effects',
    type: SettingType.toggle,
    defaultValue: true,
    labelFr: 'Effets sonores',
    labelEn: 'Sound effects',
  ),
  SettingDefinition(
    key: 'music',
    type: SettingType.toggle,
    defaultValue: true,
    labelFr: 'Musique',
    labelEn: 'Music',
  ),
  SettingDefinition(
    key: 'hints',
    type: SettingType.toggle,
    defaultValue: true,
    labelFr: 'Indices',
    labelEn: 'Hints',
  ),
  SettingDefinition(
    key: 'fullscreen',
    type: SettingType.toggle,
    defaultValue: false,
    labelFr: 'Plein écran',
    labelEn: 'Fullscreen',
  ),
  SettingDefinition(
    key: 'animation_level',
    type: SettingType.choice,
    defaultValue: 'full',
    choices: ['full', 'reduced', 'none'],
    labelFr: 'Animations',
    labelEn: 'Animations',
  ),
];
