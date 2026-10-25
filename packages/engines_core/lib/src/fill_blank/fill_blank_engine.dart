import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_slot.dart';
import '../widgets/answer_tile.dart';

/// A run of the sentence: words, or a blank to fill.
sealed class ClozePiece {
  const ClozePiece();
}

class ClozeText extends ClozePiece {
  const ClozeText(this.text);
  final String text;
}

class ClozeGap extends ClozePiece {
  const ClozeGap(this.blankId);
  final String blankId;
}

class ClozeTile {
  const ClozeTile({required this.id, required this.label});
  final String id;
  final String label;
}

class ClozeContent {
  const ClozeContent({
    required this.pieces,
    required this.tiles,
    required this.accepted,
    this.reuse = false,
    this.shuffle = true,
  });

  final List<ClozePiece> pieces;
  final List<ClozeTile> tiles;

  /// Blank id → the tile ids that are right there (usually one; several
  /// when the content accepts either, like `3 + 4` and `4 + 3`).
  final Map<String, Set<String>> accepted;

  /// A tile may fill several blanks ("un" twice in one sentence).
  final bool reuse;
  final bool shuffle;

  /// Blank ids in reading order.
  List<String> get blanks => [
    for (final p in pieces)
      if (p is ClozeGap) p.blankId,
  ];

  ClozeTile tile(String id) => tiles.firstWhere((t) => t.id == id);
}

class ClozeState {
  const ClozeState({
    required this.tileOrder,
    required this.blanks,
    this.active,
    this.filled = const {},
    this.locked = const {},
    this.tried = const {},
    this.reuse = false,
  });

  final List<String> tileOrder;

  /// Blank ids in reading order.
  final List<String> blanks;

  /// The blank the next tile goes into.
  final String? active;

  /// Blank id → tile id.
  final Map<String, String> filled;

  /// Blanks checked right — fixed for the rest of the question.
  final Set<String> locked;

  /// `tile|blank` pairs checked wrong, so a known mistake isn't repeated.
  final Set<String> tried;
  final bool reuse;

  bool get complete => filled.length == blanks.length;

  /// The first blank still open, the default target for the next tile.
  String? get firstOpen {
    for (final b in blanks) {
      if (!filled.containsKey(b)) return b;
    }
    return null;
  }

  ClozeState copyWith({
    String? active,
    bool clearActive = false,
    Map<String, String>? filled,
    Set<String>? locked,
    Set<String>? tried,
  }) => ClozeState(
    tileOrder: tileOrder,
    blanks: blanks,
    reuse: reuse,
    active: clearActive ? null : (active ?? this.active),
    filled: filled ?? this.filled,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
  );
}

sealed class ClozeAction {
  const ClozeAction();
}

/// Tap a blank: make it the target, or empty it if it's filled.
class TapBlank extends ClozeAction {
  const TapBlank(this.blankId);
  final String blankId;
}

/// Tap a tile: it goes into the target blank.
class TapClozeTile extends ClozeAction {
  const TapClozeTile(this.tileId);
  final String tileId;
}

/// Complete the sentence or the equation — the `fill_blank` engine (app
/// ADR 0047; Hafid's catalogue A3, #2 in the ranking).
///
/// "Le chat dort sur ___ lit.", "4 + ___ = 7", "Il ___ (manger / mange)".
/// The text is authored with `{id}` markers; each blank is filled from a
/// bank of tiles, never typed (a grade-1 child and a keyboard don't mix,
/// and an authored tile is what makes a wrong answer diagnostic). Tap a
/// tile and it goes into the highlighted blank, which is the first empty
/// one unless the child tapped another. Tap a filled blank to empty it.
///
/// VALIDER waits for every blank; each is checked with partial credit:
/// right ones lock, wrong ones empty, and that tile can't go back into
/// that blank.
class FillBlankEngine
    implements
        LearningEngine<ClozeContent, ClozeState, ClozeAction, BlanksAnswer> {
  const FillBlankEngine();

  static const key = 'fill_blank';
  static final _marker = RegExp(r'\{([a-z0-9_-]+)\}');

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<ClozeContent> parse(Map<String, Object?> config) {
    final text = config['text'];
    if (text is! String || text.trim().isEmpty || text.length > 240) {
      return const ParseResult.invalid('text is 1 to 240 characters.');
    }
    final pieces = <ClozePiece>[];
    var at = 0;
    for (final m in _marker.allMatches(text)) {
      if (m.start > at) pieces.add(ClozeText(text.substring(at, m.start)));
      pieces.add(ClozeGap(m.group(1)!));
      at = m.end;
    }
    if (at < text.length) pieces.add(ClozeText(text.substring(at)));
    final markers = [
      for (final p in pieces)
        if (p is ClozeGap) p.blankId,
    ];
    if (markers.isEmpty || markers.length > 4) {
      return const ParseResult.invalid('text has 1 to 4 {blank} markers.');
    }
    if (markers.toSet().length != markers.length) {
      return const ParseResult.invalid('Each {blank} appears once.');
    }

    final rawTiles = config['tiles'];
    if (rawTiles is! List || rawTiles.length < 2 || rawTiles.length > 8) {
      return const ParseResult.invalid('There are 2 to 8 tiles.');
    }
    final tiles = <ClozeTile>[];
    for (final t in rawTiles) {
      final id = t is Map ? t['id'] : null;
      final label = t is Map ? t['label'] : null;
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.trim().isEmpty) {
        return const ParseResult.invalid('Every tile needs an id and label.');
      }
      if (tiles.any((x) => x.id == id)) {
        return const ParseResult.invalid('Tile ids must be unique.');
      }
      tiles.add(ClozeTile(id: id, label: label));
    }
    final tileIds = {for (final t in tiles) t.id};

    final rawBlanks = config['blanks'];
    if (rawBlanks is! List) {
      return const ParseResult.invalid('blanks must be a list.');
    }
    final accepted = <String, Set<String>>{};
    for (final b in rawBlanks) {
      final id = b is Map ? b['id'] : null;
      final answer = b is Map ? b['answer'] : null;
      final answers = switch (answer) {
        final String one => {one},
        final List many
            when many.isNotEmpty && many.every((x) => x is String) =>
          many.cast<String>().toSet(),
        _ => null,
      };
      if (id is! String || answers == null) {
        return const ParseResult.invalid(
          'Every blank needs an id and an answer (a tile id, or a list).',
        );
      }
      if (!answers.every(tileIds.contains)) {
        return const ParseResult.invalid('A blank\'s answer must be a tile.');
      }
      if (accepted.containsKey(id)) {
        return const ParseResult.invalid('Blank ids must be unique.');
      }
      accepted[id] = answers;
    }
    if (accepted.keys.toSet().difference(markers.toSet()).isNotEmpty ||
        markers.any((m) => !accepted.containsKey(m))) {
      return const ParseResult.invalid(
        'Every {marker} needs a blank, and every blank a {marker}.',
      );
    }
    final reuse = config['reuse'] == true;
    if (!reuse) {
      // Each tile fills one blank at most: the blanks must be solvable
      // with distinct tiles.
      if (!_distinctSolution(markers, accepted)) {
        return const ParseResult.invalid(
          'Without reuse, each blank needs its own tile; set reuse: true.',
        );
      }
    }
    if (tiles.length <= markers.length && !reuse) {
      return const ParseResult.invalid(
        'There must be more tiles than blanks, or nothing is a choice.',
      );
    }
    final shuffle = config['shuffle'];
    return ParseResult.ok(
      ClozeContent(
        pieces: List.unmodifiable(pieces),
        tiles: List.unmodifiable(tiles),
        accepted: Map.unmodifiable(accepted),
        reuse: reuse,
        shuffle: shuffle is bool ? shuffle : true,
      ),
    );
  }

  /// Can each blank get a different accepted tile? (At most 4 blanks, so a
  /// plain search is fine.)
  static bool _distinctSolution(
    List<String> blanks,
    Map<String, Set<String>> accepted, [
    int i = 0,
    Set<String> used = const {},
  ]) {
    if (i == blanks.length) return true;
    for (final t in accepted[blanks[i]]!) {
      if (!used.contains(t) &&
          _distinctSolution(blanks, accepted, i + 1, {...used, t})) {
        return true;
      }
    }
    return false;
  }

  @override
  ClozeState initialize(ClozeContent content, EngineSeed seed) {
    final order = [for (final t in content.tiles) t.id];
    if (content.shuffle) order.shuffle(seed.random());
    return ClozeState(
      tileOrder: List.unmodifiable(order),
      blanks: List.unmodifiable(content.blanks),
      reuse: content.reuse,
    );
  }

  static String _pair(String tile, String blank) => '$tile|$blank';

  @override
  Transition<ClozeState> reduce(ClozeState s, ClozeAction action) {
    switch (action) {
      case TapBlank(:final blankId):
        if (!s.blanks.contains(blankId) || s.locked.contains(blankId)) {
          return Transition(s);
        }
        final there = s.filled[blankId];
        if (there == null) return Transition(s.copyWith(active: blankId));
        return Transition(
          s.copyWith(
            active: blankId,
            filled: Map.of(s.filled)..remove(blankId),
          ),
          [
            InteractionEvent('item_removed', {
              'item_id': there,
              'bucket_id': blankId,
            }),
          ],
        );

      case TapClozeTile(:final tileId):
        if (!s.tileOrder.contains(tileId)) return Transition(s);
        final target = s.active ?? s.firstOpen;
        if (target == null || s.locked.contains(target)) return Transition(s);
        if (s.tried.contains(_pair(tileId, target))) return Transition(s);
        final filled = Map.of(s.filled);
        if (!s.reuse) {
          // A tile is in one blank at a time: taking it moves it.
          filled.removeWhere((b, t) => t == tileId && !s.locked.contains(b));
          if (filled.entries.any((e) => e.value == tileId)) {
            return Transition(s); // already locked elsewhere
          }
        }
        filled[target] = tileId;
        final next = s.copyWith(clearActive: true, filled: filled);
        return Transition(next, [
          InteractionEvent('item_placed', {
            'item_id': tileId,
            'bucket_id': target,
          }),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(ClozeState s) =>
      !s.complete || s.locked.length == s.blanks.length
      ? null
      : BlanksAnswer(s.filled);

  @override
  ClozeState applyFeedback(ClozeState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
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
  Map<String, Object?> snapshot(ClozeState s) => {
    'tile_order': s.tileOrder,
    'active': s.active,
    'filled': s.filled,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
  };

  @override
  ClozeState? restore(ClozeContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['tile_order'] as List).cast<String>();
      final tileIds = {for (final t in content.tiles) t.id};
      final blanks = content.blanks;
      if (order.length != tileIds.length || !order.every(tileIds.contains)) {
        return null;
      }
      final filled = Map<String, String>.from(
        (snap['filled'] as Map?) ?? const {},
      );
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final active = snap['active'] as String?;
      if (!filled.keys.every(blanks.contains) ||
          !filled.values.every(tileIds.contains) ||
          (!content.reuse && filled.values.toSet().length != filled.length) ||
          !locked.every(
            (b) => content.accepted[b]?.contains(filled[b]) ?? false,
          ) ||
          (active != null && !blanks.contains(active))) {
        return null;
      }
      return ClozeState(
        tileOrder: List.unmodifiable(order),
        blanks: List.unmodifiable(blanks),
        reuse: content.reuse,
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
    EngineView<ClozeContent, ClozeState, ClozeAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final c = view.content;
    final p = VillagePalette.of(context);
    final target = view.enabled ? (s.active ?? s.firstOpen) : null;
    final longest = c.tiles.map((t) => t.label.length).reduce(math.max);
    // Every blank as wide as the longest tile, so a filled sentence doesn't
    // reflow under the child's finger.
    final slotWidth = (40 + longest * 13.0).clamp(64.0, 200.0);
    final textStyle = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 24,
      height: 1.3,
      color: p.ink,
    );

    final sentence = <Widget>[];
    var blankNumber = 0;
    for (final piece in c.pieces) {
      switch (piece) {
        case ClozeText(:final text):
          // Word by word, so the line wraps like text around the blanks.
          for (final word in text.split(RegExp(r'\s+'))) {
            if (word.isEmpty) continue;
            sentence.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(word, style: textStyle),
              ),
            );
          }
        case ClozeGap(:final blankId):
          blankNumber++;
          final tileId = s.filled[blankId];
          final locked = s.locked.contains(blankId);
          final isTarget = target == blankId;
          sentence.add(
            SizedBox(
              width: slotWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: Radii.cardMd,
                  boxShadow: isTarget
                      ? [BoxShadow(color: p.quebecBlueBright, spreadRadius: 3)]
                      : null,
                ),
                child: AnswerSlot(
                  key: ValueKey('blank-$blankId'),
                  index: blankNumber,
                  label: tileId == null ? null : c.tile(tileId).label,
                  state: locked
                      ? AnswerTileState.correct
                      : AnswerTileState.idle,
                  emptyLabel: fr
                      ? 'trou $blankNumber, vide${isTarget ? ', à remplir' : ''}'
                      : 'blank $blankNumber, empty${isTarget ? ', next to fill' : ''}',
                  semanticsState: locked
                      ? (fr ? 'bien rempli' : 'filled right')
                      : (fr ? 'touche pour vider' : 'tap to empty it'),
                  onTap: view.enabled && !locked
                      ? () => view.dispatch(TapBlank(blankId))
                      : null,
                ),
              ),
            ),
          );
      }
    }

    final used = c.reuse ? const <String>{} : s.filled.values.toSet();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                key: const ValueKey('cloze-sentence'),
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: sentence,
              ),
              const SizedBox(height: 24),
              Wrap(
                key: const ValueKey('cloze-tiles'),
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in s.tileOrder)
                    SizedBox(
                      width: slotWidth,
                      child: used.contains(id)
                          // Holds its place so the bank doesn't reflow.
                          ? const SizedBox(height: 52)
                          : AnswerTile(
                              key: ValueKey('cloze-tile-$id'),
                              label: c.tile(id).label,
                              state:
                                  target != null &&
                                      s.tried.contains(_pair(id, target))
                                  ? AnswerTileState.retry
                                  : AnswerTileState.idle,
                              semanticsState:
                                  target != null &&
                                      s.tried.contains(_pair(id, target))
                                  ? (fr
                                        ? 'déjà essayé ici'
                                        : 'already tried here')
                                  : null,
                              onTap:
                                  target != null &&
                                      !s.tried.contains(_pair(id, target))
                                  ? () => view.dispatch(TapClozeTile(id))
                                  : null,
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a `fill_blank` sentence: one item per blank, true when its tile
/// is one the content accepts there. Score is right blanks over blanks.
class FillBlankEvaluator implements Evaluator<ClozeContent, BlanksAnswer> {
  const FillBlankEvaluator();

  @override
  String get engineKey => FillBlankEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    ClozeContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final blanks = answer.blanks;
    if (blanks.isEmpty) throw ArgumentError('An answer must fill something.');
    final items = {
      for (final e in blanks.entries)
        e.key: content.accepted[e.key]?.contains(e.value) ?? false,
    };
    final hits = items.values.where((v) => v).length;
    final total = content.accepted.length;
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
}
