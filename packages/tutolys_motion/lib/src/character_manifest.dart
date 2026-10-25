import 'reaction.dart';

/// Which renderer draws a character. A manifest names one; the registry maps
/// it to an implementation, so moving the fox from placeholder to Rive is a
/// data change.
enum RendererType { placeholder, rive }

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
