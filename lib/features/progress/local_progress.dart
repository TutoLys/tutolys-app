import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/node_progress_local.dart';
import '../pairing/pairing_controller.dart';
import '../path/node_lessons.dart';
import '../path/path_controller.dart';
import '../path/subject_language.dart';
import '../settings/settings_controller.dart';

/// Each skill node's progress as this device knows it, the moment a lesson
/// ends (ADR 0032): the node's finished lessons over its lessons, 0..1.
///
/// The lessons are the ones the Carte would serve: every cached exercise at
/// the kid's grade, one per lesson, in the language each subject asks for.
/// Only nodes with at least one lesson appear; a node with nothing cached
/// has no local measure, which is not the same as zero.
final localNodeProgressProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final kid = ref.watch(sessionControllerProvider).kid;
  if (kid == null) return const {};
  final appLocale =
      ref.watch(settingsControllerProvider.select((s) => s.english))
      ? const Locale('en', 'CA')
      : const Locale('fr', 'CA');
  final progress = await ref.watch(nodeProgressProvider.future);
  final cached = await ref
      .watch(contentSyncProvider)
      .cachedExercises(grade: kid.gradeLevel);
  return localNodeFractions(
    cached: cached,
    progress: progress,
    appLocale: appLocale,
  );
});

/// The pure half of [localNodeProgressProvider].
Map<String, double> localNodeFractions({
  required List<Map<String, Object?>> cached,
  required Map<String, NodeProgress> progress,
  required Locale appLocale,
}) {
  final bySubject = <String, List<Map<String, Object?>>>{};
  for (final e in cached) {
    bySubject.putIfAbsent(e['subject'] as String, () => []).add(e);
  }
  final out = <String, double>{};
  for (final MapEntry(key: subject, value: envelopes) in bySubject.entries) {
    final lessons = pickLessons(
      envelopes,
      locale: contentLocaleFor(subject, appLocale),
    );
    for (final MapEntry(key: node, value: list) in lessons.entries) {
      final n = nodeLessons(list, progress[node]);
      out[node] = n.total == 0 ? 0 : n.doneCount / n.total;
    }
  }
  return out;
}

/// A node's progress as shown: the server's mastery and the local measure,
/// whichever is further along, so finishing a lesson shows at once and the
/// server's catching up never pulls the bar back. Null when neither knows
/// anything about the node.
double? shownNodeProgress({double? masteryPct, double? local}) {
  final server = masteryPct == null ? null : masteryPct / 100;
  if (server == null) return local;
  if (local == null) return server;
  return server > local ? server : local;
}
