import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// Assemble a target from tiles — a word from syllables, a number from
/// place-value parts, a sentence from words.
///
/// The third of the first three: a distinct interaction shape again
/// (assembling, rather than picking or connecting). `config` matches
/// `docs/schemas/exercise/engines/compose_build.content.schema.json`.
class ComposeBuildEngine extends TutolysEngine {
  const ComposeBuildEngine();

  @override
  String get key => 'compose_build';

  @override
  int get version => 1;

  @override
  String get category => 'general';

  @override
  SettingsManifest get settingsManifest =>
      const SettingsManifest(engineKey: 'compose_build', definitions: []);

  @override
  EngineValidation validate(Map<String, Object?> config) {
    final tiles = config['tiles'];
    if (tiles is! List || tiles.length < 2 || tiles.length > 12) {
      return const EngineValidation.invalid(
        'compose_build needs between 2 and 12 tiles.',
      );
    }

    final tileIds = <String>{};
    for (final tile in tiles) {
      if (tile is! Map) {
        return const EngineValidation.invalid(
          'Every tile needs an id and a label.',
        );
      }
      final id = tile['id'];
      final label = tile['label'];
      if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
        return const EngineValidation.invalid(
          'Every tile needs an id and a label.',
        );
      }
      tileIds.add(id);
    }

    final target = config['target'];
    if (target is! List || target.isEmpty) {
      return const EngineValidation.invalid('target cannot be empty.');
    }
    for (final id in target) {
      if (id is! String || !tileIds.contains(id)) {
        return const EngineValidation.invalid(
          'Every id in target must exist in tiles.',
        );
      }
    }

    return const EngineValidation.valid();
  }

  @override
  Widget build(EngineContext context, Map<String, Object?> config) {
    return _ComposeBuildView(engine: context, config: config);
  }
}

class _Tile {
  _Tile(this.id, this.label);
  final String id;
  final String label;
}

class _ComposeBuildView extends StatefulWidget {
  const _ComposeBuildView({required this.engine, required this.config});

  final EngineContext engine;
  final Map<String, Object?> config;

  @override
  State<_ComposeBuildView> createState() => _ComposeBuildViewState();
}

class _ComposeBuildViewState extends State<_ComposeBuildView> {
  late final List<String> _target =
      (widget.config['target'] as List).cast<String>();
  late final bool _ordered = widget.config['ordered'] != false;
  late final List<_Tile> _bank = _shuffledTiles();
  late final DateTime _startedAt = widget.engine.clock();

  final List<_Tile> _answer = [];
  bool _awaitingFeedback = false;
  int _attempts = 0;

  List<_Tile> _shuffledTiles() {
    final tiles = (widget.config['tiles'] as List)
        .cast<Map>()
        .map((t) => _Tile(t['id'] as String, t['label'] as String))
        .toList();
    tiles.shuffle(widget.engine.random);
    return tiles;
  }

  void _addToAnswer(_Tile tile) {
    if (_awaitingFeedback || _answer.length >= _target.length) return;
    setState(() {
      _bank.remove(tile);
      _answer.add(tile);
    });
    if (_answer.length == _target.length) _check();
  }

  void _returnToBank(_Tile tile) {
    if (_awaitingFeedback) return;
    setState(() {
      _answer.remove(tile);
      _bank.add(tile);
    });
  }

  Future<void> _check() async {
    final sequence = _answer.map((t) => t.id).toList();
    final isCorrect = _ordered
        ? _sequenceEquals(sequence, _target)
        : _multisetEquals(sequence, _target);

    setState(() {
      _awaitingFeedback = true;
      _attempts += 1;
    });

    await widget.engine.telemetry.logAttempt(
      answer: {'sequence': sequence},
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _bank.addAll(_answer);
      _answer.clear();
      _awaitingFeedback = false;
    });
  }

  bool _sequenceEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _multisetEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]..sort();
    final sortedB = [...b]..sort();
    return _sequenceEquals(sortedA, sortedB);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _target.length; i++)
                _TileChip(
                  label: i < _answer.length ? _answer[i].label : null,
                  isAnswerSlot: true,
                  onTap: i < _answer.length
                      ? () => _returnToBank(_answer[i])
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in _bank)
                _TileChip(
                  label: tile.label,
                  isAnswerSlot: false,
                  onTap: () => _addToAnswer(tile),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileChip extends StatelessWidget {
  const _TileChip({
    required this.label,
    required this.isAnswerSlot,
    required this.onTap,
  });

  final String? label;
  final bool isAnswerSlot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isAnswerSlot
              ? colors.surfaceContainerHighest
              : colors.primaryContainer,
          border: isAnswerSlot
              ? Border.all(color: colors.outlineVariant)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
