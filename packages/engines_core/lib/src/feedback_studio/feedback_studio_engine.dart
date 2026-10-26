import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/village_characters.dart';

enum FeedbackMode { give, askRevise }

/// One part of the piece the feedback is about: a sentence of a story, or
/// a numbered point on a drawing.
class FeedbackPart {
  const FeedbackPart({required this.id, required this.text, this.x, this.y});
  final String id;

  /// A sentence's text, or a point's short name ("le soleil").
  final String text;

  /// Drawing points only, as fractions of the picture.
  final double? x;
  final double? y;
}

class FeedbackPiece {
  const FeedbackPiece({
    required this.parts,
    this.imageRef,
    this.aspectRatio = 1.5,
    this.title,
  });

  /// A drawing when set; else a story of [parts] as sentences.
  final String? imageRef;
  final double aspectRatio;
  final String? title;
  final List<FeedbackPart> parts;

  bool get drawing => imageRef != null;

  FeedbackPart? part(String? id) => parts.where((p) => p.id == id).firstOrNull;
}

/// `give` slots, in order.
const feedbackSlots = ['opener', 'praise', 'suggestion'];

class FeedbackTile {
  const FeedbackTile({
    required this.id,
    required this.slot,
    required this.label,
    this.kind = true,
    this.refersTo,
    this.actionable = false,
    this.reaction,
    this.diagnosis,
    this.audioRef,
  });
  final String id;
  final String slot;
  final String label;

  /// False for a harsh tile ("C'est laid.").
  final bool kind;

  /// The part this tile is about; null when it's vague ("C'est beau.").
  final String? refersTo;

  /// Suggestions only: says what to do ("Ajoute un nuage.") rather than
  /// "Fais mieux.".
  final bool actionable;
  final String? reaction;
  final ErrorClassification? diagnosis;
  final String? audioRef;
}

/// `ask_revise`: a question the child may ask about their own piece. The
/// config key is `asks`: `questions` already means a série's questions.
class FeedbackAsk {
  const FeedbackAsk({
    required this.id,
    required this.label,
    this.about,
    this.comment,
  });
  final String id;
  final String label;

  /// The part a specific question is about; null for "C'est bon ?".
  final String? about;

  /// What the character pins to [about].
  final String? comment;
}

class FeedbackRevision {
  const FeedbackRevision({
    required this.id,
    required this.label,
    required this.resolves,
  });
  final String id;

  /// The part's new text.
  final String label;

  /// Does it answer the pinned comment?
  final bool resolves;
}

class FeedbackContent {
  const FeedbackContent({
    required this.mode,
    required this.character,
    required this.piece,
    this.tiles = const [],
    this.asks = const [],
    this.revisions = const {},
    this.vagueReply,
    this.delighted,
  });

  final FeedbackMode mode;

  /// The piece's author (`give`) or the reader who comments (`ask_revise`).
  final VillageCharacter character;
  final FeedbackPiece piece;
  final List<FeedbackTile> tiles;
  final List<FeedbackAsk> asks;

  /// Part id → the ways to rewrite it.
  final Map<String, List<FeedbackRevision>> revisions;

  /// What the character says to a vague question.
  final String? vagueReply;
  final String? delighted;

  FeedbackTile tile(String id) => tiles.firstWhere((t) => t.id == id);
  FeedbackAsk ask(String id) => asks.firstWhere((a) => a.id == id);

  /// Whether [tile] is right in its slot.
  bool tileRight(FeedbackTile t) => switch (t.slot) {
    'opener' => t.kind,
    'praise' => t.kind && piece.part(t.refersTo) != null,
    _ => t.kind && t.actionable && piece.part(t.refersTo) != null,
  };
}

class FeedbackState {
  const FeedbackState({
    required this.content,
    this.picks = const {},
    this.locked = const {},
    this.tried = const {},
    this.firstAsk,
    this.asked,
    this.revision,
    this.reviseLocked = false,
    this.revisionTried = const {},
    this.reaction,
    this.mood = CharacterMood.neutral,
    this.solved = false,
  });

  final FeedbackContent content;

  // give
  final Map<String, String> picks;
  final Set<String> locked;
  final Set<String> tried;

  // ask_revise
  /// The first question asked in this attempt: what `ask` grades.
  final String? firstAsk;

  /// The question asked last (its comment, if specific, is pinned).
  final String? asked;
  final String? revision;
  final bool reviseLocked;
  final Set<String> revisionTried;

  final String? reaction;
  final CharacterMood mood;
  final bool solved;

  /// The part a specific question pinned a comment to, if any.
  String? get pinned {
    final a = asked;
    return a == null ? null : content.ask(a).about;
  }

  FeedbackState copyWith({
    Map<String, String>? picks,
    Set<String>? locked,
    Set<String>? tried,
    String? firstAsk,
    String? asked,
    String? revision,
    bool clearRevision = false,
    bool? reviseLocked,
    Set<String>? revisionTried,
    String? reaction,
    CharacterMood? mood,
    bool? solved,
  }) => FeedbackState(
    content: content,
    picks: picks ?? this.picks,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
    firstAsk: firstAsk ?? this.firstAsk,
    asked: asked ?? this.asked,
    revision: clearRevision ? null : (revision ?? this.revision),
    reviseLocked: reviseLocked ?? this.reviseLocked,
    revisionTried: revisionTried ?? this.revisionTried,
    reaction: reaction ?? this.reaction,
    mood: mood ?? this.mood,
    solved: solved ?? this.solved,
  );
}

sealed class FeedbackAction {
  const FeedbackAction();
}

class PickFeedbackTile extends FeedbackAction {
  const PickFeedbackTile(this.tileId);
  final String tileId;
}

class AskFeedback extends FeedbackAction {
  const AskFeedback(this.askId);
  final String askId;
}

class PickRevision extends FeedbackAction {
  const PickRevision(this.revisionId);
  final String revisionId;
}

/// "L'atelier des commentaires" — the `feedback_studio` engine (app ADR
/// 0090; the Questions Maker's ELA request 3, the Feedback leaf).
///
/// - `give`: a village character shows their story or drawing. The child
///   builds a comment from three slots of tiles — a kind opener, a
///   specific praise that points at a real part, one helpful suggestion
///   that says what to do and where. Partial credit per slot. Harsh,
///   vague, praise of something that isn't there, "fais mieux" and "change
///   tout" are the distractors.
/// - `ask_revise`: the piece is the child's own. They choose a question
///   to ask; a vague one ("C'est bon ?") only gets "C'est beau !", a
///   specific one gets a comment pinned to that part, and the child
///   rewrites that part from options. Graded on asking a specific question
///   first, and on a rewrite that answers the comment.
///
/// Direct evidence in both modes. The character always reacts in words.
class FeedbackStudioEngine
    implements
        LearningEngine<
          FeedbackContent,
          FeedbackState,
          FeedbackAction,
          BlanksAnswer
        > {
  const FeedbackStudioEngine();

  static const key = 'feedback_studio';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String? _text(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;

  static ErrorClassification? _diagnosis(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code'];
    final version = raw['taxonomy_version'];
    return code is String && code.isNotEmpty && version is int
        ? ErrorClassification(code: code, taxonomyVersion: version)
        : null;
  }

  static ParseResult<FeedbackPiece> _piece(Object? raw) {
    if (raw is! Map) return const ParseResult.invalid('piece is an object.');
    final image = _text(raw['image_ref']);
    final rawParts = image == null ? raw['sentences'] : raw['points'];
    if (rawParts is! List || rawParts.length < 2 || rawParts.length > 8) {
      return const ParseResult.invalid(
        'piece is a story of 2 to 8 sentences, or a drawing (image_ref) '
        'with 2 to 8 points.',
      );
    }
    final parts = <FeedbackPart>[];
    for (final p in rawParts) {
      final id = p is Map ? p['id'] : null;
      final text = p is Map ? _text(p[image == null ? 'text' : 'label']) : null;
      final x = p is Map ? p['x'] : null;
      final y = p is Map ? p['y'] : null;
      if (id is! String || id.isEmpty || text == null) {
        return const ParseResult.invalid(
          'A sentence is {id, text}; a point is {id, label, x, y}.',
        );
      }
      if (image != null &&
          (x is! num || y is! num || x < 0 || x > 1 || y < 0 || y > 1)) {
        return const ParseResult.invalid('A point has x and y from 0 to 1.');
      }
      if (parts.any((q) => q.id == id)) {
        return const ParseResult.invalid('Part ids are unique.');
      }
      parts.add(
        FeedbackPart(
          id: id,
          text: text,
          x: (x as num?)?.toDouble(),
          y: (y as num?)?.toDouble(),
        ),
      );
    }
    final ratio = raw['aspect_ratio'] ?? 1.5;
    if (ratio is! num || ratio < 0.5 || ratio > 3) {
      return const ParseResult.invalid('aspect_ratio is 0.5 to 3.');
    }
    return ParseResult.ok(
      FeedbackPiece(
        parts: List.unmodifiable(parts),
        imageRef: image,
        aspectRatio: ratio.toDouble(),
        title: _text(raw['title']),
      ),
    );
  }

  @override
  ParseResult<FeedbackContent> parse(Map<String, Object?> config) {
    final mode = switch (config['mode'] ?? 'give') {
      'give' => FeedbackMode.give,
      'ask_revise' => FeedbackMode.askRevise,
      _ => null,
    };
    if (mode == null) {
      return const ParseResult.invalid('mode is give or ask_revise.');
    }
    final character = VillageCharacter.byKey(config['character']);
    if (character == null) {
      return ParseResult.invalid(
        'character is one of ${VillageCharacter.keys.join(', ')}.',
      );
    }
    final pieceResult = _piece(config['piece']);
    if (pieceResult case ParseInvalid(:final reason)) {
      return ParseResult.invalid(reason);
    }
    final piece = pieceResult.valueOrNull!;

    if (mode == FeedbackMode.give) {
      final rawTiles = config['tiles'];
      if (rawTiles is! List || rawTiles.length > 15) {
        return const ParseResult.invalid('tiles is a list of at most 15.');
      }
      final tiles = <FeedbackTile>[];
      for (final t in rawTiles) {
        if (t is! Map) return const ParseResult.invalid('A tile is an object.');
        final id = t['id'];
        final slot = t['slot'];
        final label = _text(t['label']);
        final refers = t['refers_to'];
        if (id is! String ||
            id.isEmpty ||
            !feedbackSlots.contains(slot) ||
            label == null ||
            (refers != null && refers is! String)) {
          return const ParseResult.invalid(
            'A tile is {id, slot (opener, praise or suggestion), label, '
            'kind?, refers_to?, actionable?, reaction?, diagnosis?}.',
          );
        }
        if (tiles.any((x) => x.id == id)) {
          return const ParseResult.invalid('Tile ids are unique.');
        }
        tiles.add(
          FeedbackTile(
            id: id,
            slot: slot as String,
            label: label,
            kind: t['kind'] != false,
            refersTo: refers as String?,
            actionable: t['actionable'] == true,
            reaction: _text(t['reaction']),
            diagnosis: _diagnosis(t['diagnosis']),
            audioRef: _text(t['audio_ref']),
          ),
        );
      }
      final content = FeedbackContent(
        mode: mode,
        character: character,
        piece: piece,
        tiles: List.unmodifiable(tiles),
        delighted: _text(config['delighted']),
      );
      for (final slot in feedbackSlots) {
        final options = tiles.where((t) => t.slot == slot).toList();
        final right = options.where(content.tileRight).length;
        if (right == 0 || right == options.length) {
          return ParseResult.invalid(
            'Slot $slot needs at least one right tile and one that isn\'t.',
          );
        }
      }
      return ParseResult.ok(content);
    }

    if (piece.drawing) {
      return const ParseResult.invalid(
        'ask_revise works on a story: the child rewrites a sentence.',
      );
    }
    final rawAsks = config['asks'];
    if (rawAsks is! List || rawAsks.length < 2 || rawAsks.length > 4) {
      return const ParseResult.invalid(
        'There are 2 to 4 asks (questions the child may ask).',
      );
    }
    final asks = <FeedbackAsk>[];
    for (final a in rawAsks) {
      final id = a is Map ? a['id'] : null;
      final label = a is Map ? _text(a['label']) : null;
      final about = a is Map ? a['about'] : null;
      final comment = a is Map ? _text(a['comment']) : null;
      if (id is! String ||
          id.isEmpty ||
          label == null ||
          (about != null && piece.part(about as String?) == null) ||
          (about != null) != (comment != null)) {
        return const ParseResult.invalid(
          'A question is {id, label, about?, comment?}: a specific one names '
          'a sentence and the comment pinned to it; a vague one has neither.',
        );
      }
      asks.add(
        FeedbackAsk(
          id: id,
          label: label,
          about: about as String?,
          comment: comment,
        ),
      );
    }
    if (!asks.any((a) => a.about != null) ||
        !asks.any((a) => a.about == null)) {
      return const ParseResult.invalid(
        'Give at least one specific question and one vague one.',
      );
    }
    final rawRevisions = config['revisions'];
    if (rawRevisions is! Map) {
      return const ParseResult.invalid(
        'revisions maps each asked-about sentence to its rewrites.',
      );
    }
    final revisions = <String, List<FeedbackRevision>>{};
    for (final a in asks.where((a) => a.about != null)) {
      final raw = rawRevisions[a.about];
      if (raw is! List || raw.length < 2 || raw.length > 4) {
        return ParseResult.invalid(
          'Sentence ${a.about} needs 2 to 4 rewrites.',
        );
      }
      final list = <FeedbackRevision>[];
      for (final r in raw) {
        final id = r is Map ? r['id'] : null;
        final label = r is Map ? _text(r['label']) : null;
        if (id is! String ||
            label == null ||
            r is! Map ||
            r['resolves'] is! bool) {
          return const ParseResult.invalid(
            'A rewrite is {id, label, resolves}.',
          );
        }
        list.add(
          FeedbackRevision(
            id: id,
            label: label,
            resolves: r['resolves']! as bool,
          ),
        );
      }
      if (!list.any((r) => r.resolves) || list.every((r) => r.resolves)) {
        return ParseResult.invalid(
          'Sentence ${a.about} needs a rewrite that answers the comment and '
          'one that doesn\'t.',
        );
      }
      revisions[a.about!] = List.unmodifiable(list);
    }
    return ParseResult.ok(
      FeedbackContent(
        mode: mode,
        character: character,
        piece: piece,
        asks: List.unmodifiable(asks),
        revisions: Map.unmodifiable(revisions),
        vagueReply: _text(config['vague_reply']),
        delighted: _text(config['delighted']),
      ),
    );
  }

  @override
  FeedbackState initialize(FeedbackContent content, EngineSeed seed) =>
      FeedbackState(content: content);

  @override
  Transition<FeedbackState> reduce(FeedbackState s, FeedbackAction action) {
    if (s.solved) return Transition(s);
    final c = s.content;
    switch (action) {
      case PickFeedbackTile(:final tileId):
        final t = c.tiles.where((x) => x.id == tileId).firstOrNull;
        if (t == null ||
            s.locked.contains(t.slot) ||
            s.tried.contains(t.id) ||
            s.picks[t.slot] == t.id) {
          return Transition(s);
        }
        return Transition(s.copyWith(picks: {...s.picks, t.slot: t.id}), [
          InteractionEvent('item_placed', {
            'item_id': t.id,
            'bucket_id': t.slot,
          }),
        ]);
      case AskFeedback(:final askId):
        if (s.reviseLocked ||
            !c.asks.any((a) => a.id == askId) ||
            s.asked == askId) {
          return Transition(s);
        }
        final first = s.firstAsk ?? askId;
        final keepRevision = c.ask(askId).about == s.pinned;
        return Transition(
          s.copyWith(
            firstAsk: first,
            asked: askId,
            clearRevision: !keepRevision,
          ),
          [
            InteractionEvent('option_selected', {
              'option_id': askId,
              'item_id': 'ask',
            }),
          ],
        );
      case PickRevision(:final revisionId):
        final options = c.revisions[s.pinned] ?? const [];
        if (s.reviseLocked ||
            !options.any((r) => r.id == revisionId) ||
            s.revisionTried.contains(revisionId)) {
          return Transition(s);
        }
        return Transition(s.copyWith(revision: revisionId), [
          InteractionEvent('option_selected', {
            'option_id': revisionId,
            'item_id': 'revise',
          }),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(FeedbackState s) {
    if (s.solved) return null;
    final c = s.content;
    if (c.mode == FeedbackMode.give) {
      if (!feedbackSlots.every(s.picks.containsKey)) return null;
      return BlanksAnswer(Map.of(s.picks));
    }
    final revision = s.revision;
    if (s.firstAsk == null || s.pinned == null || revision == null) return null;
    return BlanksAnswer({
      'first_ask': s.firstAsk!,
      'asked': s.asked!,
      'revision': revision,
    });
  }

  static String? _flaw(FeedbackContent c, FeedbackTile t) {
    if (!t.kind) return 'harsh';
    if (t.slot != 'opener' && c.piece.part(t.refersTo) == null) return 'vague';
    if (t.slot == 'suggestion' && !t.actionable) return 'unhelpful';
    return null;
  }

  @override
  FeedbackState applyFeedback(FeedbackState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final c = s.content;
    final solved = result.outcome == Outcome.correct;
    if (c.mode == FeedbackMode.give) {
      final locked = {...s.locked};
      final tried = {...s.tried};
      final picks = <String, String>{};
      String? reaction;
      var mood = CharacterMood.delighted;
      for (final slot in feedbackSlots) {
        final id = s.picks[slot]!;
        if (result.itemResults[slot] == true || s.locked.contains(slot)) {
          locked.add(slot);
          picks[slot] = id;
          continue;
        }
        tried.add(id);
        if (reaction == null) {
          final t = c.tile(id);
          mood = _flaw(c, t) == 'harsh'
              ? CharacterMood.putOff
              : CharacterMood.confused;
          reaction = t.reaction ?? _flaw(c, t) ?? '';
        }
      }
      return s.copyWith(
        picks: picks,
        locked: locked,
        tried: tried,
        reaction: solved ? (c.delighted ?? '') : reaction,
        mood: solved ? CharacterMood.delighted : mood,
        solved: solved,
      );
    }
    final reviseRight = result.itemResults['revise'] == true;
    return s.copyWith(
      // The next attempt grades what the child asks now.
      firstAsk: s.asked,
      reviseLocked: reviseRight,
      clearRevision: !reviseRight,
      revisionTried: reviseRight
          ? s.revisionTried
          : {...s.revisionTried, s.revision!},
      reaction: solved ? (c.delighted ?? '') : (reviseRight ? 'ask' : 'revise'),
      mood: solved ? CharacterMood.delighted : CharacterMood.confused,
      solved: solved,
    );
  }

  @override
  Map<String, Object?> snapshot(FeedbackState s) => {
    'picks': s.picks,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
    'first_ask': s.firstAsk,
    'asked': s.asked,
    'revision': s.revision,
    'revise_locked': s.reviseLocked,
    'revision_tried': s.revisionTried.toList(),
    'reaction': s.reaction,
    'mood': s.mood.name,
    'solved': s.solved,
  };

  @override
  FeedbackState? restore(FeedbackContent content, Map<String, Object?> snap) {
    try {
      Set<String> set(String k) =>
          ((snap[k] as List?) ?? const []).cast<String>().toSet();
      final picks = Map<String, String>.from(
        (snap['picks'] as Map?) ?? const {},
      );
      final locked = set('locked');
      for (final e in picks.entries) {
        final t = content.tiles.where((x) => x.id == e.value).firstOrNull;
        if (t == null || t.slot != e.key) return null;
      }
      if (!locked.every(
        (slot) =>
            picks[slot] != null &&
            content.tileRight(content.tile(picks[slot]!)),
      )) {
        return null;
      }
      final asked = snap['asked'] as String?;
      final firstAsk = snap['first_ask'] as String?;
      bool knownAsk(String? id) =>
          id == null || content.asks.any((a) => a.id == id);
      if (!knownAsk(asked) || !knownAsk(firstAsk)) return null;
      final s = FeedbackState(
        content: content,
        picks: picks,
        locked: locked,
        tried: set('tried'),
        firstAsk: firstAsk,
        asked: asked,
        revision: snap['revision'] as String?,
        reviseLocked: snap['revise_locked'] == true,
        revisionTried: set('revision_tried'),
        reaction: snap['reaction'] as String?,
        mood:
            CharacterMood.values.asNameMap()[snap['mood']] ??
            CharacterMood.neutral,
        solved: snap['solved'] == true,
      );
      final revision = s.revision;
      if (revision != null &&
          !(content.revisions[s.pinned] ?? const []).any(
            (r) => r.id == revision,
          )) {
        return null;
      }
      return s;
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<FeedbackContent, FeedbackState, FeedbackAction> view,
  ) => _FeedbackView(view: view);
}

class _FeedbackView extends StatelessWidget {
  const _FeedbackView({required this.view});
  final EngineView<FeedbackContent, FeedbackState, FeedbackAction> view;

  String _say(FeedbackContent c, FeedbackState s, bool fr) {
    final r = s.reaction;
    if (r == null) {
      return c.mode == FeedbackMode.give
          ? (fr
                ? 'Voici ce que j’ai fait. Qu’en penses-tu ?'
                : 'Here’s what I made. What do you think?')
          : (fr
                ? 'Montre-moi ton histoire. Qu’est-ce que tu veux me demander ?'
                : 'Show me your story. What do you want to ask me?');
    }
    return switch (r) {
      '' => fr ? 'Merci !' : 'Thank you!',
      'harsh' => fr ? 'Aïe… ça me fait de la peine.' : 'Ouch… that hurts.',
      'vague' =>
        fr
            ? 'Merci… mais qu’est-ce qui t’a plu ?'
            : 'Thanks… but what did you like?',
      'unhelpful' =>
        fr ? 'Je ne sais pas quoi changer…' : 'I don’t know what to change…',
      // The rewrite was right, but the first question was vague.
      'ask' =>
        fr
            ? 'Bravo pour ta phrase ! La prochaine fois, pose-moi tout de suite une question précise.'
            : 'Nice sentence! Next time, ask me a precise question straight away.',
      'revise' =>
        fr
            ? 'Hum, ta phrase ne répond pas encore à mon commentaire.'
            : 'Hmm, your sentence doesn’t answer my note yet.',
      _ => r,
    };
  }

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

    // What to highlight in the piece: the parts the picked tiles point at,
    // or the sentence a comment is pinned to.
    final highlighted = <String>{
      for (final id in s.picks.values) ?c.tile(id).refersTo,
      ?s.pinned,
    };
    final revision = s.revision;
    final rewritten = revision == null
        ? null
        : (c.revisions[s.pinned] ?? const []).firstWhere(
            (r) => r.id == revision,
          );

    final piece = _Piece(
      piece: c.piece,
      highlighted: highlighted,
      rewrite: rewritten == null ? null : (s.pinned!, rewritten.label),
      fr: fr,
    );

    final children = <Widget>[
      CharacterSays(
        key: const ValueKey('feedback-character'),
        character: c.character,
        mood: s.reaction == null ? CharacterMood.neutral : s.mood,
        locale: view.locale,
        text: _say(c, s, fr),
      ),
      const SizedBox(height: 12),
      piece,
      const SizedBox(height: 16),
    ];

    if (c.mode == FeedbackMode.give) {
      final names = {
        'opener': fr ? '1. Pour commencer, gentiment' : '1. Start kindly',
        'praise': fr
            ? '2. Ce que tu aimes, précisément'
            : '2. What you like, exactly',
        'suggestion': fr
            ? '3. Une idée pour améliorer'
            : '3. One idea to make it better',
      };
      for (final slot in feedbackSlots) {
        final locked = s.locked.contains(slot);
        children
          ..add(Text(names[slot]!, style: heading))
          ..add(const SizedBox(height: 6));
        for (final t in c.tiles.where((t) => t.slot == slot)) {
          final picked = s.picks[slot] == t.id;
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnswerTile(
                key: ValueKey('feedback-tile-${t.id}'),
                label: t.label,
                audioRef: t.audioRef,
                state: picked
                    ? (locked
                          ? AnswerTileState.correct
                          : AnswerTileState.picked)
                    : s.tried.contains(t.id)
                    ? AnswerTileState.retry
                    : AnswerTileState.idle,
                semanticsState: s.tried.contains(t.id)
                    ? (fr ? 'déjà essayé' : 'already tried')
                    : picked
                    ? (fr ? 'choisi' : 'chosen')
                    : null,
                onTap: view.enabled && !locked && !s.tried.contains(t.id)
                    ? () => view.dispatch(PickFeedbackTile(t.id))
                    : null,
              ),
            ),
          );
        }
        children.add(const SizedBox(height: 8));
      }
    } else {
      children
        ..add(Text(fr ? 'Ta question' : 'Your question', style: heading))
        ..add(const SizedBox(height: 6));
      for (final a in c.asks) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnswerTile(
              key: ValueKey('feedback-ask-${a.id}'),
              label: a.label,
              state: s.asked == a.id
                  ? AnswerTileState.picked
                  : AnswerTileState.idle,
              onTap: view.enabled && !s.reviseLocked
                  ? () => view.dispatch(AskFeedback(a.id))
                  : null,
            ),
          ),
        );
      }
      final asked = s.asked;
      if (asked != null) {
        final a = c.ask(asked);
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CharacterSays(
              key: const ValueKey('feedback-reply'),
              character: c.character,
              locale: view.locale,
              mood: a.about == null
                  ? CharacterMood.neutral
                  : CharacterMood.delighted,
              text:
                  a.comment ??
                  c.vagueReply ??
                  (fr ? 'C’est beau !' : 'It’s nice!'),
            ),
          ),
        );
      }
      final options = c.revisions[s.pinned];
      if (options != null) {
        children
          ..add(
            Text(
              fr ? 'Réécris la phrase marquée' : 'Rewrite the marked sentence',
              style: heading,
            ),
          )
          ..add(const SizedBox(height: 6));
        for (final r in options) {
          final picked = s.revision == r.id;
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnswerTile(
                key: ValueKey('feedback-revision-${r.id}'),
                label: r.label,
                state: picked
                    ? (s.reviseLocked
                          ? AnswerTileState.correct
                          : AnswerTileState.picked)
                    : s.revisionTried.contains(r.id)
                    ? AnswerTileState.retry
                    : AnswerTileState.idle,
                onTap:
                    view.enabled &&
                        !s.reviseLocked &&
                        !s.revisionTried.contains(r.id)
                    ? () => view.dispatch(PickRevision(r.id))
                    : null,
              ),
            ),
          );
        }
      }
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

/// The piece: a story with numbered sentences, or a drawing with numbered
/// points. Highlighted parts are what the comment is about.
class _Piece extends StatelessWidget {
  const _Piece({
    required this.piece,
    required this.highlighted,
    required this.rewrite,
    required this.fr,
  });

  final FeedbackPiece piece;
  final Set<String> highlighted;

  /// A sentence id and its new text, shown in place while revising.
  final (String, String)? rewrite;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final ref = piece.imageRef;
    if (ref != null) {
      return Semantics(
        label: [
          fr ? 'Un dessin.' : 'A drawing.',
          for (final (i, part) in piece.parts.indexed)
            '${i + 1} : ${part.text}.',
        ].join(' '),
        excludeSemantics: true,
        child: AspectRatio(
          aspectRatio: piece.aspectRatio,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                  child: ContentImage(
                    ref: ref,
                    fallback: ColoredBox(color: p.track),
                  ),
                ),
                for (final (i, part) in piece.parts.indexed)
                  Positioned(
                    left: part.x! * box.maxWidth - 16,
                    top: part.y! * box.maxHeight - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: highlighted.contains(part.id)
                            ? p.gold
                            : p.quebecBlue,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('feedback-piece'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.cardMd,
        border: Border.all(color: p.line, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (piece.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                piece.title!,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: p.ink,
                ),
              ),
            ),
          for (final (i, part) in piece.parts.indexed)
            Builder(
              builder: (context) {
                final mark = highlighted.contains(part.id);
                final text = rewrite != null && rewrite!.$1 == part.id
                    ? rewrite!.$2
                    : part.text;
                return Semantics(
                  label:
                      '${fr ? 'phrase' : 'sentence'} ${i + 1}${mark ? (fr ? ', marquée' : ', marked') : ''} : $text',
                  excludeSemantics: true,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: mark ? p.goldPale : null,
                      borderRadius: Radii.cardSm,
                      border: mark ? Border.all(color: p.gold, width: 2) : null,
                    ),
                    child: Text(
                      '${i + 1}. $text',
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: p.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Grades `give` per slot, and `ask_revise` on its two items.
class FeedbackStudioEvaluator
    implements Evaluator<FeedbackContent, BlanksAnswer> {
  const FeedbackStudioEvaluator();

  @override
  String get engineKey => FeedbackStudioEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    FeedbackContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final b = answer.blanks;
    final Map<String, bool> items;
    final errors = <ErrorClassification>[];
    if (content.mode == FeedbackMode.give) {
      items = {};
      for (final slot in feedbackSlots) {
        final t = content.tiles
            .where((x) => x.id == b[slot] && x.slot == slot)
            .firstOrNull;
        final right = t != null && content.tileRight(t);
        items[slot] = right;
        if (!right) {
          errors.add(t?.diagnosis ?? const ErrorClassification.unclassified());
        }
      }
    } else {
      final first = content.asks
          .where((a) => a.id == b['first_ask'])
          .firstOrNull;
      final asked = content.asks.where((a) => a.id == b['asked']).firstOrNull;
      final revision = (content.revisions[asked?.about] ?? const [])
          .where((r) => r.id == b['revision'])
          .firstOrNull;
      items = {
        'ask': first?.about != null,
        'revise': revision?.resolves ?? false,
      };
      if (items.containsValue(false)) {
        errors.add(const ErrorClassification.unclassified());
      }
    }
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
      errors: all ? const [] : errors,
    );
  }
}
