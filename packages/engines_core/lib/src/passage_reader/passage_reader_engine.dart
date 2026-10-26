import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import 'passage_discuss.dart';

/// What the child does with the passage.
enum PassageTask {
  /// Tap the sentence (or sentences) that prove the answer: "Trouve la
  /// phrase qui dit où dort le chat."
  find,

  /// Pick an answer below the passage, which stays on screen.
  choose,

  /// Answer, compare two characters' readings with the sentences they rest
  /// on, then revise after a new clue (app ADR 0088).
  discuss,
}

class PassageSentence {
  const PassageSentence({required this.id, required this.text, this.audioRef});
  final String id;
  final String text;

  /// This sentence alone, read aloud on a tap of its own speaker.
  final String? audioRef;
}

class PassageOption {
  const PassageOption({required this.id, required this.label});
  final String id;
  final String label;
}

class PassageContent {
  const PassageContent({
    required this.task,
    required this.sentences,
    required this.correct,
    this.title,
    this.options = const [],
    this.discuss,
  });

  final PassageTask task;
  final String? title;

  /// In reading order, never shuffled: a story has its own order.
  final List<PassageSentence> sentences;

  /// `choose` only.
  final List<PassageOption> options;

  /// Sentence ids (`find`) or the one option id (`choose`). Empty for
  /// `discuss`, which grades its own parts.
  final Set<String> correct;

  /// `discuss` only.
  final DiscussPart? discuss;

  bool get multiple => correct.length > 1;

  /// What a tap picks: sentences, or options.
  List<String> get choiceIds => task == PassageTask.find
      ? [for (final s in sentences) s.id]
      : [for (final o in options) o.id];
}

class PassageState {
  const PassageState({
    required this.order,
    this.single = false,
    this.selected = const {},
    this.found = const {},
    this.tried = const {},
    this.discuss,
    this.discussPart,
  });

  /// The ids a tap can pick, in display order. Options may be shuffled;
  /// sentences never are.
  final List<String> order;

  /// One right answer: a new pick replaces the last.
  final bool single;
  final Set<String> selected;

  /// Checked right — fixed for the rest of the question.
  final Set<String> found;

  /// Checked wrong — amber, and no longer tappable.
  final Set<String> tried;

  /// `discuss` only.
  final DiscussState? discuss;

  /// `discuss` only: the content the reducer checks actions against.
  final DiscussPart? discussPart;

  PassageState copyWith({
    Set<String>? selected,
    Set<String>? found,
    Set<String>? tried,
    DiscussState? discuss,
  }) => PassageState(
    order: order,
    single: single,
    selected: selected ?? this.selected,
    found: found ?? this.found,
    tried: tried ?? this.tried,
    discuss: discuss ?? this.discuss,
    discussPart: discussPart,
  );
}

sealed class PassageAction {
  const PassageAction();
}

/// Tap a sentence (`find`) or an option (`choose`).
class TapPassageChoice extends PassageAction {
  const TapPassageChoice(this.id);
  final String id;
}

/// `discuss`: the child's first answer.
class DiscussPickFirst extends PassageAction {
  const DiscussPickFirst(this.id);
  final String id;
}

/// `discuss`: the sentence a take rests on.
class DiscussCite extends PassageAction {
  const DiscussCite(this.takeId, this.sentenceId);
  final String takeId;
  final String sentenceId;
}

/// `discuss`: the answer after the clue.
class DiscussPickFinal extends PassageAction {
  const DiscussPickFinal(this.id);
  final String id;
}

/// Read a short text, then answer about it — the `passage_reader` engine
/// (app ADR 0044; the catalogue's #1, merging highlight_text,
/// evidence_highlighter and audio_listen).
///
/// Every other engine asks one isolated question. Most of grade 1's PFEQ —
/// 61 % of its marked skills — is reading, listening and responding to a
/// text: "extraire des informations explicites", "identifier ce dont on
/// parle", "Response Process". Here the text is the stimulus and stays on
/// screen.
///
/// - `find`: tap the sentence that proves the answer. Several right
///   sentences make it "trouve toutes les phrases…", with partial credit.
/// - `choose`: pick one answer below the passage.
/// - `discuss`: answer a question, then match two village characters'
///   readings to the sentences they rest on, then keep or change the
///   answer after a new clue ([Discuss]).
///
/// A child who can't read the passage yet taps the speaker beside each
/// sentence. Nothing is read aloud unless tapped, and no speaker is drawn
/// when the host has no [ContentSpeakerScope] or the sentence no audio.
class PassageReaderEngine
    implements
        LearningEngine<
          PassageContent,
          PassageState,
          PassageAction,
          AnswerValue
        > {
  const PassageReaderEngine();

  static const key = 'passage_reader';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static String? _text(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw : null;

  @override
  ParseResult<PassageContent> parse(Map<String, Object?> config) {
    final task = switch (config['task']) {
      null || 'find' => PassageTask.find,
      'choose' => PassageTask.choose,
      'discuss' => PassageTask.discuss,
      _ => null,
    };
    if (task == null) {
      return const ParseResult.invalid('task is find, choose or discuss.');
    }
    final rawSentences = config['sentences'];
    if (rawSentences is! List ||
        rawSentences.length < 2 ||
        rawSentences.length > 10) {
      return const ParseResult.invalid('A passage has 2 to 10 sentences.');
    }
    final sentences = <PassageSentence>[];
    for (final s in rawSentences) {
      final id = s is Map ? s['id'] : null;
      final text = s is Map ? _text(s['text']) : null;
      if (id is! String || id.isEmpty || text == null) {
        return const ParseResult.invalid(
          'Every sentence needs an id and text.',
        );
      }
      if (sentences.any((x) => x.id == id)) {
        return const ParseResult.invalid('Sentence ids must be unique.');
      }
      sentences.add(
        PassageSentence(id: id, text: text, audioRef: _text(s['audio_ref'])),
      );
    }
    final title = _text(config['title']);

    if (task == PassageTask.find) {
      if (config.containsKey('options') || config.containsKey('correct')) {
        return const ParseResult.invalid(
          'options and correct belong to task choose.',
        );
      }
      final raw = config['correct_ids'];
      final ids = {for (final s in sentences) s.id};
      if (raw is! List ||
          raw.isEmpty ||
          raw.any((x) => x is! String || !ids.contains(x)) ||
          raw.toSet().length != raw.length) {
        return const ParseResult.invalid(
          'correct_ids must name one or more sentences, each once.',
        );
      }
      if (raw.length == sentences.length) {
        return const ParseResult.invalid(
          'If every sentence is right, there is nothing to find.',
        );
      }
      return ParseResult.ok(
        PassageContent(
          task: task,
          title: title,
          sentences: List.unmodifiable(sentences),
          correct: raw.cast<String>().toSet(),
        ),
      );
    }

    if (config.containsKey('correct_ids')) {
      return const ParseResult.invalid('correct_ids belongs to task find.');
    }
    final rawOptions = config['options'];
    if (rawOptions is! List || rawOptions.length < 2 || rawOptions.length > 4) {
      return const ParseResult.invalid('Choosing needs 2 to 4 options.');
    }
    final options = <PassageOption>[];
    for (final o in rawOptions) {
      final id = o is Map ? o['id'] : null;
      final label = o is Map ? _text(o['label']) : null;
      if (id is! String || id.isEmpty || label == null) {
        return const ParseResult.invalid('Every option needs an id and label.');
      }
      if (options.any((x) => x.id == id)) {
        return const ParseResult.invalid('Option ids must be unique.');
      }
      options.add(PassageOption(id: id, label: label));
    }
    if (task == PassageTask.discuss) {
      if (config.containsKey('correct')) {
        return const ParseResult.invalid(
          'discuss has no correct: the clue\'s accepts says what is right.',
        );
      }
      final part = Discuss.parse(
        config,
        sentenceIds: {for (final s in sentences) s.id},
        optionIds: {for (final o in options) o.id},
      );
      return switch (part) {
        ParseOk(:final value) => ParseResult.ok(
          PassageContent(
            task: task,
            title: title,
            sentences: List.unmodifiable(sentences),
            options: List.unmodifiable(options),
            correct: const {},
            discuss: value,
          ),
        ),
        ParseInvalid(:final reason) => ParseResult.invalid(reason),
        ParseUnsupported(:final reason) => ParseResult.unsupported(reason),
      };
    }
    for (final key in const ['question', 'takes', 'clue']) {
      if (config.containsKey(key)) {
        return ParseResult.invalid('$key belongs to task discuss.');
      }
    }
    final correct = config['correct'];
    if (correct is! String || !options.any((o) => o.id == correct)) {
      return const ParseResult.invalid('correct must name one of the options.');
    }
    return ParseResult.ok(
      PassageContent(
        task: task,
        title: title,
        sentences: List.unmodifiable(sentences),
        options: List.unmodifiable(options),
        correct: {correct},
      ),
    );
  }

  @override
  PassageState initialize(PassageContent content, EngineSeed seed) {
    final order = content.choiceIds;
    // Options shuffle so the right one isn't always first; a passage's
    // sentences are a text and keep their order.
    if (content.task != PassageTask.find) order.shuffle(seed.random());
    return PassageState(
      order: List.unmodifiable(order),
      single: !content.multiple,
      discuss: content.task == PassageTask.discuss
          ? const DiscussState()
          : null,
      discussPart: content.discuss,
    );
  }

  @override
  Transition<PassageState> reduce(PassageState s, PassageAction action) {
    switch (action) {
      case DiscussPickFirst() || DiscussCite() || DiscussPickFinal():
        final d = s.discuss;
        final part = s.discussPart;
        if (d == null || part == null) return Transition(s);
        final (next, events) = Discuss.reduce(part, d, action);
        return Transition(s.copyWith(discuss: next), events);
      case TapPassageChoice(:final id):
        if (!s.order.contains(id) ||
            s.found.contains(id) ||
            s.tried.contains(id)) {
          return Transition(s);
        }
        if (s.selected.contains(id)) {
          return Transition(s.copyWith(selected: {...s.selected}..remove(id)), [
            InteractionEvent('option_deselected', {'option_id': id}),
          ]);
        }
        return Transition(
          s.copyWith(selected: s.single ? {id} : {...s.selected, id}),
          [
            InteractionEvent('option_selected', {'option_id': id}),
          ],
        );
    }
  }

  @override
  AnswerValue? extractAnswer(PassageState s) {
    final d = s.discuss;
    if (d != null) return Discuss.extract(s.discussPart!, d);
    return s.selected.isEmpty
        ? null
        : MultiSelectAnswer({...s.found, ...s.selected});
  }

  @override
  PassageState applyFeedback(PassageState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final d = s.discuss;
    if (d != null) return s.copyWith(discuss: Discuss.feedback(d, result));
    return s.copyWith(
      selected: const {},
      found: {
        ...s.found,
        for (final e in result.itemResults.entries)
          if (e.value) e.key,
      },
      tried: {
        ...s.tried,
        for (final e in result.itemResults.entries)
          if (!e.value) e.key,
      },
    );
  }

  @override
  Map<String, Object?> snapshot(PassageState s) => {
    'order': s.order,
    'selected': s.selected.toList(),
    'found': s.found.toList(),
    'tried': s.tried.toList(),
    if (s.discuss != null) 'discuss': s.discuss!.toJson(),
  };

  @override
  PassageState? restore(PassageContent content, Map<String, Object?> snap) {
    try {
      final order = (snap['order'] as List).cast<String>();
      final authored = content.choiceIds;
      final known = authored.toSet();
      if (order.length != known.length || !order.every(known.contains)) {
        return null;
      }
      final part = content.discuss;
      if (part != null) {
        final d = DiscussState.fromJson(
          (snap['discuss']! as Map).cast<String, Object?>(),
        );
        final takes = {for (final t in part.takes) t.id: t.cites};
        bool option(String? id) => id == null || known.contains(id);
        if (!option(d.first) ||
            !option(d.finalPick) ||
            !d.cites.keys.every(takes.containsKey) ||
            !d.cites.values.every(part.sentenceIds.contains) ||
            !d.lockedTakes.every((t) => d.cites[t] == takes[t]) ||
            (d.cites.isNotEmpty && d.first == null)) {
          return null;
        }
        return PassageState(
          order: List.unmodifiable(order),
          discuss: d,
          discussPart: part,
        );
      }
      if (content.task == PassageTask.find) {
        // A text is never reordered.
        for (var i = 0; i < order.length; i++) {
          if (order[i] != authored[i]) return null;
        }
      }
      Set<String> set(String k) =>
          ((snap[k] as List?) ?? const []).cast<String>().toSet();
      final selected = set('selected');
      final found = set('found');
      final tried = set('tried');
      if (!selected.followedBy(found).followedBy(tried).every(known.contains) ||
          !content.correct.containsAll(found) ||
          tried.any(content.correct.contains) ||
          (!content.multiple && selected.length > 1)) {
        return null;
      }
      return PassageState(
        order: List.unmodifiable(order),
        single: !content.multiple,
        selected: selected,
        found: found,
        tried: tried,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<PassageContent, PassageState, PassageAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final content = view.content;
    final p = VillagePalette.of(context);
    final speaker = ContentSpeakerScope.maybeOf(context);

    AnswerTileState stateOf(String id) => s.found.contains(id)
        ? AnswerTileState.correct
        : s.tried.contains(id)
        ? AnswerTileState.retry
        : s.selected.contains(id)
        ? AnswerTileState.picked
        : AnswerTileState.idle;

    String? hintOf(String id) => s.found.contains(id)
        ? (fr ? 'trouvé' : 'found')
        : s.tried.contains(id)
        ? (fr ? 'déjà essayé' : 'already tried')
        : s.selected.contains(id)
        ? (fr ? 'choisi' : 'chosen')
        : null;

    VoidCallback? tapOf(String id) =>
        view.enabled && !s.found.contains(id) && !s.tried.contains(id)
        ? () => view.dispatch(TapPassageChoice(id))
        : null;

    final find = content.task == PassageTask.find;
    final passage = _PassageCard(
      title: content.title,
      children: [
        for (final (i, sentence) in content.sentences.indexed)
          _SentenceRow(
            key: ValueKey('passage-sentence-${sentence.id}'),
            number: i + 1,
            text: sentence.text,
            fr: fr,
            onSpeak: speaker == null || sentence.audioRef == null
                ? null
                : () => speaker.speak(
                    audioRef: sentence.audioRef!,
                    partId: sentence.id,
                  ),
            // In `choose` the text is only read; in `find` it's what's tapped.
            state: find ? stateOf(sentence.id) : null,
            hint: find ? hintOf(sentence.id) : null,
            onTap: find ? tapOf(sentence.id) : null,
          ),
      ],
    );

    final part = content.discuss;
    if (part != null) {
      return DiscussView(
        part: part,
        state: s.discuss!,
        sentences: [for (final x in content.sentences) (x.id, x.text)],
        options: {for (final o in content.options) o.id: o.label},
        optionOrder: s.order,
        locale: view.locale,
        enabled: view.enabled,
        dispatch: view.dispatch,
        passage: passage,
        speaker: speaker,
      );
    }

    final toFind = content.correct.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (find && content.multiple)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    fr
                        ? 'Trouvées : ${s.found.length} sur $toFind'
                        : 'Found: ${s.found.length} of $toFind',
                    key: const ValueKey('passage-count'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.inkMuted,
                    ),
                  ),
                ),
              passage,
              if (!find) ...[
                const SizedBox(height: 16),
                for (final id in s.order)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnswerTile(
                      key: ValueKey('passage-option-$id'),
                      label: content.options
                          .firstWhere((o) => o.id == id)
                          .label,
                      state: stateOf(id),
                      semanticsState: hintOf(id),
                      onTap: tapOf(id),
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

/// The passage on its own white card, like a page.
class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return DecoratedBox(
      key: const ValueKey('passage-card'),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.cardMd,
        border: Border.all(color: p.line, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// One sentence: its speaker on the left (Hafid's rule for the prompt,
/// applied to every speaker), then the text. Tappable in `find` with the
/// same four states as [AnswerTile], each readable without colour.
class _SentenceRow extends StatelessWidget {
  const _SentenceRow({
    required this.number,
    required this.text,
    required this.fr,
    required this.onSpeak,
    required this.state,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final int number;
  final String text;
  final bool fr;
  final VoidCallback? onSpeak;

  /// Null in `choose`: the sentence is only read, never picked.
  final AnswerTileState? state;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final (border, fill, icon) = switch (state) {
      null => (Colors.transparent, Colors.transparent, null),
      AnswerTileState.idle => (p.line, p.surface, null),
      AnswerTileState.picked => (p.quebecBlueBright, p.navHoverFill, null),
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
    };
    final textWidget = Text(
      text,
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.35,
        color: p.ink,
      ),
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: textWidget),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: border),
          ],
        ],
      ),
    );
    final sentence = state == null
        ? Semantics(
            label: fr ? 'phrase $number : $text' : 'sentence $number: $text',
            excludeSemantics: true,
            child: body,
          )
        : Semantics(
            button: true,
            selected: state == AnswerTileState.picked,
            enabled: onTap != null,
            label: fr ? 'phrase $number : $text' : 'sentence $number: $text',
            hint: hint,
            excludeSemantics: true,
            child: Material(
              color: fill,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.cardSm,
                side: BorderSide(
                  color: border,
                  width: state == AnswerTileState.picked ? 3 : 2,
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: Radii.cardSm,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: body,
                ),
              ),
            ),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onSpeak != null) ...[
          IconButton(
            key: ValueKey('passage-speak-$number'),
            onPressed: onSpeak,
            tooltip: fr
                ? 'Écouter la phrase $number'
                : 'Listen to sentence $number',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            color: p.quebecBlue,
            icon: const Icon(Icons.volume_up_rounded),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(child: sentence),
      ],
    );
  }
}

/// Grades a `passage_reader` answer.
///
/// `find` grades like `find_it`: one item per pick, right picks over (right
/// sentences + wrong picks), so tapping every sentence never scores well.
/// `choose` is one pick, right or wrong. `discuss` grades its takes and,
/// when the clue decides, its revision ([Discuss.evaluate]).
class PassageReaderEvaluator implements Evaluator<PassageContent, AnswerValue> {
  const PassageReaderEvaluator();

  @override
  String get engineKey => PassageReaderEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    PassageContent content,
    AnswerValue answer,
    EvaluationContext ctx,
  ) {
    final part = content.discuss;
    if (part != null) {
      if (answer is! BlanksAnswer) {
        throw ArgumentError('A discuss answer is its steps, as blanks.');
      }
      return Discuss.evaluate(
        part: part,
        answer: answer,
        ctx: ctx,
        evaluator: '$engineKey.$policy@$version',
      );
    }
    if (answer is! MultiSelectAnswer) {
      throw ArgumentError('A find or choose answer is a pick.');
    }
    final picks = answer.selectedOptionIds;
    if (picks.isEmpty) throw ArgumentError('An answer must pick something.');
    final items = {for (final id in picks) id: content.correct.contains(id)};
    final hits = items.values.where((v) => v).length;
    final misses = items.length - hits;
    final all = hits == content.correct.length && misses == 0;
    return EvaluationResult(
      outcome: all
          ? Outcome.correct
          : hits == 0
          ? Outcome.incorrect
          : Outcome.partial,
      score: hits / (content.correct.length + misses),
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: items,
      errors: all ? const [] : const [ErrorClassification.unclassified()],
    );
  }
}
