import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../pairing/pairing_controller.dart';
import 'path_controller.dart';

/// The real skill path (A7): a flat list of this kid's math leaves at
/// their own grade, locked/available only — no "mastered" (no progress
/// model exists yet, A7 plan's gap #5), no visual tree (that's a later
/// extension, "Learner Home and Curriculum Path" in
/// `a7-skill-path-plan.md`, not this pass).
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final session = ref.watch(sessionControllerProvider);
    final pathState = ref.watch(pathControllerProvider);
    final kid = session.kid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          kid == null ? s.pathTitle : s.pairingWelcome(kid.displayName),
        ),
        actions: [
          IconButton(
            tooltip: 'Déconnecter cet appareil',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).forget(),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (pathState) {
          PathState(loading: true) => const _Loading(),
          PathState(leaves: []) => _Empty(offline: pathState.offline),
          _ => _PathList(state: pathState),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TutolysMascot(
              mood: offline ? MascotMood.thinking : MascotMood.idle,
              size: 140,
            ),
            const SizedBox(height: Space.lg),
            Text(
              s.pathEmpty,
              style: context.text.bodyLarge?.copyWith(
                color: context.extras.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PathList extends ConsumerWidget {
  const _PathList({required this.state});

  final PathState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(pathControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(Space.md),
        itemCount: state.leaves.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (context, index) {
          final leaf = state.leaves[index];
          final available = state.isAvailable(leaf);
          return _PathRow(
            leaf: leaf,
            available: available,
            onTap: available
                ? () {
                    final envelope = state.exerciseByNodeId[leaf.id]!;
                    GoRouter.of(context).push(
                      '/play',
                      extra: PlayRequest(node: leaf, envelope: envelope),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.leaf,
    required this.available,
    required this.onTap,
  });

  final CachedSkillNode leaf;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    // Locked/available is never color-only: icon and label both change too,
    // so the state reads the same without relying on color perception.
    return Card(
      child: ListTile(
        leading: Icon(
          available ? Icons.play_circle_fill : Icons.lock_outline,
          color: available ? context.colors.primary : context.extras.mutedText,
        ),
        title: Text(leaf.labelFr),
        subtitle: available ? null : Text(s.pathLocked),
        enabled: available,
        onTap: onTap,
      ),
    );
  }
}
