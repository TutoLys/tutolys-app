import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';

/// Who's watching, and where. Drawn in code.
enum StageRoom { carpet, classroom, gym }

enum StageAudience { friends, classmates, school, younger }

/// How the audience reacts to one control's choice.
enum StageReaction {
  /// Everything's fine: smiles.
  happy,

  /// Too quiet: the back row cups their ears.
  cantHear,

  /// Too loud or too fast: hands over ears, or dizzy faces.
  tooMuch,

  /// Lost: puzzled faces.
  puzzled,

  /// Bored: a yawn.
  bored,
}

sealed class StageControl {
  const StageControl(this.id, this.label);
  final String id;
  final String label;
}

/// Put the parts of the talk in order.
class StageOrder extends StageControl {
  const StageOrder(
    super.id,
    super.label, {
    required this.parts,
    required this.wrong,
  });

  /// In the right order: hello and topic, picture, key lines, ending, thanks.
  final List<(String, String)> parts;
  final StageReaction wrong;
}

/// A stop on a scale with a picture at each stop (voice volume, pace).
class StageSlider extends StageControl {
  const StageSlider(
    super.id,
    super.label, {
    required this.stops,
    required this.lo,
    required this.hi,
    required this.start,
    required this.below,
    required this.above,
    this.icon = 'volume',
  });

  /// One label per stop, low to high ("chuchoter", …, "crier").
  final List<String> stops;

  /// The right stops, inclusive (0-based).
  final int lo;
  final int hi;
  final int start;
  final StageReaction below;
  final StageReaction above;

  /// `volume` or `pace`: which pictures the stops get.
  final String icon;
}

/// Choose one option (face the audience, the text version, how to hold
/// the picture).
class StageChoice extends StageControl {
  const StageChoice(
    super.id,
    super.label, {
    required this.options,
    required this.correct,
    required this.wrong,
  });
  final List<(String, String)> options;
  final Set<String> correct;
  final StageReaction wrong;
}

class StageContent {
  const StageContent({
    required this.room,
    required this.audience,
    required this.controls,
    this.reactions = const {},
  });

  final StageRoom room;
  final StageAudience audience;
  final List<StageControl> controls;

  /// Control id → what the audience says when it goes wrong (and `ok`
  /// for the applause), in the lesson's words.
  final Map<String, String> reactions;

  StageControl control(String id) => controls.firstWhere((c) => c.id == id);
}

class StageState {
  const StageState({
    required this.content,
    required this.order,
    required this.values,
    this.picks = const {},
    this.locked = const {},
    this.tried = const {},
    this.reactions = const {},
    this.checked = false,
    this.solved = false,
  });

  final StageContent content;

  /// The parts as the child has them.
  final List<String> order;

  /// Slider id → its stop.
  final Map<String, int> values;

  /// Choice id → option id.
  final Map<String, String> picks;
  final Set<String> locked;

  /// `choice|option` checked wrong.
  final Set<String> tried;

  /// After a check: control id → how the audience took it.
  final Map<String, StageReaction> reactions;
  final bool checked;
  final bool solved;

  StageState copyWith({
    List<String>? order,
    Map<String, int>? values,
    Map<String, String>? picks,
    Set<String>? locked,
    Set<String>? tried,
    Map<String, StageReaction>? reactions,
    bool? checked,
    bool? solved,
  }) => StageState(
    content: content,
    order: order ?? this.order,
    values: values ?? this.values,
    picks: picks ?? this.picks,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
    reactions: reactions ?? this.reactions,
    checked: checked ?? this.checked,
    solved: solved ?? this.solved,
  );
}

sealed class StageAction {
  const StageAction();
}

/// Move a part one place up (-1) or down (+1).
class MoveStagePart extends StageAction {
  const MoveStagePart(this.partId, this.by);
  final String partId;
  final int by;
}

class SetStageSlider extends StageAction {
  const SetStageSlider(this.controlId, this.stop);
  final String controlId;
  final int stop;
}

class PickStageOption extends StageAction {
  const PickStageOption(this.controlId, this.optionId);
  final String controlId;
  final String optionId;
}

/// "Le théâtre du village" — the `stage_presenter` engine (app ADR 0091;
/// the Questions Maker's ELA request 4, "Presents to an audience").
///
/// The scenario sets the room and who's watching — three friends on the
/// carpet, the class, the whole school in the gym, the little ones. The
/// child plans the presentation: the order of its parts, facing the
/// audience, a voice volume and a pace on picture sliders (never recorded:
/// D8), the text version, how to hold the picture. Each control is graded
/// against the scenario's target, and the audience shows the result: the
/// back row cups its ears, the little ones yawn, everyone smiles.
///
/// **Proxy evidence**: planned choices, not a performance.
class StagePresenterEngine
    implements
        LearningEngine<StageContent, StageState, StageAction, BlanksAnswer>,
        RevealsAfterFeedback<StageState> {
  const StagePresenterEngine();

  static const key = 'stage_presenter';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    // Sliders, ↑ ↓ buttons and tiles are all keyboard-reachable, and the
    // audience's reaction is spoken in words.
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String? _text(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;

  static StageReaction? _reaction(Object? raw, StageReaction fallback) =>
      raw == null ? fallback : StageReaction.values.asNameMap()[_snake(raw)];

  static String? _snake(Object? raw) => raw is! String
      ? null
      : raw.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

  static List<(String, String)>? _pairs(
    Object? raw, {
    int min = 2,
    int max = 6,
  }) {
    if (raw is! List || raw.length < min || raw.length > max) return null;
    final out = <(String, String)>[];
    for (final x in raw) {
      final id = x is Map ? x['id'] : null;
      final label = x is Map ? _text(x['label']) : null;
      if (id is! String || id.isEmpty || label == null) return null;
      if (out.any((o) => o.$1 == id)) return null;
      out.add((id, label));
    }
    return out;
  }

  @override
  ParseResult<StageContent> parse(Map<String, Object?> config) {
    final scenario = config['scenario'];
    final room = StageRoom.values
        .asNameMap()[scenario is Map ? scenario['room'] : null];
    final audience = StageAudience.values
        .asNameMap()[scenario is Map ? scenario['audience'] : null];
    if (room == null || audience == null) {
      return const ParseResult.invalid(
        'scenario is {room: carpet, classroom or gym; audience: friends, '
        'classmates, school or younger}.',
      );
    }
    final raw = config['controls'];
    if (raw is! List || raw.isEmpty || raw.length > 6) {
      return const ParseResult.invalid('There are 1 to 6 controls.');
    }
    final controls = <StageControl>[];
    for (final c in raw) {
      if (c is! Map) {
        return const ParseResult.invalid('A control is an object.');
      }
      final id = c['id'];
      final label = _text(c['label']);
      if (id is! String || id.isEmpty || label == null) {
        return const ParseResult.invalid('A control needs an id and a label.');
      }
      if (controls.any((x) => x.id == id)) {
        return const ParseResult.invalid('Control ids are unique.');
      }
      switch (c['type']) {
        case 'order':
          final parts = _pairs(c['parts'], min: 3);
          final wrong = _reaction(c['wrong'], StageReaction.puzzled);
          if (parts == null || wrong == null) {
            return const ParseResult.invalid(
              'An order control has 3 to 6 parts {id, label}, in the right '
              'order.',
            );
          }
          if (controls.any((x) => x is StageOrder)) {
            return const ParseResult.invalid('Only one order control.');
          }
          controls.add(StageOrder(id, label, parts: parts, wrong: wrong));
        case 'slider':
          final stops = c['stops'];
          final target = c['target'];
          final start = c['start'] ?? 0;
          final below = _reaction(c['below'], StageReaction.cantHear);
          final above = _reaction(c['above'], StageReaction.tooMuch);
          final icon = c['icon'] ?? 'volume';
          if (stops is! List ||
              stops.length < 3 ||
              stops.length > 5 ||
              !stops.every((x) => _text(x) != null) ||
              target is! List ||
              target.length != 2 ||
              target[0] is! int ||
              target[1] is! int ||
              start is! int ||
              below == null ||
              above == null ||
              (icon != 'volume' && icon != 'pace')) {
            return const ParseResult.invalid(
              'A slider has 3 to 5 stops (labels), target [lo, hi] (stop '
              'indexes), start, icon volume or pace.',
            );
          }
          final lo = target[0] as int;
          final hi = target[1] as int;
          if (lo < 0 || hi >= stops.length || lo > hi) {
            return const ParseResult.invalid('target is inside the stops.');
          }
          if (lo == 0 && hi == stops.length - 1) {
            return const ParseResult.invalid(
              'Every stop is right: nothing to choose.',
            );
          }
          if (start < 0 ||
              start >= stops.length ||
              (start >= lo && start <= hi)) {
            return const ParseResult.invalid(
              'start is a stop outside the target, or there is nothing to do.',
            );
          }
          controls.add(
            StageSlider(
              id,
              label,
              stops: stops.cast<String>(),
              lo: lo,
              hi: hi,
              start: start,
              below: below,
              above: above,
              icon: icon as String,
            ),
          );
        case 'choice':
          final options = _pairs(c['options'], max: 4);
          final correct = c['correct'];
          final wrong = _reaction(c['wrong'], StageReaction.puzzled);
          if (options == null ||
              correct is! List ||
              correct.isEmpty ||
              wrong == null ||
              !correct.every((x) => options.any((o) => o.$1 == x))) {
            return const ParseResult.invalid(
              'A choice has 2 to 4 options and correct option ids.',
            );
          }
          if (correct.length == options.length) {
            return const ParseResult.invalid(
              'Every option is right: nothing to choose.',
            );
          }
          controls.add(
            StageChoice(
              id,
              label,
              options: options,
              correct: correct.cast<String>().toSet(),
              wrong: wrong,
            ),
          );
        default:
          return const ParseResult.invalid('type is order, slider or choice.');
      }
    }
    final reactions = <String, String>{};
    final rawReactions = config['reactions'];
    if (rawReactions is Map) {
      for (final e in rawReactions.entries) {
        final text = _text(e.value);
        if (e.key is! String || text == null) {
          return const ParseResult.invalid('reactions maps ids to words.');
        }
        reactions[e.key as String] = text;
      }
    }
    return ParseResult.ok(
      StageContent(
        room: room,
        audience: audience,
        controls: List.unmodifiable(controls),
        reactions: Map.unmodifiable(reactions),
      ),
    );
  }

  @override
  StageState initialize(StageContent content, EngineSeed seed) {
    final order = <String>[];
    for (final c in content.controls) {
      if (c is StageOrder) {
        order.addAll(c.parts.map((p) => p.$1));
        // Shuffle until it isn't already right.
        final random = seed.random();
        do {
          order.shuffle(random);
        } while (order.indexed.every((e) => e.$2 == c.parts[e.$1].$1));
      }
    }
    return StageState(
      content: content,
      order: List.unmodifiable(order),
      values: {
        for (final c in content.controls)
          if (c is StageSlider) c.id: c.start,
      },
    );
  }

  @override
  Transition<StageState> reduce(StageState s, StageAction action) {
    if (s.solved) return Transition(s);
    final c = s.content;
    switch (action) {
      case MoveStagePart(:final partId, :final by):
        final orderControl = c.controls.whereType<StageOrder>().firstOrNull;
        final i = s.order.indexOf(partId);
        final j = i + by;
        if (orderControl == null ||
            s.locked.contains(orderControl.id) ||
            i < 0 ||
            j < 0 ||
            j >= s.order.length ||
            by.abs() != 1) {
          return Transition(s);
        }
        final order = [...s.order]
          ..[i] = s.order[j]
          ..[j] = partId;
        return Transition(s.copyWith(order: order), [
          InteractionEvent('item_placed', {'item_id': partId, 'value': j}),
        ]);
      case SetStageSlider(:final controlId, :final stop):
        final control = c.controls
            .whereType<StageSlider>()
            .where((x) => x.id == controlId)
            .firstOrNull;
        if (control == null ||
            s.locked.contains(controlId) ||
            stop < 0 ||
            stop >= control.stops.length ||
            s.values[controlId] == stop) {
          return Transition(s);
        }
        return Transition(s.copyWith(values: {...s.values, controlId: stop}), [
          InteractionEvent('item_placed', {
            'item_id': controlId,
            'value': stop,
          }),
        ]);
      case PickStageOption(:final controlId, :final optionId):
        final control = c.controls
            .whereType<StageChoice>()
            .where((x) => x.id == controlId)
            .firstOrNull;
        if (control == null ||
            s.locked.contains(controlId) ||
            !control.options.any((o) => o.$1 == optionId) ||
            s.tried.contains('$controlId|$optionId') ||
            s.picks[controlId] == optionId) {
          return Transition(s);
        }
        return Transition(
          s.copyWith(picks: {...s.picks, controlId: optionId}),
          [
            InteractionEvent('option_selected', {
              'option_id': optionId,
              'item_id': controlId,
            }),
          ],
        );
    }
  }

  @override
  BlanksAnswer? extractAnswer(StageState s) {
    final c = s.content;
    if (s.solved ||
        c.controls.whereType<StageChoice>().any(
          (x) => !s.picks.containsKey(x.id),
        )) {
      return null;
    }
    return BlanksAnswer({
      for (final control in c.controls)
        control.id: switch (control) {
          StageOrder() => s.order.join(','),
          StageSlider() => '${s.values[control.id]}',
          StageChoice() => s.picks[control.id]!,
        },
    });
  }

  /// How the audience takes one control's answer.
  static StageReaction react(StageControl control, String? value) {
    switch (control) {
      case StageOrder(:final parts, :final wrong):
        return value == parts.map((p) => p.$1).join(',')
            ? StageReaction.happy
            : wrong;
      case StageSlider(:final lo, :final hi, :final below, :final above):
        final v = int.tryParse(value ?? '') ?? -1;
        return v < lo
            ? below
            : v > hi
            ? above
            : StageReaction.happy;
      case StageChoice(:final correct, :final wrong):
        return correct.contains(value) ? StageReaction.happy : wrong;
    }
  }

  @override
  /// The audience reacting after a check is the moment (fix 3).
  @override
  List<RevealEvent> revealsAfterFeedback(
    StageState before,
    StageState after,
    EvaluationResult result,
  ) => after.checked && after.reactions.isNotEmpty
      ? [RevealEvent('reaction')]
      : const [];

  @override
  StageState applyFeedback(StageState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final answer = extractAnswer(s.copyWith(solved: false))!;
    final locked = {...s.locked};
    final tried = {...s.tried};
    final picks = {...s.picks};
    final reactions = <String, StageReaction>{};
    for (final control in s.content.controls) {
      reactions[control.id] = react(control, answer.blanks[control.id]);
      if (result.itemResults[control.id] == true) {
        locked.add(control.id);
      } else if (control is StageChoice) {
        tried.add('${control.id}|${picks[control.id]}');
        picks.remove(control.id);
      }
    }
    return s.copyWith(
      locked: locked,
      tried: tried,
      picks: picks,
      reactions: reactions,
      checked: true,
      solved: result.outcome == Outcome.correct,
    );
  }

  @override
  Map<String, Object?> snapshot(StageState s) => {
    'order': s.order,
    'values': s.values,
    'picks': s.picks,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
    'reactions': {for (final e in s.reactions.entries) e.key: e.value.name},
    'checked': s.checked,
    'solved': s.solved,
  };

  @override
  StageState? restore(StageContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final orderControl = content.controls.whereType<StageOrder>().firstOrNull;
      final parts =
          orderControl?.parts.map((p) => p.$1).toSet() ?? const <String>{};
      if (order.length != parts.length || !order.every(parts.contains)) {
        return null;
      }
      final values = Map<String, int>.from(
        (snap['values'] as Map?) ?? const {},
      );
      final picks = Map<String, String>.from(
        (snap['picks'] as Map?) ?? const {},
      );
      for (final control in content.controls) {
        switch (control) {
          case StageSlider(:final stops):
            final v = values[control.id];
            if (v == null || v < 0 || v >= stops.length) return null;
          case StageChoice(:final options):
            final p = picks[control.id];
            if (p != null && !options.any((o) => o.$1 == p)) return null;
          case StageOrder():
            break;
        }
      }
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      if (!locked.every((id) => content.controls.any((x) => x.id == id))) {
        return null;
      }
      return StageState(
        content: content,
        order: List.unmodifiable(order),
        values: values,
        picks: picks,
        locked: locked,
        tried: ((snap['tried'] as List?) ?? const []).cast<String>().toSet(),
        reactions: {
          for (final e in ((snap['reactions'] as Map?) ?? const {}).entries)
            e.key as String: StageReaction.values.byName(e.value as String),
        },
        checked: snap['checked'] == true,
        solved: snap['solved'] == true,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<StageContent, StageState, StageAction> view,
  ) => _StageView(view: view);
}

class _StageView extends StatelessWidget {
  const _StageView({required this.view});
  final EngineView<StageContent, StageState, StageAction> view;

  static String _says(StageReaction r, bool fr) => switch (r) {
    StageReaction.happy => fr ? 'Tout le monde sourit.' : 'Everyone smiles.',
    StageReaction.cantHear =>
      fr ? 'Au fond, on n’entend rien !' : 'At the back, they can’t hear!',
    StageReaction.tooMuch =>
      fr ? 'Ouille, c’est trop !' : 'Ouch, that’s too much!',
    StageReaction.puzzled =>
      fr ? 'Le public ne comprend pas.' : 'The audience is lost.',
    StageReaction.bored => fr ? 'Quelqu’un bâille…' : 'Someone yawns…',
  };

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final c = view.content;
    final s = view.state;
    final p = VillagePalette.of(context);
    final heading = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: p.inkMuted,
    );

    // The worst reaction is the one the room shows.
    final worst = s.reactions.values
        .where((r) => r != StageReaction.happy)
        .firstOrNull;
    final roomMood = !s.checked ? null : (worst ?? StageReaction.happy);
    final said = !s.checked
        ? (fr ? 'Le public t’attend.' : 'The audience is waiting.')
        : [
            for (final control in c.controls)
              if (s.reactions[control.id] case final r?
                  when r != StageReaction.happy)
                c.reactions[control.id] ?? _says(r, fr),
            if (worst == null)
              c.reactions['ok'] ?? _says(StageReaction.happy, fr),
          ].join(' ');

    final children = <Widget>[
      Semantics(
        key: const ValueKey('stage-room'),
        label: said,
        liveRegion: true,
        excludeSemantics: true,
        child: AspectRatio(
          aspectRatio: 2.2,
          child: ClipRRect(
            borderRadius: Radii.cardMd,
            child: CustomPaint(
              painter: _RoomPainter(c.room, c.audience, roomMood, p),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      ExcludeSemantics(
        child: Text(
          said,
          key: const ValueKey('stage-said'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: p.ink,
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];

    for (final control in c.controls) {
      final locked = s.locked.contains(control.id);
      final open = view.enabled && !locked && !s.solved;
      children
        ..add(Text(control.label, style: heading))
        ..add(const SizedBox(height: 6));
      switch (control) {
        case StageOrder(:final parts):
          final labels = {for (final (id, label) in parts) id: label};
          for (final (i, id) in s.order.indexed) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: AnswerTile(
                        key: ValueKey('stage-part-$id'),
                        label: '${i + 1}. ${labels[id]}',
                        state: locked
                            ? AnswerTileState.correct
                            : AnswerTileState.idle,
                        onTap: null,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('stage-up-$id'),
                      tooltip: fr ? 'Monter' : 'Move up',
                      onPressed: open && i > 0
                          ? () => view.dispatch(MoveStagePart(id, -1))
                          : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      key: ValueKey('stage-down-$id'),
                      tooltip: fr ? 'Descendre' : 'Move down',
                      onPressed: open && i < s.order.length - 1
                          ? () => view.dispatch(MoveStagePart(id, 1))
                          : null,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
              ),
            );
          }
        case StageSlider(:final stops, :final icon):
          final v = s.values[control.id]!;
          final icons = icon == 'pace'
              ? const [
                  Icons.directions_walk_rounded,
                  Icons.directions_run_rounded,
                  Icons.speed_rounded,
                ]
              : const [
                  Icons.volume_mute_rounded,
                  Icons.volume_down_rounded,
                  Icons.volume_up_rounded,
                ];
          children.add(
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < stops.length; i++)
                      ExcludeSemantics(
                        child: Icon(
                          icons[(i *
                                  (icons.length - 1) /
                                  math.max(1, stops.length - 1))
                              .round()],
                          color: i == v ? p.quebecBlue : p.inkMuted,
                          size: 20.0 + 4 * i,
                        ),
                      ),
                  ],
                ),
                Slider(
                  key: ValueKey('stage-slider-${control.id}'),
                  value: v.toDouble(),
                  max: (stops.length - 1).toDouble(),
                  divisions: stops.length - 1,
                  label: stops[v],
                  semanticFormatterCallback: (x) => stops[x.round()],
                  onChanged: open
                      ? (x) =>
                            view.dispatch(SetStageSlider(control.id, x.round()))
                      : null,
                ),
                Text(
                  stops[v],
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: p.ink,
                  ),
                ),
              ],
            ),
          );
        case StageChoice(:final options):
          for (final (id, label) in options) {
            final picked = s.picks[control.id] == id;
            final tried = s.tried.contains('${control.id}|$id');
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AnswerTile(
                  key: ValueKey('stage-option-${control.id}-$id'),
                  label: label,
                  state: picked
                      ? (locked
                            ? AnswerTileState.correct
                            : AnswerTileState.picked)
                      : tried
                      ? AnswerTileState.retry
                      : AnswerTileState.idle,
                  semanticsState: tried
                      ? (fr ? 'déjà essayé' : 'already tried')
                      : null,
                  onTap: open && !tried
                      ? () => view.dispatch(PickStageOption(control.id, id))
                      : null,
                ),
              ),
            );
          }
      }
      children.add(const SizedBox(height: 12));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// The room from the back: rows of heads facing a small stage. A reaction
/// changes the faces, and the back row's hands.
class _RoomPainter extends CustomPainter {
  _RoomPainter(this.room, this.audience, this.mood, this.p);
  final StageRoom room;
  final StageAudience audience;
  final StageReaction? mood;
  final VillagePalette p;

  static const _skins = [
    Color(0xFFF2C9A0),
    Color(0xFFC68B59),
    Color(0xFF8D5524),
    Color(0xFFFFDBAC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final (floor, wall) = switch (room) {
      StageRoom.carpet => (const Color(0xFFB7D7F0), const Color(0xFFFFF7E8)),
      StageRoom.classroom => (const Color(0xFFE8D7B9), const Color(0xFFEFF6FF)),
      StageRoom.gym => (const Color(0xFFD9A066), const Color(0xFFE6E9EF)),
    };
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), Paint()..color = wall)
      ..drawRect(
        Rect.fromLTWH(0, h * 0.45, w, h * 0.55),
        Paint()..color = floor,
      );
    // The stage and the presenter (drawn simply: the child, holding a
    // picture).
    final stage = Rect.fromCenter(
      center: Offset(w / 2, h * 0.3),
      width: w * 0.3,
      height: h * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stage, const Radius.circular(6)),
      Paint()..color = p.gold,
    );
    final me = Offset(w / 2, h * 0.17);
    canvas
      ..drawCircle(me, h * 0.06, Paint()..color = _skins[0])
      ..drawRect(
        Rect.fromCenter(
          center: me + Offset(0, h * 0.09),
          width: h * 0.08,
          height: h * 0.1,
        ),
        Paint()..color = p.quebecBlue,
      )
      ..drawRect(
        Rect.fromLTWH(me.dx + h * 0.06, me.dy, h * 0.12, h * 0.09),
        Paint()..color = Colors.white,
      )
      ..drawRect(
        Rect.fromLTWH(me.dx + h * 0.06, me.dy, h * 0.12, h * 0.09),
        Paint()
          ..color = p.ink.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

    final (rows, perRow, scale) = switch (audience) {
      StageAudience.friends => (1, 3, 1.0),
      StageAudience.classmates => (3, 6, 0.85),
      StageAudience.school => (4, 10, 0.6),
      StageAudience.younger => (2, 5, 0.75),
    };
    for (var r = 0; r < rows; r++) {
      final y = h * 0.55 + (r + 0.5) * (h * 0.42 / rows);
      final radius = h * 0.06 * scale * (1 + r * 0.15);
      final back = r == rows - 1;
      for (var k = 0; k < perRow; k++) {
        final x = w * (k + 0.5) / perRow;
        final at = Offset(x, y);
        canvas.drawCircle(
          at,
          radius,
          Paint()..color = _skins[(r * 7 + k) % _skins.length],
        );
        _face(canvas, at, radius, back);
      }
    }
  }

  void _face(Canvas canvas, Offset at, double r, bool back) {
    final ink = Paint()
      ..color = const Color(0xFF2A2F45)
      ..strokeWidth = math.max(1.5, r * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(
        at + Offset(-r * 0.35, -r * 0.15),
        r * 0.08,
        Paint()..color = ink.color,
      )
      ..drawCircle(
        at + Offset(r * 0.35, -r * 0.15),
        r * 0.08,
        Paint()..color = ink.color,
      );
    final mouth = Rect.fromCenter(
      center: at + Offset(0, r * 0.35),
      width: r * 0.7,
      height: r * 0.4,
    );
    switch (mood) {
      case null:
        canvas.drawLine(mouth.centerLeft, mouth.centerRight, ink);
      case StageReaction.happy:
        canvas.drawArc(mouth, 0.2, 2.7, false, ink);
      case StageReaction.bored:
        canvas.drawOval(
          Rect.fromCenter(
            center: mouth.center,
            width: r * 0.35,
            height: r * 0.45,
          ),
          ink,
        );
      case StageReaction.puzzled:
        final path = Path()..moveTo(mouth.left, mouth.center.dy);
        path.quadraticBezierTo(
          mouth.center.dx,
          mouth.top,
          mouth.right,
          mouth.bottom,
        );
        canvas.drawPath(path, ink);
      case StageReaction.cantHear || StageReaction.tooMuch:
        canvas.drawLine(mouth.centerLeft, mouth.centerRight, ink);
        // Hands at the ears: cupped at the back for "can't hear", flat over
        // them everywhere for "too much".
        if (mood == StageReaction.tooMuch || back) {
          final hand = Paint()..color = const Color(0xFFE5A97C);
          final edge = Paint()
            ..color = const Color(0xFF2A2F45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, r * 0.08);
          for (final side in [-1.0, 1.0]) {
            final palm = Rect.fromCenter(
              center: at + Offset(side * r * 1.1, -r * 0.1),
              width: r * 0.6,
              height: r * 0.9,
            );
            canvas
              ..drawOval(palm, hand)
              ..drawOval(palm, edge);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.mood != mood ||
      old.room != room ||
      old.audience != audience ||
      old.p != p;
}

/// Grades each control against the scenario's target. Proxy evidence.
class StagePresenterEvaluator implements Evaluator<StageContent, BlanksAnswer> {
  const StagePresenterEvaluator();

  @override
  String get engineKey => StagePresenterEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    StageContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final items = {
      for (final control in content.controls)
        control.id:
            StagePresenterEngine.react(control, answer.blanks[control.id]) ==
            StageReaction.happy,
    };
    final right = items.values.where((v) => v).length;
    final all = right == items.length;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : right == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: right / items.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
      evidence: EvidenceLevel.proxy,
    );
  }
}
