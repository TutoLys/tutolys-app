import 'dart:math';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// Records every reaction call, so a test can assert *what* happened without
/// caring how it is presented — the same split [EngineContext] makes an
/// engine itself keep.
class RecordingFeedback implements EngineFeedback {
  final calls = <String>[];

  @override
  Future<void> correct() async => calls.add('correct');

  @override
  Future<void> incorrect() async => calls.add('incorrect');

  @override
  Future<void> celebrate() async => calls.add('celebrate');

  @override
  Future<void> hint() async => calls.add('hint');
}

const testIdentity = ExerciseIdentity(
  exerciseId: '00000000-0000-4000-8000-000000000001',
  exerciseVersion: 1,
  engineKey: 'mcq',
  engineVersion: 1,
  skillNodeId: '11111111-1111-4111-8111-111111111111',
  subject: 'MATH',
  grade: 1,
  rank: 0,
);

/// Everything an engine test needs: a telemetry client already mid-run (as
/// [ExerciseRunner] would leave it before calling `build`), a recorder for
/// its own events, and a ready-to-use [EngineContext].
class EngineHarness {
  EngineHarness._(this.outbox, this.telemetry, this.feedback);

  final InMemoryEventOutbox outbox;
  final TelemetryClient telemetry;
  final RecordingFeedback feedback;

  final finished = <ExerciseResult>[];

  static Future<EngineHarness> start({
    SettingsManifest manifest = const SettingsManifest(
      engineKey: 'test',
      definitions: [],
    ),
    Map<String, Object?> settingsOverrides = const {},
  }) async {
    final outbox = InMemoryEventOutbox();
    var tick = DateTime.utc(2026, 10, 17, 9);
    final telemetry = TelemetryClient(
      outbox: outbox,
      sessionId: 'b3968383-3c5f-4184-9642-2001de990e6f',
      appVersion: '0.1.0',
      clock: () => tick = tick.add(const Duration(milliseconds: 300)),
    );
    await telemetry.startExercise(testIdentity);

    return EngineHarness._(outbox, telemetry, RecordingFeedback());
  }

  /// A deterministic context — fixed seed, so option/tile shuffling is
  /// reproducible across test runs.
  EngineContext context({
    SettingsManifest manifest = const SettingsManifest(
      engineKey: 'test',
      definitions: [],
    ),
    Map<String, Object?> settingsOverrides = const {},
    int seed = 1,
  }) {
    return EngineContext(
      telemetry: telemetry,
      settings: ResolvedSettings(
        manifest: SettingsManifest(
          engineKey: manifest.engineKey,
          definitions: [...commonSettings, ...manifest.definitions],
        ),
        overrides: settingsOverrides,
      ),
      feedback: feedback,
      clock: DateTime.now,
      random: Random(seed),
      locale: const Locale('fr', 'CA'),
      onFinished: finished.add,
    );
  }

  List<Map<String, Object?>> get attempts =>
      outbox.all.where((e) => e['event_type'] == 'attempt').toList();

  List<Map<String, Object?>> get hints =>
      outbox.all.where((e) => e['event_type'] == 'hint_used').toList();

  bool get completedTelemetry =>
      outbox.all.any((e) => e['event_type'] == 'exercise_complete');
}
