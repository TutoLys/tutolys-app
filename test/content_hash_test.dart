import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';

/// The cross-language contract.
///
/// `expectedHash` was produced by the REAL backend
/// (`apps.exercises.models.content_sha256`) over the exact envelope below. If
/// Dart and Python ever diverge on canonicalisation, every content download
/// looks corrupted and sync never converges — so this test exists to fail
/// loudly rather than let that happen silently in production.
void main() {
  // Chosen to break naive canonicalisation: unsorted keys, nesting, French
  // accents, and a list whose order carries meaning.
  final envelope = <String, Object?>{
    'schema_version': 1,
    'exercise_id': '00000000-0000-4000-8000-000000000001',
    'version': 3,
    'engine_key': 'mcq',
    'engine_min_version': 1,
    'skill_node_id': '11111111-1111-4111-8111-111111111111',
    'subject': 'FR',
    'grade': 1,
    'rank': 2,
    'locale': 'fr-CA',
    'prompt': {
      'text': 'Quel mot est écrit correctement ?',
      'audio_ref': null,
      'image_ref': null,
    },
    'config': {
      'options': [
        {'id': 'b', 'label': 'château'},
        {'id': 'a', 'label': 'chateâu'},
      ],
      'correct': 'b',
      'hint': "Pense à l'accent circonflexe.",
    },
    'assets': <Object?>[],
  };

  const expectedHash =
      'c51b39407e39ae61e9d8f979de8c9568adb8f8a57830b83d235cfec5c72ff851';

  group('content hash matches the Python backend', () {
    test('the fixture hashes to the backend-produced value', () {
      expect(contentSha256(envelope), expectedHash);
    });

    test('key order does not change the hash', () {
      final reordered = Map<String, Object?>.fromEntries(
        envelope.entries.toList().reversed,
      );

      expect(contentSha256(reordered), expectedHash);
    });

    test('accents are left literal, not escaped', () {
      // Escaping would change every hash for French content, which is most
      // of it.
      expect(canonicalJson(envelope), contains('château'));
      expect(canonicalJson(envelope), isNot(contains(r'\u')));
    });

    test('no insignificant whitespace', () {
      expect(canonicalJson(envelope), isNot(contains(': ')));
      expect(canonicalJson(envelope), isNot(contains(', ')));
    });

    test('list order is preserved, never sorted', () {
      // `compose_build` targets are ordered: sorting would change the answer.
      final ordered = {'target': ['cha', 'peau']};
      final swapped = {'target': ['peau', 'cha']};

      expect(contentSha256(ordered), isNot(contentSha256(swapped)));
    });

    test('a real content change changes the hash', () {
      final edited = Map<String, Object?>.from(envelope)
        ..['prompt'] = {'text': 'changed', 'audio_ref': null, 'image_ref': null};

      expect(contentSha256(edited), isNot(expectedHash));
    });

    test('nested map keys are sorted too', () {
      final a = {'outer': {'z': 1, 'a': 2}};
      final b = {'outer': {'a': 2, 'z': 1}};

      expect(contentSha256(a), contentSha256(b));
    });
  });
}
