import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/swatch_text.dart';
import '../widgets/village_characters.dart';

/// One word of the draft. With [fix], it's misspelled and [fix] is how it's
/// written; [options] are the spellings offered when the child says « à
/// corriger » (they include [fix] when there is one).
class ProofToken {
  const ProofToken({
    required this.id,
    required this.text,
    this.fix,
    this.options = const [],
  });
  final String id;
  final String text;
  final String? fix;
  final List<String> options;

  bool get isError => fix != null;
}

/// One pass of the checklist: what to look at (« Je vérifie les accords
/// dans le GN ») and which words it's about.
class ProofPass {
  const ProofPass({required this.id, required this.say, required this.targets});
  final String id;
  final String say;
  final List<String> targets;
}

class ProofContent {
  const ProofContent({
    required this.character,
    required this.sentences,
    required this.passes,
  });

  final VillageCharacter character;
  final List<List<ProofToken>> sentences;
  final List<ProofPass> passes;

  ProofToken token(String id) =>
      sentences.expand((s) => s).firstWhere((t) => t.id == id);

  /// What the child may choose for [id]: keep it, or one of its spellings.
  List<String> choices(String id) => [
    ProofreadEngine.keep,
    ...token(id).options,
  ];

  /// The right decision for [id].
  String right(String id) => token(id).fix ?? ProofreadEngine.keep;

  Iterable<String> get targets => passes.expand((p) => p.targets);
}

class ProofState {
  const ProofState({
    required this.passTargets,
    this.allowed = const {},
    this.pass = 0,
    this.open,
    this.choice = const {},
    this.locked = const {},
    this.tried = const {},
  });

  /// Each pass's words, so the reducer can tell what's in play.
  final List<List<String>> passTargets;

  /// Each target word's choices: keep, or one of its spellings.
  final Map<String, List<String>> allowed;

  int get passCount => passTargets.length;

  bool decided(String t) => locked.contains(t) || choice.containsKey(t);

  bool passDone(int pass) => passTargets[pass].every(decided);

  /// The pass the child is on.
  final int pass;

  /// The word whose choices are showing.
  final String? open;

  /// Token id → `keep` or the chosen spelling.
  final Map<String, String> choice;

  /// Words checked right.
  final Set<String> locked;

  /// `token|choice` checked wrong.
  final Set<String> tried;

  ProofState copyWith({
    int? pass,
    String? open,
    bool clearOpen = false,
    Map<String, String>? choice,
    Set<String>? locked,
    Set<String>? tried,
  }) => ProofState(
    passTargets: passTargets,
    allowed: allowed,
    pass: pass ?? this.pass,
    open: clearOpen ? null : (open ?? this.open),
    choice: choice ?? this.choice,
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
  );
}

sealed class ProofAction {
  const ProofAction();
}

/// Tap a word of the current pass: show its choices.
class OpenProofToken extends ProofAction {
  const OpenProofToken(this.tokenId);
  final String tokenId;
}

/// Keep the word ([ProofreadEngine.keep]) or pick a spelling.
class ChooseProof extends ProofAction {
  const ChooseProof(this.tokenId, this.choice);
  final String tokenId;
  final String choice;
}

/// Every word of this pass is decided: on to the next one.
class NextProofPass extends ProofAction {
  const NextProofPass();
}

/// Le brouillon de Léa — the `proofread` engine (plan
/// PLAN_GRADES_2_6_ENGINES §2.2 #2, app ADR 0120).
///
/// A village character's short draft, and a checklist of 1-4 passes: the
/// PFEQ's « procédure d'autocorrection », one thing at a time (« Je trouve
/// les verbes. Je vérifie leur finale. »). In each pass the words it's
/// about are marked; the child taps each one and says « C'est bien écrit »
/// or picks how it should be written. « Étape suivante » opens the next
/// pass once every word of this one is decided; VALIDER, on the last pass,
/// grades every decision of every pass, each as an item. A right word
/// locks; a wrong decision is cleared and can't be made again.
///
/// It practises the revision procedure on someone else's draft, which is
/// what an app can do: the child's own text never enters the app (no free
/// typing, Hafid 2026-11-03).
class ProofreadEngine
    implements
        LearningEngine<ProofContent, ProofState, ProofAction, BlanksAnswer> {
  const ProofreadEngine();

  static const key = 'proofread';

  /// The choice that keeps a word as it is.
  static const keep = 'keep';
  static final _id = RegExp(r'^[a-z0-9_-]+$');

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<ProofContent> parse(Map<String, Object?> config) {
    final character = VillageCharacter.byKey(config['character']);
    if (character == null) {
      return const ParseResult.invalid('character is a village character.');
    }
    final rawSentences = config['sentences'];
    if (rawSentences is! List ||
        rawSentences.isEmpty ||
        rawSentences.length > 8) {
      return const ParseResult.invalid('A draft is 1 to 8 sentences.');
    }
    final ids = <String>{};
    final sentences = <List<ProofToken>>[];
    for (final s in rawSentences) {
      final rawTokens = s is Map ? s['tokens'] : null;
      if (rawTokens is! List || rawTokens.isEmpty || rawTokens.length > 30) {
        return const ParseResult.invalid('A sentence is 1 to 30 tokens.');
      }
      final tokens = <ProofToken>[];
      for (final t in rawTokens) {
        final m = t is Map ? t : const {};
        final id = m['id'];
        final text = m['text'];
        final fix = m['fix'];
        final rawOptions = m['options'] ?? const [];
        if (id is! String ||
            !_id.hasMatch(id) ||
            id == keep ||
            !ids.add(id) ||
            text is! String ||
            text.trim().isEmpty ||
            (fix != null && (fix is! String || fix == text)) ||
            rawOptions is! List ||
            rawOptions.length > 3 ||
            !rawOptions.every((o) => o is String && o != text)) {
          return const ParseResult.invalid(
            'Every token needs a unique id and text; a fix differs from the '
            'text; options are 0 to 3 other spellings.',
          );
        }
        final options = rawOptions.cast<String>();
        if (options.toSet().length != options.length ||
            (fix != null && !options.contains(fix))) {
          return const ParseResult.invalid(
            'options are distinct, and include the fix when there is one.',
          );
        }
        tokens.add(
          ProofToken(
            id: id,
            text: text,
            fix: fix as String?,
            options: List.unmodifiable(options),
          ),
        );
      }
      sentences.add(List.unmodifiable(tokens));
    }

    final rawPasses = config['passes'];
    if (rawPasses is! List || rawPasses.isEmpty || rawPasses.length > 4) {
      return const ParseResult.invalid('A checklist is 1 to 4 passes.');
    }
    final passes = <ProofPass>[];
    final covered = <String>{};
    for (final p in rawPasses) {
      final m = p is Map ? p : const {};
      final id = m['id'];
      final say = m['say'];
      final targets = m['targets'];
      if (id is! String ||
          say is! String ||
          say.trim().isEmpty ||
          targets is! List ||
          targets.isEmpty ||
          targets.length > 8 ||
          !targets.every(ids.contains) ||
          passes.any((x) => x.id == id)) {
        return const ParseResult.invalid(
          'Every pass needs a unique id, what to check (say), and 1 to 8 '
          'target token ids.',
        );
      }
      for (final t in targets.cast<String>()) {
        if (!covered.add(t)) {
          return const ParseResult.invalid('A word belongs to one pass only.');
        }
      }
      passes.add(
        ProofPass(id: id, say: say, targets: List.unmodifiable(targets.cast())),
      );
    }
    final errors = [
      for (final s in sentences)
        for (final t in s)
          if (t.isError) t.id,
    ];
    if (errors.isEmpty) {
      return const ParseResult.invalid('A draft has at least one mistake.');
    }
    if (!errors.every(covered.contains)) {
      return const ParseResult.invalid(
        'Every mistake is a target of some pass, or it can never be fixed.',
      );
    }
    final hint = config['hint'];
    if (hint != null && hint is! String) {
      return const ParseResult.invalid('hint is a string or null.');
    }
    return ParseResult.ok(
      ProofContent(
        character: character,
        sentences: List.unmodifiable(sentences),
        passes: List.unmodifiable(passes),
      ),
    );
  }

  @override
  ProofState initialize(ProofContent content, EngineSeed seed) =>
      ProofState(passTargets: _targets(content), allowed: _allowed(content));

  static Map<String, List<String>> _allowed(ProofContent c) =>
      Map.unmodifiable({for (final t in c.targets) t: c.choices(t)});

  static List<List<String>> _targets(ProofContent c) =>
      List.unmodifiable([for (final p in c.passes) p.targets]);

  static String _pair(String token, String choice) => '$token|$choice';

  @override
  Transition<ProofState> reduce(ProofState s, ProofAction action) {
    switch (action) {
      case OpenProofToken(:final tokenId):
        if (!s.passTargets[s.pass].contains(tokenId) ||
            s.locked.contains(tokenId)) {
          return Transition(s);
        }
        return Transition(s.copyWith(open: tokenId), [
          InteractionEvent('option_selected', {'option_id': tokenId}),
        ]);
      case ChooseProof(:final tokenId, :final choice):
        if (s.open != tokenId ||
            !(s.allowed[tokenId]?.contains(choice) ?? false) ||
            s.locked.contains(tokenId) ||
            s.tried.contains(_pair(tokenId, choice))) {
          return Transition(s);
        }
        return Transition(
          s.copyWith(choice: {...s.choice, tokenId: choice}, clearOpen: true),
          [
            InteractionEvent('item_placed', {
              'item_id': tokenId,
              'bucket_id': choice,
            }),
          ],
        );
      case NextProofPass():
        if (s.pass >= s.passCount - 1 || !s.passDone(s.pass)) {
          return Transition(s);
        }
        return Transition(s.copyWith(pass: s.pass + 1, clearOpen: true), [
          // The next step of the checklist opening is the moment (ADR 0118).
          RevealEvent('pass', itemId: '${s.pass + 1}'),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(ProofState s) {
    // VALIDER on the last step, once every word of every step is decided,
    // and something is still unchecked.
    if (s.pass != s.passCount - 1) return null;
    final all = s.passTargets.expand((t) => t);
    if (!all.every(s.decided) || all.every(s.locked.contains)) return null;
    return BlanksAnswer(s.choice);
  }

  @override
  ProofState applyFeedback(ProofState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final locked = {...s.locked};
    final tried = {...s.tried};
    final choice = <String, String>{};
    for (final e in s.choice.entries) {
      if (locked.contains(e.key) || result.itemResults[e.key] == true) {
        locked.add(e.key);
        choice[e.key] = e.value;
      } else {
        tried.add(_pair(e.key, e.value));
      }
    }
    // Back to the first step with something left to fix.
    var pass = s.passCount - 1;
    for (var i = 0; i < s.passCount; i++) {
      if (!s.passTargets[i].every(locked.contains)) {
        pass = i;
        break;
      }
    }
    return s.copyWith(
      pass: pass,
      choice: choice,
      locked: locked,
      tried: tried,
      clearOpen: true,
    );
  }

  @override
  Map<String, Object?> snapshot(ProofState s) => {
    'pass': s.pass,
    'open': s.open,
    'choice': s.choice,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
  };

  @override
  ProofState? restore(ProofContent content, Map<String, Object?> snap) {
    try {
      final targets = content.targets.toSet();
      final pass = snap['pass'] as int;
      final open = snap['open'] as String?;
      final choice = Map<String, String>.from(
        snap['choice'] as Map? ?? const {},
      );
      final locked = (snap['locked'] as List? ?? const [])
          .cast<String>()
          .toSet();
      if (pass < 0 ||
          pass >= content.passes.length ||
          (open != null && !targets.contains(open)) ||
          !choice.keys.every(targets.contains) ||
          !choice.entries.every(
            (e) => content.choices(e.key).contains(e.value),
          ) ||
          !locked.every(choice.containsKey)) {
        return null;
      }
      return ProofState(
        passTargets: _targets(content),
        allowed: _allowed(content),
        pass: pass,
        open: open,
        choice: choice,
        locked: locked,
        tried: (snap['tried'] as List? ?? const []).cast<String>().toSet(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<ProofContent, ProofState, ProofAction> view,
  ) => _ProofBoard(view: view);
}

class _ProofBoard extends StatelessWidget {
  const _ProofBoard({required this.view});
  final EngineView<ProofContent, ProofState, ProofAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final c = view.content;
    final s = view.state;
    final pass = c.passes[s.pass];
    final here = pass.targets.toSet();
    final style = TextStyle(
      fontFamily: VillageType.display,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 1.35,
      color: p.ink,
    );
    final name = c.character.name(view.locale);

    String shown(ProofToken t) {
      final pick = s.choice[t.id];
      return pick == null || pick == ProofreadEngine.keep ? t.text : pick;
    }

    Widget word(ProofToken t) {
      final target = here.contains(t.id);
      if (!target) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SwatchText(shown(t), style: style),
        );
      }
      final locked = s.locked.contains(t.id);
      final decided = s.choice.containsKey(t.id);
      final open = s.open == t.id;
      final edge = locked
          ? p.success
          : open
          ? p.quebecBlueBright
          : p.quebecBlue;
      return Semantics(
        button: !locked,
        selected: open,
        label: shown(t),
        hint: locked
            ? (fr ? 'vérifié' : 'checked')
            : decided
            ? (fr ? 'décidé, touche pour changer' : 'decided, tap to change')
            : (fr ? 'à vérifier' : 'to check'),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('proof-token-${t.id}'),
          borderRadius: Radii.cardMd,
          onTap: view.enabled && !locked
              ? () => view.dispatch(OpenProofToken(t.id))
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: Radii.cardMd,
              color: decided || locked
                  ? edge.withValues(alpha: 0.10)
                  : p.goldPale,
              border: Border(bottom: BorderSide(color: edge, width: 3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwatchText(shown(t), style: style),
                if (decided || locked) ...[
                  const SizedBox(width: 4),
                  Icon(
                    s.choice[t.id] == ProofreadEngine.keep
                        ? Icons.check_rounded
                        : Icons.edit_rounded,
                    size: 18,
                    color: edge,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final open = s.open;
    final last = s.pass == c.passes.length - 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CharacterPortrait(character: c.character, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fr ? 'Le brouillon de $name' : '$name’s draft',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: p.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                c.passes.length == 1
                    ? pass.say
                    : fr
                    ? 'Étape ${s.pass + 1} sur ${c.passes.length} : ${pass.say}'
                    : 'Step ${s.pass + 1} of ${c.passes.length}: ${pass.say}',
                key: const ValueKey('proof-pass'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: p.quebecBlue,
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: Radii.cardMd,
                  border: Border.all(color: p.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    key: const ValueKey('proof-draft'),
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final sentence in c.sentences)
                        for (final t in sentence) word(t),
                    ],
                  ),
                ),
              ),
              if (open != null) ...[
                const SizedBox(height: 16),
                Text(
                  fr
                      ? '« ${c.token(open).text} » : c’est bien écrit ?'
                      : '“${c.token(open).text}”: is it written right?',
                  key: const ValueKey('proof-question'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.ink),
                ),
                const SizedBox(height: 10),
                Wrap(
                  key: const ValueKey('proof-choices'),
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final choice in c.choices(open))
                      SizedBox(
                        width: 200,
                        child: Builder(
                          builder: (context) {
                            final tried = s.tried.contains(
                              ProofreadEngine._pair(open, choice),
                            );
                            return AnswerTile(
                              key: ValueKey('proof-choice-$open-$choice'),
                              label: choice == ProofreadEngine.keep
                                  ? (fr
                                        ? '✓ C’est bien écrit'
                                        : '✓ It’s written right')
                                  : choice,
                              state: tried
                                  ? AnswerTileState.retry
                                  : s.choice[open] == choice
                                  ? AnswerTileState.picked
                                  : AnswerTileState.idle,
                              semanticsState: tried
                                  ? (fr ? 'déjà essayé' : 'already tried')
                                  : null,
                              onTap: view.enabled && !tried
                                  ? () =>
                                        view.dispatch(ChooseProof(open, choice))
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
              if (!last) ...[
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 240,
                    child: AnswerTile(
                      key: const ValueKey('proof-next'),
                      label: fr ? 'Étape suivante →' : 'Next step →',
                      state: AnswerTileState.idle,
                      onTap: view.enabled && s.passDone(s.pass)
                          ? () => view.dispatch(const NextProofPass())
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a draft: one item per word any pass is about, true when the
/// child's decision is the right one (keep a right word, fix a wrong one
/// with its spelling). A word left undecided is an item missed, so a
/// board can't be right until every word is checked.
class ProofreadEvaluator implements Evaluator<ProofContent, BlanksAnswer> {
  const ProofreadEvaluator();

  @override
  String get engineKey => ProofreadEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    ProofContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final given = answer.blanks;
    if (given.isEmpty) throw ArgumentError('An answer must decide something.');
    final targets = content.targets.toList();
    final items = {
      for (final t in targets)
        if (given.containsKey(t)) t: given[t] == content.right(t),
    };
    final hits = items.values.where((v) => v).length;
    final all = hits == targets.length;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / targets.length,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
