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
  'samples/math_pattern_machine.json': PatternMachineEngine(),
  'samples/math_measure_tool.json': MeasureToolEngine(),
  'samples/soc_path_planner.json': PathPlannerEngine(),
  'samples/math_fraction_slice.json': FractionSliceEngine(),
  'samples/math_geometry_lab.json': GeometryLabEngine(),
  'samples/sci_experiment_lab.json': ExperimentLabEngine(),
  'samples/math_counters_board.json': CountersBoardEngine(),
  'samples/sci_sky_model.json': SkyModelEngine(),
  'samples/fr_passage_discuss.json': PassageReaderEngine(),
  'samples/fr_mail_studio.json': MailStudioEngine(),
  'samples/fr_feedback_studio.json': FeedbackStudioEngine(),
  'samples/en_stage_presenter.json': StagePresenterEngine(),
  'samples/fr_my_gallery.json': MyGalleryEngine(),
};

/// The creation lessons (app ADR 0094): real lessons where every question
/// is open work, so each must parse with `creation` on.
const _creations = {
  'pfeq_grade1_francais/21_lecon_ecrire_a_quelqu_un.json': MailStudioEngine(),
  'pfeq_grade1_francais/22_lecon_invente_ta_phrase.json': ComposeSlotsEngine(),
  'pfeq_grade1_math/75_lecon_construis_tes_figures.json': GeometryLabEngine(),
  'pfeq_grade1_math_en/75_lecon_construis_tes_figures_en.json':
      GeometryLabEngine(),
  'pfeq_grade1_english/86_make_your_own_sentence.json': ComposeSlotsEngine(),
};

final _dir = Directory('../../../tutolys-backend/content');

void main() {
  for (final MapEntry(key: file, value: engine) in {
    ..._samples,
    ..._creations,
  }.entries) {
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
        if (_creations.containsKey(file)) {
          expect(qc['creation'], isTrue, reason: 'question $i');
        }
      }
    }, skip: _dir.existsSync() ? false : 'no tutolys-backend checkout');
  }
}
