import 'dart:math';

import 'package:flutter/widgets.dart';

import 'result.dart';
import 'settings.dart';
import 'telemetry.dart';

/// What an engine may ask of its host.
///
/// Everything an engine needs arrives through here, and nothing else is
/// reachable: an engine cannot see the API client, the database, the router or
/// the kid's credentials. The Godot games had that property — they held no
/// credentials and never talked to Django — and it is worth keeping. It also
/// means an engine can be widget-tested with no app at all.
class EngineContext {
  const EngineContext({
    required this.telemetry,
    required this.settings,
    required this.feedback,
    required this.onFinished,
    required this.clock,
    required this.random,
    required this.locale,
  });

  /// The only way to write events.
  final TelemetryClient telemetry;

  /// Manifest defaults plus local overrides, already resolved.
  final ResolvedSettings settings;

  /// Shared reaction helpers, so every engine feels the same on a right or
  /// wrong answer instead of each inventing its own celebration.
  final EngineFeedback feedback;

  /// Tell the host the run is over. An engine never navigates itself — the
  /// host owns what comes next, which is what lets the same engine be used in
  /// a lesson, a review or a practice screen.
  final void Function(ExerciseResult result) onFinished;

  /// Injected so tests are deterministic rather than wall-clock dependent.
  final DateTime Function() clock;

  /// Seeded per run, so a failing case can be reproduced exactly.
  final Random random;

  final Locale locale;

  bool get isFrench => locale.languageCode == 'fr';

  /// Pick the right string without every engine writing the same ternary.
  String t({required String fr, required String en}) => isFrench ? fr : en;
}

/// Reaction helpers an engine calls instead of animating ad hoc.
abstract interface class EngineFeedback {
  /// Correct answer: sound, flash, mascot reaction.
  Future<void> correct();

  /// Wrong answer. Deliberately gentle — this is a six-year-old, and a harsh
  /// buzzer teaches avoidance rather than the skill.
  Future<void> incorrect();

  /// Run finished successfully.
  Future<void> celebrate();

  /// A hint was revealed.
  Future<void> hint();
}

/// A playable exercise type.
///
/// Every engine reduces to the same core abstraction: a prompt, an answer
/// space, a correct-answer spec, and attempts. That uniformity is what lets
/// one analytics pipeline compare a math drill with a grammar exercise.
abstract class TutolysEngine {
  const TutolysEngine();

  /// Stable identifier, matching the backend's engine registry. Changing it
  /// orphans every exercise tagged to this engine.
  String get key;

  /// Bumped when this engine's content schema changes in a breaking way. The
  /// backend's `engine_min_version` is checked against it before an exercise
  /// is handed over.
  int get version;

  /// Grouping for the settings UI and the content tooling (math, language…).
  String get category;

  /// Settings this engine exposes, on top of [commonSettings].
  SettingsManifest get settingsManifest;

  /// Whether this engine can render the given content.
  ///
  /// Called before [build]. Returning a reason rather than throwing lets the
  /// host show a friendly "this activity needs an update" state instead of a
  /// crash — the kid did nothing wrong.
  EngineValidation validate(Map<String, Object?> config);

  /// Build the playable widget.
  Widget build(EngineContext context, Map<String, Object?> config);
}

/// Outcome of [TutolysEngine.validate].
class EngineValidation {
  const EngineValidation.valid()
      : isValid = true,
        reason = null;

  const EngineValidation.invalid(this.reason) : isValid = false;

  final bool isValid;
  final String? reason;
}
