import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local_db/database.dart';
import '../../data/local_db/home_stats.dart';
import '../../data/local_db/streak_local.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../pairing/pairing_controller.dart';
import 'engine_registry_provider.dart';
import 'mascot_feedback.dart';

/// Hosts one exercise, reached by tapping an available node on the path.
///
/// The one place `TutolysEngine`/`EngineRegistry`/`EngineFeedback`/
/// `TelemetryClient` all actually come together in the running app — every
/// other app code before A7 only ever constructed test doubles for these
/// (see `a7-skill-path-plan.md`'s own gap #4).
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({required this.node, required this.envelope, super.key});

  final CachedSkillNode node;
  final Map<String, Object?> envelope;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final MascotEngineFeedback _feedback = MascotEngineFeedback();
  late final TelemetryClient _telemetry;

  @override
  void initState() {
    super.initState();
    _telemetry = TelemetryClient(
      outbox: ref.read(eventOutboxProvider),
      // One session id per visit to this screen, not one per app launch —
      // there is no app-session lifecycle wired anywhere yet (a gap beyond
      // A7's own scope: nothing calls `logSessionStart`/`logSessionEnd`
      // outside this one screen today). Flagged, not silently assumed
      // correct.
      sessionId: const Uuid().v4(),
      appVersion: appVersion,
    );
    _telemetry.logSessionStart();
  }

  @override
  void dispose() {
    _telemetry.logSessionEnd();
    _feedback.dispose();
    super.dispose();
  }

  void _handleFinished(ExerciseResult result) {
    // Home's stat tiles are real counts, never a mastery judgment — an
    // abandoned run taught nothing worth counting as "played today".
    if (result.outcome == ExerciseOutcome.completed) {
      final db = ref.read(localDatabaseProvider);
      HomeStats(db).recordExerciseCompleted(elapsedMs: result.elapsedMs);
      StreakLocal(db).recordPlayedToday();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(engineRegistryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.node.labelFr)),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<MascotMood>(
              valueListenable: _feedback.mood,
              builder: (context, mood, _) => Padding(
                padding: const EdgeInsets.all(Space.md),
                child: TutolysMascot(mood: mood, size: 96),
              ),
            ),
            Expanded(
              child: ExerciseRunner(
                envelope: widget.envelope,
                registry: registry,
                telemetry: _telemetry,
                feedback: _feedback,
                locale: Localizations.localeOf(context),
                onFinished: _handleFinished,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
