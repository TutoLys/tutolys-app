import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/creations.dart';

import '../widgets/answer_tile.dart';
import '../widgets/village_characters.dart';

/// How the message is laid out, drawn in code.
enum MailTemplate { card, letter, article, poster }

class MailSlot {
  const MailSlot({required this.id, required this.label, this.many = false});
  final String id;
  final String label;

  /// Several tiles may go in (the details a reader needs).
  final bool many;
}

class MailTile {
  const MailTile({
    required this.id,
    required this.slot,
    required this.label,
    required this.audiences,
    this.neededBy = const {},
    this.template,
    this.reaction,
    this.missingReaction,
    this.audioRef,
  });

  final String id;
  final String slot;
  final String label;

  /// Who this tile suits ("family", "friend", "teacher", "public").
  final Set<String> audiences;

  /// Who can't follow the message without it ("my dog Max" for the paper).
  final Set<String> neededBy;

  /// Format tiles only: the template it picks.
  final MailTemplate? template;

  /// What the recipient says when this tile doesn't suit them.
  final String? reaction;

  /// What the recipient says when it's needed and missing ("Qui est
  /// Max ?").
  final String? missingReaction;
  final String? audioRef;
}

class MailContent {
  const MailContent({
    required this.news,
    required this.recipient,
    required this.audience,
    required this.slots,
    required this.tiles,
    this.delighted,
    this.creation = false,
  });

  /// What the child wants to tell ("Mon chien Max a appris à rouler !").
  final String news;
  final VillageCharacter recipient;
  final String audience;
  final List<MailSlot> slots;
  final List<MailTile> tiles;

  /// What the recipient says when the message suits them.
  final String? delighted;

  /// The content marks this as the child's own work, so the shell offers
  /// to keep it. Off by default: a question with one right answer is not
  /// a creation (ADR 0093).
  final bool creation;

  MailTile tile(String id) => tiles.firstWhere((t) => t.id == id);

  List<MailTile> tilesFor(String slot) => [
    for (final t in tiles)
      if (t.slot == slot) t,
  ];

  /// Whether [picked] makes [slot] right for this recipient: every tile
  /// suits them, and every tile they need is there.
  bool slotRight(MailSlot slot, Set<String> picked) {
    if (picked.isEmpty) return false;
    final fits = picked.every((id) => tile(id).audiences.contains(audience));
    final needed = [
      for (final t in tilesFor(slot.id))
        if (t.neededBy.contains(audience)) t.id,
    ];
    return fits && needed.every(picked.contains);
  }
}

class MailState {
  const MailState({
    required this.content,
    this.picks = const {},
    this.locked = const {},
    this.tried = const {},
    this.reaction,
    this.mood = CharacterMood.neutral,
    this.solved = false,
  });

  /// So the reducer and the reaction can read the slots and tiles.
  final MailContent content;

  /// Slot id → the tiles in it.
  final Map<String, Set<String>> picks;
  final Set<String> locked;

  /// `slot|tile` pairs that didn't suit, after a check.
  final Set<String> tried;

  /// The recipient's last words, after a check.
  final String? reaction;
  final CharacterMood mood;
  final bool solved;

  MailState copyWith({
    Map<String, Set<String>>? picks,
    Set<String>? locked,
    Set<String>? tried,
    String? reaction,
    CharacterMood? mood,
    bool? solved,
  }) => MailState(
    content: content,
    picks: picks ?? this.picks,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
    reaction: reaction ?? this.reaction,
    mood: mood ?? this.mood,
    solved: solved ?? this.solved,
  );
}

sealed class MailAction {
  const MailAction();
}

/// Put a tile in its slot, or take it out again.
class ToggleMailTile extends MailAction {
  const ToggleMailTile(this.tileId);
  final String tileId;
}

/// "La poste du village" — the `mail_studio` engine (app ADR 0089; the
/// Questions Maker's ELA request 2).
///
/// The child has news to tell and writes it for one village recipient —
/// Grand-maman, the teacher, a friend, the village paper — by filling the
/// message's slots (format, greeting, body, details, sign-off) from tiles.
/// Each tile says which audiences it suits; a detail tile says who needs
/// it (Grand-maman knows Max; a newspaper reader needs "mon chien Max").
/// A slot is right when its tiles suit the recipient and nothing they need
/// is missing. The recipient reacts — delighted, confused, put off — in
/// their own words, from the lesson.
///
/// Audience fit is direct evidence; the writing itself is only a proxy,
/// because the child chooses rather than writes (ADR 0089).
class MailStudioEngine
    implements
        LearningEngine<MailContent, MailState, MailAction, BlanksAnswer> {
  const MailStudioEngine();

  static const key = 'mail_studio';

  static const audiences = {'family', 'friend', 'teacher', 'public', 'younger'};

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 2,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String? _text(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;

  static Set<String>? _tags(Object? raw, {bool allowEmpty = false}) {
    if (raw == null) return allowEmpty ? const {} : null;
    if (raw is! List || (!allowEmpty && raw.isEmpty)) return null;
    if (!raw.every(audiences.contains)) return null;
    return raw.cast<String>().toSet();
  }

  @override
  ParseResult<MailContent> parse(Map<String, Object?> config) {
    final news = _text(config['news']);
    if (news == null) return const ParseResult.invalid('news is the message.');
    final r = config['recipient'];
    final character = VillageCharacter.byKey(r is Map ? r['character'] : null);
    final audience = r is Map ? r['audience'] : null;
    if (character == null || !audiences.contains(audience)) {
      return ParseResult.invalid(
        'recipient is {character, audience}; audience is one of '
        '${audiences.join(', ')}.',
      );
    }

    final rawSlots = config['slots'];
    if (rawSlots is! List || rawSlots.length < 2 || rawSlots.length > 6) {
      return const ParseResult.invalid('There are 2 to 6 slots.');
    }
    final slots = <MailSlot>[];
    for (final s in rawSlots) {
      final id = s is Map ? s['id'] : null;
      final label = s is Map ? _text(s['label']) : null;
      if (id is! String || id.isEmpty || label == null) {
        return const ParseResult.invalid('A slot is {id, label, many?}.');
      }
      if (slots.any((x) => x.id == id)) {
        return const ParseResult.invalid('Slot ids are unique.');
      }
      slots.add(
        MailSlot(id: id, label: label, many: (s as Map)['many'] == true),
      );
    }

    final rawTiles = config['tiles'];
    if (rawTiles is! List || rawTiles.length > 24) {
      return const ParseResult.invalid('tiles is a list of at most 24.');
    }
    final tiles = <MailTile>[];
    for (final t in rawTiles) {
      if (t is! Map) return const ParseResult.invalid('A tile is an object.');
      final id = t['id'];
      final slot = t['slot'];
      final label = _text(t['label']);
      final fits = _tags(t['audiences']);
      final needed = _tags(t['needed_by'], allowEmpty: true);
      final rawTemplate = t['template'];
      final template = rawTemplate == null
          ? null
          : MailTemplate.values.asNameMap()[rawTemplate];
      if (id is! String ||
          id.isEmpty ||
          !slots.any((s) => s.id == slot) ||
          label == null ||
          fits == null ||
          needed == null) {
        return const ParseResult.invalid(
          'A tile is {id, slot, label, audiences, needed_by?, template?, '
          'reaction?, missing_reaction?}, with known audiences.',
        );
      }
      if (rawTemplate != null && template == null) {
        return const ParseResult.invalid(
          'template is card, letter, article or poster.',
        );
      }
      if (!needed.every(fits.contains)) {
        return const ParseResult.invalid(
          'A tile is needed only by audiences it suits.',
        );
      }
      if (tiles.any((x) => x.id == id)) {
        return const ParseResult.invalid('Tile ids are unique.');
      }
      tiles.add(
        MailTile(
          id: id,
          slot: slot as String,
          label: label,
          audiences: fits,
          neededBy: needed,
          template: template,
          reaction: _text(t['reaction']),
          missingReaction: _text(t['missing_reaction']),
          audioRef: _text(t['audio_ref']),
        ),
      );
    }

    final creation = config['creation'];
    if (creation != null && creation is! bool) {
      return const ParseResult.invalid('creation must be true or false.');
    }
    final content = MailContent(
      news: news,
      recipient: character,
      audience: audience as String,
      slots: List.unmodifiable(slots),
      tiles: List.unmodifiable(tiles),
      delighted: _text(config['delighted']),
      creation: creation == true,
    );
    for (final slot in slots) {
      final options = content.tilesFor(slot.id);
      final fitting = [
        for (final t in options)
          if (t.audiences.contains(audience)) t,
      ];
      if (fitting.isEmpty) {
        return ParseResult.invalid(
          'Slot ${slot.id} has no tile that suits the recipient.',
        );
      }
      final needed = [
        for (final t in options)
          if (t.neededBy.contains(audience)) t,
      ];
      // A choice must exist: a tile that doesn't suit, or (where several
      // go in) a detail the reader needs.
      if (fitting.length == options.length && (!slot.many || needed.isEmpty)) {
        return ParseResult.invalid(
          'Slot ${slot.id} has nothing to choose: add a tile that doesn\'t '
          'suit${slot.many ? ', or one the reader needs' : ''}.',
        );
      }
      if (!slot.many && needed.length > 1) {
        return ParseResult.invalid(
          'Slot ${slot.id} takes one tile but ${needed.length} are needed: '
          'make it many.',
        );
      }
    }
    return ParseResult.ok(content);
  }

  @override
  MailState initialize(MailContent content, EngineSeed seed) =>
      MailState(content: content);

  @override
  Transition<MailState> reduce(MailState s, MailAction action) {
    if (s.solved) return Transition(s);
    switch (action) {
      case ToggleMailTile(:final tileId):
        final c = s.content;
        final tile = c.tiles.where((t) => t.id == tileId).firstOrNull;
        if (tile == null || s.locked.contains(tile.slot)) return Transition(s);
        final slot = c.slots.firstWhere((x) => x.id == tile.slot);
        final now = {...?s.picks[slot.id]};
        final on = !now.contains(tileId);
        if (on && s.tried.contains('${slot.id}|$tileId')) return Transition(s);
        if (on) {
          if (!slot.many) now.clear();
          now.add(tileId);
        } else {
          now.remove(tileId);
        }
        return Transition(s.copyWith(picks: {...s.picks, slot.id: now}), [
          InteractionEvent(on ? 'item_placed' : 'item_removed', {
            'item_id': tileId,
            'bucket_id': slot.id,
          }),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(MailState s) {
    final c = s.content;
    if (s.solved || c.slots.any((x) => (s.picks[x.id] ?? const {}).isEmpty)) {
      return null;
    }
    return BlanksAnswer({
      for (final x in c.slots)
        x.id: (s.picks[x.id]!.toList()..sort()).join(','),
    });
  }

  @override
  MailState applyFeedback(MailState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final c = s.content;
    final locked = {...s.locked};
    final tried = {...s.tried};
    final picks = <String, Set<String>>{};
    String? reaction;
    var mood = CharacterMood.delighted;
    for (final slot in c.slots) {
      final picked = s.picks[slot.id] ?? const <String>{};
      if (result.itemResults[slot.id] == true || s.locked.contains(slot.id)) {
        locked.add(slot.id);
        picks[slot.id] = picked;
        continue;
      }
      // Misfits go amber and leave; a right tile stays for the retry.
      final misfit = [
        for (final id in picked)
          if (!c.tile(id).audiences.contains(c.audience)) c.tile(id),
      ];
      final kept = {
        for (final id in picked)
          if (c.tile(id).audiences.contains(c.audience)) id,
      };
      for (final t in misfit) {
        tried.add('${slot.id}|${t.id}');
      }
      picks[slot.id] = kept;
      if (reaction == null) {
        if (misfit.isNotEmpty) {
          reaction = misfit.first.reaction;
          mood = CharacterMood.putOff;
        } else {
          final missing = c
              .tilesFor(slot.id)
              .firstWhere(
                (t) =>
                    t.neededBy.contains(c.audience) && !picked.contains(t.id),
              );
          reaction = missing.missingReaction;
          mood = CharacterMood.confused;
        }
        reaction ??= '';
      }
    }
    final solved = result.outcome == Outcome.correct;
    return s.copyWith(
      picks: picks,
      locked: locked,
      tried: tried,
      reaction: solved ? (c.delighted ?? '') : reaction,
      mood: solved ? CharacterMood.delighted : mood,
      solved: solved,
    );
  }

  @override
  Map<String, Object?> snapshot(MailState s) => {
    'picks': {for (final e in s.picks.entries) e.key: e.value.toList()},
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
    'reaction': s.reaction,
    'mood': s.mood.name,
    'solved': s.solved,
  };

  @override
  MailState? restore(MailContent content, Map<String, Object?> snap) {
    try {
      final picks = {
        for (final e in (snap['picks']! as Map).entries)
          e.key as String: (e.value as List).cast<String>().toSet(),
      };
      final locked = ((snap['locked'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      for (final e in picks.entries) {
        final slot = content.slots.where((x) => x.id == e.key).firstOrNull;
        if (slot == null ||
            !e.value.every(
              (id) => content.tiles.any((t) => t.id == id && t.slot == slot.id),
            ) ||
            (!slot.many && e.value.length > 1)) {
          return null;
        }
      }
      if (!locked.every(
        (id) =>
            content.slots.any((x) => x.id == id) &&
            content.slotRight(
              content.slots.firstWhere((x) => x.id == id),
              picks[id] ?? const {},
            ),
      )) {
        return null;
      }
      return MailState(
        content: content,
        picks: picks,
        locked: locked,
        tried: ((snap['tried'] as List?) ?? const []).cast<String>().toSet(),
        reaction: snap['reaction'] as String?,
        mood:
            CharacterMood.values.asNameMap()[snap['mood']] ??
            CharacterMood.neutral,
        solved: snap['solved'] == true && locked.length == content.slots.length,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<MailContent, MailState, MailAction> view,
  ) => _MailView(view: view);
}

class _MailView extends StatelessWidget {
  const _MailView({required this.view});
  final EngineView<MailContent, MailState, MailAction> view;

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
    final name = c.recipient.name(view.locale);

    final chosen = [
      for (final slot in c.slots)
        for (final id
            in (s.picks[slot.id] ?? const <String>{}).toList()..sort())
          c.tile(id),
    ];
    final template =
        chosen.map((t) => t.template).whereType<MailTemplate>().firstOrNull ??
        MailTemplate.card;

    Widget slotRow(MailSlot slot) {
      final locked = s.locked.contains(slot.id);
      final picked = s.picks[slot.id] ?? const <String>{};
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              slot.many
                  ? '${slot.label} ${fr ? '(plusieurs possibles)' : '(you can pick several)'}'
                  : slot.label,
              style: heading,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in c.tilesFor(slot.id))
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 120,
                      maxWidth: 300,
                    ),
                    child: IntrinsicWidth(
                      child: AnswerTile(
                        key: ValueKey('mail-tile-${t.id}'),
                        label: t.label,
                        audioRef: t.audioRef,
                        state: picked.contains(t.id)
                            ? (locked
                                  ? AnswerTileState.correct
                                  : AnswerTileState.picked)
                            : s.tried.contains('${slot.id}|${t.id}')
                            ? AnswerTileState.retry
                            : AnswerTileState.idle,
                        semanticsState: s.tried.contains('${slot.id}|${t.id}')
                            ? (fr
                                  ? 'ne convient pas à $name'
                                  : 'doesn’t suit $name')
                            : picked.contains(t.id)
                            ? (fr ? 'choisi' : 'chosen')
                            : null,
                        onTap:
                            view.enabled &&
                                !locked &&
                                !s.tried.contains('${slot.id}|${t.id}')
                            ? () => view.dispatch(ToggleMailTile(t.id))
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CharacterSays(
                key: const ValueKey('mail-recipient'),
                character: c.recipient,
                mood: s.reaction == null ? CharacterMood.neutral : s.mood,
                locale: view.locale,
                text: switch ((s.reaction, s.mood)) {
                  (final r?, _) when r.isNotEmpty => r,
                  (null, _) =>
                    fr
                        ? 'Tu m’écris ? Ta nouvelle : « ${c.news} »'
                        : 'Writing to me? Your news: “${c.news}”',
                  // The lesson gave no words for this: say it plainly.
                  (_, CharacterMood.putOff) =>
                    fr
                        ? 'Hum… ce n’est pas pour moi, ça.'
                        : 'Hmm… that’s not really for me.',
                  (_, CharacterMood.confused) =>
                    fr ? 'Je ne comprends pas tout…' : 'I don’t quite follow…',
                  _ => fr ? 'Merci !' : 'Thank you!',
                },
              ),
              const SizedBox(height: 16),
              for (final slot in c.slots) slotRow(slot),
              const SizedBox(height: 4),
              Text(
                fr ? 'Ton message pour $name' : 'Your message for $name',
                style: heading,
              ),
              const SizedBox(height: 6),
              _Preview(
                key: const ValueKey('mail-preview'),
                template: template,
                lines: [
                  for (final t in chosen)
                    if (t.template == null) t.label,
                ],
                fr: fr,
                masthead: _Preview.mastheadFor(c.recipient.key, fr: fr),
              ),
              if (c.creation && s.solved)
                KeepCreationButton(
                  locale: view.locale,
                  engineKey: MailStudioEngine.key,
                  payload: {
                    'recipient': c.recipient.key,
                    'template': template.name,
                    'lines': [
                      for (final t in chosen)
                        if (t.template == null) t.label,
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

/// The message as it will arrive: a card, a letter, an article or a
/// poster, drawn in code, with the chosen tiles as its lines.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.template,
    required this.lines,
    required this.fr,
    this.masthead,
    super.key,
  });

  final MailTemplate template;
  final List<String> lines;
  final bool fr;

  /// The article's header: where it will be read. Null draws none.
  final String? masthead;

  /// An article's header follows its recipient: the village paper prints
  /// « LE JOURNAL DU VILLAGE », a report pinned on the school wall says so.
  /// Before this, every article said newspaper, even one for the school
  /// wall (grade-1 ELA 122, found in the 2026-11-16 play-test).
  static String? mastheadFor(String recipient, {required bool fr}) =>
      switch (recipient) {
        'journal' => fr ? 'LE JOURNAL DU VILLAGE' : 'THE VILLAGE PAPER',
        'babillard' => fr ? 'LE BABILLARD DE L’ÉCOLE' : 'THE SCHOOL WALL',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final (bg, border, font, size, align) = switch (template) {
      MailTemplate.card => (
        const Color(0xFFFFF1F5),
        const Color(0xFFE66BA8),
        FontWeight.w700,
        18.0,
        TextAlign.center,
      ),
      MailTemplate.letter => (
        const Color(0xFFFFFDF5),
        p.line,
        FontWeight.w600,
        17.0,
        TextAlign.left,
      ),
      MailTemplate.article => (
        Colors.white,
        p.ink,
        FontWeight.w600,
        15.0,
        TextAlign.justify,
      ),
      MailTemplate.poster => (
        p.goldPale,
        p.gold,
        FontWeight.w800,
        22.0,
        TextAlign.center,
      ),
    };
    final name = switch (template) {
      MailTemplate.card => fr ? 'une carte' : 'a card',
      MailTemplate.letter => fr ? 'une lettre' : 'a letter',
      MailTemplate.article => fr ? 'un article' : 'an article',
      MailTemplate.poster => fr ? 'une affiche' : 'a poster',
    };
    return Semantics(
      label: '${fr ? 'Aperçu' : 'Preview'}, $name : ${lines.join(' ')}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
            template == MailTemplate.card ? 18 : 6,
          ),
          border: Border.all(
            color: border,
            width: template == MailTemplate.poster ? 4 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (template == MailTemplate.article && masthead != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.ink, width: 2)),
                ),
                child: Text(
                  masthead!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 2,
                    color: p.ink,
                  ),
                ),
              ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  line,
                  textAlign: align,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: font,
                    fontSize: size,
                    color: p.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grades each slot: its tiles suit the recipient, and nothing they need
/// is missing.
class MailStudioEvaluator implements Evaluator<MailContent, BlanksAnswer> {
  const MailStudioEvaluator();

  @override
  String get engineKey => MailStudioEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    MailContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final items = <String, bool>{
      for (final slot in content.slots)
        slot.id: content.slotRight(
          slot,
          (answer.blanks[slot.id] ?? '')
              .split(',')
              .where((id) => content.tiles.any((t) => t.id == id))
              .toSet(),
        ),
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
    );
  }
}
