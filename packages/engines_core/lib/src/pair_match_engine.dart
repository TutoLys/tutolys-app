import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// Connect matching items.
///
/// A mechanically different interaction from `mcq` — tap-to-select then
/// tap-to-connect, rather than a single tap — which is why it is one of the
/// first three: it proves the engine abstraction holds across interaction
/// shapes, not just across subjects. `config` matches
/// `docs/schemas/exercise/engines/pair_match.content.schema.json`.
class PairMatchEngine extends TutolysEngine {
  const PairMatchEngine();

  @override
  String get key => 'pair_match';

  @override
  int get version => 1;

  @override
  String get category => 'general';

  @override
  SettingsManifest get settingsManifest =>
      const SettingsManifest(engineKey: 'pair_match', definitions: []);

  @override
  EngineValidation validate(Map<String, Object?> config) {
    final pairs = config['pairs'];
    if (pairs is! List || pairs.length < 2 || pairs.length > 8) {
      return const EngineValidation.invalid(
        'pair_match needs between 2 and 8 pairs.',
      );
    }

    bool isValidItem(Object? item) {
      if (item is! Map) return false;
      final id = item['id'];
      final label = item['label'];
      return id is String &&
          id.isNotEmpty &&
          label is String &&
          label.isNotEmpty;
    }

    for (final pair in pairs) {
      if (pair is! Map ||
          !isValidItem(pair['left']) ||
          !isValidItem(pair['right'])) {
        return const EngineValidation.invalid(
          'Every pair needs a left and a right item with an id and a label.',
        );
      }
    }

    final distractors = config['distractors'];
    if (distractors != null) {
      if (distractors is! List || distractors.length > 4) {
        return const EngineValidation.invalid(
          'distractors allows at most 4 items.',
        );
      }
      for (final item in distractors) {
        if (!isValidItem(item)) {
          return const EngineValidation.invalid(
            'Every distractor needs an id and a label.',
          );
        }
      }
    }

    return const EngineValidation.valid();
  }

  @override
  Widget build(EngineContext context, Map<String, Object?> config) {
    return _PairMatchView(engine: context, config: config);
  }
}

class _PairMatchView extends StatefulWidget {
  const _PairMatchView({required this.engine, required this.config});

  final EngineContext engine;
  final Map<String, Object?> config;

  @override
  State<_PairMatchView> createState() => _PairMatchViewState();
}

class _PairMatchViewState extends State<_PairMatchView> {
  late final List<Map<String, Object?>> _pairs =
      (widget.config['pairs'] as List).cast<Map<String, Object?>>();
  late final Map<String, String> _rightToLeft = {
    for (final pair in _pairs)
      (pair['right'] as Map)['id'] as String:
          (pair['left'] as Map)['id'] as String,
  };
  late final List<Map<String, Object?>> _leftItems = _shuffledLefts();
  late final List<Map<String, Object?>> _rightItems = _shuffledRights();
  late final DateTime _startedAt = widget.engine.clock();

  String? _selectedLeftId;
  final Set<String> _matchedLeftIds = {};
  String? _flashWrongRightId;
  bool _awaitingFeedback = false;
  int _attempts = 0;

  List<Map<String, Object?>> _shuffledLefts() {
    final items = _pairs
        .map((p) => (p['left'] as Map).cast<String, Object?>())
        .toList();
    items.shuffle(widget.engine.random);
    return items;
  }

  List<Map<String, Object?>> _shuffledRights() {
    final rights = _pairs.map(
      (p) => (p['right'] as Map).cast<String, Object?>(),
    );
    final distractors = ((widget.config['distractors'] as List?) ?? const [])
        .cast<Map>()
        .map((m) => m.cast<String, Object?>());
    final items = [...rights, ...distractors];
    items.shuffle(widget.engine.random);
    return items;
  }

  void _selectLeft(String id) {
    if (_awaitingFeedback || _matchedLeftIds.contains(id)) return;
    setState(() {
      _selectedLeftId = _selectedLeftId == id ? null : id;
    });
  }

  Future<void> _tapRight(String rightId) async {
    final leftId = _selectedLeftId;
    if (leftId == null || _awaitingFeedback) return;

    final isCorrect = _rightToLeft[rightId] == leftId;
    setState(() {
      _awaitingFeedback = true;
      _attempts += 1;
    });

    await widget.engine.telemetry.logAttempt(
      answer: {'left': leftId, 'right': rightId},
      isCorrect: isCorrect,
    );

    if (isCorrect) {
      await widget.engine.feedback.correct();
      final done = {..._matchedLeftIds, leftId}.length == _pairs.length;
      setState(() {
        _matchedLeftIds.add(leftId);
        _selectedLeftId = null;
        _awaitingFeedback = false;
      });

      if (done) {
        await widget.engine.feedback.celebrate();
        widget.engine.onFinished(
          ExerciseResult(
            outcome: ExerciseOutcome.completed,
            attempts: _attempts,
            correct: _pairs.length,
            elapsedMs: widget.engine
                .clock()
                .difference(_startedAt)
                .inMilliseconds,
          ),
        );
      }
      return;
    }

    await widget.engine.feedback.incorrect();
    if (!mounted) return;
    setState(() => _flashWrongRightId = rightId);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _flashWrongRightId = null;
      _selectedLeftId = null;
      _awaitingFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (final item in _leftItems)
                  _PairTile(
                    label: item['label'] as String,
                    isSelected: _selectedLeftId == item['id'],
                    isMatched: _matchedLeftIds.contains(item['id']),
                    isWrong: false,
                    onTap: () => _selectLeft(item['id'] as String),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final item in _rightItems)
                  _PairTile(
                    label: item['label'] as String,
                    isSelected: false,
                    isMatched:
                        _rightToLeft[item['id']] != null &&
                        _matchedLeftIds.contains(_rightToLeft[item['id']]),
                    isWrong: _flashWrongRightId == item['id'],
                    onTap: () => _tapRight(item['id'] as String),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.label,
    required this.isSelected,
    required this.isMatched,
    required this.isWrong,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isMatched;
  final bool isWrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = VillagePalette.of(context);
    // Amber, never red: the design's "almost" (retry) state.
    final color = isWrong
        ? palette.retry
        : isMatched
        ? palette.success
        : isSelected
        ? Theme.of(context).colorScheme.primary
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isMatched ? null : onTap,
          style: color != null
              ? OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 2),
                )
              : null,
          child: Text(label),
        ),
      ),
    );
  }
}
