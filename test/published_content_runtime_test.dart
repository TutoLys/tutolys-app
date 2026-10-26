import 'dart:convert';
import 'dart:io';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';

/// Every lesson the backend publishes plays on the new runtime, never the
/// legacy host. Hafid hit a full-width legacy mcq because `prompt.speech`
/// came as a string and the envelope parser refused it.
///
/// Reads the backend's content files from the sibling checkout, so it
/// skips where that checkout isn't present.
void main() {
  final root = Directory('../tutolys-backend/content');

  test(
    'every published lesson parses and has an engine on the new runtime',
    () {
      final registry = ProviderContainer().read(learningEngineRegistryProvider);
      final failures = <String>[];
      var checked = 0;
      for (final f
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.json') &&
                    !f.path.contains('/samples/') &&
                    !f.path.endsWith('.authoring.json'),
              )) {
        final json = jsonDecode(f.readAsStringSync());
        if (json is! Map<String, Object?> || json['engine_key'] == null) {
          continue;
        }
        checked++;
        final name = f.path.split('content/').last;
        switch (QuestionEnvelope.parse(json)) {
          case ParseOk(:final value):
            if (!registry.servesAll(value)) {
              failures.add('$name: no runtime engine');
              continue;
            }
            for (final q in value.questions) {
              final r = registry.resolve(
                q,
                minimumVersion: value.engineMinVersion,
              );
              if (r case LearningEngineMissing(:final reason)) {
                failures.add('$name q${q.index}: $reason');
              }
            }
          case ParseInvalid(:final reason) || ParseUnsupported(:final reason):
            failures.add('$name: $reason');
        }
      }
      expect(checked, greaterThan(100), reason: 'found the content');
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    skip: root.existsSync()
        ? false
        : 'no tutolys-backend checkout beside this one',
  );
}
