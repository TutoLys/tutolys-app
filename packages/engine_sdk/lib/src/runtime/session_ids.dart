import 'package:uuid/uuid.dart';

/// Deterministic ids for an activity session.
///
/// Derived, not random, so a resumed session re-derives exactly the ids it
/// had before the crash. That is the whole duplicate-submission defence: if
/// the app dies between writing an attempt to the outbox and writing the
/// session snapshot, the resumed run produces the *same* `event_id` for that
/// attempt, the outbox's primary key drops it locally, and telemetry's
/// `ON CONFLICT (event_id, …)` covers anything that already left the device.
class SessionIds {
  SessionIds(this.activitySessionId) {
    if (!Uuid.isValidUUID(fromString: activitySessionId)) {
      throw ArgumentError.value(
        activitySessionId,
        'activitySessionId',
        'must be a UUID',
      );
    }
  }

  /// Fresh logical session. One per exercise played; survives resume.
  factory SessionIds.create() => SessionIds(_uuid.v4());

  static const _uuid = Uuid();

  final String activitySessionId;

  String questionInstanceId(int questionIndex) =>
      _uuid.v5(activitySessionId, 'question:$questionIndex');

  /// The `event_id` of the persisted verdict for one attempt.
  String attemptEventId(int questionIndex, int attemptNumber) =>
      _uuid.v5(questionInstanceId(questionIndex), 'attempt:$attemptNumber');

  /// The `exercise_run_id` for one question. Mastery and XP key off it (one
  /// `XPAward` per run), so it must be stable across a resume or a resumed
  /// question would be paid twice.
  String exerciseRunId(int questionIndex) =>
      _uuid.v5(questionInstanceId(questionIndex), 'run');
}
