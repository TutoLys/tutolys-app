import 'dart:async';
import 'dart:convert';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutolys_motion/tutolys_motion.dart';
import 'package:uuid/uuid.dart';

import '../../data/local_db/creation_store.dart';
import '../../data/local_db/database.dart';
import '../../data/local_db/drift_activity_session_store.dart';
import '../../data/local_db/home_stats.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../data/local_db/streak_local.dart';
import '../../data/sync/content_in_use.dart';
import '../../data/sync/drift_audio_resolver.dart';
import '../../data/sync/drift_image_resolver.dart';
import '../../data/sync/lesson_key.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../audio/app_sounds.dart';
import '../audio/music_director.dart';
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart' show contentInUseProvider;
import '../profile/avatars.dart';
import '../profile/rare_avatar_found.dart';
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
/// The legacy host's width on a wide screen, the new shell's widest.
const double legacyMaxWidth = 720;

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

  /// A rare avatar this lesson revealed, shown on the celebration.
  String? _rareAvatarKey;

  // Legacy path.
  TelemetryClient? _telemetry;
  LegacyFeedbackBridge? _bridge;
  DriftAudioResolver? _legacyAudio;

  String get _kidId => ref.read(activeKidIdProvider) ?? unpairedKidId;

  /// Holds this lesson against offline-window eviction while it's on
  /// screen (ADR 0095): its audio and pictures must not vanish mid-game.
  late final ContentInUse _inUse;

  @override
  void initState() {
    super.initState();
    _inUse = ref.read(contentInUseProvider)..hold(_exerciseId);
    unawaited(_readReplay());
    // No music under a question being read (ADR 0035).
    _music.activityEntered();
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
    _inUse.release(_exerciseId);
    _music.activityLeft();
    _lifecycle.dispose();
    unawaited(_autoRead?.cancel());
    unawaited(_audio.stopChannel(AudioChannel.narration));
    // Not exited and not finished means the screen went away mid-session:
    // leave the snapshot in place so the next visit resumes it.
    _controller?.dispose();
    // Left before the celebration: the session says so (an abandon
    // before its end), so no quest counts it.
    _telemetry?.logSessionEnd(finished: _summary != null);
    _bridge?.dispose();
    _director.dispose();
    super.dispose();
  }

  // ── runtime path ───────────────────────────────────────────────────────

  late final MusicDirector _music = ref.read(musicDirectorProvider);

  /// One of the three moments every engine shares (ADR 0035), on the SFX
  /// channel: the Réglages toggle and volume apply there.
  void _effect(SfxMoment moment) => _audio.play(
    AudioRequest(
      source: EffectAudio(moment.effectName),
      channel: AudioChannel.sfx,
    ),
  );

  void _onRuntimeEvent(RuntimeEvent e) {
    switch (e) {
      // VALIDER's verdict, once per check, whichever engine judged it.
      case AnswerEvaluated(:final result):
        _effect(
          result.outcome == Outcome.correct
              ? SfxMoment.answerRight
              : SfxMoment.answerRetry,
        );
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

  /// Puts the active kid's "Mes créations" above the engine, so a creative
  /// engine can keep what the child made and `my_gallery` can hang it
  /// (ADR 0036). Local only.
  Widget _creationShelf(Widget child) {
    final shelf = ref.watch(creationShelfProvider);
    if (shelf == null) return child;
    return CreationShelfScope(shelf: shelf, child: child);
  }

  /// The speaker an engine draws beside its own parts (a `passage_reader`
  /// sentence, app ADR 0044). With read-aloud off there is no scope, so the
  /// engine draws no speaker at all. The request is logged as part of the
  /// prompt, under the part's id.
  Widget _contentSpeaker(ActivitySessionController c, Widget child) {
    if (!ref.watch(settingsControllerProvider).readAloud) return child;
    return ContentSpeakerScope(
      speaker: _ContentSpeaker((audioRef, partId) {
        unawaited(c.recordAudioRequest(SpeechPart.prompt, partId: partId));
        _audio.play(
          AudioRequest(
            source: PrerecordedAudio(exerciseId: _exerciseId, ref: audioRef),
            channel: AudioChannel.narration,
            priority: 10,
          ),
        );
      }),
      child: child,
    );
  }

  /// XP so far: every finished question, plus the one just answered right
  /// — shown the moment the banner says "Bravo", not a tap later.
  /// Question XP only: the lesson bonuses arrive with the celebration.
  /// XP so far, question by question as the backend's ledger pays it
  /// (backend ADR 0047): the question that finishes the lesson carries the
  /// lesson bonus, or on a replay the half, so the counter ends on exactly
  /// the celebration's number.
  int _runtimeXp() {
    final c = _controller!;
    final results = [..._questionResults];
    final s = c.state;
    if (s.phase == SessionPhase.feedback && s.lastOutcome == Outcome.correct) {
      results.add(
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: s.attempts,
          correct: 1,
          elapsedMs: 0,
        ),
      );
    }
    return xpSoFar(
      results,
      questions: c.envelope.questions.length,
      replay: _replay,
    );
  }

  /// This kid already finished this lesson, in any language (the backend
  /// keys a replay on `lesson_group`): no lesson bonus, half the questions.
  bool _replay = false;

  Future<void> _readReplay() async {
    final done = (await ref.read(
      nodeProgressProvider.future,
    ))[widget.node.id]?.exerciseIds;
    if (done == null || done.isEmpty) return;
    final key = lessonKeyOf(widget.envelope);
    if (done.contains(widget.envelope['exercise_id'])) {
      _replay = true;
      return;
    }
    // Another language version of the same lesson counts too.
    final db = ref.read(localDatabaseProvider);
    final rows = await (db.select(
      db.exerciseCacheTable,
    )..where((t) => t.skillNodeId.equals(widget.node.id))).get();
    _replay = rows.any(
      (r) =>
          done.contains(r.exerciseId) &&
          lessonKeyOf(jsonDecode(r.payload) as Map<String, Object?>) == key,
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
    _effect(SfxMoment.activityComplete);
    final perQuestion = result.questionResults.isEmpty
        ? [result]
        : result.questionResults;
    final summary = ActivitySummary(
      questions: perQuestion.length,
      solved: perQuestion.where((q) => q.correct > 0).length,
      firstTry: perQuestion.where((q) => q.isFirstTryPerfect).length,
      // A client-side estimate — `manage.py award_xp` hasn't run yet. The
      // authoritative total still comes from `ProgressState.totalXp`.
      xp: estimateXp(result, replay: _replay),
    );

    // Home's stat tiles, the offline streak, and the map's "done" mark all
    // learn about this now, not when the backend next catches up.
    final db = ref.read(localDatabaseProvider);
    final lessonId = widget.envelope['exercise_id'] as String?;
    HomeStats(db, kidId: _kidId).recordExerciseCompleted(
      elapsedMs: result.elapsedMs,
      exerciseId: lessonId,
    );
    StreakLocal(db, kidId: _kidId).recordPlayedToday();
    unawaited(
      NodeProgressLocal(db, kidId: _kidId)
          .recordCompleted(
            widget.node.id,
            perfect: summary.perfect,
            exerciseId: lessonId,
            lessonGroup: widget.envelope['lesson_group'] as String?,
          )
          .then((_) => ref.invalidate(nodeProgressProvider)),
    );
    // A perfect lesson may reveal a rare avatar (ADR 0050).
    if (summary.perfect && lessonId != null) {
      unawaited(
        ref
            .read(avatarControllerProvider.notifier)
            .rollRareDrop(lessonId, subject: widget.node.subject)
            .then((key) {
              if (key != null && mounted) {
                setState(() => _rareAvatarKey = key);
              }
            }),
      );
    }

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
          // The same fox as in the game, cued to `victory` just before this
          // mounts: two hops and confetti, or a still pose under reduced
          // motion.
          character: CharacterStage(
            director: _director,
            registry: ref.read(characterRegistryProvider),
            size: 150,
          ),
          extraRows: [
            if (_rareAvatarKey case final key?) RareAvatarFound(avatarKey: key),
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
        body: _creationShelf(
          ImageResolverScope(
            resolver: _images,
            exerciseId: _exerciseId,
            child: _contentSpeaker(
              c,
              LearningActivityView(
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
          ),
        ),
      );
    }

    return Scaffold(
      body: ImageResolverScope(
        resolver: _images,
        exerciseId: _exerciseId,
        // The legacy host has no width cap of its own: on a wide desktop
        // its answers stretched edge to edge (Hafid: "too wide"). Nothing
        // published takes this path now; if anything ever does, it reads
        // at the new shell's width.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: legacyMaxWidth),
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
        ),
      ),
    );
  }
}

class _ContentSpeaker implements ContentSpeaker {
  const _ContentSpeaker(this._speak);

  final void Function(String audioRef, String partId) _speak;

  @override
  void speak({required String audioRef, required String partId}) =>
      _speak(audioRef, partId);
}
