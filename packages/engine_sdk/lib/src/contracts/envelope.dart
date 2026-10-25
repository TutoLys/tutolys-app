/// The typed view of an exercise envelope from `GET /content/exercises`.
///
/// Parsing is **tolerant of unknown keys, strict on known ones**. The backend
/// schemas are `additionalProperties: false`, so the server never ships junk;
/// but an older app must keep playing a newer envelope that gained optional
/// fields (architecture doc G10). So a field this version has never heard of
/// is ignored, and a field it knows with the wrong type is an invalid
/// envelope.
///
/// Envelope schema v1 is everything published today. v2 adds only optional
/// fields — `prompt.speech`, `speech_policy`, `evaluation`,
/// `min_app_version`, `secondary_skill_node_ids`, a per-question
/// `engine_key` — each with a default that reproduces v1 behaviour exactly.
library;

import 'parse_result.dart';

/// Envelope schema versions this build understands.
const supportedEnvelopeSchemaVersions = {1, 2};

enum SpeechMode {
  /// A pre-generated asset (Piper, today). The only mode with an
  /// implementation.
  prerecorded,

  /// Synthesised on device. Interface only (doc §10 D2): a `TtsEngine`
  /// adapter may appear later; until then a `tts` request falls back to
  /// the asset if one exists, or to no audio.
  tts,
}

/// When a part of a question may be read aloud.
enum SpeechTrigger {
  /// Read when the question appears.
  auto,

  /// Readable through its speaker button only.
  onRequest,

  /// Never read — e.g. the options of a reading-comprehension question,
  /// where reading them aloud gives the answer away.
  never;

  static SpeechTrigger? parse(Object? v) => switch (v) {
    'auto' => auto,
    'on_request' => onRequest,
    'never' => never,
    _ => null,
  };
}

/// How a piece of text should *sound*, which may differ from how it reads:
/// "7 + 5" is spoken "sept plus cinq".
class SpeechSpec {
  const SpeechSpec({this.text, this.locale, this.mode = SpeechMode.prerecorded});

  final String? text;
  final String? locale;
  final SpeechMode mode;
}

class SpeechPolicy {
  const SpeechPolicy({
    this.prompt = SpeechTrigger.auto,
    this.options = SpeechTrigger.onRequest,
    this.feedback = SpeechTrigger.onRequest,
  });

  /// v1 behaviour: the runner auto-plays the prompt's audio (ADR 0013).
  static const v1Default = SpeechPolicy();

  final SpeechTrigger prompt;
  final SpeechTrigger options;
  final SpeechTrigger feedback;
}

class PromptSpec {
  const PromptSpec({this.text, this.audioRef, this.imageRef, this.speech});

  static const empty = PromptSpec();

  final String? text;
  final String? audioRef;
  final String? imageRef;
  final SpeechSpec? speech;
}

class EvaluationPolicy {
  const EvaluationPolicy({this.policy = 'exact', this.version = 1, this.maxAttempts});

  static const v1Default = EvaluationPolicy();

  final String policy;
  final int version;

  /// Null = retry until correct, today's contract for every engine. A
  /// number caps attempts per question; after the last one the question is
  /// completed unsolved and the activity moves on.
  final int? maxAttempts;
}

/// One question inside an exercise. A v1 exercise without
/// `config.questions` is exactly one implicit question.
class QuestionSpec {
  const QuestionSpec({
    required this.index,
    required this.engineKey,
    required this.prompt,
    required this.config,
  });

  final int index;

  /// The exercise's engine unless the question overrides it (doc §10 D4).
  final String engineKey;
  final PromptSpec prompt;
  final Map<String, Object?> config;
}

class QuestionEnvelope {
  const QuestionEnvelope({
    required this.schemaVersion,
    required this.exerciseId,
    required this.version,
    required this.engineKey,
    required this.engineMinVersion,
    required this.skillNodeId,
    required this.subject,
    required this.grade,
    required this.rank,
    required this.locale,
    required this.questions,
    this.contentHash,
    this.minAppVersion,
    this.secondarySkillNodeIds = const [],
    this.speechPolicy = SpeechPolicy.v1Default,
    this.evaluation = EvaluationPolicy.v1Default,
    this.raw = const {},
  });

  final int schemaVersion;
  final String exerciseId;
  final int version;
  final String? contentHash;
  final String engineKey;
  final int engineMinVersion;
  final String? minAppVersion;
  final String skillNodeId;
  final List<String> secondarySkillNodeIds;
  final String subject;
  final int grade;
  final int rank;
  final String locale;
  final SpeechPolicy speechPolicy;
  final EvaluationPolicy evaluation;
  final List<QuestionSpec> questions;

  /// The envelope exactly as received, for the legacy runner path.
  final Map<String, Object?> raw;

  /// Primary skill first, then any secondary ones.
  List<String> get skillNodeIds => [skillNodeId, ...secondarySkillNodeIds];

  static ParseResult<QuestionEnvelope> parse(Map<String, Object?> json) {
    final r = _Reader(json);
    final schemaVersion = r.optInt('schema_version') ?? 1;
    if (!supportedEnvelopeSchemaVersions.contains(schemaVersion)) {
      return ParseResult.unsupported(
        'Envelope schema v$schemaVersion is newer than this app supports.',
      );
    }

    final exerciseId = r.reqString('exercise_id');
    final version = r.reqInt('version');
    final engineKey = r.reqString('engine_key');
    final skillNodeId = r.reqString('skill_node_id');
    final subject = r.reqString('subject');
    final grade = r.reqInt('grade');
    final rank = r.reqInt('rank');
    final config = r.optMap('config') ?? const <String, Object?>{};
    final prompt = _parsePrompt(r, r.optMap('prompt'), 'prompt');

    final questions = <QuestionSpec>[];
    final rawQuestions = config['questions'];
    if (rawQuestions is List && rawQuestions.isNotEmpty) {
      for (var i = 0; i < rawQuestions.length; i++) {
        final q = rawQuestions[i];
        if (q is! Map) {
          r.errors.add('config.questions[$i] must be an object');
          continue;
        }
        final qr = _Reader(q.cast<String, Object?>(), r.errors, 'config.questions[$i].');
        questions.add(
          QuestionSpec(
            index: i,
            engineKey: qr.optString('engine_key') ?? engineKey ?? '',
            prompt: _parsePrompt(qr, qr.optMap('prompt'), 'prompt'),
            config: qr.optMap('config') ?? const <String, Object?>{},
          ),
        );
      }
    } else if (rawQuestions != null && rawQuestions is! List) {
      r.errors.add('config.questions must be a list');
    } else {
      questions.add(
        QuestionSpec(
          index: 0,
          engineKey: engineKey ?? '',
          prompt: prompt,
          config: config,
        ),
      );
    }

    final policyMap = r.optMap('speech_policy');
    SpeechPolicy speechPolicy = SpeechPolicy.v1Default;
    if (policyMap != null) {
      SpeechTrigger trigger(String key, SpeechTrigger fallback) {
        final v = policyMap[key];
        if (v == null) return fallback;
        final parsed = SpeechTrigger.parse(v);
        if (parsed == null) r.errors.add('speech_policy.$key is not a known trigger');
        return parsed ?? fallback;
      }

      speechPolicy = SpeechPolicy(
        prompt: trigger('prompt', SpeechTrigger.auto),
        options: trigger('options', SpeechTrigger.onRequest),
        feedback: trigger('feedback', SpeechTrigger.onRequest),
      );
    }

    final evalMap = r.optMap('evaluation');
    EvaluationPolicy evaluation = EvaluationPolicy.v1Default;
    if (evalMap != null) {
      final er = _Reader(evalMap, r.errors, 'evaluation.');
      final maxAttempts = er.optInt('max_attempts');
      if (maxAttempts != null && maxAttempts < 1) {
        r.errors.add('evaluation.max_attempts must be ≥ 1');
      }
      evaluation = EvaluationPolicy(
        policy: er.optString('policy') ?? 'exact',
        version: er.optInt('version') ?? 1,
        maxAttempts: maxAttempts,
      );
    }

    final secondary = r.optStringList('secondary_skill_node_ids') ?? const [];
    final minAppVersion = r.optString('min_app_version');
    if (minAppVersion != null && AppVersion.tryParse(minAppVersion) == null) {
      r.errors.add('min_app_version is not a version string');
    }

    if (r.errors.isNotEmpty) return ParseResult.invalid(r.errors.join('; '));

    return ParseResult.ok(
      QuestionEnvelope(
        schemaVersion: schemaVersion,
        exerciseId: exerciseId!,
        version: version!,
        contentHash: r.optString('content_hash'),
        engineKey: engineKey!,
        engineMinVersion: r.optInt('engine_min_version') ?? 1,
        minAppVersion: minAppVersion,
        skillNodeId: skillNodeId!,
        secondarySkillNodeIds: secondary,
        subject: subject!,
        grade: grade!,
        rank: rank!,
        locale: r.optString('locale') ?? 'fr-CA',
        speechPolicy: speechPolicy,
        evaluation: evaluation,
        questions: List.unmodifiable(questions),
        raw: json,
      ),
    );
  }

  static PromptSpec _parsePrompt(_Reader parent, Map<String, Object?>? m, String path) {
    if (m == null) return PromptSpec.empty;
    final r = _Reader(m, parent.errors, '${parent.prefix}$path.');
    final speechMap = r.optMap('speech');
    SpeechSpec? speech;
    if (speechMap != null) {
      final sr = _Reader(speechMap, parent.errors, '${r.prefix}speech.');
      final mode = switch (speechMap['mode']) {
        null || 'prerecorded' => SpeechMode.prerecorded,
        'tts' => SpeechMode.tts,
        _ => null,
      };
      if (mode == null) parent.errors.add('${r.prefix}speech.mode is not a known mode');
      speech = SpeechSpec(
        text: sr.optString('text'),
        locale: sr.optString('locale'),
        mode: mode ?? SpeechMode.prerecorded,
      );
    }
    return PromptSpec(
      text: r.optString('text'),
      audioRef: r.optString('audio_ref'),
      imageRef: r.optString('image_ref'),
      speech: speech,
    );
  }
}

/// A dotted version string, compared numerically: `1.10.0` > `1.9.3`.
/// Build metadata after `+` and pre-release tags after `-` are ignored —
/// the floor is about which features exist, not which build.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  static AppVersion? tryParse(String s) {
    final core = s.split('+').first.split('-').first.trim();
    if (core.isEmpty) return null;
    final parts = <int>[];
    for (final p in core.split('.')) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      parts.add(n);
    }
    return AppVersion(List.unmodifiable(parts));
  }

  @override
  int compareTo(AppVersion other) {
    final n = parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < n; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => parts.join('.');
}

class _Reader {
  _Reader(this.json, [List<String>? errors, this.prefix = ''])
    : errors = errors ?? <String>[];

  final Map<String, Object?> json;
  final List<String> errors;
  final String prefix;

  T? _opt<T>(String key, String type) {
    final v = json[key];
    if (v == null) return null;
    if (v is T) return v as T;
    errors.add('$prefix$key must be $type');
    return null;
  }

  T? _req<T>(String key, String type) {
    if (json[key] == null) {
      errors.add('$prefix$key is required');
      return null;
    }
    return _opt<T>(key, type);
  }

  String? optString(String key) => _opt<String>(key, 'a string');
  String? reqString(String key) => _req<String>(key, 'a string');
  int? optInt(String key) => _opt<int>(key, 'an integer');
  int? reqInt(String key) => _req<int>(key, 'an integer');

  Map<String, Object?>? optMap(String key) =>
      _opt<Map>(key, 'an object')?.cast<String, Object?>();

  List<String>? optStringList(String key) {
    final list = _opt<List>(key, 'a list');
    if (list == null) return null;
    if (list.any((e) => e is! String)) {
      errors.add('$prefix$key must be a list of strings');
      return null;
    }
    return List.unmodifiable(list.cast<String>());
  }
}
