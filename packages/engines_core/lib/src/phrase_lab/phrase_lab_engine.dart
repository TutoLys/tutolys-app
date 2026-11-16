import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/swatch_text.dart';
import '../widgets/token_flow.dart';

/// What a `phrase_lab` question asks (plan PLAN_GRADES_2_6_ENGINES §2.2).
enum PhraseTask {
  /// Bracket each group of words and name it: SUJET, PRÉDICAT, GN…
  group,

  /// Run the PFEQ's manipulations on one group (effacer, déplacer…), say
  /// whether the sentence still works each time, then name the group.
  test,
}

/// A manipulation the PFEQ uses to find a group's function.
enum PhraseOp {
  delete,
  move,
  pronoun,
  cestQui;

  static PhraseOp? parse(Object? v) => switch (v) {
    'delete' => delete,
    'move' => move,
    'pronoun' => pronoun,
    'cest_qui' => cestQui,
    _ => null,
  };

  String get wire => this == cestQui ? 'cest_qui' : name;

  String label(bool fr) => switch (this) {
    delete => fr ? 'Effacer le groupe' : 'Delete the group',
    move => fr ? 'Déplacer le groupe' : 'Move the group',
    pronoun => fr ? 'Remplacer par un pronom' : 'Replace with a pronoun',
    cestQui => fr ? 'Encadrer par « C’est… qui »' : 'Frame with “It is… who”',
  };
}

class PhraseToken {
  const PhraseToken({required this.id, required this.text});
  final String id;
  final String text;
}

/// A label from the tray. The lesson writes the words (« Sujet »,
/// « Complément de phrase »), so a français lesson keeps its grammar terms
/// whatever language the app is in.
class PhraseLabel {
  const PhraseLabel({required this.id, required this.label});
  final String id;
  final String label;
}

/// A run of tokens, `from` to `to` inclusive, by position.
class PhraseSpan {
  const PhraseSpan(this.from, this.to);
  final int from;
  final int to;

  String get key => '$from-$to';
  bool contains(int i) => i >= from && i <= to;
  bool overlaps(PhraseSpan o) => from <= o.to && o.from <= to;

  static PhraseSpan? parse(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null || a > b || a < 0) return null;
    return PhraseSpan(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is PhraseSpan && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class PhraseGroup {
  const PhraseGroup({
    required this.id,
    required this.span,
    required this.labelId,
  });
  final String id;
  final PhraseSpan span;
  final String labelId;
}

class PhraseTest {
  const PhraseTest({
    required this.id,
    required this.op,
    required this.result,
    required this.ok,
    this.label,
  });
  final String id;
  final PhraseOp op;

  /// The sentence after the manipulation, as the lesson writes it.
  final String result;

  /// Whether that sentence still works.
  final bool ok;

  /// The button's words, when the lesson wants its own.
  final String? label;
}

class PhraseContent {
  const PhraseContent({
    required this.task,
    required this.tokens,
    required this.labels,
    this.groups = const [],
    this.focus,
    this.tests = const [],
    this.conclusion = const [],
    this.conclusionCorrect,
  });

  final PhraseTask task;
  final List<PhraseToken> tokens;
  final List<PhraseLabel> labels;

  /// task group: the groups to find, in reading order.
  final List<PhraseGroup> groups;

  /// task test: the group under test, shown framed.
  final PhraseSpan? focus;
  final List<PhraseTest> tests;

  /// task test: label ids to conclude from, and the right one. Empty when
  /// the question stops at the tests.
  final List<String> conclusion;
  final String? conclusionCorrect;

  PhraseLabel label(String id) => labels.firstWhere((l) => l.id == id);

  /// What the child sees inside [span].
  String text(PhraseSpan span) =>
      joinTokens([for (var i = span.from; i <= span.to; i++) tokens[i].text]);
}

class PhraseState {
  const PhraseState({
    required this.task,
    required this.asked,
    this.needsConclusion = false,
    this.onlyLabel,
    this.anchor,
    this.spans = const [],
    this.named = const {},
    this.selected,
    this.locked = const {},
    this.tried = const {},
    this.run = const {},
    this.judged = const {},
    this.conclusion,
    this.lockedItems = const {},
  });

  final PhraseTask task;

  /// Items the question asks for: groups, or tests (+1 for a conclusion).
  /// VALIDER waits for all of them.
  final int asked;
  final bool needsConclusion;

  /// With one label in the tray, a new bracket takes it at once.
  final String? onlyLabel;

  // ── group ──
  /// The token a new bracket starts from.
  final int? anchor;

  /// The child's brackets, in reading order.
  final List<PhraseSpan> spans;

  /// Span key → label id.
  final Map<String, String> named;

  /// The bracket the next label goes on.
  final String? selected;

  /// Span keys checked right.
  final Set<String> locked;

  /// `span|label` checked wrong (group) or `test|verdict` (test).
  final Set<String> tried;

  // ── test ──
  /// Tests whose result has been shown.
  final Set<String> run;

  /// Test id → the child's verdict (true: it still works).
  final Map<String, bool> judged;
  final String? conclusion;

  /// Test ids, or `conclusion`, checked right.
  final Set<String> lockedItems;

  PhraseState copyWith({
    int? anchor,
    bool clearAnchor = false,
    List<PhraseSpan>? spans,
    Map<String, String>? named,
    String? selected,
    bool clearSelected = false,
    Set<String>? locked,
    Set<String>? tried,
    Set<String>? run,
    Map<String, bool>? judged,
    String? conclusion,
    bool clearConclusion = false,
    Set<String>? lockedItems,
  }) => PhraseState(
    task: task,
    asked: asked,
    needsConclusion: needsConclusion,
    onlyLabel: onlyLabel,
    anchor: clearAnchor ? null : (anchor ?? this.anchor),
    spans: spans ?? this.spans,
    named: named ?? this.named,
    selected: clearSelected ? null : (selected ?? this.selected),
    locked: locked ?? this.locked,
    tried: tried ?? this.tried,
    run: run ?? this.run,
    judged: judged ?? this.judged,
    conclusion: clearConclusion ? null : (conclusion ?? this.conclusion),
    lockedItems: lockedItems ?? this.lockedItems,
  );
}

sealed class PhraseAction {
  const PhraseAction();
}

/// Tap a word: start a bracket there, or close the one started.
class TapPhraseToken extends PhraseAction {
  const TapPhraseToken(this.index);
  final int index;
}

/// Tap a bracket: select it for a label, or (selected already) undo it.
class TapPhraseSpan extends PhraseAction {
  const TapPhraseSpan(this.key);
  final String key;
}

/// Tap a label in the tray: it goes on the selected bracket.
class TapPhraseLabel extends PhraseAction {
  const TapPhraseLabel(this.labelId);
  final String labelId;
}

/// Show what the sentence becomes after a manipulation.
class RunPhraseTest extends PhraseAction {
  const RunPhraseTest(this.testId);
  final String testId;
}

/// Say whether the changed sentence still works.
class JudgePhraseTest extends PhraseAction {
  const JudgePhraseTest(this.testId, {required this.works});
  final String testId;
  final bool works;
}

/// Name the group after the tests.
class PickPhraseConclusion extends PhraseAction {
  const PickPhraseConclusion(this.labelId);
  final String labelId;
}

/// L'atelier des phrases — the `phrase_lab` engine, slice 1 (plan
/// PLAN_GRADES_2_6_ENGINES §2.2, app ADR 0119).
///
/// One sentence, as tappable words. Two tasks:
/// - `group`: tap a group's first and last word to bracket it, then name
///   it from the tray. VALIDER waits for one bracket per group asked, each
///   named; each is graded on its exact words and its name, with partial
///   credit. A right one locks; a wrong one comes off, and that name can't
///   go back on those words.
/// - `test`: one group is framed. The child runs each manipulation the
///   lesson lists (effacer, déplacer, remplacer par un pronom, encadrer),
///   sees the sentence it gives, and says whether it still works; then, if
///   the lesson asks, names the group. Each verdict is an item.
///
/// The changed sentences are written by the lesson, never computed:
/// capitals, commas and elision are French's business, not the engine's.
class PhraseLabEngine
    implements
        LearningEngine<PhraseContent, PhraseState, PhraseAction, BlanksAnswer> {
  const PhraseLabEngine();

  static const key = 'phrase_lab';
  static const conclusionItem = 'conclusion';
  static final _id = RegExp(r'^[a-z0-9_-]+$');

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<PhraseContent> parse(Map<String, Object?> config) {
    final task = switch (config['task']) {
      null || 'group' => PhraseTask.group,
      'test' => PhraseTask.test,
      _ => null,
    };
    if (task == null) {
      return const ParseResult.unsupported('task is group or test.');
    }

    final rawTokens = config['tokens'];
    if (rawTokens is! List || rawTokens.length < 2 || rawTokens.length > 24) {
      return const ParseResult.invalid('A sentence is 2 to 24 tokens.');
    }
    final tokens = <PhraseToken>[];
    final position = <String, int>{};
    for (final t in rawTokens) {
      final id = t is Map ? t['id'] : null;
      final text = t is Map ? t['text'] : null;
      if (id is! String || !_id.hasMatch(id) || text is! String) {
        return const ParseResult.invalid('Every token needs an id and text.');
      }
      if (text.trim().isEmpty || position.containsKey(id)) {
        return const ParseResult.invalid('Token ids are unique; text is set.');
      }
      position[id] = tokens.length;
      tokens.add(PhraseToken(id: id, text: text));
    }

    PhraseSpan? span(Object? from, Object? to) {
      final a = position[from];
      final b = position[to];
      return a == null || b == null || a > b ? null : PhraseSpan(a, b);
    }

    final rawLabels = config['labels'];
    if (rawLabels is! List || rawLabels.isEmpty || rawLabels.length > 6) {
      return const ParseResult.invalid('labels is 1 to 6 {id, label}.');
    }
    final labels = <PhraseLabel>[];
    for (final l in rawLabels) {
      final id = l is Map ? l['id'] : null;
      final label = l is Map ? l['label'] : null;
      if (id is! String ||
          !_id.hasMatch(id) ||
          label is! String ||
          label.trim().isEmpty ||
          labels.any((x) => x.id == id)) {
        return const ParseResult.invalid('Every label needs a unique id.');
      }
      labels.add(PhraseLabel(id: id, label: label));
    }
    final labelIds = {for (final l in labels) l.id};
    final hint = config['hint'];
    if (hint != null && hint is! String) {
      return const ParseResult.invalid('hint is a string or null.');
    }

    if (task == PhraseTask.group) {
      final rawGroups = config['groups'];
      if (rawGroups is! List || rawGroups.isEmpty || rawGroups.length > 4) {
        return const ParseResult.invalid('A group task asks for 1 to 4.');
      }
      final groups = <PhraseGroup>[];
      for (final g in rawGroups) {
        final m = g is Map ? g : const {};
        final id = m['id'];
        final s = span(m['from'], m['to']);
        final label = m['label'];
        if (id is! String || s == null || !labelIds.contains(label)) {
          return const ParseResult.invalid(
            'Every group needs an id, from ≤ to among the tokens, and a '
            'label from labels.',
          );
        }
        if (groups.any((x) => x.id == id || x.span.overlaps(s))) {
          return const ParseResult.invalid(
            'Group ids are unique and groups never overlap.',
          );
        }
        groups.add(PhraseGroup(id: id, span: s, labelId: label as String));
      }
      groups.sort((a, b) => a.span.from.compareTo(b.span.from));
      return ParseResult.ok(
        PhraseContent(
          task: task,
          tokens: List.unmodifiable(tokens),
          labels: List.unmodifiable(labels),
          groups: List.unmodifiable(groups),
        ),
      );
    }

    final rawFocus = config['group'];
    final focus = rawFocus is Map
        ? span(rawFocus['from'], rawFocus['to'])
        : null;
    if (focus == null) {
      return const ParseResult.invalid(
        'A test task frames a group {from, to}.',
      );
    }
    final rawTests = config['tests'];
    if (rawTests is! List || rawTests.isEmpty || rawTests.length > 3) {
      return const ParseResult.invalid('A test task runs 1 to 3 tests.');
    }
    final tests = <PhraseTest>[];
    for (final t in rawTests) {
      final m = t is Map ? t : const {};
      final id = m['id'];
      final op = PhraseOp.parse(m['op']);
      final result = m['result'];
      final ok = m['ok'];
      final label = m['label'];
      if (id is! String ||
          !_id.hasMatch(id) ||
          id == conclusionItem ||
          op == null ||
          result is! String ||
          result.trim().isEmpty ||
          ok is! bool ||
          (label != null && label is! String) ||
          tests.any((x) => x.id == id)) {
        return const ParseResult.invalid(
          'Every test needs a unique id, an op (delete, move, pronoun, '
          'cest_qui), the result sentence and ok.',
        );
      }
      tests.add(
        PhraseTest(
          id: id,
          op: op,
          result: result,
          ok: ok,
          label: label as String?,
        ),
      );
    }
    final rawConclusion = config['conclusion'];
    var options = const <String>[];
    String? correct;
    if (rawConclusion != null) {
      final m = rawConclusion is Map ? rawConclusion : const {};
      final o = m['options'];
      correct = m['correct'] as String?;
      if (o is! List ||
          o.length < 2 ||
          o.length > 4 ||
          !o.every(labelIds.contains) ||
          o.toSet().length != o.length ||
          !o.contains(correct)) {
        return const ParseResult.invalid(
          'conclusion is {options: 2 to 4 label ids, correct: one of them}.',
        );
      }
      options = o.cast<String>();
    }
    return ParseResult.ok(
      PhraseContent(
        task: task,
        tokens: List.unmodifiable(tokens),
        labels: List.unmodifiable(labels),
        focus: focus,
        tests: List.unmodifiable(tests),
        conclusion: List.unmodifiable(options),
        conclusionCorrect: correct,
      ),
    );
  }

  @override
  PhraseState initialize(PhraseContent content, EngineSeed seed) =>
      _blank(content);

  static PhraseState _blank(PhraseContent c) => PhraseState(
    task: c.task,
    asked: c.task == PhraseTask.group
        ? c.groups.length
        : c.tests.length + (c.conclusion.isEmpty ? 0 : 1),
    needsConclusion: c.conclusion.isNotEmpty,
    onlyLabel: c.labels.length == 1 ? c.labels.single.id : null,
  );

  static String _pair(String a, String b) => '$a|$b';

  @override
  Transition<PhraseState> reduce(PhraseState s, PhraseAction action) {
    switch (action) {
      case TapPhraseToken(:final index):
        if (s.task != PhraseTask.group || index < 0) return Transition(s);
        if (s.spans.any((x) => x.contains(index))) return Transition(s);
        final anchor = s.anchor;
        if (anchor == null) {
          return Transition(s.copyWith(anchor: index, clearSelected: true), [
            InteractionEvent('option_selected', {'option_id': 't$index'}),
          ]);
        }
        final span = PhraseSpan(
          anchor < index ? anchor : index,
          anchor < index ? index : anchor,
        );
        // A bracket can't swallow another one.
        if (s.spans.any(span.overlaps)) {
          return Transition(s.copyWith(anchor: index));
        }
        final spans = [...s.spans, span]
          ..sort((a, b) => a.from.compareTo(b.from));
        final only = s.onlyLabel;
        return Transition(
          s.copyWith(
            clearAnchor: true,
            spans: spans,
            named: only == null ? null : {...s.named, span.key: only},
            selected: only == null ? span.key : null,
            clearSelected: only != null,
          ),
          [
            InteractionEvent('item_placed', {'item_id': span.key}),
          ],
        );

      case TapPhraseSpan(:final key):
        final span = PhraseSpan.parse(key);
        if (span == null || !s.spans.contains(span) || s.locked.contains(key)) {
          return Transition(s);
        }
        if (s.selected != key) {
          return Transition(s.copyWith(selected: key, clearAnchor: true));
        }
        return Transition(
          s.copyWith(
            spans: [...s.spans]..remove(span),
            named: Map.of(s.named)..remove(key),
            clearSelected: true,
          ),
          [
            InteractionEvent('item_removed', {'item_id': key}),
          ],
        );

      case TapPhraseLabel(:final labelId):
        final target = s.selected ?? _firstUnnamed(s);
        if (target == null ||
            s.locked.contains(target) ||
            s.tried.contains(_pair(target, labelId))) {
          return Transition(s);
        }
        return Transition(
          s.copyWith(named: {...s.named, target: labelId}, clearSelected: true),
          [
            InteractionEvent('item_placed', {
              'item_id': labelId,
              'bucket_id': target,
            }),
          ],
        );

      case RunPhraseTest(:final testId):
        if (s.task != PhraseTask.test || s.run.contains(testId)) {
          return Transition(s);
        }
        return Transition(s.copyWith(run: {...s.run, testId}), [
          InteractionEvent('experiment_run', {'item_id': testId}),
          // The changed sentence appearing is the moment (ADR 0118).
          RevealEvent('test', itemId: testId),
        ]);

      case JudgePhraseTest(:final testId, :final works):
        final verdict = works ? 'ok' : 'not_ok';
        if (!s.run.contains(testId) ||
            s.lockedItems.contains(testId) ||
            s.tried.contains(_pair(testId, verdict))) {
          return Transition(s);
        }
        return Transition(s.copyWith(judged: {...s.judged, testId: works}), [
          InteractionEvent('option_selected', {
            'option_id': verdict,
            'item_id': testId,
          }),
        ]);

      case PickPhraseConclusion(:final labelId):
        if (s.lockedItems.contains(conclusionItem) ||
            s.tried.contains(_pair(conclusionItem, labelId))) {
          return Transition(s);
        }
        return Transition(s.copyWith(conclusion: labelId), [
          InteractionEvent('option_selected', {
            'option_id': labelId,
            'item_id': conclusionItem,
          }),
        ]);
    }
  }

  static String? _firstUnnamed(PhraseState s) {
    for (final span in s.spans) {
      if (!s.named.containsKey(span.key)) return span.key;
    }
    return null;
  }

  @override
  BlanksAnswer? extractAnswer(PhraseState s) {
    if (s.task == PhraseTask.group) {
      if (s.spans.length != s.asked ||
          s.spans.any((x) => !s.named.containsKey(x.key)) ||
          s.locked.length == s.asked) {
        return null;
      }
      return BlanksAnswer(s.named);
    }
    final tests = s.asked - (s.needsConclusion ? 1 : 0);
    if (s.judged.length != tests ||
        (s.needsConclusion && s.conclusion == null) ||
        s.lockedItems.length == s.asked) {
      return null;
    }
    return BlanksAnswer({
      for (final e in s.judged.entries) e.key: e.value ? 'ok' : 'not_ok',
      if (s.conclusion != null) conclusionItem: s.conclusion!,
    });
  }

  @override
  PhraseState applyFeedback(PhraseState s, EvaluationResult result) {
    if (result.outcome == Outcome.ungraded) return s;
    final tried = {...s.tried};
    if (s.task == PhraseTask.group) {
      final locked = {...s.locked};
      final spans = <PhraseSpan>[];
      final named = <String, String>{};
      for (final span in s.spans) {
        final k = span.key;
        if (locked.contains(k) || result.itemResults[k] == true) {
          locked.add(k);
          spans.add(span);
          named[k] = s.named[k]!;
        } else if (s.named[k] != null) {
          tried.add(_pair(k, s.named[k]!));
        }
      }
      return s.copyWith(
        spans: spans,
        named: named,
        locked: locked,
        tried: tried,
        clearSelected: true,
        clearAnchor: true,
      );
    }
    final locked = {...s.lockedItems};
    final judged = <String, bool>{};
    for (final e in s.judged.entries) {
      if (locked.contains(e.key) || result.itemResults[e.key] == true) {
        locked.add(e.key);
        judged[e.key] = e.value;
      } else {
        tried.add(_pair(e.key, e.value ? 'ok' : 'not_ok'));
      }
    }
    var conclusion = s.conclusion;
    if (conclusion != null) {
      if (result.itemResults[conclusionItem] == true) {
        locked.add(conclusionItem);
      } else if (!locked.contains(conclusionItem)) {
        tried.add(_pair(conclusionItem, conclusion));
        conclusion = null;
      }
    }
    return PhraseState(
      task: s.task,
      asked: s.asked,
      needsConclusion: s.needsConclusion,
      run: s.run,
      judged: judged,
      conclusion: conclusion,
      lockedItems: locked,
      tried: tried,
    );
  }

  @override
  Map<String, Object?> snapshot(PhraseState s) => {
    'anchor': s.anchor,
    'spans': [for (final x in s.spans) x.key],
    'named': s.named,
    'selected': s.selected,
    'locked': s.locked.toList(),
    'tried': s.tried.toList(),
    'run': s.run.toList(),
    'judged': s.judged,
    'conclusion': s.conclusion,
    'locked_items': s.lockedItems.toList(),
  };

  @override
  PhraseState? restore(PhraseContent content, Map<String, Object?> snap) {
    try {
      final n = content.tokens.length;
      final spans = [
        for (final k in (snap['spans'] as List? ?? const []).cast<String>())
          PhraseSpan.parse(k)!,
      ];
      if (spans.any((x) => x.to >= n)) return null;
      for (var i = 0; i < spans.length; i++) {
        for (var j = i + 1; j < spans.length; j++) {
          if (spans[i].overlaps(spans[j])) return null;
        }
      }
      final keys = {for (final x in spans) x.key};
      final labelIds = {for (final l in content.labels) l.id};
      final named = Map<String, String>.from(snap['named'] as Map? ?? const {});
      final locked = (snap['locked'] as List? ?? const [])
          .cast<String>()
          .toSet();
      final anchor = snap['anchor'] as int?;
      final selected = snap['selected'] as String?;
      final testIds = {for (final t in content.tests) t.id};
      final run = (snap['run'] as List? ?? const []).cast<String>().toSet();
      final judged = Map<String, bool>.from(snap['judged'] as Map? ?? const {});
      final conclusion = snap['conclusion'] as String?;
      if (!named.keys.every(keys.contains) ||
          !named.values.every(labelIds.contains) ||
          !locked.every(keys.contains) ||
          (anchor != null && (anchor < 0 || anchor >= n)) ||
          (selected != null && !keys.contains(selected)) ||
          !run.every(testIds.contains) ||
          !judged.keys.every(run.contains) ||
          (conclusion != null && !content.conclusion.contains(conclusion))) {
        return null;
      }
      final blank = _blank(content);
      return PhraseState(
        task: content.task,
        asked: blank.asked,
        needsConclusion: blank.needsConclusion,
        onlyLabel: blank.onlyLabel,
        anchor: anchor,
        spans: spans,
        named: named,
        selected: selected,
        locked: locked,
        tried: (snap['tried'] as List? ?? const []).cast<String>().toSet(),
        run: run,
        judged: judged,
        conclusion: conclusion,
        lockedItems: (snap['locked_items'] as List? ?? const [])
            .cast<String>()
            .toSet(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<PhraseContent, PhraseState, PhraseAction> view,
  ) => view.content.task == PhraseTask.group
      ? _GroupBoard(view: view)
      : _TestBoard(view: view);
}

TextStyle _wordStyle(VillagePalette p) => TextStyle(
  fontFamily: VillageType.display,
  fontWeight: FontWeight.w700,
  fontSize: 24,
  height: 1.3,
  color: p.ink,
);

/// The sentence with its brackets, and the label tray.
class _GroupBoard extends StatelessWidget {
  const _GroupBoard({required this.view});
  final EngineView<PhraseContent, PhraseState, PhraseAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final c = view.content;
    final s = view.state;
    final style = _wordStyle(p);
    final asked = c.groups.length;

    Widget word(int i) {
      final anchored = s.anchor == i;
      return Semantics(
        button: true,
        selected: anchored,
        label: c.tokens[i].text,
        hint: anchored
            ? (fr ? 'début du groupe, touche le dernier mot' : 'start of group')
            : (fr ? 'touche pour commencer un groupe' : 'tap to start a group'),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('phrase-token-$i'),
          borderRadius: Radii.cardMd,
          onTap: view.enabled ? () => view.dispatch(TapPhraseToken(i)) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: Radii.cardMd,
              color: anchored ? p.quebecBlue.withValues(alpha: 0.14) : null,
              border: Border.all(
                color: anchored ? p.quebecBlueBright : Colors.transparent,
                width: 3,
              ),
            ),
            child: SwatchText(c.tokens[i].text, style: style),
          ),
        ),
      );
    }

    Widget bracket(PhraseSpan span) {
      final k = span.key;
      final locked = s.locked.contains(k);
      final selected = s.selected == k;
      final labelId = s.named[k];
      final edge = locked
          ? p.success
          : selected
          ? p.quebecBlueBright
          : p.quebecBlue;
      return Semantics(
        button: !locked,
        selected: selected,
        label: [
          c.text(span),
          if (labelId != null) c.label(labelId).label,
        ].join(', '),
        hint: locked
            ? (fr ? 'bien trouvé' : 'found')
            : selected
            ? (fr ? 'touche encore pour défaire' : 'tap again to undo')
            : (fr ? 'touche pour le nommer' : 'tap to name it'),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('phrase-span-$k'),
          borderRadius: Radii.cardMd,
          onTap: view.enabled && !locked
              ? () => view.dispatch(TapPhraseSpan(k))
              : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            decoration: BoxDecoration(
              borderRadius: Radii.cardMd,
              color: edge.withValues(alpha: 0.10),
              border: Border.all(color: edge, width: selected ? 4 : 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TokenFlow(
                  runSpacing: 0,
                  pieces: [
                    for (var i = span.from; i <= span.to; i++)
                      TokenPiece.single(
                        c.tokens[i].text,
                        SwatchText(c.tokens[i].text, style: style),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  labelId == null ? '?' : c.label(labelId).label,
                  key: ValueKey('phrase-span-label-$k'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: locked ? p.success : p.quebecBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pieces = <TokenPiece>[];
    for (var i = 0; i < c.tokens.length; i++) {
      final span = s.spans.where((x) => x.from == i).firstOrNull;
      if (span != null) {
        pieces.add(
          TokenPiece(
            first: c.tokens[span.from].text,
            last: c.tokens[span.to].text,
            child: bracket(span),
          ),
        );
        i = span.to;
      } else {
        pieces.add(TokenPiece.single(c.tokens[i].text, word(i)));
      }
    }

    final target = s.selected ?? PhraseLabEngine._firstUnnamed(s);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TokenFlow(key: const ValueKey('phrase-sentence'), pieces: pieces),
              const SizedBox(height: 12),
              Text(
                fr
                    ? 'Groupes : ${s.spans.length} / $asked'
                    : 'Groups: ${s.spans.length} / $asked',
                key: const ValueKey('phrase-count'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                key: const ValueKey('phrase-labels'),
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final l in c.labels)
                    SizedBox(
                      width: 200,
                      child: Builder(
                        builder: (context) {
                          final tried =
                              target != null &&
                              s.tried.contains(
                                PhraseLabEngine._pair(target, l.id),
                              );
                          return AnswerTile(
                            key: ValueKey('phrase-label-${l.id}'),
                            label: l.label,
                            state: tried
                                ? AnswerTileState.retry
                                : AnswerTileState.idle,
                            semanticsState: tried
                                ? (fr
                                      ? 'déjà essayé ici'
                                      : 'already tried here')
                                : null,
                            onTap: view.enabled && target != null && !tried
                                ? () => view.dispatch(TapPhraseLabel(l.id))
                                : null,
                          );
                        },
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

/// The framed group, one card per manipulation, and the conclusion.
class _TestBoard extends StatelessWidget {
  const _TestBoard({required this.view});
  final EngineView<PhraseContent, PhraseState, PhraseAction> view;

  @override
  Widget build(BuildContext context) {
    final fr = view.locale.languageCode == 'fr';
    final p = VillagePalette.of(context);
    final c = view.content;
    final s = view.state;
    final style = _wordStyle(p);
    final focus = c.focus!;

    final sentence = TokenFlow(
      key: const ValueKey('phrase-sentence'),
      pieces: [
        for (var i = 0; i < c.tokens.length; i++)
          if (i == focus.from)
            TokenPiece(
              first: c.tokens[focus.from].text,
              last: c.tokens[focus.to].text,
              child: Container(
                key: const ValueKey('phrase-focus'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: Radii.cardMd,
                  color: p.quebecBlue.withValues(alpha: 0.10),
                  border: Border.all(color: p.quebecBlue, width: 3),
                ),
                child: SwatchText(c.text(focus), style: style),
              ),
            )
          else if (!focus.contains(i))
            TokenPiece.single(
              c.tokens[i].text,
              SwatchText(c.tokens[i].text, style: style),
            ),
      ],
    );

    Widget testCard(PhraseTest t) {
      final shown = s.run.contains(t.id);
      final locked = s.lockedItems.contains(t.id);
      final verdict = s.judged[t.id];
      Widget choice(bool works) {
        final tried = s.tried.contains(
          PhraseLabEngine._pair(t.id, works ? 'ok' : 'not_ok'),
        );
        final picked = verdict == works;
        return Expanded(
          child: AnswerTile(
            key: ValueKey('phrase-judge-${t.id}-${works ? 'ok' : 'not_ok'}'),
            label: works
                ? (fr ? 'Ça marche' : 'It works')
                : (fr ? 'Ça ne marche pas' : 'It doesn’t work'),
            state: locked && picked
                ? AnswerTileState.correct
                : tried
                ? AnswerTileState.retry
                : picked
                ? AnswerTileState.picked
                : AnswerTileState.idle,
            onTap: view.enabled && !locked && !tried
                ? () => view.dispatch(JudgePhraseTest(t.id, works: works))
                : null,
          ),
        );
      }

      return Card(
        key: ValueKey('phrase-test-${t.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerTile(
                key: ValueKey('phrase-run-${t.id}'),
                label: t.label ?? t.op.label(fr),
                state: shown ? AnswerTileState.picked : AnswerTileState.idle,
                onTap: view.enabled && !shown
                    ? () => view.dispatch(RunPhraseTest(t.id))
                    : null,
              ),
              if (shown) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: SwatchText(
                    t.result,
                    key: ValueKey('phrase-result-${t.id}'),
                    style: style.copyWith(fontSize: 21),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    choice(true),
                    const SizedBox(width: 10),
                    choice(false),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    final allJudged = c.tests.every((t) => s.judged.containsKey(t.id));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sentence,
              const SizedBox(height: 16),
              for (final t in c.tests) ...[
                testCard(t),
                const SizedBox(height: 10),
              ],
              if (c.conclusion.isNotEmpty && allJudged) ...[
                const SizedBox(height: 6),
                Text(
                  fr ? 'Donc, ce groupe est…' : 'So this group is…',
                  key: const ValueKey('phrase-conclusion-title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.ink),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final id in c.conclusion)
                      SizedBox(
                        width: 200,
                        child: Builder(
                          builder: (context) {
                            final tried = s.tried.contains(
                              PhraseLabEngine._pair(
                                PhraseLabEngine.conclusionItem,
                                id,
                              ),
                            );
                            final locked = s.lockedItems.contains(
                              PhraseLabEngine.conclusionItem,
                            );
                            final picked = s.conclusion == id;
                            return AnswerTile(
                              key: ValueKey('phrase-conclude-$id'),
                              label: c.label(id).label,
                              state: locked && picked
                                  ? AnswerTileState.correct
                                  : tried
                                  ? AnswerTileState.retry
                                  : picked
                                  ? AnswerTileState.picked
                                  : AnswerTileState.idle,
                              onTap: view.enabled && !locked && !tried
                                  ? () =>
                                        view.dispatch(PickPhraseConclusion(id))
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grades a `phrase_lab` question.
/// - group: one item per asked group, true when a bracket has exactly its
///   words and its name. A bracket that matches nothing makes an extra,
///   false item, so a board with brackets in the wrong places can't be
///   right.
/// - test: one item per test (the child's verdict against `ok`), and one
///   for the conclusion when the lesson asks for it.
class PhraseLabEvaluator implements Evaluator<PhraseContent, BlanksAnswer> {
  const PhraseLabEvaluator();

  @override
  String get engineKey => PhraseLabEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    PhraseContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final given = answer.blanks;
    if (given.isEmpty) throw ArgumentError('An answer must hold something.');
    final items = <String, bool>{};
    final int total;
    if (content.task == PhraseTask.group) {
      for (final g in content.groups) {
        if (given.containsKey(g.span.key)) {
          items[g.span.key] = given[g.span.key] == g.labelId;
        }
      }
      for (final k in given.keys) {
        items.putIfAbsent(k, () => false);
      }
      total = content.groups.length > items.length
          ? content.groups.length
          : items.length;
    } else {
      for (final t in content.tests) {
        final v = given[t.id];
        if (v != null) items[t.id] = (v == 'ok') == t.ok;
      }
      final picked = given[PhraseLabEngine.conclusionItem];
      if (picked != null) {
        items[PhraseLabEngine.conclusionItem] =
            picked == content.conclusionCorrect;
      }
      total = content.tests.length + (content.conclusion.isEmpty ? 0 : 1);
    }
    final hits = items.values.where((v) => v).length;
    final all = hits == total && items.length == total;
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
