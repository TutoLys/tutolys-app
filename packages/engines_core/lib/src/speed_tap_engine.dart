import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// Tap the right option before the clock runs out.
///
/// Same content shape as [McqEngine] — `options` + `correct` — plus
/// `time_limit_ms`: an arcade/timed presentation layer, not a new content
/// contract (the old Godot archetype registry's own note on this one:
/// "cheapest engine to prove — no new content contract"). A timeout is
/// scored exactly like a wrong tap: a logged wrong attempt, gentle feedback,
/// and the countdown restarts — never an abandon the engine decides on its
/// own, same forgiving retry-until-correct philosophy as `McqEngine`.
class SpeedTapEngine extends TutolysEngine {
  const SpeedTapEngine();

  @override
  String get key => 'speed_tap';

  @override
  int get version => 1;

  @override
  String get category => 'general';

  @override
  SettingsManifest get settingsManifest =>
      const SettingsManifest(engineKey: 'speed_tap', definitions: []);

  @override
  EngineValidation validate(Map<String, Object?> config) {
    final options = config['options'];
    if (options is! List || options.length < 2 || options.length > 6) {
      return const EngineValidation.invalid(
        'speed_tap needs between 2 and 6 options.',
      );
    }

    final ids = <String>{};
    for (final option in options) {
      if (option is! Map) {
        return const EngineValidation.invalid(
          'Every option needs an id and a label.',
        );
      }
      final id = option['id'];
      final label = option['label'];
      if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
        return const EngineValidation.invalid(
          'Every option needs an id and a label.',
        );
      }
      ids.add(id);
    }
    if (ids.length != options.length) {
      return const EngineValidation.invalid('Option ids must be unique.');
    }

    final correct = config['correct'];
    if (correct is! String || !ids.contains(correct)) {
      return const EngineValidation.invalid(
        'correct must name one of the options.',
      );
    }

    final timeLimitMs = config['time_limit_ms'];
    if (timeLimitMs is! int || timeLimitMs < 1000 || timeLimitMs > 60000) {
      return const EngineValidation.invalid(
        'time_limit_ms must be an integer between 1000 and 60000.',
      );
    }

    return const EngineValidation.valid();
  }

  @override
  Widget build(EngineContext context, Map<String, Object?> config) {
    return _SpeedTapView(engine: context, config: config);
  }
}

class _SpeedTapView extends StatefulWidget {
  const _SpeedTapView({required this.engine, required this.config});

  final EngineContext engine;
  final Map<String, Object?> config;

  @override
  State<_SpeedTapView> createState() => _SpeedTapViewState();
}

class _SpeedTapViewState extends State<_SpeedTapView> {
  late final List<Map<String, Object?>> _options = _buildOptions();
  late final DateTime _startedAt = widget.engine.clock();
  late final int _timeLimitMs = widget.config['time_limit_ms'] as int;

  Timer? _ticker;
  int _remainingMs = 0;
  String? _selected;
  bool _awaitingFeedback = false;
  bool _hintRevealed = false;
  int _attempts = 0;

  static const _tickInterval = Duration(milliseconds: 100);

  String get _correctId => widget.config['correct'] as String;
  String? get _hint => widget.config['hint'] as String?;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<Map<String, Object?>> _buildOptions() {
    final options = (widget.config['options'] as List)
        .cast<Map<String, Object?>>()
        .toList();
    final shuffle = widget.config['shuffle'] != false;
    if (shuffle) options.shuffle(widget.engine.random);
    return options;
  }

  void _startTimer() {
    _remainingMs = _timeLimitMs;
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) {
      if (!mounted) return;
      final next = _remainingMs - _tickInterval.inMilliseconds;
      if (next <= 0) {
        _ticker?.cancel();
        setState(() => _remainingMs = 0);
        _timeOut();
        return;
      }
      setState(() => _remainingMs = next);
    });
  }

  Future<void> _timeOut() async {
    if (_awaitingFeedback) return;
    setState(() {
      _awaitingFeedback = true;
      _attempts += 1;
    });

    await widget.engine.telemetry.logAttempt(
      answer: {'selected': null, 'timed_out': true},
      isCorrect: false,
    );
    await widget.engine.feedback.incorrect();
    if (!mounted) return;
    setState(() => _awaitingFeedback = false);
    _startTimer();
  }

  Future<void> _choose(String id) async {
    if (_awaitingFeedback) return;

    final isCorrect = id == _correctId;
    setState(() {
      _selected = id;
      _awaitingFeedback = true;
      _attempts += 1;
    });

    await widget.engine.telemetry.logAttempt(
      answer: {'selected': id},
      isCorrect: isCorrect,
    );

    if (isCorrect) {
      _ticker?.cancel();
      await widget.engine.feedback.correct();
      await widget.engine.feedback.celebrate();
      widget.engine.onFinished(
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: _attempts,
          correct: 1,
          elapsedMs: widget.engine
              .clock()
              .difference(_startedAt)
              .inMilliseconds,
        ),
      );
      return;
    }

    await widget.engine.feedback.incorrect();
    if (!mounted) return;
    setState(() {
      _selected = null;
      _awaitingFeedback = false;
    });
    _startTimer();
  }

  Future<void> _revealHint() async {
    setState(() => _hintRevealed = true);
    await widget.engine.telemetry.logHint();
    await widget.engine.feedback.hint();
  }

  @override
  Widget build(BuildContext context) {
    final hintsEnabled = widget.engine.settings.toggle('hints', fallback: true);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _remainingMs / _timeLimitMs,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          for (final option in _options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OptionButton(
                label: option['label'] as String,
                isWrong: _selected == option['id'] && _selected != _correctId,
                onTap: () => _choose(option['id'] as String),
              ),
            ),
          if (_hint != null && hintsEnabled) ...[
            const SizedBox(height: 16),
            if (_hintRevealed)
              Text(_hint!, textAlign: TextAlign.center)
            else
              TextButton(
                onPressed: _revealHint,
                child: Text(widget.engine.t(fr: 'Indice', en: 'Hint')),
              ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.isWrong,
    required this.onTap,
  });

  final String label;
  final bool isWrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: isWrong
            ? FilledButton.styleFrom(backgroundColor: Colors.red.shade400)
            : null,
        child: Text(label),
      ),
    );
  }
}
