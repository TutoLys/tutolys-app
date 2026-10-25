import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';
import 'learning_areas.dart';
import 'skill_path.dart';

/// One titled stretch of path: a learning area and its leaves, in order.
class PathSection {
  const PathSection({required this.title, required this.nodes});

  /// Null for leaves whose strand no known area claims.
  final String? title;
  final List<PathNode> nodes;
}

/// Lays a subject's leaves out as the Carte draws them.
///
/// Every state is real or absent:
/// - **mastered** — the backend says so (`is_mastered`, ADR 0009's 80% rule).
/// - **active** — the first playable, unmastered node in path order: where
///   the kid is. Exactly one per subject, which is what lets the mascot and
///   the "Continuer" card mean something.
/// - **available** — playable, unmastered, further along.
/// - **locked** — nothing synced to play yet. That is the only real reason a
///   node is closed today; nothing gates on order.
List<PathSection> buildCarteSections({
  required String subject,
  required List<CachedSkillNode> leaves,
  required Set<String> playable,
  required List<SkillMasteryDto> masteries,
  required bool english,
}) {
  final areas = learningAreas[subject] ?? const <LearningArea>[];
  final areaOfStrand = <String, int>{
    for (var i = 0; i < areas.length; i++)
      for (final strand in areas[i].strands) strand: i,
  };

  // -1 collects leaves no area claims; it goes last, untitled.
  final groups = <int, List<CachedSkillNode>>{};
  for (final leaf in leaves) {
    final strand = strandOf(leaf.stableKey);
    final area = strand == null ? -1 : (areaOfStrand[strand] ?? -1);
    groups.putIfAbsent(area, () => []).add(leaf);
  }

  final masteryOf = {for (final m in masteries) m.skillNodeId: m};
  var frontierTaken = false;

  final order = groups.keys.toList()
    ..sort((a, b) => a == -1 ? 1 : (b == -1 ? -1 : a.compareTo(b)));

  return [
    for (final area in order)
      PathSection(
        title: area == -1
            ? null
            : (english ? areas[area].labelEn : areas[area].labelFr),
        nodes: [
          for (final leaf in groups[area]!
            ..sort((a, b) => naturalCompare(a.stableKey, b.stableKey)))
            () {
              final mastery = masteryOf[leaf.id];
              final PathNodeState state;
              if (mastery?.isMastered ?? false) {
                state = PathNodeState.mastered;
              } else if (!playable.contains(leaf.id)) {
                state = PathNodeState.locked;
              } else if (!frontierTaken) {
                frontierTaken = true;
                state = PathNodeState.active;
              } else {
                state = PathNodeState.available;
              }
              return PathNode(
                id: leaf.id,
                // A missing English label is a content gap, not a reason to
                // show nothing — fall back to French.
                label: english && leaf.labelEn.isNotEmpty
                    ? leaf.labelEn
                    : leaf.labelFr,
                state: state,
                masteryPct: mastery == null ? null : mastery.masteryPct / 100,
              );
            }(),
        ],
      ),
  ];
}

/// Orders `o:2` before `o:10`, which a plain string compare gets backwards —
/// and objective order is the curriculum's own order through a strand.
int naturalCompare(String a, String b) {
  final chunk = RegExp(r'\d+|\D+');
  final ca = chunk.allMatches(a).map((m) => m.group(0)!).toList();
  final cb = chunk.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final na = int.tryParse(ca[i]);
    final nb = int.tryParse(cb[i]);
    final c = (na != null && nb != null)
        ? na.compareTo(nb)
        : ca[i].compareTo(cb[i]);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}
