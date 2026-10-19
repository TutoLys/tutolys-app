import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/database.dart';

/// Hosts one exercise, reached by tapping a node on the path.
///
/// Placeholder until the real `EngineRegistry`/`EngineFeedback`
/// implementations land (A7, piece 4) — at that point this wraps
/// `ExerciseRunner` instead of showing a stand-in. Exists now so go_router
/// has a real second destination to push to and pop back from.
class PlayScreen extends StatelessWidget {
  const PlayScreen({required this.node, super.key});

  final CachedSkillNode node;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(title: Text(node.labelFr)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TutolysMascot(mood: MascotMood.thinking, size: 120),
                const SizedBox(height: Space.lg),
                Text(
                  node.labelFr,
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.playBack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
