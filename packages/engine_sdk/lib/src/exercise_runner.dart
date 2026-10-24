import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'audio.dart';
import 'engine.dart';
import 'registry.dart';
import 'result.dart';
import 'settings.dart';
import 'telemetry.dart';

/// Renders whatever engine a content envelope names.
///
/// This is the mechanism behind the plan's commercially-locked decision: the
/// backend's `engine_key` picks what renders, so retagging an exercise to a
/// different engine is a content change, not an app release. Every call site
/// hands this the envelope and gets back the right engine wired up — it never
/// switches on `engine_key` itself.
///
/// Also where the telemetry lifecycle lives so no engine has to get it right
/// itself: [TelemetryClient.startExercise] is called before the engine is
/// built, and [TelemetryClient.logComplete] / [TelemetryClient.logAbandon] are
/// called exactly once, from one place, regardless of which engine ran.
///
/// A multi-question exercise (`config.questions` present and non-empty) is
/// handled here too, by composition rather than new state-machine logic:
/// `build()` detects it and delegates to [_MultiQuestionSequencer], which
/// renders a fresh child `ExerciseRunner` per question, keyed by index so
/// Flutter's own widget lifecycle (not hand-rolled bookkeeping) gives each
/// question a correct, independent telemetry run — including the abandon-
/// on-dispose path, for free, the same way the single-question case already
/// gets it.
class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner({
    required this.envelope,
    required this.registry,
    required this.telemetry,
    required this.feedback,
    required this.audio,
    required this.onFinished,
    required this.locale,
    this.settingsOverrides = const {},
    this.clock,
    this.random,
    this.unsupportedBuilder,
    super.key,
  });

  /// The §5.4 content envelope — exactly what `ContentSync` caches.
  final Map<String, Object?> envelope;

  final EngineRegistry registry;
  final TelemetryClient telemetry;
  final EngineFeedback feedback;

  /// Resolves a question prompt's `audio_ref` to cached bytes, for the
  /// "read the question aloud" control. Required, not optional — a host
  /// with nothing cached yet passes [InMemoryAudioResolver], which simply
  /// always resolves to `null` (no button shown), rather than this widget
  /// having its own separate notion of "no audio support".
  final AudioResolver audio;

  /// Called exactly once per run, after telemetry has already recorded the
  /// outcome. The host decides what screen comes next; this widget never
  /// navigates on its own.
  final ValueChanged<ExerciseResult> onFinished;

  final Locale locale;

  /// The kid's or parent's local overrides, keyed by setting key. Values that
  /// do not match the resolved manifest are ignored by [ResolvedSettings].
  final Map<String, Object?> settingsOverrides;

  final DateTime Function()? clock;
  final Random? random;

  /// Override for the unsupported/invalid-content fallback, mostly for
  /// tests. Receives a human reason string.
  final Widget Function(BuildContext context, String reason)?
  unsupportedBuilder;

  @override
  State<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends State<ExerciseRunner> {
  late final Random _random = widget.random ?? Random();
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late final ExercisePromptAudio _player = ExercisePromptAudio();

  bool _started = false;
  bool _finished = false;
  Future<void>? _startFuture;

  /// Which `exerciseId/audioRef` has already been resolved-and-autoplayed,
  /// so a rebuild (e.g. a settings change) never replays the same prompt.
  /// Only set once resolution actually *succeeds* — a `null` result (not
  /// synced yet) must stay eligible to retry on a later rebuild, rather
  /// than being treated as "handled" forever.
  String? _autoPlayedFor;

  /// Guards against a second concurrent resolve for the same key while
  /// the first is still in flight — separate from [_autoPlayedFor] so a
  /// `null` result doesn't block a legitimate retry.
  String? _resolvingFor;
  Uint8List? _audioBytes;

  @override
  void didUpdateWidget(ExerciseRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.envelope['exercise_id'] != widget.envelope['exercise_id'] ||
        oldWidget.envelope['version'] != widget.envelope['version'] ||
        oldWidget.envelope['engine_key'] != widget.envelope['engine_key']) {
      // A genuinely new exercise was handed to the same runner instance
      // (e.g. the host advanced a PageView without recreating the widget).
      // Re-run the full lifecycle rather than carrying over stale state.
      _started = false;
      _finished = false;
      _startFuture = null;
      _autoPlayedFor = null;
      _resolvingFor = null;
      _audioBytes = null;
    }
  }

  @override
  void dispose() {
    // The kid left mid-run — a signal in its own right, not something to
    // drop silently. Best-effort: dispose cannot be awaited.
    if (_started && !_finished) {
      unawaited(widget.telemetry.logAbandon());
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final envelope = widget.envelope;
    final config =
        (envelope['config'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    final questions = config['questions'];
    if (questions is List && questions.isNotEmpty) {
      return _MultiQuestionSequencer(
        outerEnvelope: envelope,
        questions: questions.cast<Map<String, Object?>>(),
        registry: widget.registry,
        telemetry: widget.telemetry,
        feedback: widget.feedback,
        audio: widget.audio,
        locale: widget.locale,
        settingsOverrides: widget.settingsOverrides,
        clock: widget.clock,
        random: widget.random,
        unsupportedBuilder: widget.unsupportedBuilder,
        onFinished: widget.onFinished,
      );
    }

    final engineKey = envelope['engine_key'] as String?;
    final minVersion = envelope['engine_min_version'] as int? ?? 1;

    if (engineKey == null) {
      return _fallback(
        context,
        _t('Cet exercice est incomplet.', 'This exercise is incomplete.'),
      );
    }

    final resolution = widget.registry.resolve(
      engineKey: engineKey,
      minimumVersion: minVersion,
    );

    return switch (resolution) {
      UnknownEngine() => _fallback(
        context,
        _t(
          "Cette activité a besoin d'une mise à jour de l'application.",
          'This activity needs an app update.',
        ),
      ),
      EngineVersionTooOld() => _fallback(
        context,
        _t(
          "Cette activité a besoin d'une mise à jour de l'application.",
          'This activity needs an app update.',
        ),
      ),
      ResolvedEngine(:final engine) => _buildResolved(context, engine, config),
    };
  }

  Widget _buildResolved(
    BuildContext context,
    TutolysEngine engine,
    Map<String, Object?> config,
  ) {
    final validation = engine.validate(config);
    if (!validation.isValid) {
      return _fallback(
        context,
        validation.reason ??
            _t('Ce contenu est invalide.', 'This content is invalid.'),
      );
    }

    _startFuture ??= _startRun(engine);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrompt(context),
        Expanded(
          child: FutureBuilder<void>(
            future: _startFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              return engine.build(_buildContext(engine), config);
            },
          ),
        ),
      ],
    );
  }

  /// Text/audio/image prompt, shown identically whichever engine answers it.
  ///
  /// Uniform across engines on purpose: an engine's `build` never sees the
  /// prompt, so every engine cannot help but present it the same way.
  Widget _buildPrompt(BuildContext context) {
    final prompt = (widget.envelope['prompt'] as Map?)?.cast<String, Object?>();
    final text = prompt?['text'] as String?;
    final audioRef = prompt?['audio_ref'] as String?;
    final exerciseId = widget.envelope['exercise_id'] as String?;

    if ((text == null || text.isEmpty) && audioRef == null) {
      return const SizedBox.shrink();
    }

    if (audioRef != null && exerciseId != null) {
      _maybeAutoPlay(exerciseId, audioRef);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (text != null && text.isNotEmpty)
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: DefaultTextStyle.of(context).style
                    .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          if (audioRef != null) ...[
            const SizedBox(width: 8),
            _ReadAloudButton(
              enabled: _audioBytes != null,
              onPressed: () {
                final bytes = _audioBytes;
                if (bytes == null) return;
                unawaited(
                  _player.play(bytes, cacheKey: '$exerciseId/$audioRef'),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Resolve + play once per `exerciseId/audioRef`, not once per rebuild.
  ///
  /// Called from `build()`, so the guard has to be synchronous and
  /// immediate — marking `_autoPlayedFor` before the `await` is what stops
  /// a second concurrent rebuild from kicking off a second resolve.
  void _maybeAutoPlay(String exerciseId, String audioRef) {
    final key = '$exerciseId/$audioRef';
    if (_autoPlayedFor == key || _resolvingFor == key) return;
    _resolvingFor = key;

    scheduleMicrotask(() async {
      final bytes = await widget.audio.bytesFor(
        exerciseId: exerciseId,
        ref: audioRef,
      );
      _resolvingFor = null;
      if (!mounted || bytes == null) return;
      _autoPlayedFor = key;
      setState(() => _audioBytes = bytes);
      await _player.play(bytes, cacheKey: key);
    });
  }

  Future<void> _startRun(TutolysEngine engine) async {
    final envelope = widget.envelope;
    await widget.telemetry.startExercise(
      ExerciseIdentity(
        exerciseId: envelope['exercise_id'] as String,
        exerciseVersion: envelope['version'] as int,
        engineKey: engine.key,
        engineVersion: engine.version,
        skillNodeId: envelope['skill_node_id'] as String,
        subject: envelope['subject'] as String,
        grade: envelope['grade'] as int,
        rank: envelope['rank'] as int,
      ),
    );
    _started = true;
  }

  EngineContext _buildContext(TutolysEngine engine) {
    final manifest = SettingsManifest(
      engineKey: engine.key,
      definitions: [...commonSettings, ...engine.settingsManifest.definitions],
    );
    final settings = ResolvedSettings(
      manifest: manifest,
      overrides: widget.settingsOverrides,
    );

    return EngineContext(
      telemetry: widget.telemetry,
      settings: settings,
      feedback: widget.feedback,
      clock: _clock,
      random: _random,
      locale: widget.locale,
      onFinished: _handleFinished,
    );
  }

  void _handleFinished(ExerciseResult result) {
    if (_finished) return;
    _finished = true;

    final logged = switch (result.outcome) {
      ExerciseOutcome.completed => widget.telemetry.logComplete(),
      ExerciseOutcome.abandoned => widget.telemetry.logAbandon(),
    };

    logged.then((_) {
      if (mounted) widget.onFinished(result);
    });
  }

  Widget _fallback(BuildContext context, String reason) {
    return widget.unsupportedBuilder?.call(context, reason) ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(reason, textAlign: TextAlign.center),
          ),
        );
  }

  String _t(String fr, String en) =>
      widget.locale.languageCode == 'fr' ? fr : en;
}

/// A speaker icon, tap-to-replay. Deliberately minimal — design_system's
/// themed controls live in the app layer, which this package never depends
/// on, so this is plain Flutter widgets dressed just enough to be usable,
/// not a themed component.
class _ReadAloudButton extends StatelessWidget {
  const _ReadAloudButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        Icons.volume_up,
        color: enabled
            ? null
            : IconTheme.of(context).color?.withValues(alpha: 0.3),
      ),
      tooltip: 'Écouter / Listen',
    );
  }
}

/// Sequences an exercise's `questions[]` through one child [ExerciseRunner]
/// at a time, reusing it entirely unmodified per question rather than
/// re-implementing its start/finish/abandon lifecycle here.
///
/// Each question becomes a synthetic single-question envelope — the outer
/// exercise's shared fields (`exercise_id`, `version`, `engine_key`,
/// `skill_node_id`, subject/grade/rank/locale) plus that question's own
/// `prompt`/`config` — so telemetry sees exactly the same event shape it
/// always has: one `exercise_start`/`exercise_complete` pair per question,
/// each with its own `exercise_run_id`, all sharing the same `exercise_id`.
/// Nothing downstream (mastery, streaks, the daily challenge, XP) needed to
/// change for that — see tutolys-backend ADR 0022/0023.
class _MultiQuestionSequencer extends StatefulWidget {
  const _MultiQuestionSequencer({
    required this.outerEnvelope,
    required this.questions,
    required this.registry,
    required this.telemetry,
    required this.feedback,
    required this.audio,
    required this.locale,
    required this.settingsOverrides,
    required this.clock,
    required this.random,
    required this.unsupportedBuilder,
    required this.onFinished,
  });

  final Map<String, Object?> outerEnvelope;
  final List<Map<String, Object?>> questions;
  final EngineRegistry registry;
  final TelemetryClient telemetry;
  final EngineFeedback feedback;
  final AudioResolver audio;
  final Locale locale;
  final Map<String, Object?> settingsOverrides;
  final DateTime Function()? clock;
  final Random? random;
  final Widget Function(BuildContext context, String reason)?
  unsupportedBuilder;
  final ValueChanged<ExerciseResult> onFinished;

  @override
  State<_MultiQuestionSequencer> createState() =>
      _MultiQuestionSequencerState();
}

class _MultiQuestionSequencerState extends State<_MultiQuestionSequencer> {
  int _index = 0;
  final List<ExerciseResult> _results = [];

  Map<String, Object?> get _currentEnvelope {
    final question = widget.questions[_index];
    return {
      ...widget.outerEnvelope,
      'prompt': question['prompt'] ?? const <String, Object?>{},
      'config': question['config'] ?? const <String, Object?>{},
    };
  }

  void _handleQuestionFinished(ExerciseResult result) {
    _results.add(result);

    if (_index + 1 < widget.questions.length) {
      setState(() => _index += 1);
      return;
    }

    widget.onFinished(
      ExerciseResult(
        outcome: ExerciseOutcome.completed,
        attempts: _results.fold(0, (sum, r) => sum + r.attempts),
        correct: _results.fold(0, (sum, r) => sum + r.correct),
        elapsedMs: _results.fold(0, (sum, r) => sum + r.elapsedMs),
        questionResults: List.unmodifiable(_results),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExerciseRunner(
      // Keyed by index: a new question is a new ExerciseRunner State, so
      // its own initState/dispose lifecycle — including the
      // abandon-on-dispose telemetry call — applies to each question
      // independently, with no bookkeeping duplicated here.
      key: ValueKey(_index),
      envelope: _currentEnvelope,
      registry: widget.registry,
      telemetry: widget.telemetry,
      feedback: widget.feedback,
      audio: widget.audio,
      locale: widget.locale,
      settingsOverrides: widget.settingsOverrides,
      clock: widget.clock,
      random: widget.random,
      unsupportedBuilder: widget.unsupportedBuilder,
      onFinished: _handleQuestionFinished,
    );
  }
}
