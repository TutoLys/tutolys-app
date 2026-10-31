import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/arrow_label.dart';

import '../../core/i18n/strings.dart';

import '../pairing/pairing_controller.dart';
import 'subject_progress.dart';
import 'subject_strip.dart';
import 'village_scene.dart';
import '../audio/app_sounds.dart' show mascotSongFor;
import '../audio/music_director.dart';
import '../quests/quest_board.dart';
import '../quests/quests_screen.dart' show QuestListPending, questTitle;
import '../gallery/village_gallery.dart';
import '../path/play_node.dart';
import '../path/programme.dart';
import '../path/subject_pills.dart'
    show subjectArt, subjectArtFallback, subjectLabel;

/// Village — the learner's home.
///
/// The design's layout: a greeting with the mascot, the village scene with a
/// building per subject, and the navy "activité recommandée" bar beneath it.
///
/// Every number shown is real or absent. The design mocks per-subject
/// progress ("68/100" under each building) and a coin balance, and neither
/// exists: `/api/v1/me/progress` reports overall mastery with no per-subject
/// breakdown, and there is no currency anywhere in the product. Rather than
/// render convincing fiction on the most-looked-at screen, the buildings
/// carry their name only and the coin pill is absent.
class VillageScreen extends ConsumerWidget {
  const VillageScreen({
    this.onOpenPath,
    this.onOpenQuests,
    this.onOpenSubject,
    super.key,
  });

  /// Where "Continuer" and a quest row lead: the Carte.
  ///
  /// Supplied by the shell, which owns which page is showing — the screen
  /// does not navigate itself, same as `VillageNavShell` and
  /// `SettingsScreen`.
  final VoidCallback? onOpenPath;

  /// The quest panel's "Voir toutes": the Quêtes page.
  final VoidCallback? onOpenQuests;

  /// A live building: the Carte, opened on that building's subject.
  final ValueChanged<String>? onOpenSubject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kid = ref.watch(sessionControllerProvider).kid;
    final boardAsync = ref.watch(questBoardProvider);
    final board = boardAsync.value;
    final boardFailed = board == null && boardAsync.hasError;
    void retryBoard() => ref.invalidate(questBoardProvider);
    // Per-subject mastery, joined locally from the per-skill figures the
    // backend already sends plus the cached curriculum's own subject per
    // node — no extra endpoint, and it works offline.
    final t = context.s;
    final next = ref.watch(carteNextProvider);
    Widget recommend({required bool fullWidth}) => _RecommendBar(
      fullWidth: fullWidth,
      next: next,
      // A2: the gold button starts the frontier's activity, as the
      // design's `js-start-exercise` does. With nothing open yet it
      // still leads to the Carte.
      onContinue: next == null
          ? onOpenPath
          : () =>
                playNode(context, ref, leaf: next.leaf, lessons: next.lessons),
    );
    // A subject opens on the Carte; the gallery opens on the kid's own
    // shelf (ADR 0098).
    void openBuilding(VillageBuilding b) {
      if (b.subject == galleryBuildingCode) {
        openVillageGallery(context, ref);
      } else {
        onOpenSubject?.call(b.subject);
      }
    }

    final bySubject =
        ref.watch(subjectProgressProvider).value ?? <String, double>{};
    final withoutLessons =
        ref.watch(subjectsWithoutLessonsProvider).value ?? const <String>{};
    // The fox sings in the app's language, not a subject's (ADR 0035).
    void sing() => ref
        .read(musicDirectorProvider)
        .toggleSong(
          mascotSongFor(Localizations.localeOf(context).languageCode),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No greeting row here: the shell's header already carries the
            // name and the stat pills, and two of them on one screen was
            // the duplication Hafid's screenshot showed.
            // `grid-template-columns: 1fr 300px` above the mobile
            // breakpoint; the panel drops under the scene below it.
            LayoutBuilder(
              builder: (context, constraints) {
                final buildings = [
                  for (final b in villageBuildings(
                    t,
                    subjects: ref.watch(programmeSubjectsProvider),
                  ))
                    b.withProgress(
                      bySubject[b.subject],
                      hasLessons: !withoutLessons.contains(b.subject),
                    ),
                ];

                // Below the phone breakpoint the design does not shrink the
                // village — it replaces it. The scene positions buildings at
                // fixed fractions of a wide canvas, so on ~390px they
                // overlap, their pills collide and the whole thing clips.
                // AM11: and below 900px too. At 768 the scene drew at 0.62
                // and its labels read at ~7px; the phone layout is legible
                // and puts « Continuer » first.
                if (constraints.maxWidth < _sceneMinWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MobileGreeting(
                        text: _greetingFor(t, kid?.displayName, board),
                        onTapMascot: sing,
                      ),
                      // A6: the one action that matters comes first on a
                      // phone, its button full width.
                      const SizedBox(height: Space.md),
                      recommend(fullWidth: true),
                      const SizedBox(height: Space.md),
                      SubjectStrip(
                        buildings: buildings,
                        title: t.villageYourSubjects,
                        onTapBuilding: (b) => openBuilding(b),
                      ),
                      const SizedBox(height: Space.md),
                      _QuestPanel(
                        quests: board?.quests,
                        failed: boardFailed,
                        onRetry: retryBoard,
                        onOpenPath: onOpenPath,
                        onOpenQuests: onOpenQuests,
                      ),
                    ],
                  );
                }

                final scene = LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    height: _sceneHeight(box.maxWidth),
                    child: VillageScene(
                      buildings: buildings,
                      signTitle: t.villageSignTitle,
                      signSubtitle: kid?.gradeLevel == null
                          ? ''
                          : t.gradeLabel(kid!.gradeLevel),
                      greeting: _greetingFor(t, kid?.displayName, board),
                      onTapBuilding: (b) => openBuilding(b),
                      onTapMascot: sing,
                    ),
                  ),
                );
                final panel = _QuestPanel(
                  quests: board?.quests,
                  failed: boardFailed,
                  onRetry: retryBoard,
                  onOpenPath: onOpenPath,
                  onOpenQuests: onOpenQuests,
                );

                // Side by side only while the scene keeps ~760px of its own
                // (plus the 300px panel and the gap); below that six buildings
                // and their pills crowd, so the panel moves underneath.
                // Wider than a phone, the recommend bar sits under the
                // scene and its panel, as the design draws it.
                // « Continuer » comes first at every width (AM11), as it
                // does on a phone.
                if (constraints.maxWidth < _sideBySideMinWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      recommend(fullWidth: false),
                      const SizedBox(height: Space.lg),
                      scene,
                      const SizedBox(height: Space.md),
                      panel,
                    ],
                  );
                }
                // Beside the scene the panel is exactly the scene's height,
                // top and bottom edges aligned; more rows than fit scroll
                // inside it.
                final sceneWidth =
                    constraints.maxWidth - _panelWidth - Space.lg;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    recommend(fullWidth: false),
                    const SizedBox(height: Space.lg),
                    SizedBox(
                      height: _sceneHeight(sceneWidth),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: scene),
                          const SizedBox(width: Space.lg),
                          SizedBox(
                            width: _panelWidth,
                            child: _QuestPanel(
                              key: const ValueKey('village-quest-panel'),
                              quests: board?.quests,
                              failed: boardFailed,
                              onRetry: retryBoard,
                              onOpenPath: onOpenPath,
                              onOpenQuests: onOpenQuests,
                              fillHeight: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Below this the quest panel sits under the scene rather than beside it.
const double _sideBySideMinWidth = 1100;

/// Narrower content than this gets the phone layout instead of the scene
/// (AM11).
const double _sceneMinWidth = 900;

/// The design's `grid-template-columns: 1fr 300px`.
const double _panelWidth = 300;

/// Height follows width: the design's 580px at full size, never so short
/// that the buildings crowd together vertically.
double _sceneHeight(double width) => (width * 0.6).clamp(400.0, 580.0);

/// What the fox says. Built from the real open-quest count when there is one,
/// so it is never a line of flavour text pretending to know something.
String _greetingFor(Strings t, String? name, QuestBoard? board) {
  final hello = t.greeting(name ?? '');
  final open = board?.openCount ?? 0;
  final line = open == 0
      ? t.villageGreetingReady
      : t.villageGreetingQuests(open);
  return '$hello $line';
}

/// The navy band: the Carte's frontier node, named with its subject's
/// building, area and skill (A2). With nothing open yet it says "Continue
/// ton parcours" and leads to the Carte.
class _RecommendBar extends StatelessWidget {
  const _RecommendBar({this.next, this.onContinue, this.fullWidth = false});

  final CarteNext? next;
  final VoidCallback? onContinue;

  /// A phone (A6): the button goes under the text, full width, the
  /// prototype's `.recommend .recommend-btn { width:100% }`.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final info = <Widget>[
      if (next case final next?) ...[
        Image.asset(
          'assets/images/${subjectArt[next.subject] ?? subjectArtFallback}',
          key: const ValueKey('recommend-building'),
          width: 52,
          height: 52,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 14),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.s.villageRecommendedLabel,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.66,
                fontWeight: FontWeight.w700,
                color: Color(0xFFBFD3FF),
              ),
            ),
            SizedBox(height: 3),
            Text(
              switch (next) {
                final next? => [
                  subjectLabel(context.s, next.subject),
                  ?next.areaTitle,
                ].join(' · '),
                null => context.s.villageContinuePath,
              },
              key: const ValueKey('recommend-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            if (next case final next?)
              Text(
                next.label,
                key: const ValueKey('recommend-skill'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBFD3FF),
                ),
              ),
          ],
        ),
      ),
    ];
    final Widget button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const ValueKey('recommend-continue'),
        onTap: onContinue,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.goldLight, p.gold],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: p.gold.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            child: fullWidth
                ? Center(
                    child: ArrowLabel(
                      context.s.villageContinueCta,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF241A04),
                      ),
                    ),
                  )
                : ArrowLabel(
                    context.s.villageContinueCta,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF241A04),
                    ),
                  ),
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.quebecBlue, Color(0xFF16285E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: p.shadow, blurRadius: 40, offset: Offset(0, 16)),
        ],
      ),
      child: fullWidth
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: info),
                const SizedBox(height: 14),
                button,
              ],
            )
          : Row(children: [...info, button]),
    );
  }
}

/// "Quêtes du jour" — the design's right-hand panel (`.quest-panel` with
/// `.quest-panel-head` and `.quest-row`s).
///
/// The same three quests Quêtes lists, from [questBoardProvider]. An open
/// quest's row leads to the Carte, where it is played; "Voir toutes" opens
/// Quêtes.
class _QuestPanel extends StatelessWidget {
  const _QuestPanel({
    super.key,
    required this.quests,
    this.onOpenPath,
    this.onOpenQuests,
    this.fillHeight = false,
    this.failed = false,
    this.onRetry,
  });

  final List<DailyQuestItem>? quests;

  /// The board couldn't be read (A3).
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenPath;
  final VoidCallback? onOpenQuests;

  /// Fill the height it is given and scroll the rows inside it, rather than
  /// sizing to its rows. Set beside the scene, where the two must line up.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final items = quests;

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (items == null)
          QuestListPending(failed: failed, onRetry: onRetry)
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Text(
              t.villageNoQuests,
              style: TextStyle(fontSize: 12.5, color: p.inkMuted),
            ),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
            _QuestRow(
              key: ValueKey('village-quest-${items[i].key}'),
              quest: items[i],
              title: questTitle(t, items[i]),
              onTap: items[i].done ? null : onOpenPath,
            ),
          ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset('assets/images/asset-target.webp', width: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  t.villageQuestsTitle,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: p.ink,
                  ),
                ),
              ),
              if (onOpenQuests != null)
                TextButton(
                  key: const ValueKey('village-quests-see-all'),
                  onPressed: onOpenQuests,
                  style: TextButton.styleFrom(
                    foregroundColor: p.quebecBlueBright,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(t.villageQuestsSeeAll),
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (fillHeight)
            Expanded(child: SingleChildScrollView(child: rows))
          else
            rows,
        ],
      ),
    );
  }
}

/// `.q-chip`: a 38px tile with the design's 145° gradients, one colour and
/// icon per kind of quest. The design's pink/blue/purple trio, assigned by
/// what the quest asks rather than by subject — these quests have none.
(List<Color>, IconData) _chipFor(QuestKind kind) => (
  switch (kind) {
    QuestKind.challenge => const [Color(0xFFF472B6), Color(0xFFEC4899)],
    QuestKind.exercises => const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
    QuestKind.minutes => const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
  },
  questIconFor(kind),
);

/// `.quest-row`: chip, title over "n/m" and the track, then the status dot
/// (green check once done, blue play otherwise) above the XP reward.
class _QuestRow extends StatelessWidget {
  const _QuestRow({
    super.key,
    required this.quest,
    required this.title,
    this.onTap,
  });

  final DailyQuestItem quest;
  final String title;
  final VoidCallback? onTap;

  static const _doneGreen = Color(0xFF3DBE7A);

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final (colors, icon) = _chipFor(quest.kind);
    final done = quest.done;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  // 145deg in CSS: top-left to bottom-right.
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.3,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${quest.progress}/${quest.target}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: p.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  VillageProgressBar(
                    value: quest.target == 0
                        ? 0
                        : quest.progress / quest.target,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  key: ValueKey(done ? 'quest-status-done' : 'quest-status-go'),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? _doneGreen : p.quebecBlueBright,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.play_arrow_rounded,
                    size: done ? 15 : 16,
                    color: Colors.white,
                  ),
                ),
                // Only a reward the backend pays (quest_board.dart).
                if (quest.xpReward case final xp?) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        // The XP star, as on Quêtes: there are no coins.
                        'assets/images/asset-xpstar.webp',
                        width: 12,
                        height: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        context.s.questRewardXp(xp),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: p.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The fox and its line, on a phone — the scene's own greeting lives inside
/// the village canvas, which mobile does not render.
class _MobileGreeting extends StatelessWidget {
  const _MobileGreeting({required this.text, this.onTapMascot});

  final String text;
  final VoidCallback? onTapMascot;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TappableMascot(height: 64, onTap: onTapMascot),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: p.shadowSmall,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: p.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
