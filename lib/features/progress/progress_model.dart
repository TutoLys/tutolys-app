import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';
import '../path/carte_model.dart';
import 'local_progress.dart';

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

  /// 0..1 — the mean over every leaf in the area at the kid's grade of its
  /// shown progress (server mastery or local lessons, whichever is further,
  /// ADR 0032), the same rule the Village uses per subject.
  final double fraction;

  final AreaStatus status;
}

/// Progrès rows for one subject, titled exactly as the Carte titles its
/// stretches (both go through [groupLeavesByArea]).
///
/// Status is a fact, not a threshold on the bar: **mastered** only when the
/// backend says every leaf in the area is (`is_mastered`); **learning** once
/// any leaf has real mastery or a finished lesson; otherwise **not
/// started**. The design's mock
/// shows a 68 % bar marked "Maîtrisé", which this rule would never produce —
/// a gold pill over a third of the work still undone tells a kid they are
/// finished when they are not.
List<AreaProgress> buildAreaProgress({
  required String subject,
  required List<CachedSkillNode> leaves,
  required List<SkillMasteryDto> masteries,
  required bool english,
  Map<String, double> local = const {},
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
          final shown = shownNodeProgress(
            masteryPct: m?.masteryPct,
            local: local[leaf.id],
          );
          if (shown == null) continue;
          earned += shown;
          if (m?.isMastered ?? false) mastered++;
          if (shown > 0) touched = true;
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
