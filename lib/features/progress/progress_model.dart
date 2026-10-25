import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';
import '../path/carte_model.dart';

/// The design's three strand statuses.
enum AreaStatus { mastered, learning, notStarted }

/// One row of "par compétence": a learning area and how far through it the
/// kid is.
class AreaProgress {
  const AreaProgress({
    required this.title,
    required this.fraction,
    required this.status,
  });

  /// Null for leaves no known area claims.
  final String? title;

  /// 0..1 — the mean of real mastery over every leaf in the area at the
  /// kid's grade, the same rule the Village uses per subject, so a kid
  /// halfway through every skill reads as halfway rather than as zero.
  final double fraction;

  final AreaStatus status;
}

/// Progrès rows for one subject, titled exactly as the Carte titles its
/// stretches (both go through [groupLeavesByArea]).
///
/// Status is a fact, not a threshold on the bar: **mastered** only when the
/// backend says every leaf in the area is (`is_mastered`); **learning** once
/// any leaf has real mastery; otherwise **not started**. The design's mock
/// shows a 68 % bar marked "Maîtrisé", which this rule would never produce —
/// a gold pill over a third of the work still undone tells a kid they are
/// finished when they are not.
List<AreaProgress> buildAreaProgress({
  required String subject,
  required List<CachedSkillNode> leaves,
  required List<SkillMasteryDto> masteries,
  required bool english,
}) {
  final masteryOf = {for (final m in masteries) m.skillNodeId: m};
  return [
    for (final group in groupLeavesByArea(
      subject: subject,
      leaves: leaves,
      english: english,
    ))
      () {
        var earned = 0.0;
        var mastered = 0;
        var touched = false;
        for (final leaf in group.leaves) {
          final m = masteryOf[leaf.id];
          if (m == null) continue;
          earned += m.masteryPct / 100;
          if (m.isMastered) mastered++;
          if (m.masteryPct > 0) touched = true;
        }
        final count = group.leaves.length;
        return AreaProgress(
          title: group.title,
          fraction: count == 0 ? 0 : (earned / count).clamp(0.0, 1.0),
          status: count > 0 && mastered == count
              ? AreaStatus.mastered
              : touched
              ? AreaStatus.learning
              : AreaStatus.notStarted,
        );
      }(),
  ];
}
