/// The engine contract.
///
/// An engine depends on this package and the design system only — never on the
/// app, the API client or the database. That keeps engines widget-testable in
/// isolation and keeps credentials out of game code.
library;

export 'src/audio.dart';
export 'src/audio/audio_contracts.dart';
export 'src/audio/channel_audio_coordinator.dart';
export 'src/audio/web_audio_player.dart';
export 'src/audio/output_keep_alive.dart';
export 'src/audio/audio_debug.dart';
export 'src/audio/keep_alive_config.dart';
export 'src/contracts/answer.dart';
export 'src/contracts/envelope.dart';
export 'src/contracts/evaluation.dart';
export 'src/contracts/learning_engine.dart';
export 'src/contracts/learning_engine_registry.dart';
export 'src/contracts/parse_result.dart';
export 'src/engine.dart';
export 'src/exercise_runner.dart';
export 'src/images.dart';
export 'src/outbox.dart';
export 'src/registry.dart';
export 'src/result.dart';
export 'src/runtime/active_clock.dart';
export 'src/runtime/legacy_feedback_bridge.dart';
export 'src/runtime/activity_session_controller.dart';
export 'src/runtime/activity_session_machine.dart';
export 'src/runtime/runtime_event.dart';
export 'src/runtime/session_ids.dart';
export 'src/runtime/v1_event_recorder.dart';
export 'src/runtime/v2_event_recorder.dart';
export 'src/runtime/activity_session_store.dart';
export 'src/settings.dart';
export 'src/telemetry.dart';
