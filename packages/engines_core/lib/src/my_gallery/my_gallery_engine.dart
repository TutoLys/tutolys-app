import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../widgets/answer_tile.dart';
import '../widgets/creations.dart';
import '../widgets/village_characters.dart';

class GalleryVisitor {
  const GalleryVisitor({required this.character, required this.comment});
  final VillageCharacter character;
  final String comment;
}

class GalleryContent {
  const GalleryContent({
    required this.reasons,
    required this.visitors,
    this.maxHang = CreationShelf.maxHung,
    this.engines,
  });

  /// Why the child hangs a piece ("J'en suis fier", "C'est drôle").
  final List<(String, String)> reasons;
  final List<GalleryVisitor> visitors;
  final int maxHang;

  /// Only creations from these engines; null for all.
  final Set<String>? engines;
}

class GalleryState {
  const GalleryState({
    this.available,
    this.hung = const {},
    this.solved = false,
    this.maxHang = CreationShelf.maxHung,
  });

  /// The child's creations' ids, once loaded from the shelf.
  final List<String>? available;

  /// Creation id → the reason chosen for it (null until chosen).
  final Map<String, String?> hung;
  final bool solved;
  final int maxHang;

  bool get empty => available != null && available!.isEmpty;

  GalleryState copyWith({
    List<String>? available,
    Map<String, String?>? hung,
    bool? solved,
  }) => GalleryState(
    available: available ?? this.available,
    hung: hung ?? this.hung,
    solved: solved ?? this.solved,
    maxHang: maxHang,
  );
}

sealed class GalleryAction {
  const GalleryAction();
}

/// The view read the shelf: these are the child's creations.
class GalleryLoaded extends GalleryAction {
  const GalleryLoaded(this.ids);
  final List<String> ids;
}

/// Hang a creation, or take it down.
class ToggleHang extends GalleryAction {
  const ToggleHang(this.creationId);
  final String creationId;
}

class SetHangReason extends GalleryAction {
  const SetHangReason(this.creationId, this.reasonId);
  final String creationId;
  final String reasonId;
}

/// "Ma galerie au village" — the `my_gallery` engine (app ADR 0092; the
/// Questions Maker's ELA request 5, "Selects pieces to publish").
///
/// The child's own creations — compose_build sentences, pattern_machine
/// patterns, geometry_lab shapes, mail_studio messages, each kept with
/// "Garder dans mes créations" — come from the per-kid local shelf
/// ([CreationShelf], the app's "Mes créations"). The child hangs one to
/// three and says why with a reason tile; then village characters visit
/// and say something kind.
///
/// **Practice only**: no mastery, a participation event. Any choice made
/// with reasons is right. With no creations yet, the gallery says so and
/// the child can carry on rather than be stuck.
class MyGalleryEngine
    implements
        LearningEngine<
          GalleryContent,
          GalleryState,
          GalleryAction,
          BlanksAnswer
        > {
  const MyGalleryEngine();

  static const key = 'my_gallery';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.explicit,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  static const creators = {
    'compose_build',
    'pattern_machine',
    'geometry_lab',
    'mail_studio',
  };

  @override
  ParseResult<GalleryContent> parse(Map<String, Object?> config) {
    final rawReasons = config['reasons'];
    if (rawReasons is! List || rawReasons.length < 2 || rawReasons.length > 6) {
      return const ParseResult.invalid('There are 2 to 6 reasons.');
    }
    final reasons = <(String, String)>[];
    for (final r in rawReasons) {
      final id = r is Map ? r['id'] : null;
      final label = r is Map ? r['label'] : null;
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.trim().isEmpty) {
        return const ParseResult.invalid('A reason is {id, label}.');
      }
      if (reasons.any((x) => x.$1 == id)) {
        return const ParseResult.invalid('Reason ids are unique.');
      }
      reasons.add((id, label));
    }
    final rawVisitors = config['visitors'];
    if (rawVisitors is! List || rawVisitors.isEmpty || rawVisitors.length > 3) {
      return const ParseResult.invalid('There are 1 to 3 visitors.');
    }
    final visitors = <GalleryVisitor>[];
    for (final v in rawVisitors) {
      final character = VillageCharacter.byKey(
        v is Map ? v['character'] : null,
      );
      final comment = v is Map ? v['comment'] : null;
      if (character == null || comment is! String || comment.trim().isEmpty) {
        return const ParseResult.invalid(
          'A visitor is {character, comment}: a village character and their '
          'kind words.',
        );
      }
      visitors.add(GalleryVisitor(character: character, comment: comment));
    }
    final maxHang = config['max_hang'] ?? CreationShelf.maxHung;
    if (maxHang is! int || maxHang < 1 || maxHang > CreationShelf.maxHung) {
      return ParseResult.invalid('max_hang is 1 to ${CreationShelf.maxHung}.');
    }
    final rawEngines = config['engines'];
    if (rawEngines != null &&
        (rawEngines is! List ||
            rawEngines.isEmpty ||
            !rawEngines.every(creators.contains))) {
      return ParseResult.invalid(
        'engines lists engines that keep creations: ${creators.join(', ')}.',
      );
    }
    return ParseResult.ok(
      GalleryContent(
        reasons: List.unmodifiable(reasons),
        visitors: List.unmodifiable(visitors),
        maxHang: maxHang,
        engines: (rawEngines as List?)?.cast<String>().toSet(),
      ),
    );
  }

  @override
  GalleryState initialize(GalleryContent content, EngineSeed seed) =>
      GalleryState(maxHang: content.maxHang);

  @override
  Transition<GalleryState> reduce(GalleryState s, GalleryAction action) {
    if (s.solved) return Transition(s);
    switch (action) {
      case GalleryLoaded(:final ids):
        final known = ids.toSet();
        return Transition(
          s.copyWith(
            available: List.unmodifiable(ids),
            hung: {
              for (final e in s.hung.entries)
                if (known.contains(e.key)) e.key: e.value,
            },
          ),
        );
      case ToggleHang(:final creationId):
        final available = s.available;
        if (available == null || !available.contains(creationId)) {
          return Transition(s);
        }
        if (s.hung.containsKey(creationId)) {
          return Transition(s.copyWith(hung: {...s.hung}..remove(creationId)), [
            InteractionEvent('item_removed', {'item_id': 'creation'}),
          ]);
        }
        if (s.hung.length >= s.maxHang) return Transition(s);
        return Transition(s.copyWith(hung: {...s.hung, creationId: null}), [
          InteractionEvent('item_placed', {'item_id': 'creation'}),
        ]);
      case SetHangReason(:final creationId, :final reasonId):
        if (!s.hung.containsKey(creationId) || s.hung[creationId] == reasonId) {
          return Transition(s);
        }
        return Transition(s.copyWith(hung: {...s.hung, creationId: reasonId}), [
          InteractionEvent('option_selected', {
            'option_id': reasonId,
            'item_id': 'reason',
          }),
        ]);
    }
  }

  @override
  BlanksAnswer? extractAnswer(GalleryState s) {
    if (s.solved || s.available == null) return null;
    if (s.empty) return BlanksAnswer({'empty': 'true'});
    if (s.hung.isEmpty || s.hung.values.any((r) => r == null)) return null;
    return BlanksAnswer({
      for (final e in s.hung.entries) 'hang_${e.key}': e.value!,
    });
  }

  @override
  GalleryState applyFeedback(GalleryState s, EvaluationResult result) =>
      result.outcome == Outcome.correct ? s.copyWith(solved: true) : s;

  @override
  Map<String, Object?> snapshot(GalleryState s) => {
    'available': s.available,
    'hung': s.hung,
    'solved': s.solved,
  };

  @override
  GalleryState? restore(GalleryContent content, Map<String, Object?> snap) {
    try {
      final available = (snap['available'] as List?)?.cast<String>();
      final hung = Map<String, String?>.from(
        (snap['hung'] as Map?) ?? const {},
      );
      final reasons = {for (final r in content.reasons) r.$1};
      if (hung.length > content.maxHang ||
          (available != null && !hung.keys.every(available.contains)) ||
          !hung.values.every((r) => r == null || reasons.contains(r))) {
        return null;
      }
      return GalleryState(
        available: available,
        hung: hung,
        solved: snap['solved'] == true,
        maxHang: content.maxHang,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<GalleryContent, GalleryState, GalleryAction> view,
  ) => _GalleryView(view: view);
}

class _GalleryView extends StatefulWidget {
  const _GalleryView({required this.view});
  final EngineView<GalleryContent, GalleryState, GalleryAction> view;

  @override
  State<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<_GalleryView> {
  List<Creation> _creations = const [];
  var _persisted = false;
  var _loading = false;

  /// The gallery opens on a wall of the child's creations; hanging is an
  /// optional step (UX review N12: it opened as a task). A snapshot with
  /// something already hung reopens straight in hanging.
  late var _hanging = widget.view.state.hung.isNotEmpty;

  Future<void> _showLarge(Creation x) => showDialog<void>(
    context: context,
    builder: (context) {
      final fr = widget.view.locale.languageCode == 'fr';
      return Dialog(
        key: ValueKey('gallery-large-${x.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 320,
                height: 320,
                child: FittedBox(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: creationView(x, locale: widget.view.locale),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('gallery-large-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(fr ? 'Fermer' : 'Close'),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) {
      _loading = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final shelf = CreationShelfScope.maybeOf(context);
    final c = widget.view.content;
    final creations = shelf == null
        ? const <Creation>[]
        : await shelf.list(engineKeys: c.engines, limit: 24);
    if (!mounted) return;
    // Only what this app can draw again.
    final shown = [
      for (final x in creations)
        if (creationView(x, locale: widget.view.locale) != null) x,
    ];
    setState(() => _creations = shown);
    widget.view.dispatch(GalleryLoaded([for (final x in shown) x.id]));
  }

  @override
  void didUpdateWidget(_GalleryView old) {
    super.didUpdateWidget(old);
    final s = widget.view.state;
    if (s.solved && !_persisted && !s.empty) {
      _persisted = true;
      unawaited(_hang(s));
    }
  }

  /// Hang the chosen pieces on the shelf, taking down the rest first so
  /// the shelf's limit is never hit.
  Future<void> _hang(GalleryState s) async {
    final shelf = CreationShelfScope.maybeOf(context);
    if (shelf == null) return;
    try {
      for (final x in _creations) {
        if (x.hung && !s.hung.containsKey(x.id)) {
          await shelf.setHung(x.id, false);
        }
      }
      for (final id in s.hung.keys) {
        await shelf.setHung(id, true);
      }
    } on Object {
      // The gallery still showed it; the shelf can be fixed next visit.
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
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

    if (s.available == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s.empty) {
      return Center(
        child: CharacterSays(
          key: const ValueKey('gallery-empty'),
          character: VillageCharacter.byKey('foxy')!,
          locale: view.locale,
          text: fr
              ? 'Ta galerie est encore vide ! Quand tu réussis une création, '
                    'appuie sur « Garder dans mes créations ».'
              : 'Your gallery is still empty! When you finish a creation, '
                    'press “Keep in my creations”.',
        ),
      );
    }

    if (!_hanging) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FocusTraversalGroup(
            child: Column(
              key: const ValueKey('gallery-wall'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (i, x) in _creations.indexed)
                      Semantics(
                        button: true,
                        label: fr
                            ? 'Création ${i + 1}, touche pour la voir en grand'
                            : 'Creation ${i + 1}, tap to see it big',
                        excludeSemantics: true,
                        child: Material(
                          color: p.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: Radii.cardMd,
                            side: BorderSide(
                              color: x.hung ? p.gold : p.line,
                              width: x.hung ? 4 : 2,
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('gallery-wall-${x.id}'),
                            borderRadius: Radii.cardMd,
                            onTap: () => unawaited(_showLarge(x)),
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: creationView(x, locale: view.locale),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const ValueKey('gallery-start-hanging'),
                  onPressed: view.enabled
                      ? () => setState(() => _hanging = true)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    side: BorderSide(color: p.gold, width: 2),
                    foregroundColor: p.ink,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.push_pin_rounded),
                  label: Text(
                    fr ? 'Accrocher mes préférées' : 'Hang my favourites',
                    style: const TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget card(Creation x) {
      final hung = s.hung.containsKey(x.id);
      final reason = s.hung[x.id];
      return SizedBox(
        width: 170,
        child: Column(
          children: [
            Semantics(
              button: true,
              selected: hung,
              label: hung
                  ? (fr ? 'Création accrochée' : 'Hung creation')
                  : (fr
                        ? 'Création, touche pour l’accrocher'
                        : 'Creation, tap to hang it'),
              child: Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.cardMd,
                  side: BorderSide(
                    color: hung ? p.gold : p.line,
                    width: hung ? 5 : 2,
                  ),
                ),
                child: InkWell(
                  key: ValueKey('gallery-card-${x.id}'),
                  borderRadius: Radii.cardMd,
                  onTap: view.enabled && !s.solved
                      ? () => view.dispatch(ToggleHang(x.id))
                      : null,
                  child: SizedBox(
                    height: 130,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ExcludeSemantics(
                        child: creationView(x, locale: view.locale)!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hung) ...[
              const SizedBox(height: 6),
              // Full card width, padded, wrapping: the dense tile's
              // one-line label touched its edges (« Je suis fier ou
              // fière »).
              for (final (id, label) in c.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnswerTile(
                      key: ValueKey('gallery-reason-${x.id}-$id'),
                      label: label,
                      state: reason == id
                          ? AnswerTileState.picked
                          : AnswerTileState.idle,
                      onTap: view.enabled && !s.solved
                          ? () => view.dispatch(SetHangReason(x.id, id))
                          : null,
                    ),
                  ),
                ),
            ],
          ],
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
              Text(
                fr
                    ? 'Choisis jusqu’à ${c.maxHang} créations à accrocher, et dis pourquoi.'
                    : 'Pick up to ${c.maxHang} creations to hang, and say why.',
                style: heading,
              ),
              Text(
                '${s.hung.length} / ${c.maxHang}',
                key: const ValueKey('gallery-count'),
                style: heading.copyWith(color: p.ink),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [for (final x in _creations) card(x)],
              ),
              if (s.solved) ...[
                const SizedBox(height: 16),
                for (final v in c.visitors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CharacterSays(
                      key: ValueKey('gallery-visitor-${v.character.key}'),
                      character: v.character,
                      mood: CharacterMood.delighted,
                      locale: view.locale,
                      text: v.comment,
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

/// Practice only: right whenever the child hung something and said why
/// (or the gallery was empty). Nothing here becomes mastery.
class MyGalleryEvaluator implements Evaluator<GalleryContent, BlanksAnswer> {
  const MyGalleryEvaluator();

  @override
  String get engineKey => MyGalleryEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    GalleryContent content,
    BlanksAnswer answer,
    EvaluationContext ctx,
  ) {
    final b = answer.blanks;
    final reasons = {for (final r in content.reasons) r.$1};
    final hung = b.keys.where((k) => k.startsWith('hang_')).length;
    final ok =
        b['empty'] == 'true' ||
        (hung >= 1 &&
            hung <= content.maxHang &&
            b.entries
                .where((e) => e.key.startsWith('hang_'))
                .every((e) => reasons.contains(e.value)));
    return EvaluationResult(
      outcome: ok ? Outcome.correct : Outcome.incorrect,
      score: ok ? 1 : 0,
      attemptNumber: ctx.attemptNumber,
      evaluator: '$engineKey.$policy@$version',
      skillNodeIds: ctx.skillNodeIds,
      itemResults: {'published': ok},
      evidence: EvidenceLevel.practice,
    );
  }
}
