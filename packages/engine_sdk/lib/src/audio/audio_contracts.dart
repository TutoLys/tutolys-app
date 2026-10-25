/// Audio, as services the runtime coordinates — never something an engine
/// plays itself.
///
/// The existing `ExercisePromptAudio` (one player per runner) keeps serving
/// the legacy runner. Phase 2 implements [AudioCoordinator] on audioplayers
/// with one app-scoped player per channel, at which point the speaker
/// button, character speech and effects stop being able to talk over each
/// other.
library;

import '../contracts/envelope.dart';
import '../runtime/runtime_event.dart';

enum AudioChannel {
  /// Reading the question, options or feedback aloud.
  narration,

  /// A character speaking. Shares the voice lane with [narration]: two
  /// voices at once is noise to a six-year-old.
  character,

  /// Short effects. Never interrupt a voice.
  sfx,

  /// Background music. None exists yet (frontend spec §3.8); the channel is
  /// here so music ducks under voices from day one.
  music;

  bool get isVoice => this == narration || this == character;
}

sealed class AudioSource {
  const AudioSource();
}

/// A cached asset, resolved through `AudioResolver` (Piper output today).
class PrerecordedAudio extends AudioSource {
  const PrerecordedAudio({required this.exerciseId, required this.ref});
  final String exerciseId;
  final String ref;
}

/// Speech synthesised on device. No implementation ships (doc §10 D2); the
/// coordinator reports [PlaybackPhase.unavailable] for it unless a
/// [TtsEngine] is installed that supports the locale.
class TtsUtterance extends AudioSource {
  const TtsUtterance({required this.text, required this.locale});
  final String text;
  final String locale;
}

/// A bundled effect by name (`correct`, `retry`, `complete`).
class EffectAudio extends AudioSource {
  const EffectAudio(this.name);
  final String name;
}

class AudioRequest {
  const AudioRequest({
    required this.source,
    required this.channel,
    this.priority = 0,
    this.loop = false,
  });

  final AudioSource source;
  final AudioChannel channel;

  /// Play again from the start, seamlessly, until stopped: background
  /// music. The clip's own end never completes the handle.
  final bool loop;

  /// Within the voice lane, a request of equal or higher priority replaces
  /// what is playing; a lower one is dropped. A child pressing the speaker
  /// always outranks an ambient character line.
  final int priority;
}

enum PlaybackPhase { loading, playing, completed, stopped, unavailable, error }

class PlaybackStatus {
  const PlaybackStatus(this.requestId, this.phase);
  final int requestId;
  final PlaybackPhase phase;
}

abstract interface class PlaybackHandle {
  int get requestId;

  /// Completes when playback ends for any reason. Never throws: an audio
  /// failure must never block a question (brief §20).
  Future<PlaybackPhase> get done;

  Future<void> stop();
}

abstract interface class AudioCoordinator {
  PlaybackHandle play(AudioRequest request);
  Future<void> pause();
  Future<void> resume();
  Future<void> stopChannel(AudioChannel channel);
  Future<void> stopAll();
  Stream<PlaybackStatus> get status;
  Future<void> dispose();
}

/// On-device speech synthesis. Interface only.
abstract interface class TtsEngine {
  Future<bool> supportsLocale(String locale);
  Future<void> speak(String text, {required String locale});
  Future<void> stop();
}

/// Microphone capture for future speaking activities (Phase 6). Interface
/// only, and deliberately separate from playback.
///
/// Privacy is part of the contract: [capture] returns derived data, and a
/// raw recording exists only if [VoiceCaptureRequest.retainRecording] was
/// set — which no flow does until counsel has reviewed voice capture for
/// children (doc §10 D8). A speech recogniser's transcript is never, on its
/// own, evidence of mispronunciation.
abstract interface class VoiceCaptureService {
  Future<VoicePermission> permission();
  Future<VoiceCaptureResult> capture(VoiceCaptureRequest request);
  Future<void> cancel();
}

enum VoicePermission { granted, denied, notAuthorizedByGuardian, unsupported }

class VoiceCaptureRequest {
  const VoiceCaptureRequest({
    required this.locale,
    required this.maxDuration,
    this.retainRecording = false,
  });
  final String locale;
  final Duration maxDuration;
  final bool retainRecording;
}

class VoiceCaptureResult {
  const VoiceCaptureResult({
    required this.durationMs,
    this.transcript,
    this.transcriptConfidence,
    this.recordingRef,
  });
  final int durationMs;
  final String? transcript;
  final double? transcriptConfidence;

  /// Null unless retention was requested and authorised.
  final String? recordingRef;
}

// ── policies (pure) ──────────────────────────────────────────────────────────

/// What the coordinator should do with a new request, given what plays now.
class LaneDecision {
  const LaneDecision({
    required this.start,
    this.stop = const {},
    this.duckMusic = false,
  });
  final bool start;

  /// Channels to stop before starting.
  final Set<AudioChannel> stop;
  final bool duckMusic;
}

/// The coordination rules, kept pure so they're tested without a player:
/// one voice at a time (by priority), one effect at a time, music under
/// voices.
abstract final class AudioLanePolicy {
  static LaneDecision admit(
    AudioRequest request, {
    required Map<AudioChannel, int> playingPriorities,
  }) {
    final voices = playingPriorities.entries.where((e) => e.key.isVoice);
    switch (request.channel) {
      case AudioChannel.narration || AudioChannel.character:
        final top = voices.isEmpty
            ? null
            : voices.map((e) => e.value).reduce((a, b) => a > b ? a : b);
        if (top != null && request.priority < top) {
          return const LaneDecision(start: false);
        }
        return LaneDecision(
          start: true,
          stop: {for (final v in voices) v.key},
          duckMusic: playingPriorities.containsKey(AudioChannel.music),
        );
      case AudioChannel.sfx:
        return LaneDecision(
          start: true,
          stop: playingPriorities.containsKey(AudioChannel.sfx)
              ? {AudioChannel.sfx}
              : const {},
        );
      case AudioChannel.music:
        return LaneDecision(
          start: true,
          stop: playingPriorities.containsKey(AudioChannel.music)
              ? {AudioChannel.music}
              : const {},
          duckMusic: voices.isNotEmpty,
        );
    }
  }
}

/// What may be read aloud in one question, and how.
///
/// The shell's speaker buttons and auto-read all go through this, so a
/// reading assessment that forbids reading its options aloud can't be
/// undone by one engine forgetting the rule.
class SpeechPlan {
  SpeechPlan({
    required this.envelope,
    required this.question,
    this.readAloudEnabled = true,
  });

  final QuestionEnvelope envelope;
  final QuestionSpec question;

  /// The kid's Réglages "read aloud" setting. When off, nothing auto-plays,
  /// but speaker buttons still work — turning off automatic reading is not
  /// asking for silence.
  final bool readAloudEnabled;

  SpeechTrigger triggerFor(SpeechPart part) => switch (part) {
    SpeechPart.prompt => envelope.speechPolicy.prompt,
    SpeechPart.option => envelope.speechPolicy.options,
    SpeechPart.feedback => envelope.speechPolicy.feedback,
  };

  bool canSpeak(SpeechPart part) => triggerFor(part) != SpeechTrigger.never;

  bool autoPlays(SpeechPart part) =>
      readAloudEnabled && triggerFor(part) == SpeechTrigger.auto;

  /// The prompt's audio source, or null if it has none or may not be spoken.
  ///
  /// A pre-recorded asset always wins: it was rendered from the authored
  /// speech text, and it's what works offline on every platform. TTS is the
  /// fallback only when the content asks for it and there is no asset.
  AudioSource? promptSource() {
    if (!canSpeak(SpeechPart.prompt)) return null;
    final prompt = question.prompt;
    final ref = prompt.audioRef;
    if (ref != null) {
      return PrerecordedAudio(exerciseId: envelope.exerciseId, ref: ref);
    }
    final speech = prompt.speech;
    if (speech != null && speech.mode == SpeechMode.tts) {
      final text = speech.text ?? prompt.text;
      if (text != null && text.isNotEmpty) {
        return TtsUtterance(
          text: text,
          locale: speech.locale ?? envelope.locale,
        );
      }
    }
    return null;
  }
}
