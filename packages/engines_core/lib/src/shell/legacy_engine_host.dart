import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';

import 'activity_shell.dart';

/// Runs a `TutolysEngine` exercise inside the shared shell.
///
/// The bridge between the two contracts until every engine is ported: the
/// shell supplies the frame (close, character), the existing
/// [ExerciseRunner] still owns the prompt, the engine and its telemetry,
/// exactly as before — so no content, event or score changes by moving
/// here. What a legacy exercise can't have, it doesn't show: no progress
/// track (the runner doesn't report its question index), no VALIDER (these
/// engines resolve on tap), no shell hint (each engine draws its own), and
/// no pause (`speed_tap`'s countdown can't be paused from outside).
class LegacyEngineHost extends StatelessWidget {
  const LegacyEngineHost({
    required this.envelope,
    required this.registry,
    required this.telemetry,
    required this.feedback,
    required this.locale,
    required this.onFinished,
    required this.onClose,
    this.audio,
    this.character,
    this.settingsOverrides = const {},
    super.key,
  });

  final Map<String, Object?> envelope;
  final EngineRegistry registry;
  final TelemetryClient telemetry;

  /// Usually a [LegacyFeedbackBridge], so characters react.
  final EngineFeedback feedback;
  final Locale locale;
  final void Function(ExerciseResult result) onFinished;

  /// Leaving: the host pops, and the runner logs the abandon on dispose.
  final VoidCallback onClose;
  final AudioResolver? audio;
  final Widget? character;
  final Map<String, Object?> settingsOverrides;

  @override
  Widget build(BuildContext context) => ActivityShell(
    locale: locale,
    onClose: onClose,
    character: character,
    scrollBody: false,
    body: ExerciseRunner(
      envelope: envelope,
      registry: registry,
      telemetry: telemetry,
      feedback: feedback,
      audio: audio ?? InMemoryAudioResolver(),
      locale: locale,
      settingsOverrides: settingsOverrides,
      onFinished: onFinished,
    ),
  );
}
