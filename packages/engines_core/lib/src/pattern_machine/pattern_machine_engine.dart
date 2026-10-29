import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/creations.dart';
import '../widgets/answer_tile.dart';
import '../widgets/idle_hand_hint.dart';

enum PatternShape {
  circle,
  square,
  triangle,
  diamond,
  hexagon,
  star,
  heart,
  arrow,
}

enum PatternColor { red, blue, yellow, green, orange, purple, pink }

enum PatternSize { small, medium, large }

/// One term of a pattern: a shape drawn in code, or a short text (a number,
/// a letter). Two pieces are the same term when their [key]s match.
class PatternPiece {
  const PatternPiece.shape({
    required PatternShape this.shape,
    this.color = PatternColor.blue,
    this.size = PatternSize.medium,
    this.turn = 0,
  }) : text = null;

  const PatternPiece.text(String this.text)
    : shape = null,
      color = PatternColor.blue,
      size = PatternSize.medium,
      turn = 0;

  final PatternShape? shape;
  final PatternColor color;
  final PatternSize size;

  /// Clockwise quarter turns in degrees: 0, 90, 180 or 270.
  final int turn;
  final String? text;

  /// The inverse of [fromJson], for a saved creation.
  Map<String, Object?> toJson() => text != null
      ? {'text': text}
      : {
          'shape': shape!.name,
          'color': color.name,
          'size': const {
            PatternSize.small: 's',
            PatternSize.medium: 'm',
            PatternSize.large: 'l',
          }[size],
          'turn': turn,
        };

  String get key => text != null
      ? 't:$text'
      : 's:${shape!.name}:${color.name}:${size.name}:$turn';

  static const _sizes = {
    's': PatternSize.small,
    'm': PatternSize.medium,
    'l': PatternSize.large,
  };

  /// Null when [raw] isn't a piece.
  static PatternPiece? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text != null) {
      if (text is! String || text.trim().isEmpty || text.length > 4) {
        return null;
      }
      if (raw.containsKey('shape')) return null;
      return PatternPiece.text(text);
    }
    final shape = PatternShape.values.asNameMap()[raw['shape']];
    final color = raw['color'] == null
        ? PatternColor.blue
        : PatternColor.values.asNameMap()[raw['color']];
    final size = raw['size'] == null ? PatternSize.medium : _sizes[raw['size']];
    final turn = raw['turn'] ?? 0;
    if (shape == null ||
        color == null ||
        size == null ||
        turn is! int ||
        !const {0, 90, 180, 270}.contains(turn)) {
      return null;
    }
    return PatternPiece.shape(
      shape: shape,
      color: color,
      size: size,
      turn: turn,
    );
  }

  /// What a screen reader says: "petit triangle bleu", "blue arrow
  /// pointing up", "8".
  String describe(Locale locale) {
    final t = text;
    if (t != null) return t;
    return locale.languageCode == 'fr' ? _fr() : _en();
  }

  static const _frNoun = {
    PatternShape.circle: ('cercle', false),
    PatternShape.square: ('carré', false),
    PatternShape.triangle: ('triangle', false),
    PatternShape.diamond: ('losange', false),
    PatternShape.hexagon: ('hexagone', false),
    PatternShape.star: ('étoile', true),
    PatternShape.heart: ('cœur', false),
    PatternShape.arrow: ('flèche', true),
  };

  static const _frColor = {
    PatternColor.red: ('rouge', 'rouge'),
    PatternColor.blue: ('bleu', 'bleue'),
    PatternColor.yellow: ('jaune', 'jaune'),
    PatternColor.green: ('vert', 'verte'),
    PatternColor.orange: ('orange', 'orange'),
    PatternColor.purple: ('violet', 'violette'),
    PatternColor.pink: ('rose', 'rose'),
  };

  String _fr() {
    final (noun, fem) = _frNoun[shape]!;
    final (m, f) = _frColor[color]!;
    final size = switch (this.size) {
      PatternSize.small => fem ? 'petite ' : 'petit ',
      PatternSize.large => fem ? 'grande ' : 'grand ',
      PatternSize.medium => '',
    };
    final turned = shape == PatternShape.arrow
        ? switch (turn) {
            90 => ' vers la droite',
            180 => ' vers le bas',
            270 => ' vers la gauche',
            _ => ' vers le haut',
          }
        : switch (turn) {
            180 => ' à l’envers',
            90 || 270 => fem ? ' couchée' : ' couché',
            _ => '',
          };
    return '$size$noun ${fem ? f : m}$turned';
  }

  String _en() {
    final size = switch (this.size) {
      PatternSize.small => 'small ',
      PatternSize.large => 'big ',
      PatternSize.medium => '',
    };
    final turned = shape == PatternShape.arrow
        ? switch (turn) {
            90 => ' pointing right',
            180 => ' pointing down',
            270 => ' pointing left',
            _ => ' pointing up',
          }
        : switch (turn) {
            180 => ' upside down',
            90 || 270 => ' on its side',
            _ => '',
          };
    return '$size${color.name} ${shape!.name}$turned';
  }
}

class PatternChoice {
  const PatternChoice({required this.id, required this.piece});
  final String id;
  final PatternPiece piece;
}

class PatternContent {
  const PatternContent({
    required this.sequence,
    required this.hidden,
    required this.choices,
    this.continues = true,
    this.shuffle = true,
    this.creation = false,
    this.invent = false,
    this.slots = 0,
    this.core,
    this.vary = const {},
  });

  /// Invent mode (`task: "invent"`, ADR 0095): an empty strip of [slots]
  /// cells the child fills from the [choices] palette with a pattern of
  /// their own. There is no [sequence]; every cell is a gap.
  final bool invent;
  final int slots;

  /// Invent: the core size the pattern must have, or null for any core of
  /// 2 or more.
  final int? core;

  /// Invent: what must change inside the core — `shape`, `color`.
  final Set<String> vary;

  /// Cells in the row: the sequence, or the invent strip.
  int get length => invent ? slots : sequence.length;

  /// Every term, the hidden ones included.
  final List<PatternPiece> sequence;

  /// Indexes into [sequence] the child fills, ascending.
  final List<int> hidden;
  final List<PatternChoice> choices;

  /// Draw "…" after the last term: the pattern goes on.
  final bool continues;
  final bool shuffle;

  /// The content marks this as the child's own work, so the shell offers
  /// to keep it. Off by default: a question with one right answer is not
  /// a creation (ADR 0093).
  final bool creation;

  static String gapId(int index) => 'g$index';

  List<String> get gaps => [for (final i in hidden) gapId(i)];

  PatternChoice choice(String id) => choices.firstWhere((c) => c.id == id);

  /// The piece a gap expects, or null for an unknown gap.
  PatternPiece? expected(String gap) {
    final i = int.tryParse(gap.substring(1));
    if (!gap.startsWith('g') || i == null || !hidden.contains(i)) return null;
    return sequence[i];
  }
}

class PatternState {
  const PatternState({
    required this.choiceOrder,
    required this.gaps,
    this.active,
    this.filled = const {},
    this.locked = const {},
    this.tried = const {},
  });

  final List<String> choiceOrder;

  /// Gap ids in reading order.
  final List<String> gaps;

  /// The gap the next choice goes into.
  final String? active;

  /// Gap id → choice id.
  final Map<String, String> filled;

  /// Gaps checked right — fixed for the rest of the question.
  final Set<String> locked;

  /// `choice|gap` pairs checked wrong.
  final Set<String> tried;

  bool get complete => filled.length == gaps.length;

  String? get firstOpen {
    for (final g in gaps) {
      if (!filled.containsKey(g)) return g;
    }
    return null;
  }

  PatternState copyWith({
    String? active,
    bool clearActive = false,
    Map<String, String>? filled,
    Set<String>? locked,
    Set<String>? tried,
  }) => PatternState(
    choiceOrder: choiceOrder,
    gaps: gaps,
    active: clearActive ? null : (active ?? this.active),
    filled: filled ?? this.filled,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
  );
}

sealed class PatternAction {
  const PatternAction();
}

/// Tap a gap: make it the target, or empty it if it's filled.
class TapPatternGap extends PatternAction {
  const TapPatternGap(this.gapId);
  final String gapId;
}

/// Tap a choice: a copy of it goes into the target gap.
class TapPatternChoice extends PatternAction {
  const TapPatternChoice(this.choiceId);
  final String choiceId;
}

/// "Qu'est-ce qui suit ?" — the `pattern_machine` engine (app ADR 0048;
/// Hafid's catalogue B26, #5 in the ranking).
///
/// A row of terms with one to three gaps: what comes next, or what's
/// missing in the middle. Terms are shapes drawn in code (any shape,
/// colour, size and quarter turn, so frises work too) or short texts
/// (numbers for a numeric regularity). The content authors the *whole*
/// sequence and says which terms are hidden; the right answer is whichever
/// choice is the same piece, so a lesson can't name a wrong answer key.
///
/// A choice is a stamp, not a tile: it stays in the bank, because a
/// pattern repeats (A B A B _ _ wants A twice). VALIDER waits for every
/// gap; right gaps lock, wrong ones empty, and that choice can't go back
/// into that gap.
class PatternMachineEngine
    implements
        LearningEngine<
          PatternContent,
          PatternState,
          PatternAction,
          BlanksAnswer
        > {
  const PatternMachineEngine();

  static const key = 'pattern_machine';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<PatternContent> parse(Map<String, Object?> config) {
    final task = config['task'] ?? 'continue';
    if (task == 'invent') return _parseInvent(config);
    if (task != 'continue') {
      return const ParseResult.invalid('task is continue or invent.');
    }
    final rawSequence = config['sequence'];
    if (rawSequence is! List ||
        rawSequence.length < 4 ||
        rawSequence.length > 12) {
      return const ParseResult.invalid('sequence has 4 to 12 terms.');
    }
    final sequence = <PatternPiece>[];
    for (final raw in rawSequence) {
      final piece = PatternPiece.fromJson(raw);
      if (piece == null) {
        return const ParseResult.invalid(
          'A term is a {shape, color?, size?, turn?} or a {text} of 1 to 4 '
          'characters.',
        );
      }
      sequence.add(piece);
    }

    final rawHidden = config['hidden'];
    if (rawHidden is! List ||
        rawHidden.isEmpty ||
        rawHidden.length > 3 ||
        !rawHidden.every((i) => i is int)) {
      return const ParseResult.invalid('hidden lists 1 to 3 term indexes.');
    }
    final hidden = rawHidden.cast<int>().toSet().toList()..sort();
    if (hidden.length != rawHidden.length ||
        hidden.first < 0 ||
        hidden.last >= sequence.length) {
      return const ParseResult.invalid(
        'hidden indexes are distinct and inside the sequence.',
      );
    }
    if (sequence.length - hidden.length < 3) {
      return const ParseResult.invalid(
        'At least 3 terms stay visible, or there is no pattern to see.',
      );
    }

    final rawChoices = config['choices'];
    if (rawChoices is! List || rawChoices.length < 2 || rawChoices.length > 6) {
      return const ParseResult.invalid('There are 2 to 6 choices.');
    }
    final choices = <PatternChoice>[];
    for (final raw in rawChoices) {
      final id = raw is Map ? raw['id'] : null;
      final piece = raw is Map
          ? PatternPiece.fromJson({
              for (final e in raw.entries)
                if (e.key != 'id') e.key: e.value,
            })
          : null;
      if (id is! String || id.isEmpty || piece == null) {
        return const ParseResult.invalid(
          'Every choice needs an id and is a piece.',
        );
      }
      if (choices.any((c) => c.id == id)) {
        return const ParseResult.invalid('Choice ids must be unique.');
      }
      if (choices.any((c) => c.piece.key == piece.key)) {
        return const ParseResult.invalid('Two choices are the same piece.');
      }
      choices.add(PatternChoice(id: id, piece: piece));
    }
    final choiceKeys = {for (final c in choices) c.piece.key};
    final answerKeys = {for (final i in hidden) sequence[i].key};
    if (!answerKeys.every(choiceKeys.contains)) {
      return const ParseResult.invalid(
        'Every hidden term must be one of the choices.',
      );
    }
    if (choices.length <= answerKeys.length) {
      return const ParseResult.invalid(
        'There must be a wrong choice, or nothing is a choice.',
      );
    }
    final continues = config['continues'];
    final shuffle = config['shuffle'];
    final creation = config['creation'];
    if (creation != null && creation is! bool) {
      return const ParseResult.invalid('creation must be true or false.');
    }
    return ParseResult.ok(
      PatternContent(
        sequence: List.unmodifiable(sequence),
        hidden: List.unmodifiable(hidden),
        choices: List.unmodifiable(choices),
        continues: continues is bool ? continues : true,
        shuffle: shuffle is bool ? shuffle : true,
        creation: creation == true,
      ),
    );
  }

  /// The palette: 2 to 6 distinct pieces, each with an id.
  static (List<PatternChoice>?, String?) _choices(Object? raw) {
    if (raw is! List || raw.length < 2 || raw.length > 6) {
      return (null, 'There are 2 to 6 choices.');
    }
    final choices = <PatternChoice>[];
    for (final r in raw) {
      final id = r is Map ? r['id'] : null;
      final piece = r is Map
          ? PatternPiece.fromJson({
              for (final e in r.entries)
                if (e.key != 'id') e.key: e.value,
            })
          : null;
      if (id is! String || id.isEmpty || piece == null) {
        return (null, 'Every choice needs an id and is a piece.');
      }
      if (choices.any((c) => c.id == id)) {
        return (null, 'Choice ids must be unique.');
      }
      if (choices.any((c) => c.piece.key == piece.key)) {
        return (null, 'Two choices are the same piece.');
      }
      choices.add(PatternChoice(id: id, piece: piece));
    }
    return (choices, null);
  }

  ParseResult<PatternContent> _parseInvent(Map<String, Object?> config) {
    for (final key in const ['sequence', 'hidden']) {
      if (config.containsKey(key)) {
        return ParseResult.invalid('$key is for task continue.');
      }
    }
    final (choices, why) = _choices(config['palette']);
    if (choices == null) return ParseResult.invalid('palette: $why');
    final slots = config['slots'] ?? 6;
    if (slots is! int || slots < 4 || slots > 12) {
      return const ParseResult.invalid('slots is 4 to 12.');
    }
    final core = config['core'];
    if (core != null && (core is! int || core < 2 || core * 2 > slots)) {
      return const ParseResult.invalid(
        'core is 2 or more, and fits twice in the slots.',
      );
    }

    final rawVary = config['vary'] ?? const <Object>[];
    if (rawVary is! List ||
        !rawVary.every((v) => v == 'shape' || v == 'color')) {
      return const ParseResult.invalid('vary lists shape and/or color.');
    }
    final vary = rawVary.cast<String>().toSet();
    for (final v in vary) {
      final kinds = {
        for (final c in choices)
          if (c.piece.text == null)
            v == 'shape' ? c.piece.shape : c.piece.color,
      };
      if (kinds.length < 2) {
        return ParseResult.invalid('vary $v needs two ${v}s in the palette.');
      }
    }
    final creation = config['creation'];
    if (creation != null && creation is! bool) {
      return const ParseResult.invalid('creation must be true or false.');
    }
    final continues = config['continues'];
    return ParseResult.ok(
      PatternContent(
        sequence: const [],
        hidden: List.unmodifiable([for (var i = 0; i < slots; i++) i]),
        choices: List.unmodifiable(choices),
        continues: continues is bool ? continues : true,
        shuffle: false,
        creation: creation == true,
        invent: true,
        slots: slots,
        core: core as int?,
        vary: Set.unmodifiable(vary),
      ),
    );
  }

  @override
  PatternState initialize(PatternContent content, EngineSeed seed) {
    final order = [for (final c in content.choices) c.id];
    if (content.shuffle) order.shuffle(seed.random());
    return PatternState(
      choiceOrder: List.unmodifiable(order),
      gaps: List.unmodifiable(content.gaps),
    );
  }

  static String _pair(String choice, String gap) => '$choice|$gap';

  @override
  Transition<PatternState> reduce(PatternState s, PatternAction action) {
    switch (action) {
      case TapPatternGap(:final gapId):
        if (!s.gaps.contains(gapId) || s.locked.contains(gapId)) {
          return Transition(s);
        }
        final there = s.filled[gapId];
        if (there == null) return Transition(s.copyWith(active: gapId));
        return Transition(
          s.copyWith(active: gapId, filled: Map.of(s.filled)..remove(gapId)),
          [
            InteractionEvent('item_removed', {
              'item_id': there,
              'bucket_id': gapId,
            }),
          ],
        );

      case TapPatternChoice(:final choiceId):
        if (!s.choiceOrder.contains(choiceId)) return Transition(s);
        final target = s.active ?? s.firstOpen;
        if (target == null || s.locked.contains(target)) return Transition(s);
        if (s.tried.contains(_pair(choiceId, target))) return Transition(s);
        return Transition(
          s.copyWith(
            clearActive: true,
            filled: {...s.filled, target: choiceId},
          ),
          [
            InteractionEvent('item_placed', {
              'item_id': choiceId,
              'bucket_id': target,
            }),
          ],
        );
    }
  }

  @override
  BlanksAnswer? extractAnswer(PatternState s) =>
      !s.complete || s.locked.length == s.gaps.length
      ? null
      : BlanksAnswer(s.filled);

  @override
  PatternState applyFeedback(PatternState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    if (result.itemResults.isEmpty) {
      // Invent: the strip is the child's, so a miss keeps every piece for
      // them to change; a pattern that repeats locks whole.
      return result.outcome == Outcome.correct
          ? s.copyWith(clearActive: true, locked: s.gaps.toSet())
          : s.copyWith(clearActive: true);
    }
    final locked = {...s.locked};
    final tried = {...s.tried};
    final filled = <String, String>{};
    for (final e in s.filled.entries) {
      if (s.locked.contains(e.key) || result.itemResults[e.key] == true) {
        locked.add(e.key);
        filled[e.key] = e.value;
      } else if (result.itemResults[e.key] == false) {
        tried.add(_pair(e.value, e.key));
      }
    }
    return s.copyWith(
      clearActive: true,
      filled: filled,
      locked: locked,
      tried: tried,
    );
  }

  @override
  Map<String, Object?> snapshot(PatternState s) => {
    'choice_order': s.choiceOrder,
    'active': s.active,
    'filled': s.filled,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
  };

  @override
  PatternState? restore(PatternContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['choice_order'] as List).cast<String>();
      final ids = {for (final c in content.choices) c.id};
      final gaps = content.gaps;
      if (order.length != ids.length || !order.every(ids.contains)) {
        return null;
      }
      final filled = Map<String, String>.from(
        (snap['filled'] as Map?) ?? const {},
      );
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final active = snap['active'] as String?;
      if (!filled.keys.every(gaps.contains) ||
          !filled.values.every(ids.contains) ||
          !locked.every(
            (g) =>
                filled[g] != null &&
                (content.invent ||
                    content.choice(filled[g]!).piece.key ==
                        content.expected(g)?.key),
          ) ||
          (active != null && !gaps.contains(active))) {
        return null;
      }
      return PatternState(
        choiceOrder: List.unmodifiable(order),
        gaps: List.unmodifiable(gaps),
        active: active,
        filled: filled,
        locked: locked,
        tried: ((snap['tried'] as List?) ?? const []).cast<String>().toSet(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<PatternContent, PatternState, PatternAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final c = view.content;
    final p = VillagePalette.of(context);
    final target = view.enabled ? (s.active ?? s.firstOpen) : null;
    final cell = c.length > 8 ? 56.0 : 68.0;

    final row = <Widget>[];
    var gapNumber = 0;
    for (var i = 0; i < c.length; i++) {
      if (!c.hidden.contains(i)) {
        final piece = c.sequence[i];
        row.add(
          Semantics(
            label: piece.describe(view.locale),
            child: _Cell(size: cell, piece: piece, state: null),
          ),
        );
        continue;
      }
      gapNumber++;
      final gap = PatternContent.gapId(i);
      final choiceId = s.filled[gap];
      final locked = s.locked.contains(gap);
      final isTarget = target == gap;
      final piece = choiceId == null ? null : c.choice(choiceId).piece;
      final label = piece == null
          ? (fr
                ? 'case $gapNumber, vide${isTarget ? ', à remplir' : ''}'
                : 'gap $gapNumber, empty${isTarget ? ', next to fill' : ''}')
          : piece.describe(view.locale);
      row.add(
        Semantics(
          button: true,
          label: label,
          hint: piece == null
              ? null
              : locked
              ? (fr ? 'bien placé' : 'right')
              : (fr ? 'touche pour vider' : 'tap to empty it'),
          excludeSemantics: true,
          child: _Cell(
            key: ValueKey('pattern-gap-$gap'),
            size: cell,
            piece: piece,
            state: locked ? AnswerTileState.correct : AnswerTileState.idle,
            isGap: true,
            highlighted: isTarget,
            onTap: view.enabled && !locked
                ? () => view.dispatch(TapPatternGap(gap))
                : null,
          ),
        ),
      );
    }
    if (c.continues) {
      row.add(
        ExcludeSemantics(
          child: SizedBox(
            height: cell,
            child: Center(
              child: Text(
                '…',
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: p.inkMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                key: const ValueKey('pattern-row'),
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: row,
              ),
              const SizedBox(height: 28),
              Wrap(
                key: const ValueKey('pattern-choices'),
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.choiceOrder)
                    Builder(
                      builder: (context) {
                        // Invent starts on an empty strip: the idle hand
                        // shows the first stamp to press (G3).
                        final hand =
                            c.invent &&
                            view.enabled &&
                            s.filled.isEmpty &&
                            id == s.choiceOrder.first;
                        final piece = c.choice(id).piece;
                        final tried =
                            target != null &&
                            s.tried.contains(_pair(id, target));
                        return Semantics(
                          button: true,
                          enabled: target != null && !tried,
                          label: piece.describe(view.locale),
                          hint: tried
                              ? (fr ? 'déjà essayé ici' : 'already tried here')
                              : null,
                          excludeSemantics: true,
                          child: IdleHandHint(
                            show: hand,
                            child: _Cell(
                              key: ValueKey('pattern-choice-$id'),
                              size: 72,
                              piece: piece,
                              state: tried
                                  ? AnswerTileState.retry
                                  : AnswerTileState.idle,
                              onTap: target != null && !tried
                                  ? () => view.dispatch(TapPatternChoice(id))
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (c.creation && s.locked.length == s.gaps.length)
                KeepCreationButton(
                  locale: view.locale,
                  engineKey: PatternMachineEngine.key,
                  payload: {
                    'pieces': [
                      if (c.invent)
                        for (final g in s.gaps)
                          c.choice(s.filled[g]!).piece.toJson()
                      else
                        for (final piece in c.sequence) piece.toJson(),
                    ],
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square card holding one piece: a shown term (no [state]), a gap, or
/// a choice. Every state reads without colour: right gets a check, retry
/// a target icon, the gap to fill a thick outline.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.piece,
    required this.state,
    this.isGap = false,
    this.highlighted = false,
    this.onTap,
    super.key,
  });

  final double size;
  final PatternPiece? piece;
  final AnswerTileState? state;
  final bool isGap;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final empty = piece == null;
    final (border, fill, icon) = switch (state) {
      AnswerTileState.retry => (
        p.retry,
        p.retryPale,
        Icons.track_changes_rounded,
      ),
      AnswerTileState.correct => (
        p.success,
        p.successPale,
        Icons.check_rounded,
      ),
      _ when highlighted => (p.quebecBlueBright, p.navHoverFill, null),
      _ when isGap && empty => (p.line, p.track.withValues(alpha: 0.35), null),
      _ => (p.line, p.surface, null),
    };
    final content = Stack(
      children: [
        if (piece case final piece?)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: PatternPieceView(piece: piece),
            ),
          ),
        if (icon != null)
          Positioned(
            right: 3,
            top: 3,
            child: Icon(icon, size: 14, color: border),
          ),
      ],
    );
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardMd,
          side: BorderSide(color: border, width: highlighted ? 3 : 2),
        ),
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: Radii.cardMd, child: content),
      ),
    );
  }
}

/// Draws one [PatternPiece] to fill its box: a shape, or its text.
class PatternPieceView extends StatelessWidget {
  const PatternPieceView({required this.piece, super.key});

  final PatternPiece piece;

  static const colors = {
    PatternColor.red: Color(0xFFE5484D),
    PatternColor.blue: Color(0xFF2F6FDE),
    PatternColor.yellow: Color(0xFFF5C02B),
    PatternColor.green: Color(0xFF2FA35A),
    PatternColor.orange: Color(0xFFF08A24),
    PatternColor.purple: Color(0xFF8E4EC6),
    PatternColor.pink: Color(0xFFE66BA8),
  };

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final text = piece.text;
    if (text != null) {
      return FittedBox(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontWeight: FontWeight.w800,
            fontSize: 32,
            color: p.ink,
          ),
        ),
      );
    }
    return CustomPaint(
      painter: _ShapePainter(piece, colors[piece.color]!, p.ink),
      size: Size.infinite,
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.piece, this.color, this.ink);

  final PatternPiece piece;
  final Color color;
  final Color ink;

  static const _scale = {
    PatternSize.small: 0.55,
    PatternSize.medium: 0.78,
    PatternSize.large: 1.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * _scale[piece.size]!;
    final center = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(piece.turn * math.pi / 180);
    final path = _path(piece.shape!, side / 2);
    canvas
      ..drawPath(path, Paint()..color = color)
      // A dark edge, so yellow and pink still read on a white card.
      ..drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, side * 0.04)
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  /// The shape centred on the origin, fitting a circle of radius [r].
  static Path _path(PatternShape shape, double r) {
    Path polygon(int n, double radius, [double inner = 0]) {
      final path = Path();
      final points = inner == 0 ? n : n * 2;
      for (var i = 0; i < points; i++) {
        final rr = inner == 0 || i.isEven ? radius : inner;
        final a = -math.pi / 2 + i * 2 * math.pi / points;
        final pt = Offset(rr * math.cos(a), rr * math.sin(a));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path..close();
    }

    switch (shape) {
      case PatternShape.circle:
        return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
      case PatternShape.square:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCircle(center: Offset.zero, radius: r * 0.82),
            Radius.circular(r * 0.12),
          ),
        );
      case PatternShape.triangle:
        return Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.95, r * 0.75)
          ..lineTo(-r * 0.95, r * 0.75)
          ..close();
      case PatternShape.diamond:
        return Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.7, 0)
          ..lineTo(0, r)
          ..lineTo(-r * 0.7, 0)
          ..close();
      case PatternShape.hexagon:
        return polygon(6, r);
      case PatternShape.star:
        return polygon(5, r, r * 0.45);
      case PatternShape.heart:
        return Path()
          ..moveTo(0, r * 0.9)
          ..cubicTo(-r * 1.3, 0, -r * 0.7, -r * 1.1, 0, -r * 0.45)
          ..cubicTo(r * 0.7, -r * 1.1, r * 1.3, 0, 0, r * 0.9)
          ..close();
      case PatternShape.arrow:
        return Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.8, -r * 0.1)
          ..lineTo(r * 0.3, -r * 0.1)
          ..lineTo(r * 0.3, r)
          ..lineTo(-r * 0.3, r)
          ..lineTo(-r * 0.3, -r * 0.1)
          ..lineTo(-r * 0.8, -r * 0.1)
          ..close();
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.piece.key != piece.key || old.color != color || old.ink != ink;
}

/// Grades a `pattern_machine` row: one item per gap, true when the chosen
/// piece is the hidden term. Score is right gaps over gaps.
class PatternMachineEvaluator
    implements Evaluator<PatternContent, BlanksAnswer> {
  const PatternMachineEvaluator();

  @override
  String get engineKey => PatternMachineEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    PatternContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final gaps = answer.blanks;
    if (gaps.isEmpty) throw ArgumentError('An answer must fill something.');
    if (content.invent) return _invent(content, gaps, ctx);
    final ids = {for (final c in content.choices) c.id};
    final items = {
      for (final e in gaps.entries)
        e.key:
            ids.contains(e.value) &&
            content.expected(e.key)?.key == content.choice(e.value).piece.key,
    };
    final hits = items.values.where((v) => v).length;
    final total = content.hidden.length;
    final all = hits == total;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / total,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }

  /// The smallest core the strip repeats: p with every cell equal to the
  /// cell p before it. A strip that never repeats returns its length.
  static int periodOf(List<String> keys) {
    for (var p = 1; p < keys.length; p++) {
      var ok = true;
      for (var i = p; i < keys.length && ok; i++) {
        ok = keys[i] == keys[i - p];
      }
      if (ok) return p;
    }
    return keys.length;
  }

  /// Invent (ADR 0095): any strip whose smallest core is 2 or more pieces
  /// and fits at least twice is a pattern — whichever piece it starts on,
  /// and a partial last repeat is fine (ABABA). A core of 1 (AAAA) isn't a
  /// pattern to see. Content can ask for an exact [PatternContent.core]
  /// size and for the core to [PatternContent.vary] in shape or colour.
  /// A miss is amber, with a code saying what's still missing.
  EvaluationResult _invent(
    PatternContent content,
    Map<String, String> gaps,
    EvaluationContext ctx,
  ) {
    final pieces = [
      for (final g in content.gaps)
        if (gaps[g] case final id?) content.choice(id).piece,
    ];
    if (pieces.length != content.slots) {
      throw ArgumentError('An invented strip must fill every cell.');
    }
    final p = periodOf([for (final x in pieces) x.key]);
    final coreOf = pieces.take(p);
    final String? why;
    if (p < 2 || p * 2 > pieces.length) {
      why = 'no_repeat';
    } else if (content.core != null && p != content.core) {
      why = 'core_size';
    } else if (content.vary.any(
      (v) =>
          {for (final x in coreOf) v == 'shape' ? x.shape : x.color}.length < 2,
    )) {
      why = 'vary';
    } else {
      why = null;
    }
    return EvaluationResult(
      outcome: why == null ? Outcome.correct : Outcome.incorrect,
      score: why == null ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      feedbackCode: why,
      errors: why == null
          ? const []
          : const [ErrorClassification.unclassified()],
    );
  }
}
