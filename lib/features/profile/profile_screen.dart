import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../pairing/pairing_controller.dart';

/// The profile tab (A7.2, visual-layer-only scope): the kid's name and
/// grade, and where "sign out this device" now lives (moved off the path
/// screen's app bar once there was a real home for it). Deliberately no
/// avatar-unlock-by-mastery or real badge grid — both need the server-owned
/// progression engine (#3/#10 on the open-items list), so this shows a
/// placeholder rather than a fabricated one.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final kid = ref.watch(sessionControllerProvider).kid;

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
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).forget(),
              icon: const Icon(Icons.logout),
              label: Text(s.profileSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
