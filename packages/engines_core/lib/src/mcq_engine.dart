import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// Tap the right option.
///
/// The most universal archetype — works for every subject, which is why it
/// ported first. `config` matches
/// `docs/schemas/exercise/engines/mcq.content.schema.json` on the backend.
class McqEngine extends TutolysEngine {
  const McqEngine();

  @override
  String get key => 'mcq';

  @override
  int get version => 1;

  @override
  String get category => 'general';

  @override
  SettingsManifest get settingsManifest =>
      const SettingsManifest(engineKey: 'mcq', definitions: []);

  @override
  EngineValidation validate(Map<String, Object?> config) {
    final options = config['options'];
    if (options is! List || options.length < 2 || options.length > 6) {
      return const EngineValidation.invalid(
        'mcq needs between 2 and 6 options.',
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

    return const EngineValidation.valid();
  }

  @override
  Widget build(EngineContext context, Map<String, Object?> config) {
    return _McqView(engine: context, config: config);
  }
}

class _McqView extends StatefulWidget {
  const _McqView({required this.engine, required this.config});

  final EngineContext engine;
  final Map<String, Object?> config;

  @override
  State<_McqView> createState() => _McqViewState();
}

class _McqViewState extends State<_McqView> {
  late final List<Map<String, Object?>> _options = _buildOptions();
  late final DateTime _startedAt = widget.engine.clock();

  String? _selected;
  bool _awaitingFeedback = false;
  bool _hintRevealed = false;
  int _attempts = 0;

  String get _correctId => widget.config['correct'] as String;
  String? get _hint => widget.config['hint'] as String?;

  List<Map<String, Object?>> _buildOptions() {
    final options =
        (widget.config['options'] as List).cast<Map<String, Object?>>().toList();
    final shuffle = widget.config['shuffle'] != false;
    if (shuffle) options.shuffle(widget.engine.random);
    return options;
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
      await widget.engine.feedback.correct();
      await widget.engine.feedback.celebrate();
      widget.engine.onFinished(
        ExerciseResult(
          outcome: ExerciseOutcome.completed,
          attempts: _attempts,
          correct: 1,
          elapsedMs:
              widget.engine.clock().difference(_startedAt).inMilliseconds,
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
                child: Text(
                  widget.engine.t(fr: 'Indice', en: 'Hint'),
                ),
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
