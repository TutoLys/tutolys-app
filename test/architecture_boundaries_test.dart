// Package dependency rules for the learning engine platform
// (docs/architecture/learning-engine-platform.md §4.1), checked against
// the actual import lines rather than trusted to review.
//
// The rule that matters most: an engine never reaches characters, audio
// players, storage or the network. That is what lets the fox become a Rive
// character, or audioplayers be swapped, without touching a single engine.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

List<(String file, String uri)> _importsUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return const [];
  return [
    for (final f in root.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        for (final m in _import.allMatches(f.readAsStringSync())) (f.path, m.group(1)!),
  ];
}

void _expectNone(String dir, bool Function(String uri) forbidden, String why) {
  final imports = _importsUnder(dir);
  // A moved or misspelled directory would otherwise pass vacuously.
  expect(imports, isNotEmpty, reason: 'no imports found under $dir');
  final offenders = [
    for (final (file, uri) in imports)
      if (forbidden(uri)) '$file → $uri',
  ];
  expect(offenders, isEmpty, reason: why);
}

bool _package(String uri, String name) => uri.startsWith('package:$name/');

void main() {
  test('engines import only flutter, engine_sdk and design_system', () {
    const allowed = ['flutter', 'engine_sdk', 'design_system', 'engines_core', 'meta', 'collection'];
    _expectNone(
      'packages/engines_core/lib',
      (uri) =>
          uri.startsWith('package:') &&
          !allowed.any((name) => _package(uri, name)),
      'engines must not depend on characters, audio, storage, networking or the app',
    );
  });

  test('engine_sdk knows nothing about characters, the app, storage or the network', () {
    _expectNone(
      'packages/engine_sdk/lib',
      (uri) =>
          _package(uri, 'tutolys_motion') ||
          _package(uri, 'engines_core') ||
          _package(uri, 'tutolys_app') ||
          _package(uri, 'drift') ||
          _package(uri, 'dio') ||
          _package(uri, 'flutter_riverpod'),
      'the contracts package sits below everything else',
    );
  });

  test('the motion package never depends on engines or the app', () {
    _expectNone(
      'packages/tutolys_motion/lib',
      (uri) => _package(uri, 'engines_core') || _package(uri, 'tutolys_app'),
      'characters react to runtime events, never to a specific engine',
    );
  });

  test('the pure runtime and contracts stay free of audio players', () {
    for (final dir in ['packages/engine_sdk/lib/src/runtime', 'packages/engine_sdk/lib/src/contracts']) {
      _expectNone(
        dir,
        (uri) => _package(uri, 'audioplayers') || _package(uri, 'path_provider'),
        '$dir must stay pure: testable without a platform',
      );
    }
  });
}
