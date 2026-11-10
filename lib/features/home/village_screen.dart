import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';

import '../pairing/pairing_controller.dart';
import 'subject_progress.dart';
import 'subject_strip.dart';
import 'village_scene.dart';
import 'village3d/village_bridge.dart';
import 'village3d/village_scene_host.dart';
import 'village3d/village_scene_loading.dart';
import 'village3d/village_strings.dart';
import 'village3d/village_weather.dart';
import '../audio/app_sounds.dart' show mascotSongFor;
import '../audio/music_director.dart';
import '../quests/quest_board.dart';
import '../quests/quests_screen.dart' show QuestListPending, questTitle;
import '../gallery/village_gallery.dart';
import '../path/programme.dart';
import '../settings/settings_controller.dart';

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
    final t = context.s;
    // A subject opens on the Carte; the gallery opens on the kid's own
    // shelf (ADR 0098).
    void openBuilding(VillageBuilding b) {
      if (b.subject == galleryBuildingCode) {
        openVillageGallery(context, ref);
      } else {
        onOpenSubject?.call(b.subject);
      }
    }

    // Per-subject mastery, joined locally from the per-skill figures the
    // backend already sends plus the cached curriculum's own subject per
    // node — no extra endpoint, and it works offline.
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
    final signSubtitle = kid?.gradeLevel == null
        ? ''
        : t.gradeLabel(kid!.gradeLevel);
    final greeting = _greetingFor(t, kid?.displayName, board);
    void openCode(String code) {
      for (final b in buildings) {
        if (b.subject == code) return openBuilding(b);
      }
    }

    final active3d = ref.watch(village3dActiveProvider);
    Widget questPanel({bool fill = false, Key? key}) => _QuestPanel(
      key: key,
      quests: board?.quests,
      failed: boardFailed,
      onRetry: retryBoard,
      onOpenPath: onOpenPath,
      onOpenQuests: onOpenQuests,
      fillHeight: fill,
    );

    // Hafid, 2026-11-10: "It should take the whole screen … give the 3d the
    // full space". No recommended-activity band: the header, the nav and
    // the quests stay, and the village fills everything else, down to the
    // bottom of the window, at every size (ADR 0126).
    return SafeArea(
      key: const ValueKey('village-body'),
      child: LayoutBuilder(
        builder: (context, box) {
          // The breakpoints measure the content inside the page padding,
          // as they always have (AM11).
          final inner = box.maxWidth - 2 * Space.lg;
          final phone = inner < _sceneMinWidth;

          // A phone without the 3D scene: the 2D village doesn't fit a
          // phone (AM11), so it keeps its phone layout, scrolling.
          if (phone && !active3d) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MobileGreeting(text: greeting, onTapMascot: sing),
                  const SizedBox(height: Space.md),
                  SubjectStrip(
                    buildings: buildings,
                    title: t.villageYourSubjects,
                    onTapBuilding: openBuilding,
                  ),
                  const SizedBox(height: Space.md),
                  questPanel(),
                ],
              ),
            );
          }

          final scene = ClipRRect(
            key: const ValueKey('village-scene-box'),
            borderRadius: BorderRadius.circular(24),
            // The weather is asked only where the 3D scene can show it.
            child: VillageWeatherPoller(
              enabled: active3d,
              child: VillageSceneHost(
                state: VillageSceneState(
                  buildings: buildings,
                  lang: Localizations.localeOf(context).languageCode,
                  signTitle: t.villageSignTitle,
                  signSubtitle: signSubtitle,
                  greeting: greeting,
                  reduced: MediaQuery.disableAnimationsOf(context),
                  strings: village3dStrings(t),
                  weather: ref.watch(villageWeatherProvider),
                ),
                onOpen: openCode,
                onMascot: sing,
                // The 2D village, for good, where the 3D one can't run; the
                // host shows its own loader while the 3D one loads. On a
                // phone the 2D village doesn't fit, and a failure switches
                // to the phone layout anyway, so the loader holds the box.
                fallback: phone
                    ? const VillageSceneLoading()
                    : VillageScene(
                        buildings: buildings,
                        signTitle: t.villageSignTitle,
                        signSubtitle: signSubtitle,
                        greeting: greeting,
                        onTapBuilding: openBuilding,
                        onTapMascot: sing,
                      ),
              ),
            ),
          );
          final gap = phone ? Space.md : Space.lg;

          // Wide: the quests beside the village, at its full height. They
          // fold to a slim tab so the village gets the width (Hafid,
          // 2026-11-10); the scene re-fits as the column animates.
          if (inner >= _sideBySideMinWidth) {
            final folded = ref.watch(
              settingsControllerProvider.select((s) => s.questsFolded),
            );
            final settings = ref.read(settingsControllerProvider.notifier);
            final width = folded ? _foldedTabWidth : _panelWidth;
            return Padding(
              padding: EdgeInsets.all(gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: scene),
                  SizedBox(width: gap),
                  AnimatedContainer(
                    key: const ValueKey('village-quest-column'),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: width,
                    // The content takes its final width at once and the
                    // column reveals it, so nothing reflows mid-animation.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: width,
                        maxWidth: width,
                        child: folded
                            ? _QuestTab(
                                board: board,
                                onUnfold: () => settings.setQuestsFolded(false),
                              )
                            : _QuestPanel(
                                key: const ValueKey('village-quest-panel'),
                                quests: board?.quests,
                                failed: boardFailed,
                                onRetry: retryBoard,
                                onOpenPath: onOpenPath,
                                onOpenQuests: onOpenQuests,
                                fillHeight: true,
                                onFold: () => settings.setQuestsFolded(true),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Tablet and phone: the village fills; the quests open in a
          // sheet from a slim row under it. Under it, not over it: on web
          // the scene's iframe takes every tap in its box, and on Linux
          // its view draws above Flutter.
          return Padding(
            padding: EdgeInsets.all(gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: scene),
                SizedBox(height: phone ? Space.sm : Space.md),
                _QuestsButton(
                  board: board,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.md,
                          0,
                          Space.md,
                          Space.md,
                        ),
                        child: questPanel(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

/// The quest panel folded: a slim tab on the right edge.
const double _foldedTabWidth = 64;

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

/// Below the village on tablets and phones: today's quests, one tap from a
/// sheet, with the same count the header pill shows.
class _QuestsButton extends StatelessWidget {
  const _QuestsButton({required this.board, required this.onTap});

  final QuestBoard? board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final quests = board?.quests;
    final done = quests?.where((q) => q.done).length;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const ValueKey('village-quests-button'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Image.asset('assets/images/asset-target.webp', width: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s.villageQuestsTitle,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: p.ink,
                  ),
                ),
              ),
              if (quests != null && done != null)
                Text(
                  '$done/${quests.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: p.inkMuted,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_up_rounded, color: p.inkMuted),
            ],
          ),
        ),
      ),
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
    this.onFold,
  });

  final List<DailyQuestItem>? quests;

  /// Folds the panel to its tab. Null (in the sheet) shows no control.
  final VoidCallback? onFold;

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
              if (onFold != null)
                IconButton(
                  key: const ValueKey('village-quests-fold'),
                  tooltip: t.questsFold,
                  onPressed: onFold,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    color: p.inkMuted,
                  ),
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

/// The quest panel folded (Hafid, 2026-11-10): the quest icon and today's
/// count, top of the right edge. A tap, or Enter, unfolds it.
class _QuestTab extends StatelessWidget {
  const _QuestTab({required this.board, required this.onUnfold});

  final QuestBoard? board;
  final VoidCallback onUnfold;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final quests = board?.quests;
    final done = quests?.where((q) => q.done).length;
    return Align(
      alignment: Alignment.topCenter,
      child: Tooltip(
        message: context.s.questsUnfold,
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          elevation: 0,
          shadowColor: p.shadow,
          child: InkWell(
            key: const ValueKey('village-quests-unfold'),
            borderRadius: BorderRadius.circular(20),
            onTap: onUnfold,
            child: Semantics(
              button: true,
              label: context.s.questsUnfold,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        color: p.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Image.asset('assets/images/asset-target.webp', width: 26),
                      if (quests != null && done != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$done/${quests.length}',
                          key: const ValueKey('village-quests-tab-count'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.q-chip`: a 38px tile with the design's 145° gradients, one colour and
/// icon per kind of quest. The design's pink/blue/purple trio, assigned by
/// what the quest asks rather than by subject — these quests have none.
(List<Color>, IconData) _chipFor(QuestKind kind) =>
    (questChipColors(kind), questIconFor(kind));

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
