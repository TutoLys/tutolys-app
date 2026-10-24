import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pairing_controller.dart';
import '../progress/progress_controller.dart';

/// Per-subject mastery, joined locally rather than fetched.
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
final subjectProgressProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final progress = ref.watch(progressControllerProvider);
  final kid = ref.watch(sessionControllerProvider).kid;
  if (kid == null) return const {};

  final db = ref.watch(localDatabaseProvider);
  final leaves = await (db.select(db.skillNodeTable)
        ..where((t) => t.grade.equals(kid.gradeLevel)))
      .get();
  if (leaves.isEmpty) return const {};

  final subjectOf = {for (final leaf in leaves) leaf.id: leaf.subject};

  final total = <String, int>{};
  for (final leaf in leaves) {
    total[leaf.subject] = (total[leaf.subject] ?? 0) + 1;
  }

  // Sum real mastery percentages rather than counting mastered leaves: a kid
  // halfway through every skill in a subject has made real progress, and a
  // mastered-only count would show them zero.
  final earned = <String, double>{};
  for (final mastery in progress.masteries) {
    final subject = subjectOf[mastery.skillNodeId];
    if (subject == null) continue;
    earned[subject] = (earned[subject] ?? 0) + (mastery.masteryPct / 100);
  }

  return {
    for (final entry in total.entries)
      if (entry.value > 0)
        entry.key: ((earned[entry.key] ?? 0) / entry.value).clamp(0.0, 1.0),
  };
});
