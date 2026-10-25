import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/breathing_mascot.dart';
import '../../data/local_db/database.dart';
import '../../data/local_db/drift_activity_session_store.dart';
import '../../data/local_db/home_stats.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../data/local_db/streak_local.dart';
import '../../data/sync/drift_audio_resolver.dart';
import '../../data/sync/drift_image_resolver.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../pairing/pairing_controller.dart';
import '../settings/settings_controller.dart';
import 'engine_registry_provider.dart';
import 'learning_platform_providers.dart';
import 'xp_estimate.dart';

/// Hosts one exercise, reached by tapping an available node on the path.
///
/// The composition root of the learning engine platform (architecture doc
/// §4.1): the shared shell, the animation director and its cast, the audio
/// coordinator and the durable session store all meet here, and nowhere
/// else. Engines see none of it.
///
/// Two paths, picked per exercise:
///
/// - **runtime** — every question's engine is on the new `LearningEngine`
///   contract: an [ActivitySessionController] drives it, with resume after
///   a crash and the shell's VALIDER / feedback banner.
/// - **legacy** — anything else (all content, in Phase 2): the existing
///   `ExerciseRunner` inside the shell via [LegacyEngineHost], with its own
///   telemetry unchanged and its reactions bridged to the director.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({required this.node, required this.envelope, super.key});

  final CachedSkillNode node;
  final Map<String, Object?> envelope;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  late final AnimationDirector _director;
  late final AppLifecycleListener _lifecycle;

  /// Captured once: `ref` is unusable in [dispose], which still needs it.
  late final AudioCoordinator _audio = ref.read(audioCoordinatorProvider);

  /// Pictures for `image_ref`s, put above the engine (ADR 0027).
  late final ImageResolver _images = DriftImageResolver(
    ref.read(localDatabaseProvider),
  );

  /// Every question in the exercise shares its envelope's `assets[]`.
  String get _exerciseId => widget.envelope['exercise_id'] as String;

  // Runtime path.
  ActivitySessionController? _controller;
  StreamSubscription<RuntimeEvent>? _autoRead;
  final List<ExerciseResult> _questionResults = [];

  /// Set when the exercise is completed: the celebration replaces the
  /// exercise until the child presses Continuer.
  ActivitySummary? _summary;

  // Legacy path.
  TelemetryClient? _telemetry;
  LegacyFeedbackBridge? _bridge;
  DriftAudioResolver? _legacyAudio;

  String get _kidId => ref.read(activeKidIdProvider) ?? unpairedKidId;

  @override
  void initState() {
    super.initState();
    final parsed = QuestionEnvelope.parse(widget.envelope).valueOrNull;
    final learning = ref.read(learningEngineRegistryProvider);

    final Stream<RuntimeEvent> events;
    if (parsed != null && learning.servesAll(parsed)) {
      final controller = ActivitySessionController(
        envelope: parsed,
        kidId: _kidId,
        engines: learning,
        evaluators: ref.read(evaluatorRegistryProvider),
        store: DriftActivitySessionStore(
          ref.read(localDatabaseProvider),
          kidId: _kidId,
        ),
        appVersion: appVersion,
        currentAppVersion: AppVersion.tryParse(appVersion),
      );
      _controller = controller;
      events = controller.events;
      _autoRead = controller.events.listen(_onRuntimeEvent);
      unawaited(_startRuntime(controller));
    } else {
      _legacyAudio = DriftAudioResolver(ref.read(localDatabaseProvider));
      _bridge = LegacyFeedbackBridge();
      events = _bridge!.events;
      _telemetry = TelemetryClient(
        outbox: ref.read(eventOutboxProvider),
        // One session id per visit to this screen: the legacy path has no
        // logical session that outlives it (the runtime path does).
        sessionId: const Uuid().v4(),
        appVersion: appVersion,
      )..logSessionStart();
    }

    _director = AnimationDirector(
      events: events,
      cast: defaultCast,
      registry: ref.read(characterRegistryProvider),
    );

    _audio; // resolve now, while ref is usable
    _lifecycle = AppLifecycleListener(
      onHide: () {
        unawaited(_controller?.pause());
        unawaited(_audio.pause());
      },
      onShow: () => unawaited(_controller?.resume()),
    );
  }

  Future<void> _startRuntime(ActivitySessionController c) async {
    final store = DriftActivitySessionStore(
      ref.read(localDatabaseProvider),
      kidId: _kidId,
    );
    final previous = await store.live(
      kidId: _kidId,
      exerciseId: c.envelope.exerciseId,
    );
    await c.start(resumeFrom: previous);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _director.reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_autoRead?.cancel());
    unawaited(_audio.stopChannel(AudioChannel.narration));
    // Not exited and not finished means the screen went away mid-session:
    // leave the snapshot in place so the next visit resumes it.
    _controller?.dispose();
    _telemetry?.logSessionEnd();
    _bridge?.dispose();
    _director.dispose();
    super.dispose();
  }

  // ── runtime path ───────────────────────────────────────────────────────

  void _onRuntimeEvent(RuntimeEvent e) {
    switch (e) {
      case QuestionPresented(:final questionIndex):
        final c = _controller!;
        final plan = _planFor(c, questionIndex);
        if (plan != null && plan.autoPlays(SpeechPart.prompt)) _speak(c, plan);
      case QuestionCompleted(:final attempts, :final solved):
        _questionResults.add(
          ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: attempts,
            correct: solved ? 1 : 0,
            elapsedMs: 0,
          ),
        );
      case _:
    }
  }

  SpeechPlan? _planFor(ActivitySessionController c, int index) {
    if (index >= c.envelope.questions.length) return null;
    return SpeechPlan(
      envelope: c.envelope,
      question: c.envelope.questions[index],
      readAloudEnabled: ref.read(settingsControllerProvider).readAloud,
    );
  }

  void _speak(ActivitySessionController c, SpeechPlan plan) {
    final source = plan.promptSource();
    if (source == null) return;
    unawaited(c.recordAudioRequest(SpeechPart.prompt));
    _audio.play(
      AudioRequest(
        source: source,
        channel: AudioChannel.narration,
        priority: 10,
      ),
    );
  }

  /// XP so far: every finished question, plus the one just answered right
  /// — shown the moment the banner says "Bravo", not a tap later.
  int _runtimeXp() {
    final c = _controller!;
    final done = _questionResults.fold(0, (sum, q) => sum + estimateXp(q));
    final s = c.state;
    if (s.phase != SessionPhase.feedback || s.lastOutcome != Outcome.correct) {
      return done;
    }
    return done +
        estimateXp(
          ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: s.attempts,
            correct: 1,
            elapsedMs: 0,
          ),
        );
  }

  void _onRuntimeDone() {
    final c = _controller!;
    if (c.state.phase == SessionPhase.completed &&
        _questionResults.isNotEmpty) {
      final attempts = _questionResults.fold(0, (s, q) => s + q.attempts);
      final correct = _questionResults.fold(0, (s, q) => s + q.correct);
      _handleFinished(
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: attempts,
          correct: correct,
          elapsedMs: c.activeMs,
          questionResults: _questionResults.length > 1
              ? List.of(_questionResults)
              : const [],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── shared ─────────────────────────────────────────────────────────────

  void _handleFinished(ExerciseResult result) {
    // An abandoned run taught nothing worth counting or celebrating.
    if (result.outcome != ExerciseOutcome.completed) {
      Navigator.of(context).pop();
      return;
    }
    final perQuestion = result.questionResults.isEmpty
        ? [result]
        : result.questionResults;
    final summary = ActivitySummary(
      questions: perQuestion.length,
      solved: perQuestion.where((q) => q.correct > 0).length,
      firstTry: perQuestion.where((q) => q.isFirstTryPerfect).length,
      // A client-side estimate — `manage.py award_xp` hasn't run yet. The
      // authoritative total still comes from `ProgressState.totalXp`.
      xp: estimateXp(result),
    );

    // Home's stat tiles, the offline streak, and the map's "done" mark all
    // learn about this now, not when the backend next catches up.
    final db = ref.read(localDatabaseProvider);
    HomeStats(
      db,
      kidId: _kidId,
    ).recordExerciseCompleted(elapsedMs: result.elapsedMs);
    StreakLocal(db, kidId: _kidId).recordPlayedToday();
    unawaited(
      NodeProgressLocal(db, kidId: _kidId)
          .recordCompleted(
            widget.node.id,
            perfect: summary.perfect,
            exerciseId: widget.envelope['exercise_id'] as String?,
          )
          .then((_) => ref.invalidate(nodeProgressProvider)),
    );

    _director.cue(
      const ReactionCue(
        role: ActorRole.guide,
        reaction: Reaction.victory,
        priority: CuePriority.critical,
        hold: null,
      ),
    );
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    final summary = _summary;
    if (summary != null) {
      final name = ref.read(sessionControllerProvider).kid?.displayName;
      final strings = ShellStrings.of(locale);
      return Scaffold(
        body: ActivityCompleteView(
          summary: summary,
          locale: locale,
          title: summary.perfect
              ? null
              : (name == null ? null : strings.wellDone(name)),
          // The real fox art for the big moment, not the in-game placeholder:
          // the celebration is the one screen with room for it.
          character: const BreathingMascot(height: 150, hoverLift: false),
          extraRows: [
            for (final row
                in ref.watch(celebrationRowsProvider).value ?? const [])
              CelebrationRow(
                icon: row.icon,
                label: row.label,
                value: row.value,
                max: row.max,
              ),
          ],
          onContinue: () => Navigator.of(context).pop(),
        ),
      );
    }

    final stage = CharacterStage(
      director: _director,
      registry: ref.read(characterRegistryProvider),
      size: compact ? 56 : 72,
    );

    final c = _controller;
    if (c != null) {
      return Scaffold(
        body: ImageResolverScope(
          resolver: _images,
          exerciseId: _exerciseId,
          child: LearningActivityView(
            controller: c,
            locale: locale,
            character: stage,
            onDone: _onRuntimeDone,
            xpEarned: _runtimeXp,
            speakPrompt: (q) {
              final plan = _planFor(c, q.index);
              if (plan == null || plan.promptSource() == null) return null;
              return () => _speak(c, plan);
            },
          ),
        ),
      );
    }

    return Scaffold(
      body: ImageResolverScope(
        resolver: _images,
        exerciseId: _exerciseId,
        child: LegacyEngineHost(
          envelope: widget.envelope,
          registry: ref.watch(engineRegistryProvider),
          telemetry: _telemetry!,
          feedback: _bridge!,
          audio: _legacyAudio,
          locale: locale,
          character: stage,
          onFinished: _handleFinished,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
