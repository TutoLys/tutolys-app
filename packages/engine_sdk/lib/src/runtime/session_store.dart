import 'activity_session_machine.dart';

/// Everything needed to resume an activity exactly where it stopped.
class SessionSnapshot {
  const SessionSnapshot({
    required this.activitySessionId,
    required this.kidId,
    required this.exerciseId,
    required this.exerciseVersion,
    required this.contentHash,
    required this.seed,
    required this.state,
    required this.activeMs,
    required this.updatedAt,
    this.engineState,
  });

  final String activitySessionId;
  final String kidId;
  final String exerciseId;
  final int exerciseVersion;

  /// The content the session was played against. A snapshot whose hash no
  /// longer matches the cached exercise is abandoned, never replayed against
  /// new content — the stored engine state would describe options that may
  /// no longer exist.
  final String? contentHash;
  final int seed;
  final SessionState state;

  /// The current question's engine state, from `LearningEngine.snapshot`.
  /// Null between questions, and for legacy engines, which can't snapshot.
  final Map<String, Object?>? engineState;
  final int activeMs;
  final DateTime updatedAt;

  /// Whether this snapshot may resume against the exercise now cached.
  bool matches({required int exerciseVersion, required String? contentHash}) =>
      exerciseVersion == this.exerciseVersion && contentHash == this.contentHash;

  Map<String, Object?> toJson() => {
    'activity_session_id': activitySessionId,
    'kid_id': kidId,
    'exercise_id': exerciseId,
    'exercise_version': exerciseVersion,
    'content_hash': contentHash,
    'seed': seed,
    'state': state.toJson(),
    'engine_state': engineState,
    'active_ms': activeMs,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static SessionSnapshot? fromJson(Map<String, Object?> json) {
    try {
      final state = SessionState.fromJson(
        (json['state'] as Map).cast<String, Object?>(),
      );
      if (state == null) return null;
      return SessionSnapshot(
        activitySessionId: json['activity_session_id'] as String,
        kidId: json['kid_id'] as String,
        exerciseId: json['exercise_id'] as String,
        exerciseVersion: json['exercise_version'] as int,
        contentHash: json['content_hash'] as String?,
        seed: json['seed'] as int,
        state: state,
        engineState: (json['engine_state'] as Map?)?.cast<String, Object?>(),
        activeMs: json['active_ms'] as int,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    } on Object {
      return null;
    }
  }
}

/// Durable home for in-progress sessions, one live session per kid and
/// exercise. Implemented on drift in the app (Phase 2); engines never see it.
abstract interface class SessionStore {
  /// Upsert. Called after every durable step, after the step's events are in
  /// the outbox — so a snapshot never claims progress the event log lacks.
  Future<void> save(SessionSnapshot snapshot);

  /// The live (non-terminal) session for this kid and exercise, if any.
  Future<SessionSnapshot?> live({required String kidId, required String exerciseId});

  /// Every live session for a kid — read at launch to apply `Interrupt`.
  Future<List<SessionSnapshot>> allLive(String kidId);

  /// Drop a session once it is terminal and its events are queued.
  Future<void> remove(String activitySessionId);
}

class InMemorySessionStore implements SessionStore {
  final Map<String, SessionSnapshot> _byId = {};

  @override
  Future<void> save(SessionSnapshot snapshot) async {
    // Round-trip through JSON so tests exercise the same path drift will.
    _byId[snapshot.activitySessionId] = SessionSnapshot.fromJson(snapshot.toJson())!;
  }

  @override
  Future<SessionSnapshot?> live({required String kidId, required String exerciseId}) async {
    for (final s in _byId.values) {
      if (s.kidId == kidId && s.exerciseId == exerciseId && !s.state.phase.isTerminal) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<SessionSnapshot>> allLive(String kidId) async => [
    for (final s in _byId.values)
      if (s.kidId == kidId && !s.state.phase.isTerminal) s,
  ];

  @override
  Future<void> remove(String activitySessionId) async {
    _byId.remove(activitySessionId);
  }
}
