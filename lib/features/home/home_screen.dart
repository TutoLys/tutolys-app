import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart';
import 'home_controller.dart';

/// The learner's landing tab (A7.2): a greeting, a "continue learning" card
/// for the next real available skill, and today's real play stats — no XP,
/// streak, or rank (those need the server-owned progression engine this
/// pass deliberately defers, see ADR/plan notes on A7.2's scope).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;
    final home = ref.watch(homeControllerProvider);
    final pathState = ref.watch(pathControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(homeControllerProvider.notifier).refresh();
            await ref.read(pathControllerProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(Space.md),
            children: [
              Text(
                kid == null ? s.pathTitle : s.homeGreeting(kid.displayName),
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: Space.lg),
              _ContinueLearningCard(pathState: pathState),
              const SizedBox(height: Space.lg),
              if (!home.loading) _StatsRow(home: home),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends ConsumerWidget {
  const _ContinueLearningCard({required this.pathState});

  final PathState pathState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    CachedSkillNode? nextLeaf;
    for (final leaf in pathState.leaves) {
      if (pathState.isAvailable(leaf)) {
        nextLeaf = leaf;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TutolysMascot(
                  mood: nextLeaf == null
                      ? MascotMood.idle
                      : MascotMood.celebrating,
                  size: 56,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    s.homeContinueLearning,
                    style: context.text.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            if (nextLeaf == null)
              Text(
                s.pathEmpty,
                style: context.text.bodyMedium?.copyWith(
                  color: context.extras.mutedText,
                ),
              )
            else ...[
              Text(
                nextLeaf.labelFr,
                style: context.text.bodyLarge,
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                // The real app's own CTA system gives its primary "play"
                // action a warm gold/amber treatment, never the generic
                // brand blue every other button uses (confirmed from its
                // shipped `main.css`'s `--games-cta-play-*` tokens) — the
                // theme's secondary (gold) scheme is exactly that pairing.
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.secondary,
                  foregroundColor: context.colors.onSecondary,
                ),
                onPressed: () async {
                  final envelope = pathState.exerciseByNodeId[nextLeaf!.id]!;
                  // Home's own stat tiles only ever load once (IndexedStack
                  // keeps this screen alive, it never rebuilds on its own) —
                  // `push` resolves exactly when the kid comes back, which is
                  // the one moment "today's" real counters can have changed.
                  await GoRouter.of(context).push(
                    '/play',
                    extra: PlayRequest(node: nextLeaf, envelope: envelope),
                  );
                  if (context.mounted) {
                    ref.read(homeControllerProvider.notifier).refresh();
                  }
                },
                child: Text(s.homePlay),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final minutes = (home.msPlayedToday / 60000).round();

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.videogame_asset_rounded,
            value: '${home.exercisesCompletedToday}',
            label: s.homeStatExercises,
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.schedule_rounded,
            value: '$minutes',
            label: s.homeStatMinutes,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(height: Space.xs),
            Text(value, style: context.text.headlineSmall),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: context.extras.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
