import 'package:uuid/uuid.dart';

import '../contracts/evaluation.dart';
import 'runtime_event.dart';
import 'session_ids.dart';
import 'v1_event_recorder.dart';

/// Records against `play_event.v2` (telemetry ADR 0013): everything v1
/// records, exactly as v1 records it, plus what v1 had nowhere to put.
///
/// **Built on [V1EventRecorder], never beside it.** Every event v1 writes
/// is written here with the same `event_id` and the same v1 fields, then
/// gains v2's: so `attempt` and `exercise_complete` mean what they meant,
/// every aggregate, mastery, XP and streak reads v2 rows unchanged, and an
/// app upgraded mid-session can never write one attempt twice under two
/// ids.
///
/// What v2 adds:
///
/// - on **every** event: `event_category`, `activity_session_id`,
///   `session_run_id`, `sequence`, `active_elapsed_ms`, `content_hash`, and
///   `question_instance_id` while a question is open;
/// - on an `attempt`: `evaluation` — outcome, partial-credit score,
///   evaluator, `errors` as `{code, taxonomy_version}`, per-part `items`;
/// - on `attempt` and `exercise_complete`: `assistance` — hints and audio
///   replays so far in this question. A first `audio_requested` is not
///   assistance; a replay is (telemetry's evidence read).
/// - events v1 dropped: `question_presented`, `session_paused` /
///   `session_resumed`, and every interaction (`option_selected`,
///   `item_placed`, `audio_replayed`…) with an ids-only `payload`.
///
/// `sequence` counts per activity session across questions and resumes;
/// it rides in [state], which the controller commits in the same
/// transaction as the events (ADR 0019), so a resume never repeats or
/// skips one. `session_run_id` is new per recorder, i.e. per mount.
///
/// An event type telemetry v2 doesn't know is not sent — it would only come
/// back `rejected` and sit stuck in the outbox — and is counted in
/// [unrecordedCount] instead, so a new engine vocabulary is noticed.
class V2EventRecorder implements RuntimeEventRecorder {
  V2EventRecorder({
    required this.ids,
    required this.appVersion,
    String? sessionRunId,
  }) : sessionRunId = sessionRunId ?? const Uuid().v4(),
       _v1 = V1EventRecorder(ids: ids, appVersion: appVersion);

  final SessionIds ids;
  final String appVersion;

  /// One per mount of the activity.
  final String sessionRunId;

  final V1EventRecorder _v1;

  static const _uuid = Uuid();
  static const schemaVersion = 2;

  /// The interaction and pause types `play_event.v2.json` accepts.
  static const knownTypes = {
    'question_presented',
    'option_selected',
    'option_deselected',
    'pair_connected',
    'pair_disconnected',
    'tile_placed',
    'tile_removed',
    'tile_moved',
    'item_placed',
    'item_removed',
    'time_expired',
    'audio_requested',
    'audio_replayed',
    'session_paused',
    'session_resumed',
  };

  /// Payload keys the schema refuses: display text, pointer data, audio.
  static const _forbiddenKeys = {
    'label',
    'text',
    'stem',
    'prompt',
    'value',
    'answer',
    'transcript',
    'x',
    'y',
    'dx',
    'dy',
    'keystroke',
    'audio',
  };
  static final _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  int _sequence = 0;
  int? _questionIndex;
  int _hints = 0;
  int _audioReplays = 0;
  int _unrecorded = 0;

  @override
  int get unrecordedCount => _unrecorded;

  @override
  List<Map<String, Object?>> record(RuntimeEvent event, RecorderFrame f) {
    switch (event) {
      case QuestionPresented(:final questionIndex):
        _questionIndex = questionIndex;
        _hints = 0;
        _audioReplays = 0;
      case HintRequested():
        if (_questionIndex != null) _hints += 1;
      case AudioRequested(:final replay):
        if (replay && _questionIndex != null) _audioReplays += 1;
      case _:
    }

    final v1 = _v1.record(event, f);
    final out = <Map<String, Object?>>[
      for (final e in v1) _upgrade(e, event, f),
    ];

    final ownType = v1.isEmpty || event is QuestionPresented;
    if (ownType && event is! AnswerSubmitted && event.category.isDurable) {
      if (knownTypes.contains(event.type)) {
        out.add(_v2Only(event, f));
      } else {
        _unrecorded++;
      }
    }

    switch (event) {
      case QuestionCompleted() || ActivityAbandoned():
        _questionIndex = null;
      case _:
    }
    return out;
  }

  Map<String, Object?> _common(RecorderFrame f, EventCategory category) => {
    'schema_version': schemaVersion,
    'event_category': category.wire,
    'activity_session_id': ids.activitySessionId,
    'session_run_id': sessionRunId,
    'question_instance_id': _questionIndex == null
        ? null
        : ids.questionInstanceId(_questionIndex!),
    'sequence': _sequence++,
    'active_elapsed_ms': f.activeMs,
    'content_hash': f.contentHash,
  };

  Map<String, Object?> _assistance() => {
    'hints': _hints,
    'audio_replays': _audioReplays,
  };

  /// A v1 event, with v2's fields added. Its id and v1 fields are kept.
  Map<String, Object?> _upgrade(
    Map<String, Object?> v1,
    RuntimeEvent cause,
    RecorderFrame f,
  ) {
    final type = v1['event_type'];
    // Session-level v1 events carry no question.
    final sessionLevel = type == 'session_start' || type == 'session_end';
    final question = _questionIndex;
    if (sessionLevel) _questionIndex = null;
    final e = <String, Object?>{
      ...v1,
      ..._common(f, cause.category),
      'payload': null,
      'evaluation': null,
      'assistance': null,
    };
    _questionIndex = question;
    // A stale-resume abandon doesn't know the engine version (0); v2's
    // minimum is 1, so say "unknown" rather than send an invalid event.
    if (e['engine_version'] == 0) e['engine_version'] = null;
    if (type == 'attempt' && cause is AnswerEvaluated) {
      e['evaluation'] = _evaluation(cause.result);
      e['assistance'] = _assistance();
    } else if (type == 'exercise_complete') {
      e['assistance'] = _assistance();
    }
    return e;
  }

  static Map<String, Object?> _evaluation(EvaluationResult r) => {
    'outcome': r.outcome.wire,
    'score': r.score.clamp(0, 1),
    'evaluator': r.evaluator,
    'authority': r.authority.name,
    'errors': [
      for (final e in r.errors.take(16))
        {'code': e.code, 'taxonomy_version': e.taxonomyVersion},
    ],
    if (r.itemResults.isNotEmpty)
      'items': Map.fromEntries(r.itemResults.entries.take(64)),
  };

  /// An event v1 had no type for.
  Map<String, Object?> _v2Only(RuntimeEvent event, RecorderFrame f) {
    final run = _questionIndex == null
        ? null
        : ids.exerciseRunId(_questionIndex!);
    final identity = run == null ? null : f.identity;
    final common = _common(f, event.category);
    return {
      ...common,
      'event_id': _uuid.v5(ids.activitySessionId, 'v2:${common['sequence']}'),
      'event_ts': f.now.toUtc().toIso8601String(),
      'session_id': ids.activitySessionId,
      'event_type': event.type,
      'app_version': appVersion,
      'exercise_run_id': run,
      'exercise_id': identity?.exerciseId,
      'exercise_version': identity?.exerciseVersion,
      'engine_key': identity?.engineKey,
      'engine_version': identity == null || identity.engineVersion < 1
          ? null
          : identity.engineVersion,
      'skill_node_id': identity?.skillNodeId,
      'subject': identity?.subject,
      'grade': identity?.grade,
      'rank': identity?.rank,
      'payload': _payload(event.payload),
      'evaluation': null,
      'assistance': null,
      'answer_payload': null,
      'is_correct': null,
    };
  }

  /// Ids and indexes only, flat, at most 8 keys — what the schema accepts.
  /// Anything else is dropped here rather than sent to be rejected.
  static Map<String, Object?>? _payload(Map<String, Object?> raw) {
    final out = <String, Object?>{};
    for (final e in raw.entries) {
      if (out.length == 8) break;
      if (_forbiddenKeys.contains(e.key) || !_keyPattern.hasMatch(e.key)) {
        continue;
      }
      final v = e.value;
      if (v == null || v is bool || v is int) {
        out[e.key] = v;
      } else if (v is String) {
        out[e.key] = v.length > 64 ? v.substring(0, 64) : v;
      }
    }
    return out.isEmpty ? null : out;
  }

  @override
  Map<String, Object?> get state => {
    'v1': _v1.state,
    'sequence': _sequence,
    'question_index': _questionIndex,
    'hints': _hints,
    'audio_replays': _audioReplays,
  };

  @override
  void restore(Map<String, Object?>? s) {
    if (s == null) return;
    // A snapshot written by the v1 recorder: its tallies are the v1 part.
    if (!s.containsKey('v1')) {
      _v1.restore(s);
      _questionIndex = s['question_index'] as int?;
      return;
    }
    _v1.restore((s['v1'] as Map?)?.cast<String, Object?>());
    _sequence = s['sequence'] as int? ?? 0;
    _questionIndex = s['question_index'] as int?;
    _hints = s['hints'] as int? ?? 0;
    _audioReplays = s['audio_replays'] as int? ?? 0;
  }
}
