import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';

/// The Carte's « Révision » row (OW3, Hafid 2026-10-31; ADR 0111): skills
/// the kid's own data says to go back to, at most [reviewCapPerSubject] per
/// subject, in a row of their own rather than inline, so a review never
/// reads as being sent back.
///
/// Evidence only: a skill qualifies when the backend's §5.9 classifier
/// (backend ADR 0010) marks it `struggling` or `watch`. The app never
/// guesses that from scores itself; the thresholds are server config. With
/// no status served, the row doesn't show.
const reviewCapPerSubject = 3;

/// The classifier's statuses that mean "go back to this one".
const reviewStatuses = {'struggling', 'watch'};

/// This subject's review skills, worst first: `struggling` before `watch`,
/// then the lower mastery. Only skills in [leaves] with a lesson to play
/// ([playable]), so a tap always opens a game.
List<CachedSkillNode> reviewLeaves({
  required List<SkillMasteryDto> masteries,
  required List<CachedSkillNode> leaves,
  required Set<String> playable,
  int cap = reviewCapPerSubject,
}) {
  final byId = {for (final l in leaves) l.id: l};
  final due = [
    for (final m in masteries)
      if (reviewStatuses.contains(m.status) &&
          !m.isMastered &&
          byId.containsKey(m.skillNodeId) &&
          playable.contains(m.skillNodeId))
        m,
  ];
  due.sort((a, b) {
    final rank = (a.status == 'struggling' ? 0 : 1).compareTo(
      b.status == 'struggling' ? 0 : 1,
    );
    if (rank != 0) return rank;
    final pct = a.masteryPct.compareTo(b.masteryPct);
    return pct != 0 ? pct : a.skillNodeId.compareTo(b.skillNodeId);
  });
  return [for (final m in due.take(cap)) byId[m.skillNodeId]!];
}
