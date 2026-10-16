import 'engine.dart';

/// Maps an engine key to its implementation.
///
/// This is the mechanism behind a LOCKED decision in the plan: the backend
/// picks which engine renders a question, so adding an exercise — or changing
/// which engine an existing one uses — is a data change with no app release.
/// Only a brand-new engine *type* needs a new build.
class EngineRegistry {
  EngineRegistry(List<TutolysEngine> engines)
      : _byKey = {for (final engine in engines) engine.key: engine} {
    if (_byKey.length != engines.length) {
      // Two engines claiming one key would make rendering depend on list
      // order, which is the kind of bug that only shows up in production.
      final keys = engines.map((e) => e.key).toList();
      final duplicates = keys.where((k) => keys.where((o) => o == k).length > 1).toSet();
      throw ArgumentError('Duplicate engine keys: ${duplicates.join(', ')}');
    }
  }

  final Map<String, TutolysEngine> _byKey;

  Iterable<TutolysEngine> get engines => _byKey.values;

  Iterable<String> get keys => _byKey.keys;

  bool contains(String key) => _byKey.containsKey(key);

  TutolysEngine? lookup(String key) => _byKey[key];

  /// Resolve an engine for an exercise envelope.
  ///
  /// Returns a typed miss rather than null so the host can tell "we have never
  /// heard of this engine" (the app is too old) from "we have it but not this
  /// version" (the app is too old in a different way). Both need an update
  /// prompt; neither should crash a child's session.
  EngineResolution resolve({
    required String engineKey,
    required int minimumVersion,
  }) {
    final engine = _byKey[engineKey];
    if (engine == null) {
      return EngineResolution.unknownEngine(engineKey);
    }
    if (engine.version < minimumVersion) {
      return EngineResolution.versionTooOld(
        engineKey: engineKey,
        available: engine.version,
        required: minimumVersion,
      );
    }
    return EngineResolution.resolved(engine);
  }
}

sealed class EngineResolution {
  const EngineResolution();

  factory EngineResolution.resolved(TutolysEngine engine) = ResolvedEngine;

  factory EngineResolution.unknownEngine(String key) = UnknownEngine;

  factory EngineResolution.versionTooOld({
    required String engineKey,
    required int available,
    required int required,
  }) = EngineVersionTooOld;
}

class ResolvedEngine extends EngineResolution {
  const ResolvedEngine(this.engine);
  final TutolysEngine engine;
}

class UnknownEngine extends EngineResolution {
  const UnknownEngine(this.engineKey);
  final String engineKey;
}

class EngineVersionTooOld extends EngineResolution {
  const EngineVersionTooOld({
    required this.engineKey,
    required this.available,
    required this.required,
  });

  final String engineKey;
  final int available;
  final int required;
}
