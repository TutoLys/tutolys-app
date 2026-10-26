import 'dart:convert';
import 'dart:io';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend's content_cli and these engines' `parse` each enforce the
/// same rules, in Python and in Dart. This parses every question of each
/// engine's sample lesson with the app's own parser, so the two can't
/// drift unnoticed. Skipped when the backend checkout isn't beside this
/// repo.
const _samples = {
  'math_pattern_machine.json': PatternMachineEngine(),
  'math_measure_tool.json': MeasureToolEngine(),
  'soc_path_planner.json': PathPlannerEngine(),
  'math_fraction_slice.json': FractionSliceEngine(),
  'math_geometry_lab.json': GeometryLabEngine(),
};

final _dir = Directory('../../../tutolys-backend/content/samples');

void main() {
  for (final MapEntry(key: file, value: engine) in _samples.entries) {
    test('$file parses in the app', () {
      final lesson = jsonDecode(
        File('${_dir.path}/$file').readAsStringSync(),
      ) as Map<String, Object?>;
      final config = lesson['config']! as Map<String, Object?>;
      final questions =
          (config['questions'] as List?) ??
          [
            {'config': config},
          ];
      expect(questions, isNotEmpty);
      for (final (i, q) in questions.indexed) {
        final qc = (q as Map)['config'] as Map<String, Object?>;
        final parsed = (engine as LearningEngine).parse(qc);
        expect(
          parsed,
          isA<ParseOk<Object?>>(),
          reason: 'question $i: ${parsed is ParseInvalid ? parsed.reason : ''}',
        );
      }
    }, skip: _dir.existsSync() ? false : 'no tutolys-backend checkout');
  }
}
