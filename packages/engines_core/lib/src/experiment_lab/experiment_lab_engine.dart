import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/pick_one.dart';

/// A scene the engine draws itself, so the science lessons need no art.
enum ExperimentScene { plant, water, mix }

/// What each scene can show. A lesson without a scene uses `image_ref`
/// pictures (or just the outcome's words).
const experimentLooks = {
  ExperimentScene.plant: {'dry', 'small', 'healthy', 'drowned'},
  ExperimentScene.water: {'ice', 'liquid', 'steam'},
  ExperimentScene.mix: {'dissolved', 'settled', 'floating'},
};

class ExperimentValue {
  const ExperimentValue({required this.id, required this.label});
  final String id;
  final String label;
}

class ExperimentVariable {
  const ExperimentVariable({
    required this.id,
    required this.label,
    required this.values,
  });
  final String id;
  final String label;
  final List<ExperimentValue> values;

  ExperimentValue value(String id) => values.firstWhere((v) => v.id == id);
}

class ExperimentOutcome {
  const ExperimentOutcome({required this.label, this.look, this.imageRef});
  final String label;
  final String? look;
  final String? imageRef;
}

class ExperimentContent {
  const ExperimentContent({
    required this.variables,
    required this.outcomes,
    required this.options,
    required this.correctId,
    required this.minRuns,
    this.scene,
    this.shuffle = true,
  });

  final ExperimentScene? scene;
  final List<ExperimentVariable> variables;

  /// Combination key (value ids joined by `|`, in variable order) → what
  /// happens.
  final Map<String, ExperimentOutcome> outcomes;
  final List<ExperimentValue> options;
  final String correctId;

  /// Different experiments to run before the conclusion can be checked.
  final int minRuns;
  final bool shuffle;

  List<String> get ids => [for (final o in options) o.id];

  ExperimentValue option(String id) => options.firstWhere((o) => o.id == id);

  static String keyOf(List<String> valueIds) => valueIds.join('|');

  /// "Eau : beaucoup, Lumière : soleil".
  String describe(String combo) {
    final ids = combo.split('|');
    return [
      for (var i = 0; i < variables.length; i++)
        '${variables[i].label} : ${variables[i].value(ids[i]).label}',
    ].join(', ');
  }
}

class ExperimentState {
  const ExperimentState({
    required this.settings,
    required this.minRuns,
    required this.pick,
    this.runs = const [],
  });

  /// The chosen value per variable, in variable order.
  final List<String> settings;

  /// Experiments run, as combination keys, oldest first, each once.
  final List<String> runs;
  final int minRuns;
  final PickState pick;

  String get current => ExperimentContent.keyOf(settings);

  /// The last run, which the result card shows.
  String? get shown => runs.isEmpty ? null : runs.last;

  bool get readyToConclude => runs.length >= minRuns;

  ExperimentState copyWith({
    List<String>? settings,
    List<String>? runs,
    PickState? pick,
  }) => ExperimentState(
    settings: settings ?? this.settings,
    runs: runs ?? this.runs,
    minRuns: minRuns,
    pick: pick ?? this.pick,
  );
}

sealed class ExperimentAction {
  const ExperimentAction();
}

class SetVariable extends ExperimentAction {
  const SetVariable(this.index, this.valueId);
  final int index;
  final String valueId;
}

class RunExperiment extends ExperimentAction {
  const RunExperiment();
}

class PickConclusion extends ExperimentAction {
  const PickConclusion(this.id);
  final String id;
}

/// "Petit scientifique" — the `experiment_lab` engine (app ADR 0083;
/// Hafid's catalogue B18, with ecosystem_sim B20's plant).
///
/// Change one or two things, run the experiment, see what happens, then
/// say what you found. The child sets each variable (water: none, a
/// little, a lot), presses "Essayer", and the result is drawn — a plant,
/// a pot of water, a glass with something stirred in — and written in a
/// notebook of every run. The conclusion is a choice of 2–4 sentences,
/// checked once at least `min_runs` different experiments have been run:
/// a conclusion is only science if it comes from trying.
///
/// The experiments themselves are never graded; only the conclusion is.
class ExperimentLabEngine
    implements
        LearningEngine<
          ExperimentContent,
          ExperimentState,
          ExperimentAction,
          SingleChoiceAnswer
        > {
  const ExperimentLabEngine();

  static const key = 'experiment_lab';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Every control is a spoken button, and each result is spoken in
    // words, so the drawing is never the only way to see what happened.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static List<ExperimentValue>? _values(
    Object? raw, {
    required int min,
    required int max,
  }) {
    if (raw is! List || raw.length < min || raw.length > max) return null;
    final out = <ExperimentValue>[];
    for (final v in raw) {
      final id = v is Map ? v['id'] : null;
      final label = v is Map ? v['label'] : null;
      if (id is! String ||
          id.isEmpty ||
          id.contains('|') ||
          label is! String ||
          label.trim().isEmpty ||
          out.any((o) => o.id == id)) {
        return null;
      }
      out.add(ExperimentValue(id: id, label: label));
    }
    return out;
  }

  @override
  ParseResult<ExperimentContent> parse(Map<String, Object?> config) {
    final rawScene = config['scene'];
    final scene = rawScene == null
        ? null
        : ExperimentScene.values.asNameMap()[rawScene];
    if (rawScene != null && scene == null) {
      return const ParseResult.invalid('scene is plant, water or mix.');
    }

    final rawVars = config['variables'];
    if (rawVars is! List || rawVars.isEmpty || rawVars.length > 2) {
      return const ParseResult.invalid('There are 1 or 2 variables.');
    }
    final variables = <ExperimentVariable>[];
    for (final v in rawVars) {
      final id = v is Map ? v['id'] : null;
      final label = v is Map ? v['label'] : null;
      final values = _values(v is Map ? v['values'] : null, min: 2, max: 4);
      if (id is! String ||
          label is! String ||
          label.trim().isEmpty ||
          values == null ||
          variables.any((x) => x.id == id)) {
        return const ParseResult.invalid(
          'A variable is {id, label, values} with 2 to 4 unique values.',
        );
      }
      variables.add(ExperimentVariable(id: id, label: label, values: values));
    }

    final combos = <String>[''];
    for (final v in variables) {
      final next = <String>[];
      for (final prefix in combos) {
        for (final value in v.values) {
          next.add(prefix.isEmpty ? value.id : '$prefix|${value.id}');
        }
      }
      combos
        ..clear()
        ..addAll(next);
    }

    final rawOutcomes = config['outcomes'];
    if (rawOutcomes is! List) {
      return const ParseResult.invalid('outcomes must be a list.');
    }
    final outcomes = <String, ExperimentOutcome>{};
    for (final o in rawOutcomes) {
      final when = o is Map ? o['when'] : null;
      final label = o is Map ? o['label'] : null;
      final look = o is Map ? o['look'] : null;
      final image = o is Map ? o['image_ref'] : null;
      if (when is! Map || label is! String || label.trim().isEmpty) {
        return const ParseResult.invalid(
          'An outcome is {when, label, look?, image_ref?}.',
        );
      }
      if (when.length != variables.length ||
          !variables.every((v) => v.values.any((x) => x.id == when[v.id]))) {
        return const ParseResult.invalid(
          'An outcome\'s when sets every variable to one of its values.',
        );
      }
      final combo = ExperimentContent.keyOf([
        for (final v in variables) when[v.id] as String,
      ]);
      if (outcomes.containsKey(combo)) {
        return const ParseResult.invalid('Two outcomes share the same when.');
      }
      if (look != null &&
          (scene == null ||
              look is! String ||
              !experimentLooks[scene]!.contains(look))) {
        return ParseResult.invalid(
          scene == null
              ? 'look needs a scene.'
              : 'look for $rawScene is one of ${experimentLooks[scene]!.join(', ')}.',
        );
      }
      if (image != null && image is! String) {
        return const ParseResult.invalid('image_ref is a string.');
      }
      outcomes[combo] = ExperimentOutcome(
        label: label,
        look: look as String?,
        imageRef: image as String?,
      );
    }
    if (outcomes.length != combos.length) {
      return const ParseResult.invalid(
        'Every combination of values needs exactly one outcome.',
      );
    }

    final options = _values(config['options'], min: 2, max: 4);
    if (options == null) {
      return const ParseResult.invalid(
        'There are 2 to 4 options of {id, label}.',
      );
    }
    final correct = config['correct'];
    if (correct is! String || !options.any((o) => o.id == correct)) {
      return const ParseResult.invalid('correct is one of the options.');
    }
    final minRuns = config['min_runs'] ?? math.min(2, combos.length);
    if (minRuns is! int || minRuns < 1 || minRuns > combos.length) {
      return const ParseResult.invalid(
        'min_runs is 1 to the number of combinations.',
      );
    }
    return ParseResult.ok(
      ExperimentContent(
        scene: scene,
        variables: List.unmodifiable(variables),
        outcomes: Map.unmodifiable(outcomes),
        options: List.unmodifiable(options),
        correctId: correct,
        minRuns: minRuns,
        shuffle: config['shuffle'] is bool ? config['shuffle']! as bool : true,
      ),
    );
  }

  @override
  ExperimentState initialize(ExperimentContent content, EngineSeed seed) =>
      ExperimentState(
        settings: [for (final v in content.variables) v.values.first.id],
        minRuns: content.minRuns,
        pick: PickOne.initialize(content.ids, seed, shuffle: content.shuffle),
      );

  @override
  Transition<ExperimentState> reduce(
    ExperimentState s,
    ExperimentAction action,
  ) {
    if (s.pick.solved) return Transition(s);
    switch (action) {
      case SetVariable(:final index, :final valueId):
        if (index < 0 ||
            index >= s.settings.length ||
            s.settings[index] == valueId) {
          return Transition(s);
        }
        return Transition(
          s.copyWith(settings: [...s.settings]..[index] = valueId),
        );
      case RunExperiment():
        final combo = s.current;
        return Transition(
          s.copyWith(runs: [...s.runs.where((r) => r != combo), combo]),
          [
            InteractionEvent('experiment_run', {'item_id': combo}),
          ],
        );
      case PickConclusion(:final id):
        if (!s.readyToConclude) return Transition(s);
        final t = PickOne.reduce(s.pick, PickChoice(id));
        return Transition(s.copyWith(pick: t.state), t.events);
    }
  }

  @override
  SingleChoiceAnswer? extractAnswer(ExperimentState s) =>
      s.readyToConclude ? PickOne.extractAnswer(s.pick) : null;

  @override
  ExperimentState applyFeedback(ExperimentState s, EvaluationResult result) =>
      s.copyWith(pick: PickOne.applyFeedback(s.pick, result));

  @override
  Map<String, Object?> snapshot(ExperimentState s) => {
    'settings': s.settings,
    'runs': s.runs,
    'pick': PickOne.snapshot(s.pick),
  };

  @override
  ExperimentState? restore(
    ExperimentContent content,
    Map<String, Object?> snap,
  ) {
    try {
      final settings = (snap['settings'] as List).cast<String>();
      final runs = (snap['runs'] as List).cast<String>();
      final pick = PickOne.restore(
        (snap['pick']! as Map).cast<String, Object?>(),
        ids: content.ids,
        correctId: content.correctId,
      );
      if (pick == null ||
          settings.length != content.variables.length ||
          !content.outcomes.containsKey(ExperimentContent.keyOf(settings)) ||
          !runs.every(content.outcomes.containsKey) ||
          runs.toSet().length != runs.length ||
          (pick.selected != null && runs.length < content.minRuns)) {
        return null;
      }
      return ExperimentState(
        settings: List.unmodifiable(settings),
        runs: List.unmodifiable(runs),
        minRuns: content.minRuns,
        pick: pick,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<ExperimentContent, ExperimentState, ExperimentAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final p = VillagePalette.of(context);
    final shown = s.shown;
    final outcome = shown == null ? null : c.outcomes[shown];
    final open = view.enabled && !s.pick.solved;
    final label = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 14,
      color: p.inkMuted,
    );

    final controls = [
      for (var i = 0; i < c.variables.length; i++) ...[
        Text(c.variables[i].label, style: label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in c.variables[i].values)
              SizedBox(
                width: 132,
                child: Semantics(
                  label: '${c.variables[i].label} : ${v.label}',
                  selected: s.settings[i] == v.id,
                  button: true,
                  excludeSemantics: true,
                  child: AnswerTile(
                    key: ValueKey('exp-${c.variables[i].id}-${v.id}'),
                    label: v.label,
                    state: s.settings[i] == v.id
                        ? AnswerTileState.picked
                        : AnswerTileState.idle,
                    onTap: open
                        ? () => view.dispatch(SetVariable(i, v.id))
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const ValueKey('exp-run'),
          onPressed: open ? () => view.dispatch(const RunExperiment()) : null,
          icon: const Icon(Icons.science_rounded),
          label: Text(fr ? 'Essayer' : 'Try it'),
        ),
      ),
    ];

    final result = Semantics(
      key: const ValueKey('exp-result'),
      liveRegion: true,
      label: outcome == null
          ? (fr
                ? 'Pas encore d’essai. Choisis, puis appuie sur Essayer.'
                : 'No experiment yet. Choose, then press Try it.')
          : '${c.describe(shown!)} : ${outcome.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: Radii.cardMd,
          border: Border.all(color: p.line, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 150,
              child: outcome == null
                  ? Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 64,
                          color: p.line,
                        ),
                      ),
                    )
                  : outcome.look != null
                  ? CustomPaint(
                      painter: _ScenePainter(c.scene!, outcome.look!, p),
                      size: Size.infinite,
                    )
                  : outcome.imageRef != null
                  ? ContentImage(
                      ref: outcome.imageRef!,
                      fallback: const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            Text(
              outcome?.label ??
                  (fr ? 'Fais un essai pour voir.' : 'Try it to find out.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );

    final notebook = s.runs.isEmpty
        ? const SizedBox.shrink()
        : Column(
            key: const ValueKey('exp-notebook'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(fr ? 'Mon carnet' : 'My notebook', style: label),
              const SizedBox(height: 4),
              for (final r in s.runs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${c.describe(r)} → ${c.outcomes[r]!.label}',
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: p.ink,
                    ),
                  ),
                ),
            ],
          );

    final remaining = c.minRuns - s.runs.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 600
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: controls,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: result),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...controls,
                          const SizedBox(height: 12),
                          result,
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              notebook,
              const SizedBox(height: 16),
              Text(
                fr ? 'Ce que j’ai découvert' : 'What I found out',
                style: label,
              ),
              const SizedBox(height: 6),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    fr
                        ? 'Fais encore $remaining essai${remaining > 1 ? 's' : ''} différent${remaining > 1 ? 's' : ''} avant de répondre.'
                        : 'Try $remaining more different experiment${remaining > 1 ? 's' : ''} before you answer.',
                    key: const ValueKey('exp-remaining'),
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: p.inkMuted,
                    ),
                  ),
                ),
              PickOne.choices(
                state: s.pick,
                enabled: view.enabled && s.readyToConclude,
                fr: fr,
                label: (id) => c.option(id).label,
                onPick: (id) => view.dispatch(PickConclusion(id)),
                keyPrefix: 'exp-choice',
                width: 300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three built-in scenes. Plain shapes, readable at a glance; each
/// look differs by more than colour.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.look, this.p);
  final ExperimentScene scene;
  final String look;
  final VillagePalette p;

  static const _soil = Color(0xFF7A4E2D);
  static const _pot = Color(0xFFC8693B);
  static const _leaf = Color(0xFF2FA35A);
  static const _dry = Color(0xFFB08A4A);
  static const _water = Color(0xFF6FB7F0);
  static const _ice = Color(0xFFDDF1FF);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h = size.height;
    final edge = Paint()
      ..color = p.ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    switch (scene) {
      case ExperimentScene.plant:
        final pot = Path()
          ..moveTo(cx - 40, h - 46)
          ..lineTo(cx + 40, h - 46)
          ..lineTo(cx + 30, h - 4)
          ..lineTo(cx - 30, h - 4)
          ..close();
        canvas
          ..drawPath(pot, Paint()..color = _pot)
          ..drawPath(pot, edge)
          ..drawRect(
            Rect.fromLTRB(cx - 38, h - 52, cx + 38, h - 44),
            Paint()..color = _soil,
          );
        if (look == 'drowned') {
          canvas.drawOval(
            Rect.fromLTRB(cx - 36, h - 58, cx + 36, h - 46),
            Paint()..color = _water,
          );
        }
        final (height, leaves, color, droop) = switch (look) {
          'dry' => (50.0, 2, _dry, true),
          'small' => (45.0, 2, _leaf, false),
          'drowned' => (60.0, 3, const Color(0xFFC9C04A), true),
          _ => (78.0, 4, _leaf, false),
        };
        final stem = Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final top = Offset(cx + (droop ? 18 : 0), h - 52 - height);
        canvas.drawLine(Offset(cx, h - 52), top, stem);
        for (var i = 0; i < leaves; i++) {
          final t = (i + 1) / (leaves + 1);
          final at = Offset.lerp(Offset(cx, h - 52), top, t)!;
          final side = i.isEven ? 1 : -1;
          canvas.save();
          canvas.translate(at.dx, at.dy);
          // Upright leaves angle up; wilted ones hang down.
          canvas.rotate(switch ((side, droop)) {
            (1, false) => -0.5,
            (_, false) => math.pi + 0.5,
            (1, true) => 0.9,
            _ => math.pi - 0.9,
          });
          canvas.drawOval(
            const Rect.fromLTWH(0, -6, 26, 12),
            Paint()..color = color,
          );
          canvas.restore();
        }
        if (look == 'healthy') {
          canvas.drawCircle(top, 10, Paint()..color = const Color(0xFFF5C02B));
        }
      case ExperimentScene.water:
        final pot = RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - 55, h - 70, cx + 55, h - 6),
          const Radius.circular(10),
        );
        canvas.drawRRect(pot, Paint()..color = p.surface);
        switch (look) {
          case 'ice':
            for (final dx in [-30.0, 0.0, 30.0]) {
              final cube = RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(cx + dx, h - 28),
                  width: 24,
                  height: 24,
                ),
                const Radius.circular(4),
              );
              canvas
                ..drawRRect(cube, Paint()..color = _ice)
                ..drawRRect(cube, edge);
            }
          case 'liquid':
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTRB(cx - 53, h - 50, cx + 53, h - 8),
                const Radius.circular(8),
              ),
              Paint()..color = _water,
            );
          default: // steam: a little water left, and wisps rising
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTRB(cx - 53, h - 22, cx + 53, h - 8),
                const Radius.circular(6),
              ),
              Paint()..color = _water,
            );
            final wisp = Paint()
              ..color = p.inkMuted.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round;
            for (final dx in [-25.0, 0.0, 25.0]) {
              final path = Path()..moveTo(cx + dx, h - 78);
              for (var k = 1; k <= 3; k++) {
                path.quadraticBezierTo(
                  cx + dx + (k.isOdd ? 10 : -10),
                  h - 78 - k * 14 + 7,
                  cx + dx,
                  h - 78 - k * 14,
                );
              }
              canvas.drawPath(path, wisp);
            }
        }
        canvas.drawRRect(pot, edge);
      case ExperimentScene.mix:
        final glass = Path()
          ..moveTo(cx - 45, 12)
          ..lineTo(cx - 36, h - 6)
          ..lineTo(cx + 36, h - 6)
          ..lineTo(cx + 45, 12);
        final water = Path()
          ..moveTo(cx - 42, 40)
          ..lineTo(cx - 36.5, h - 8)
          ..lineTo(cx + 36.5, h - 8)
          ..lineTo(cx + 42, 40)
          ..close();
        canvas.drawPath(
          water,
          Paint()
            ..color = look == 'dissolved'
                ? const Color(0xFFB9A0E8)
                : _water.withValues(alpha: 0.6),
        );
        final grains = Paint()..color = const Color(0xFF8A6A3A);
        if (look == 'settled') {
          for (var i = 0; i < 14; i++) {
            canvas.drawCircle(
              Offset(cx - 30 + (i * 37 % 60), h - 14 - (i % 3) * 4.0),
              3.5,
              grains,
            );
          }
        }
        if (look == 'floating') {
          canvas.drawRect(
            Rect.fromLTRB(cx - 41.5, 40, cx + 41.5, 54),
            Paint()..color = const Color(0xFFF5C02B),
          );
        }
        canvas.drawPath(glass, edge);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene != scene || old.look != look || old.p != p;
}

/// Grades the conclusion. The experiments are free; only what the child
/// concludes from them is checked.
class ExperimentLabEvaluator
    implements Evaluator<ExperimentContent, SingleChoiceAnswer> {
  const ExperimentLabEvaluator();

  @override
  String get engineKey => ExperimentLabEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    ExperimentContent content,
    SingleChoiceAnswer answer,
    EvaluationContext ctx,
  ) => PickOne.evaluate(
    engineKey: engineKey,
    ids: content.ids,
    correctId: content.correctId,
    answer: answer,
    ctx: ctx,
  );
}
