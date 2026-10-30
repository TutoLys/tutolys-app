import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/content_freshness.dart';
import '../pairing/pairing_controller.dart';
import '../path/programme.dart';
import '../progress/local_progress.dart';
import '../progress/progress_controller.dart';

/// Per-subject progress, joined locally rather than fetched.
///
/// `/api/v1/me/progress` already returns mastery for every skill the kid has
/// played, and `skill_node_cache` already records which subject each skill
/// belongs to. The per-subject figure the Village shows is the join of those
/// two — no new endpoint, no new field, and it works offline because both
/// sides are already on the device.
///
/// The denominator is the kid's **cached leaves for that subject at their
/// own grade**, which is the same set the Carte draws from. A subject the
/// device has never synced has no denominator and returns null rather than
/// zero: "not measured" and "measured at zero" are different, and only one
/// of them should read as a kid having done nothing.
final subjectProgressProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final progress = ref.watch(progressControllerProvider);
  final kid = ref.watch(sessionControllerProvider).kid;
  if (kid == null) return const {};

  final db = ref.watch(localDatabaseProvider);
  final leaves = await (db.select(
    db.skillNodeTable,
  )..where((t) => t.grade.equals(kid.gradeLevel))).get();
  if (leaves.isEmpty) return const {};

  final subjectOf = {for (final leaf in leaves) leaf.id: leaf.subject};

  final total = <String, int>{};
  for (final leaf in leaves) {
    total[leaf.subject] = (total[leaf.subject] ?? 0) + 1;
  }

  // Sum each leaf's progress rather than counting mastered leaves: a kid
  // halfway through every skill in a subject has made real progress, and a
  // mastered-only count would show them zero. Per leaf, server mastery or
  // the local lesson measure, whichever is further (ADR 0032), so a lesson
  // finished today counts before the server's scheduled refresh has run.
  final local = await ref.watch(localNodeProgressProvider.future);
  final mastery = {
    for (final m in progress.masteries) m.skillNodeId: m.masteryPct,
  };
  final earned = <String, double>{};
  for (final id in {...mastery.keys, ...local.keys}) {
    final subject = subjectOf[id];
    if (subject == null) continue;
    final shown = shownNodeProgress(masteryPct: mastery[id], local: local[id]);
    earned[subject] = (earned[subject] ?? 0) + (shown ?? 0);
  }

  return {
    for (final entry in total.entries)
      if (entry.value > 0)
        entry.key: ((earned[entry.key] ?? 0) / entry.value).clamp(0.0, 1.0),
  };
});

/// The kid's subjects this device has synced and found no lesson for, at
/// their grade: ESL and FLS today (ADR 0101), CCQ until it has content.
///
/// Only a subject that really synced counts, so a first launch doesn't call
/// every subject empty before anything has downloaded. Shown as « Bientôt »
/// on its building, never as « 0 % » or « À découvrir », which would promise
/// a child something to play.
final subjectsWithoutLessonsProvider = FutureProvider<Set<String>>((ref) async {
  final kid = ref.watch(sessionControllerProvider).kid;
  if (kid == null) return const {};
  // The Carte invalidates this after each content sync.
  final db = ref.watch(localDatabaseProvider);
  final freshness = ContentFreshness(db);
  final empty = <String>{};
  for (final subject in ref.watch(programmeSubjectsProvider)) {
    if (await freshness.lastSynced(subject, kid.gradeLevel) == null) continue;
    final one =
        await (db.select(db.manifestEntryTable)
              ..where(
                (t) =>
                    t.subject.equals(subject) & t.grade.equals(kid.gradeLevel),
              )
              ..limit(1))
            .getSingleOrNull();
    if (one == null) empty.add(subject);
  }
  return empty;
});
