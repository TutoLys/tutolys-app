import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';
import 'pin_gate.dart';

/// The profile tab (A7.2, visual-layer-only scope + B9's follow-up): the
/// kid's name and grade, their real mastered-skills count and day-streak
/// (both now readable from the backend, see ADR 0009), and where "sign out
/// this device" lives. Deliberately no avatar-unlock-by-mastery or real
/// badge grid yet — that needs a product decision on what unlocks what,
/// not just the data (#3 on the open-items list), so that stays a
/// placeholder rather than a fabricated one.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;
    final progress = ref.watch(progressControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.profileTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Center(
              child: Column(
                children: [
                  const TutolysMascot(mood: MascotMood.idle, size: 120),
                  const SizedBox(height: Space.md),
                  if (kid != null) ...[
                    Text(kid.displayName, style: context.text.headlineSmall),
                    const SizedBox(height: Space.xxs),
                    Text(
                      s.profileGrade(kid.gradeLevel),
                      style: context.text.bodyMedium?.copyWith(
                        color: context.extras.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            if (!progress.loading) _ProgressSummary(progress: progress),
            const SizedBox(height: Space.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: context.extras.mutedText,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        s.profileBadgesComingSoon,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.extras.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            OutlinedButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout),
              label: Text(s.profileSignOut),
            ),
          ],
        ),
      ),
    );
  }

  /// A PIN gate stands between this tap and a real sign-out — see
  /// `pin_gate.dart`. Without it, a kid signing out by accident (or on a
  /// whim) costs a guardian a full re-pair.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final allowed = await requireGuardianPin(context, ref);
    if (!allowed || !context.mounted) return;
    ref.read(sessionControllerProvider.notifier).forget();
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.progress});

  final ProgressState progress;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // A freshly-paired kid (or a read that couldn't reach telemetry) has
    // nothing real to show yet — no card at all, rather than a fabricated
    // "0 skills mastered" that reads as a judgement.
    if (progress.totalSkills == 0 && progress.currentStreakDays == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Expanded(
              child: _ProgressTile(
                icon: Icons.local_fire_department_rounded,
                value: progress.currentStreakDays == null
                    ? '–'
                    : '${progress.currentStreakDays}',
                label: progress.currentStreakDays == null
                    ? s.homeStatStreak
                    : s.profileStreakDays(progress.currentStreakDays!),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: _ProgressTile(
                icon: Icons.star_rounded,
                value: '${progress.masteredCount}',
                label: s.profileSkillsMastered(progress.masteredCount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: context.colors.primary, size: 20),
            const SizedBox(width: Space.xs),
            Text(value, style: context.text.titleLarge),
          ],
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.extras.mutedText,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
