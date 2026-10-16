import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../pairing/pairing_controller.dart';

/// Placeholder for the skill path (A7).
///
/// Exists now so the paired state is reachable and the pairing flow can be
/// exercised end to end. The real Duolingo-style path needs the curriculum
/// tree, which lands in Phase 4 — building it against placeholder data would
/// mean throwing it away.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final s = context.s;
    final kid = session.kid;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TutolysMascot(mood: MascotMood.celebrating, size: 140),
                const SizedBox(height: Space.lg),
                Text(
                  kid == null ? s.pathTitle : s.pairingWelcome(kid.displayName),
                  style: context.text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  s.pathEmpty,
                  style: context.text.bodyLarge
                      ?.copyWith(color: context.extras.mutedText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).forget(),
                  child: const Text('Déconnecter cet appareil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
