import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import 'home_controller.dart';
import 'subject_progress.dart';
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
  const VillageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kid = ref.watch(sessionControllerProvider).kid;
    final home = ref.watch(homeControllerProvider);
    final progress = ref.watch(progressControllerProvider);
    // Per-subject mastery, joined locally from the per-skill figures the
    // backend already sends plus the cached curriculum's own subject per
    // node — no extra endpoint, and it works offline.
    final bySubject = ref.watch(subjectProgressProvider).value ?? <String, double>{};

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Greeting(
              name: kid?.displayName ?? '',
              grade: kid?.gradeLevel,
              streakDays: progress.currentStreakDays,
              streakEstimated: progress.isStreakEstimated,
              totalXp: progress.totalXp,
              exercisesToday: home.exercisesCompletedToday,
            ),
            const SizedBox(height: Space.md),
            // `grid-template-columns: 1fr 300px` above the mobile
            // breakpoint; the panel drops under the scene below it.
            LayoutBuilder(
              builder: (context, constraints) {
                final scene = SizedBox(
                  height: 580,
                  child: VillageScene(
                    buildings: [
                      for (final b in villageBuildings)
                        b.withProgress(bySubject[subjectCodeFor(b.label)]),
                    ],
                    signTitle: '🍁 Village des Érables',
                    signSubtitle: kid?.gradeLevel == null
                        ? ''
                        : '${kid!.gradeLevel}e année',
                    greeting: _greetingFor(kid?.displayName, progress),
                  ),
                );
                final panel = _QuestPanel(progress: progress);

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
            const _RecommendBar(),
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
String subjectCodeFor(String label) => switch (label) {
      'Mathématiques' => 'MATH',
      'Français' => 'FR',
      'Anglais' => 'EN',
      'Science et techno.' => 'SCI',
      'Univers social' => 'SOC',
      _ => '',
    };

/// What the fox says. Built from the real daily quest when there is one,
/// so it is never a line of flavour text pretending to know something.
String _greetingFor(String? name, ProgressState progress) {
  final who = (name == null || name.isEmpty) ? '' : ' $name';
  final quest = progress.dailyQuest;
  if (quest == null) return 'Salut$who ! Prêt à jouer ? 🎯';
  return 'Salut$who ! Ton défi du jour t\'attend 🎯';
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.grade,
    required this.streakDays,
    required this.streakEstimated,
    required this.totalXp,
    required this.exercisesToday,
  });

  final String name;
  final int? grade;
  final int? streakDays;
  final bool streakEstimated;
  final int totalXp;
  final int exercisesToday;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/asset-mascot-welcome.webp',
          height: 96,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Salut !' : 'Salut $name !',
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: p.ink,
                ),
              ),
              if (grade != null)
                Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    '${grade}e année',
                    style: TextStyle(
                      fontSize: 13,
                      color: p.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            _StatPill(
              asset: 'asset-xpstar.webp',
              // The real ledger total (ADR 0022), not a level — levels are
              // an XP-to-level rule nobody has decided yet.
              label: '$totalXp XP',
            ),
            _StatPill(
              asset: 'asset-flame.webp',
              // The `~` marks a local estimate, never the server's figure —
              // ADR 0006's convention, kept.
              label: streakDays == null
                  ? '–'
                  : '${streakEstimated ? '~' : ''}$streakDays j',
            ),
            _StatPill(
              asset: 'asset-target.webp',
              label: '$exercisesToday aujourd\'hui',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: p.shadowSmall,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/$asset', width: 18, height: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The navy band. Its content is a real recommendation only once something
/// computes one — today the Carte knows what is next, this does not, so it
/// points there rather than naming a node it has not chosen.
class _RecommendBar extends StatelessWidget {
  const _RecommendBar();

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
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVITÉ RECOMMANDÉE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.66,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBFD3FF),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Continue ton parcours',
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
          DecoratedBox(
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
              padding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 11,
              ),
              child: Text(
                'Continuer →',
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF241A04),
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
  const _QuestPanel({required this.progress});

  final ProgressState progress;

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
          BoxShadow(
            color: p.shadow,
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
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
                  'Quêtes du jour',
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
                'Aucune quête aujourd\'hui.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: p.inkMuted,
                ),
              ),
            )
          else
            _QuestRow(
              // `DailyQuestDto` carries no title — the daily challenge is
              // one fixed quest type ("N correct in a row, today", backend
              // ADR 0019), so its name is derived rather than transported.
              title: '${quest.target} bonnes réponses de suite',
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
  });

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
                    valueColor: AlwaysStoppedAnimation(
                      p.quebecBlueBright,
                    ),
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
              color: done
                  ? Color(0xFF3DBE7A)
                  : p.quebecBlueBright,
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
