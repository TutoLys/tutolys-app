import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/village_characters.dart';
import 'passage_reader_engine.dart'
    show
        DiscussCite,
        DiscussPickFinal,
        DiscussPickFirst,
        PassageAction,
        TapPassageChoice;

/// One character's reading of the passage, resting on one sentence.
class DiscussTake {
  const DiscussTake({
    required this.id,
    required this.character,
    required this.text,
    required this.cites,
    this.audioRef,
  });
  final String id;
  final VillageCharacter character;
  final String text;

  /// The sentence id this take rests on.
  final String cites;

  /// The line read aloud, on tap only: a pre-reader can't read it.
  final String? audioRef;
}

/// The sentence revealed once both takes are matched.
class DiscussClue {
  const DiscussClue({
    required this.id,
    required this.text,
    this.audioRef,
    this.accepts,
  });
  final String id;
  final String text;
  final String? audioRef;

  /// The final answers the clue makes right (proxy evidence). Null when both
  /// takes stay valid: the revision is practice and any answer is fine.
  final Set<String>? accepts;
}

class DiscussPart {
  const DiscussPart({
    required this.question,
    required this.takes,
    required this.clue,
    required this.sentenceIds,
    required this.optionIds,
  });
  final String question;
  final List<DiscussTake> takes;
  final DiscussClue clue;

  /// What a cite and a pick may name, so the reducer can check them.
  final Set<String> sentenceIds;
  final Set<String> optionIds;
}

/// Where a `discuss` question stands. Its steps unfold on screen as the
/// child goes, and are checked together with one VALIDER.
class DiscussState {
  const DiscussState({
    this.first,
    this.cites = const {},
    this.finalPick,
    this.clueShown = false,
    this.lockedTakes = const {},
    this.triedCites = const {},
    this.finalLocked = false,
    this.finalTried = const {},
  });

  /// The child's first answer (never graded: it's theirs).
  final String? first;

  /// Take id → the sentence the child says it rests on.
  final Map<String, String> cites;
  final String? finalPick;

  /// Once shown, the clue stays, even if a match is later undone.
  final bool clueShown;
  final Set<String> lockedTakes;

  /// `take|sentence` pairs checked wrong.
  final Set<String> triedCites;
  final bool finalLocked;
  final Set<String> finalTried;

  DiscussState copyWith({
    String? first,
    Map<String, String>? cites,
    String? finalPick,
    bool clearFinal = false,
    bool? clueShown,
    Set<String>? lockedTakes,
    Set<String>? triedCites,
    bool? finalLocked,
    Set<String>? finalTried,
  }) => DiscussState(
    first: first ?? this.first,
    cites: cites ?? this.cites,
    finalPick: clearFinal ? null : (finalPick ?? this.finalPick),
    clueShown: clueShown ?? this.clueShown,
    lockedTakes: lockedTakes ?? this.lockedTakes,
    triedCites: triedCites ?? this.triedCites,
    finalLocked: finalLocked ?? this.finalLocked,
    finalTried: finalTried ?? this.finalTried,
  );

  Map<String, Object?> toJson() => {
    'first': first,
    'cites': cites,
    'final': finalPick,
    'clue_shown': clueShown,
    'locked_takes': lockedTakes.toList(),
    'tried_cites': triedCites.toList(),
    'final_locked': finalLocked,
    'final_tried': finalTried.toList(),
  };

  static DiscussState fromJson(Map<String, Object?> j) {
    Set<String> set(String k) =>
        ((j[k] as List?) ?? const []).cast<String>().toSet();
    return DiscussState(
      first: j['first'] as String?,
      cites: Map<String, String>.from((j['cites'] as Map?) ?? const {}),
      finalPick: j['final'] as String?,
      clueShown: j['clue_shown'] == true,
      lockedTakes: set('locked_takes'),
      triedCites: set('tried_cites'),
      finalLocked: j['final_locked'] == true,
      finalTried: set('final_tried'),
    );
  }
}

abstract final class Discuss {
  static String pair(String take, String sentence) => '$take|$sentence';

  static ParseResult<DiscussPart> parse(
    Map<String, Object?> config, {
    required Set<String> sentenceIds,
    required Set<String> optionIds,
  }) {
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    final question = text(config['question']);
    if (question == null) {
      return const ParseResult.invalid('discuss needs a question.');
    }
    final rawTakes = config['takes'];
    if (rawTakes is! List || rawTakes.length != 2) {
      return const ParseResult.invalid('discuss has exactly 2 takes.');
    }
    final takes = <DiscussTake>[];
    for (final t in rawTakes) {
      final id = t is Map ? t['id'] : null;
      final character = VillageCharacter.byKey(
        t is Map ? t['character'] : null,
      );
      final body = t is Map ? text(t['text']) : null;
      final cites = t is Map ? t['cites'] : null;
      if (id is! String || id.isEmpty || character == null || body == null) {
        return ParseResult.invalid(
          'A take is {id, character, text, cites}; character is one of '
          '${VillageCharacter.keys.join(', ')}.',
        );
      }
      if (cites is! String || !sentenceIds.contains(cites)) {
        return const ParseResult.invalid('A take cites one of the sentences.');
      }
      takes.add(
        DiscussTake(
          id: id,
          character: character,
          text: body,
          cites: cites,
          audioRef: text((t as Map)['audio_ref']),
        ),
      );
    }
    if (takes[0].id == takes[1].id ||
        takes[0].character == takes[1].character) {
      return const ParseResult.invalid(
        'The two takes need their own ids and characters.',
      );
    }
    if (takes[0].cites == takes[1].cites) {
      return const ParseResult.invalid(
        'The two takes cite different sentences, or matching them means '
        'nothing.',
      );
    }
    final rawClue = config['clue'];
    final clueId = rawClue is Map ? rawClue['id'] : null;
    final clueText = rawClue is Map ? text(rawClue['text']) : null;
    if (clueId is! String || clueText == null || sentenceIds.contains(clueId)) {
      return const ParseResult.invalid(
        'clue is a new sentence {id, text}, not one of the passage\'s.',
      );
    }
    final rawAccepts = (rawClue as Map)['accepts'];
    Set<String>? accepts;
    if (rawAccepts != null) {
      if (rawAccepts is! List ||
          rawAccepts.isEmpty ||
          !rawAccepts.every(optionIds.contains)) {
        return const ParseResult.invalid(
          'clue accepts lists option ids, or is left out when both takes '
          'stay valid.',
        );
      }
      accepts = rawAccepts.cast<String>().toSet();
      if (accepts.length == optionIds.length) {
        return const ParseResult.invalid(
          'If the clue accepts every option, leave accepts out.',
        );
      }
    }
    return ParseResult.ok(
      DiscussPart(
        question: question,
        takes: List.unmodifiable(takes),
        clue: DiscussClue(
          id: clueId,
          text: clueText,
          audioRef: text(rawClue['audio_ref']),
          accepts: accepts,
        ),
        sentenceIds: Set.unmodifiable(sentenceIds),
        optionIds: Set.unmodifiable(optionIds),
      ),
    );
  }

  static (DiscussState, List<InteractionEvent>) reduce(
    DiscussPart part,
    DiscussState s,
    PassageAction action,
  ) {
    final optionIds = part.optionIds;
    final sentenceIds = part.sentenceIds;
    switch (action) {
      case TapPassageChoice():
        return (s, const []);
      case DiscussPickFirst(:final id):
        if (s.clueShown || !optionIds.contains(id) || s.first == id) {
          return (s, const []);
        }
        return (
          s.copyWith(first: id),
          [
            InteractionEvent('option_selected', {
              'option_id': id,
              'item_id': 'first',
            }),
          ],
        );
      case DiscussCite(:final takeId, :final sentenceId):
        if (s.first == null ||
            !part.takes.any((t) => t.id == takeId) ||
            !sentenceIds.contains(sentenceId) ||
            s.lockedTakes.contains(takeId) ||
            s.triedCites.contains(pair(takeId, sentenceId))) {
          return (s, const []);
        }
        final cites = {...s.cites, takeId: sentenceId};
        return (
          s.copyWith(
            cites: cites,
            clueShown: s.clueShown || cites.length == part.takes.length,
          ),
          [
            InteractionEvent('item_placed', {
              'item_id': takeId,
              'bucket_id': sentenceId,
            }),
          ],
        );
      case DiscussPickFinal(:final id):
        if (!s.clueShown ||
            s.finalLocked ||
            !optionIds.contains(id) ||
            s.finalTried.contains(id)) {
          return (s, const []);
        }
        return (
          s.copyWith(finalPick: id),
          [
            InteractionEvent('option_selected', {
              'option_id': id,
              'item_id': 'final',
            }),
          ],
        );
    }
  }

  static BlanksAnswer? extract(DiscussPart part, DiscussState s) {
    final first = s.first;
    final last = s.finalPick;
    if (first == null ||
        last == null ||
        s.cites.length != part.takes.length ||
        (s.lockedTakes.length == part.takes.length && s.finalLocked)) {
      return null;
    }
    return BlanksAnswer({
      'first': first,
      for (final e in s.cites.entries) 'take_${e.key}': e.value,
      'final': last,
    });
  }

  static DiscussState feedback(DiscussState s, EvaluationResult result) {
    final items = result.itemResults;
    final locked = {...s.lockedTakes};
    final tried = {...s.triedCites};
    final cites = <String, String>{};
    for (final e in s.cites.entries) {
      final verdict = items['take_${e.key}'];
      if (s.lockedTakes.contains(e.key) || verdict == true) {
        locked.add(e.key);
        cites[e.key] = e.value;
      } else if (verdict == false) {
        tried.add(pair(e.key, e.value));
      }
    }
    final finalVerdict = items['final'];
    final finalRight = finalVerdict != false;
    return s.copyWith(
      cites: cites,
      lockedTakes: locked,
      triedCites: tried,
      finalLocked: finalRight,
      clearFinal: !finalRight,
      finalTried: finalRight ? s.finalTried : {...s.finalTried, s.finalPick!},
    );
  }

  /// One item per take (the sentence it rests on: direct evidence) and,
  /// when the clue decides, one for the revised answer (proxy). When both
  /// takes stay valid the revision is practice and isn't an item at all.
  static EvaluationResult evaluate({
    required DiscussPart part,
    required BlanksAnswer answer,
    required EvaluationContext ctx,
    required String evaluator,
  }) {
    final b = answer.blanks;
    final items = <String, bool>{
      for (final t in part.takes) 'take_${t.id}': b['take_${t.id}'] == t.cites,
      if (part.clue.accepts != null)
        'final': part.clue.accepts!.contains(b['final']),
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
      evaluator: evaluator,
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}

/// The `discuss` view: the passage stays above; below it the question,
/// then the two takes with sentence chips, then the clue and the final
/// answer, each appearing as the step before is done.
class DiscussView extends StatelessWidget {
  const DiscussView({
    required this.part,
    required this.state,
    required this.sentences,
    required this.options,
    required this.optionOrder,
    required this.locale,
    required this.enabled,
    required this.dispatch,
    required this.passage,
    this.speaker,
    super.key,
  });

  final DiscussPart part;
  final DiscussState state;

  /// Sentence id → its number in the passage (1-based) and text.
  final List<(String, String)> sentences;
  final Map<String, String> options;
  final List<String> optionOrder;
  final Locale locale;
  final bool enabled;
  final void Function(PassageAction action) dispatch;
  final Widget passage;
  final ContentSpeaker? speaker;

  @override
  Widget build(BuildContext context) {
    final fr = locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final s = state;
    final heading = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: p.inkMuted,
    );

    Widget optionTile(String id, {required bool forFinal}) {
      final picked = forFinal ? s.finalPick == id : s.first == id;
      final tileState = forFinal
          ? (s.finalLocked && picked
                ? AnswerTileState.correct
                : s.finalTried.contains(id)
                ? AnswerTileState.retry
                : picked
                ? AnswerTileState.picked
                : AnswerTileState.idle)
          : (picked ? AnswerTileState.picked : AnswerTileState.idle);
      final canTap =
          enabled &&
          (forFinal
              ? !s.finalLocked && !s.finalTried.contains(id)
              : !s.clueShown);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnswerTile(
          key: ValueKey('discuss-${forFinal ? 'final' : 'first'}-$id'),
          label: options[id]!,
          prominent: true,
          state: tileState,
          semanticsState: tileState == AnswerTileState.retry
              ? (fr ? 'déjà essayé' : 'already tried')
              : picked
              ? (fr ? 'choisi' : 'chosen')
              : null,
          onTap: canTap
              ? () => dispatch(
                  forFinal ? DiscussPickFinal(id) : DiscussPickFirst(id),
                )
              : null,
        ),
      );
    }

    Widget citeChips(DiscussTake take) {
      final locked = s.lockedTakes.contains(take.id);
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (i, (id, text)) in sentences.indexed)
            SizedBox(
              width: 48,
              child: Semantics(
                label: fr
                    ? 'phrase ${i + 1} : $text'
                    : 'sentence ${i + 1}: $text',
                button: true,
                selected: s.cites[take.id] == id,
                excludeSemantics: true,
                child: AnswerTile(
                  key: ValueKey('discuss-cite-${take.id}-$id'),
                  label: '${i + 1}',
                  dense: true,
                  state: s.cites[take.id] == id
                      ? (locked
                            ? AnswerTileState.correct
                            : AnswerTileState.picked)
                      : s.triedCites.contains(Discuss.pair(take.id, id))
                      ? AnswerTileState.retry
                      : AnswerTileState.idle,
                  onTap:
                      enabled &&
                          !locked &&
                          !s.triedCites.contains(Discuss.pair(take.id, id))
                      ? () => dispatch(DiscussCite(take.id, id))
                      : null,
                ),
              ),
            ),
        ],
      );
    }

    final clue = part.clue;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              passage,
              const SizedBox(height: 16),
              Text(
                part.question,
                style: heading.copyWith(color: p.ink, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (final id in optionOrder) optionTile(id, forFinal: false),
              if (s.first != null) ...[
                const SizedBox(height: 12),
                RevealIntoView(
                  child: Text(
                    fr
                        ? 'Deux amis ont lu la même histoire. Quelle phrase montre ce que chacun pense ?'
                        : 'Two friends read the same story. Which sentence shows what each one thinks?',
                    key: const ValueKey('discuss-takes'),
                    style: heading,
                  ),
                ),
                const SizedBox(height: 8),
                for (final take in part.takes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CharacterSays(
                      character: take.character,
                      text: take.text,
                      locale: locale,
                      onSpeak: speaker == null || take.audioRef == null
                          ? null
                          : () => speaker!.speak(
                              audioRef: take.audioRef!,
                              partId: take.id,
                            ),
                      trailing: citeChips(take),
                    ),
                  ),
              ],
              if (s.clueShown) ...[
                RevealIntoView(
                  child: Container(
                    key: const ValueKey('discuss-clue'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.goldPale,
                      borderRadius: Radii.cardMd,
                      border: Border.all(color: p.gold, width: 2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (speaker != null && clue.audioRef != null)
                          IconButton(
                            key: const ValueKey('discuss-clue-speak'),
                            onPressed: () => speaker!.speak(
                              audioRef: clue.audioRef!,
                              partId: clue.id,
                            ),
                            tooltip: fr
                                ? 'Écouter l’indice'
                                : 'Listen to the clue',
                            color: p.quebecBlue,
                            icon: const Icon(Icons.volume_up_rounded),
                          ),
                        Expanded(
                          child: Semantics(
                            label: fr
                                ? 'Nouvel indice : ${clue.text}'
                                : 'New clue: ${clue.text}',
                            liveRegion: true,
                            excludeSemantics: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: fr
                                        ? 'Nouvel indice : '
                                        : 'New clue: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: clue.text),
                                ],
                              ),
                              style: TextStyle(
                                fontFamily: VillageType.display,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fr
                      ? 'Et maintenant, que penses-tu ? Tu peux garder ta réponse ou la changer.'
                      : 'What do you think now? You can keep your answer or change it.',
                  style: heading,
                ),
                const SizedBox(height: 8),
                for (final id in optionOrder) optionTile(id, forFinal: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrolls itself to the top of the activity body when it first appears,
/// so a part the child's tap just revealed isn't left below the fold (UX
/// review AM28: Léa and Omar appeared off-screen). Instant when motion is
/// reduced.
class RevealIntoView extends StatefulWidget {
  const RevealIntoView({required this.child, super.key});
  final Widget child;

  @override
  State<RevealIntoView> createState() => _RevealIntoViewState();
}

class _RevealIntoViewState extends State<RevealIntoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: still ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
