import 'reaction.dart';

/// Which renderer draws a character. A manifest names one; the registry maps
/// it to an implementation, so moving the fox from bitmap to Rive is a
/// data change.
///
/// - [placeholder]: the hand-painted `TutolysMascot`. Last-resort fallback.
/// - [bitmap]: still images (one per pose slot) moved by native Flutter
///   motion — `BitmapCharacterRenderer`. Today's fox.
/// - [rive]: reserved. Not installed: Rive is not approved (animation plan
///   §12). A Rive manifest on this build falls back to [placeholder].
enum RendererType { placeholder, bitmap, rive }

/// Describes one character: what it can do and how to draw it.
class CharacterManifest {
  CharacterManifest({
    required this.id,
    required this.version,
    required this.rendererType,
    required Set<Reaction> supported,
    Map<Reaction, Reaction> fallbacks = const {},
    this.idle = Reaction.idle,
    this.assets = const {},
  }) : supported = Set.unmodifiable({...supported, idle}),
       fallbacks = Map.unmodifiable(fallbacks);

  final String id;
  final int version;
  final RendererType rendererType;
  final Set<Reaction> supported;

  /// Where an unsupported reaction goes instead, e.g. `victory → celebrating`.
  /// Chains are followed; anything left over lands on [idle].
  final Map<Reaction, Reaction> fallbacks;
  final Reaction idle;

  /// Renderer-specific asset references (an image per reaction, a `.riv`
  /// path and state-machine name). Opaque to the director.
  final Map<String, String> assets;

  /// Reads a manifest delivered as data (`assets/characters/<id>/manifest.json`
  /// shape — see ADR 0060). Unknown reaction names are dropped rather than
  /// thrown on, so a manifest written for a newer build still loads.
  factory CharacterManifest.fromJson(Map<String, Object?> json) {
    Reaction? reaction(Object? name) {
      for (final r in Reaction.values) {
        if (r.name == name) return r;
      }
      return null;
    }

    final renderer = RendererType.values.firstWhere(
      (t) => t.name == json['renderer'],
      orElse: () => RendererType.placeholder,
    );
    final supported = <Reaction>{
      for (final n in (json['supported'] as List<Object?>? ?? const []))
        ?reaction(n),
    };
    final fallbacks = <Reaction, Reaction>{};
    for (final MapEntry(:key, :value)
        in (json['fallbacks'] as Map<String, Object?>? ?? const {}).entries) {
      final from = reaction(key);
      final to = reaction(value);
      if (from != null && to != null) fallbacks[from] = to;
    }
    return CharacterManifest(
      id: json['id']! as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      rendererType: renderer,
      supported: supported,
      fallbacks: fallbacks,
      idle: reaction(json['idle']) ?? Reaction.idle,
      assets: {
        for (final MapEntry(:key, :value)
            in (json['assets'] as Map<String, Object?>? ?? const {}).entries)
          if (value is String) key: value,
      },
    );
  }

  /// The reaction this character will actually perform for [wanted].
  ///
  /// A missing reaction is never an error: a character with no `explaining`
  /// animation explains by looking `thinking`, or just idles. A character
  /// without art must not stop a question.
  Reaction resolve(Reaction wanted) {
    var current = wanted;
    final seen = <Reaction>{};
    while (!supported.contains(current)) {
      if (!seen.add(current)) return idle; // a cycle in authored fallbacks
      final next = fallbacks[current];
      if (next == null) return idle;
      current = next;
    }
    return current;
  }
}
