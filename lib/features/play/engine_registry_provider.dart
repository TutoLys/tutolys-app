import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The real, production engine set (A7, piece 4) — Set A, chosen for being
/// mechanically distinct (tap / select-and-connect / assemble), one per
/// interaction shape. Adding a new engine *type* needs a new build; which
/// engine an existing exercise *uses* is the backend's call, not this
/// list's (see `EngineRegistry`'s own doc comment).
final engineRegistryProvider = Provider<EngineRegistry>((ref) {
  return EngineRegistry([
    const McqEngine(),
    const PairMatchEngine(),
    const ComposeBuildEngine(),
  ]);
});
