import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/play/engine_registry_provider.dart';

void main() {
  test('resolves the real engines, each at version 1', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(engineRegistryProvider);

    expect(registry.keys.toSet(), {
      'mcq',
      'pair_match',
      'compose_build',
      'speed_tap',
    });
    for (final key in registry.keys) {
      final resolution = registry.resolve(engineKey: key, minimumVersion: 1);
      expect(resolution, isA<ResolvedEngine>());
    }
  });

  test('an unknown engine key is a typed miss, not a crash', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(engineRegistryProvider);
    final resolution = registry.resolve(engineKey: 'nope', minimumVersion: 1);

    expect(resolution, isA<UnknownEngine>());
  });
}
