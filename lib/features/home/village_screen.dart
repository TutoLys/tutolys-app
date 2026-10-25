import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';

import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import 'subject_progress.dart';
import 'subject_strip.dart';
import '../../core/widgets/breathing_mascot.dart';
import 'village_scene.dart';

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
  const VillageScreen({this.onOpenPath, super.key});

  /// Where "Continuer", a quest row and a building all lead: the Carte.
  ///
  /// Supplied by the shell, which owns which page is showing — the screen
  /// does not navigate itself, same as `VillageNavShell` and
  /// `SettingsScreen`.
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kid = ref.watch(sessionControllerProvider).kid;
    final progress = ref.watch(progressControllerProvider);
    // Per-subject mastery, joined locally from the per-skill figures the
    // backend already sends plus the cached curriculum's own subject per
    // node — no extra endpoint, and it works offline.
    final t = context.s;
    final bySubject =
        ref.watch(subjectProgressProvider).value ?? <String, double>{};

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
                  for (final b in villageBuildings(t))
                    b.withProgress(bySubject[subjectCodeFor(b.asset)]),
                ];

                // Below the phone breakpoint the design does not shrink the
                // village — it replaces it. The scene positions buildings at
                // fixed fractions of a wide canvas, so on ~390px they
                // overlap, their pills collide and the whole thing clips.
                if (constraints.maxWidth < Breakpoints.compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MobileGreeting(
                        text: _greetingFor(t, kid?.displayName, progress),
                      ),
                      const SizedBox(height: Space.md),
                      SubjectStrip(
                        buildings: buildings,
                        title: t.villageYourSubjects,
                        onTapBuilding: (_) => onOpenPath?.call(),
                      ),
                      const SizedBox(height: Space.md),
                      _QuestPanel(progress: progress, onOpenPath: onOpenPath),
                    ],
                  );
                }

                final scene = SizedBox(
                  height: 580,
                  child: VillageScene(
                    buildings: buildings,
                    signTitle: t.villageSignTitle,
                    signSubtitle: kid?.gradeLevel == null
                        ? ''
                        : t.gradeLabel(kid!.gradeLevel),
                    greeting: _greetingFor(t, kid?.displayName, progress),
                    onTapBuilding: (_) => onOpenPath?.call(),
                  ),
                );
                final panel = _QuestPanel(
                  progress: progress,
                  onOpenPath: onOpenPath,
                );

                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      scene,
                      const SizedBox(height: Space.md),
                      panel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: scene),
                    const SizedBox(width: Space.lg),
                    SizedBox(width: 300, child: panel),
                  ],
                );
              },
            ),
            const SizedBox(height: Space.lg),
            _RecommendBar(onContinue: onOpenPath),
          ],
        ),
      ),
    );
  }
}

/// Maps a building's display label to the backend's subject code.
///
/// The codes are the backend's own `SubjectCode` set; `CCQ` is not among
/// them (open item #13), so Culture québécoise has no code and will read as
/// unmeasured until that curriculum round happens.
/// Keyed on the asset rather than the label: labels are localised now, and
/// matching on translated display text is how a feature silently breaks the
/// moment someone switches language.
String subjectCodeFor(String asset) => switch (asset) {
  'asset-bldg-math.webp' => 'MATH',
  'asset-bldg-francais.webp' => 'FR',
  'asset-bldg-anglais.webp' => 'EN',
  'asset-bldg-science.webp' => 'SCI',
  'asset-bldg-univers-social.webp' => 'SOC',
  _ => '',
};

/// What the fox says. Built from the real daily quest when there is one,
/// so it is never a line of flavour text pretending to know something.
String _greetingFor(Strings t, String? name, ProgressState progress) {
  final hello = t.greeting(name ?? '');
  final line = progress.dailyQuest == null
      ? t.villageGreetingReady
      : t.villageGreetingQuest;
  return '$hello $line';
}

/// The navy band. Its content is a real recommendation only once something
/// computes one — today the Carte knows what is next, this does not, so it
/// points there rather than naming a node it has not chosen.
class _RecommendBar extends StatelessWidget {
  const _RecommendBar({this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
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
      child: Row(
        children: [
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
                  context.s.villageContinuePath,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
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
                  child: Text(
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
          ),
        ],
      ),
    );
  }
}

/// "Quêtes du jour" — the design's right-hand panel.
///
/// The design mocks three quests. Exactly one real quest type exists (the
/// daily challenge, `tutolys-backend` ADR 0019); teacher-assigned and
/// bonus-review quests need school plumbing and are open item #11. So this
/// renders the real one and says plainly that it is the only one, rather
/// than padding the list to three.
class _QuestPanel extends StatelessWidget {
  const _QuestPanel({required this.progress, this.onOpenPath});

  final ProgressState progress;
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final quest = progress.dailyQuest;

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: p.shadow, blurRadius: 40, offset: Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset('assets/images/asset-target.webp', width: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.s.villageQuestsTitle,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (quest == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm),
              child: Text(
                context.s.villageNoQuests,
                style: TextStyle(fontSize: 12.5, color: p.inkMuted),
              ),
            )
          else
            _QuestRow(
              onTap: onOpenPath,
              // `DailyQuestDto` carries no title — the daily challenge is
              // one fixed quest type ("N correct in a row, today", backend
              // ADR 0019), so its name is derived rather than transported.
              title: context.s.streakQuestTitle(quest.target),
              done: quest.completed,
              current: quest.progress,
              target: quest.target,
            ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.title,
    required this.done,
    required this.current,
    required this.target,
    this.onTap,
  });

  final VoidCallback? onTap;

  final String title;
  final bool done;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  '$current/$target',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: p.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: target == 0 ? 0 : current / target,
                    minHeight: 6,
                    backgroundColor: p.track,
                    valueColor: AlwaysStoppedAnimation(p.quebecBlueBright),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done ? Color(0xFF3DBE7A) : p.quebecBlueBright,
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : Icons.play_arrow,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The fox and its line, on a phone — the scene's own greeting lives inside
/// the village canvas, which mobile does not render.
class _MobileGreeting extends StatelessWidget {
  const _MobileGreeting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BreathingMascot(height: 64),
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
