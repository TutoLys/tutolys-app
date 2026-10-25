import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

AudioRequest _req(AudioChannel c, [int priority = 0]) =>
    AudioRequest(source: const EffectAudio('x'), channel: c, priority: priority);

QuestionEnvelope _env(Map<String, Object?> extra, {Map<String, Object?>? prompt}) =>
    QuestionEnvelope.parse({
      'exercise_id': 'ex',
      'version': 1,
      'engine_key': 'mcq',
      'skill_node_id': 's',
      'subject': 'FR',
      'grade': 1,
      'rank': 0,
      'prompt': prompt ?? {'text': 'Lis le mot', 'audio_ref': 'audio'},
      'config': const {},
      ...extra,
    }).valueOrNull!;

void main() {
  group('AudioLanePolicy', () {
    test('a new voice replaces the current voice and ducks music', () {
      final d = AudioLanePolicy.admit(
        _req(AudioChannel.narration, 5),
        playingPriorities: {AudioChannel.character: 1, AudioChannel.music: 0},
      );
      expect(d.start, isTrue);
      expect(d.stop, {AudioChannel.character});
      expect(d.duckMusic, isTrue);
    });

    test('a lower-priority voice is dropped while a higher one plays', () {
      final d = AudioLanePolicy.admit(
        _req(AudioChannel.character, 1),
        playingPriorities: {AudioChannel.narration: 5},
      );
      expect(d.start, isFalse);
      expect(d.stop, isEmpty);
    });

    test('an effect never interrupts a voice, only another effect', () {
      final d = AudioLanePolicy.admit(
        _req(AudioChannel.sfx),
        playingPriorities: {AudioChannel.narration: 5, AudioChannel.sfx: 0},
      );
      expect(d.start, isTrue);
      expect(d.stop, {AudioChannel.sfx});
    });

    test('music starting under a voice starts ducked', () {
      final d = AudioLanePolicy.admit(
        _req(AudioChannel.music),
        playingPriorities: {AudioChannel.narration: 1},
      );
      expect(d.duckMusic, isTrue);
    });
  });

  group('SpeechPlan', () {
    test('v1 content auto-reads the prompt from its asset', () {
      final env = _env(const {});
      final plan = SpeechPlan(envelope: env, question: env.questions.single);
      expect(plan.autoPlays(SpeechPart.prompt), isTrue);
      expect(plan.canSpeak(SpeechPart.option), isTrue);
      expect(plan.autoPlays(SpeechPart.option), isFalse);
      final src = plan.promptSource() as PrerecordedAudio;
      expect(src.ref, 'audio');
      expect(src.exerciseId, 'ex');
    });

    test('a reading assessment can forbid reading options aloud', () {
      final env = _env({'speech_policy': {'options': 'never'}});
      final plan = SpeechPlan(envelope: env, question: env.questions.single);
      expect(plan.canSpeak(SpeechPart.option), isFalse);
    });

    test('a forbidden prompt has no source even when an asset exists', () {
      final env = _env({'speech_policy': {'prompt': 'never'}});
      expect(SpeechPlan(envelope: env, question: env.questions.single).promptSource(), isNull);
    });

    test('read-aloud off stops auto-play but keeps the speaker button', () {
      final env = _env(const {});
      final plan = SpeechPlan(envelope: env, question: env.questions.single, readAloudEnabled: false);
      expect(plan.autoPlays(SpeechPart.prompt), isFalse);
      expect(plan.canSpeak(SpeechPart.prompt), isTrue);
    });

    test('tts falls back to the speech text only when there is no asset', () {
      final env = _env(
        const {},
        prompt: {
          'text': '7 + 5',
          'speech': {'text': 'sept plus cinq', 'mode': 'tts'},
        },
      );
      final src = SpeechPlan(envelope: env, question: env.questions.single).promptSource()
          as TtsUtterance;
      expect(src.text, 'sept plus cinq');
      expect(src.locale, 'fr-CA');
    });

    test('an asset wins over tts', () {
      final env = _env(
        const {},
        prompt: {
          'text': '7 + 5',
          'audio_ref': 'audio',
          'speech': {'text': 'sept plus cinq', 'mode': 'tts'},
        },
      );
      expect(
        SpeechPlan(envelope: env, question: env.questions.single).promptSource(),
        isA<PrerecordedAudio>(),
      );
    });
  });
}
