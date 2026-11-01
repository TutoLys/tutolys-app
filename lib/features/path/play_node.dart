import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../data/sync/content_sync.dart' show NodeDownload;
import '../../data/sync/window_plan.dart';
import '../progress/progress_controller.dart';
import '../settings/settings_controller.dart';
import '../play/play_screen.dart' show PlayExit;
import 'carte_model.dart';
import 'node_lessons.dart';
import 'path_controller.dart';
import 'skill_path.dart';

/// The Carte's frontier: the one node "Continuer" means (A2).
class CarteNext {
  const CarteNext({
    required this.subject,
    required this.leaf,
    required this.label,
    required this.lessons,
    this.areaTitle,
  });

  final String subject;
  final CachedSkillNode leaf;

  /// The node's name as the Carte shows it, in the right language.
  final String label;
  final NodeLessons lessons;

  /// The learning area the node sits in, as the Carte titles it.
  final String? areaTitle;
}

/// The active node of the subject the Carte is on, computed exactly as the
/// Carte computes it (`buildCarteSections`), or null while it loads or when
/// nothing is open.
final carteNextProvider = Provider<CarteNext?>((ref) {
  final state = ref.watch(pathControllerProvider);
  if (state.loading || state.leaves.isEmpty) return null;
  final lessons = nodeLessonsOf(
    state,
    ref.watch(nodeProgressProvider).value ?? const {},
  );
  final english = ref.watch(settingsControllerProvider.select((s) => s.english));
  final sections = buildCarteSections(
    subject: state.subject,
    leaves: state.leaves,
    playable: state.carteLessons.keys.toSet(),
    masteries: ref.watch(progressControllerProvider).masteries,
    appLocale: english ? const Locale('en', 'CA') : const Locale('fr', 'CA'),
    completed: {
      for (final MapEntry(:key, :value) in lessons.entries)
        if (value.complete) key,
    },
  );
  for (final section in sections) {
    for (final node in section.nodes) {
      if (node.state != PathNodeState.active) continue;
      final nodeLessons = lessons[node.id];
      if (nodeLessons == null) return null;
      return CarteNext(
        subject: state.subject,
        leaf: state.leaves.firstWhere((l) => l.id == node.id),
        label: node.label,
        lessons: nodeLessons,
        areaTitle: section.title,
      );
    }
  }
  return null;
});

/// Plays a node's next lesson: the one path into a game from the Carte and
/// from Village's "Continuer". A lesson outside the offline window is
/// downloaded first, or a kind word says it needs the Internet (ADR 0095).
/// Returns once the kid is back.
Future<void> playNode(
  BuildContext context,
  WidgetRef ref, {
  required CachedSkillNode leaf,
  required NodeLessons lessons,
}) async {
  var envelope = lessons.next;
  if (isNotDownloaded(envelope)) {
    final id = envelope['exercise_id'];
    final ready = await _download(context, ref, leaf.id);
    if (!ready || !context.mounted) return;
    final fresh = ref.read(pathControllerProvider).lessonsByNodeId[leaf.id];
    final found = fresh?.where((l) => l['exercise_id'] == id);
    if (found == null || found.isEmpty) return;
    envelope = found.first;
  }
  final exit = await GoRouter.of(
    context,
  ).push<Object?>('/play', extra: PlayRequest(node: leaf, envelope: envelope));
  // The header's XP and streak, and the map's mastery, all moved. The
  // shell keeps tabs alive, so nothing re-reads on its own.
  ref.read(progressControllerProvider.notifier).refresh();
  // « Suivant » on the celebration (G12): the Carte's frontier, read now,
  // after the lesson just finished has moved it.
  if (exit == PlayExit.next && context.mounted) {
    final next = ref.read(carteNextProvider);
    if (next != null) {
      await playNode(context, ref, leaf: next.leaf, lessons: next.lessons);
    }
  }
}

/// Downloads a leaf, with a small wait on screen; offline or failed, a
/// kind word instead. True once the lesson is on the device.
Future<bool> _download(
  BuildContext context,
  WidgetRef ref,
  String skillNodeId,
) async {
  final t = context.s;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('carte-downloading'),
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(t.pathDownloading)),
          ],
        ),
      ),
    ),
  );
  final result = await ref
      .read(pathControllerProvider.notifier)
      .download(skillNodeId);
  navigator.pop();
  if (result == NodeDownload.done) return true;
  messenger?.showSnackBar(
    SnackBar(
      key: const ValueKey('carte-not-downloaded'),
      content: Text(
        result == NodeDownload.offline
            ? t.pathNotDownloadedOffline
            : t.pathDownloadFailed,
      ),
    ),
  );
  return false;
}
