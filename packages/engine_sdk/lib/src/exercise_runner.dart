import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

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
class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner({
    required this.envelope,
    required this.registry,
    required this.telemetry,
    required this.feedback,
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

  bool _started = false;
  bool _finished = false;
  Future<void>? _startFuture;

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
    }
  }

  @override
  void dispose() {
    // The kid left mid-run — a signal in its own right, not something to
    // drop silently. Best-effort: dispose cannot be awaited.
    if (_started && !_finished) {
      unawaited(widget.telemetry.logAbandon());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final envelope = widget.envelope;
    final engineKey = envelope['engine_key'] as String?;
    final minVersion = envelope['engine_min_version'] as int? ?? 1;
    final config = (envelope['config'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    if (engineKey == null) {
      return _fallback(context, _t('Cet exercice est incomplet.',
          'This exercise is incomplete.'));
    }

    final resolution =
        widget.registry.resolve(engineKey: engineKey, minimumVersion: minVersion);

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
    final prompt =
        (widget.envelope['prompt'] as Map?)?.cast<String, Object?>();
    final text = prompt?['text'] as String?;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
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
      definitions: [
        ...commonSettings,
        ...engine.settingsManifest.definitions,
      ],
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
