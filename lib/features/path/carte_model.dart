import 'package:flutter/widgets.dart' show Locale;

import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';
import 'kid_label.dart';
import 'learning_areas.dart';
import 'skill_path.dart';
import 'subject_language.dart';

/// One titled stretch of path: a learning area and its leaves, in order.
class PathSection {
  const PathSection({required this.title, required this.nodes});

  /// Null for leaves whose strand no known area claims.
  final String? title;
  final List<PathNode> nodes;
}

/// A learning area's leaves, in curriculum order.
class AreaGroup {
  const AreaGroup({required this.title, required this.leaves});

  /// Null for leaves whose strand no known area claims.
  final String? title;
  final List<CachedSkillNode> leaves;
}

/// Groups a subject's leaves by PFEQ learning area, in the ministry's order.
/// Inside an area, strands follow the map's own order, and leaves follow
/// their `stable_key` within a strand. Sorting the whole area by key put
/// strands in alphabetical order, so math opened on "opérations" instead of
/// "sens et écriture des nombres" (Hafid, 2026-10-25). Leaves no area claims
/// come last, untitled. Shared by the Carte and Progrès so their titles
/// always agree.
///
/// When the curriculum endpoint sent document order and areas (backend ADR
/// 0044), those are used instead: areas in document order, titled with the
/// document's own labels, leaves by `doc_order`. That covers what the table
/// can't (français beyond "Écrire", CCQ). The table stays as the fallback
/// for a cache filled by an older backend.
List<AreaGroup> groupLeavesByArea({
  required String subject,
  required List<CachedSkillNode> leaves,
  required bool english,
}) {
  if (leaves.isNotEmpty && leaves.every((l) => l.docOrder != null)) {
    return _groupByServerAreas(leaves, english: english);
  }
  final areas = learningAreas[subject] ?? const <LearningArea>[];
  final areaOfStrand = <String, int>{
    for (var i = 0; i < areas.length; i++)
      for (final strand in areas[i].strands) strand: i,
  };
  // The strand's position in the maps, which list them in ministry order.
  final rankOfStrand = <String, int>{
    for (final (i, strand) in [
      for (final area in areas) ...area.strands,
    ].indexed)
      strand: i,
  };
  int byStrandThenKey(CachedSkillNode a, CachedSkillNode b) {
    final ra = rankOfStrand[strandOf(a.stableKey)] ?? rankOfStrand.length;
    final rb = rankOfStrand[strandOf(b.stableKey)] ?? rankOfStrand.length;
    return ra != rb
        ? ra.compareTo(rb)
        : naturalCompare(a.stableKey, b.stableKey);
  }

  // -1 collects leaves no area claims; it goes last, untitled.
  final groups = <int, List<CachedSkillNode>>{};
  for (final leaf in leaves) {
    final strand = strandOf(leaf.stableKey);
    final area = strand == null ? -1 : (areaOfStrand[strand] ?? -1);
    groups.putIfAbsent(area, () => []).add(leaf);
  }

  final order = groups.keys.toList()
    ..sort((a, b) => a == -1 ? 1 : (b == -1 ? -1 : a.compareTo(b)));

  return [
    for (final area in order)
      AreaGroup(
        title: area == -1
            ? null
            : (english ? areas[area].labelEn : areas[area].labelFr),
        leaves: groups[area]!..sort(byStrandThenKey),
      ),
  ];
}

List<AreaGroup> _groupByServerAreas(
  List<CachedSkillNode> leaves, {
  required bool english,
}) {
  final sorted = [...leaves]
    ..sort((a, b) => a.docOrder!.compareTo(b.docOrder!));
  // Keyed by the area's position; a leaf with no area (its parent was
  // archived) goes last, untitled, rather than vanishing.
  final groups = <int, List<CachedSkillNode>>{};
  final titles = <int, String>{};
  for (final leaf in sorted) {
    final fr = leaf.areaLabelFr;
    final key = fr == null ? -1 : (leaf.areaOrdinal ?? 0);
    groups.putIfAbsent(key, () => []).add(leaf);
    if (fr != null) {
      final en = leaf.areaLabelEn ?? '';
      titles.putIfAbsent(key, () => english && en.isNotEmpty ? en : fr);
    }
  }
  final order = groups.keys.toList()
    ..sort((a, b) => a == -1 ? 1 : (b == -1 ? -1 : a.compareTo(b)));
  return [
    for (final key in order)
      AreaGroup(title: titles[key], leaves: groups[key]!),
  ];
}

/// Lays a subject's leaves out as the Carte draws them.
///
/// Every state is real or absent:
/// - **mastered** — the backend says so (`is_mastered`, ADR 0009's 80% rule).
/// - **completed** — the kid finished every lesson on it on this device
///   ([completed], from `nodeProgressProvider`). Immediate, unlike mastery,
///   which waits on telemetry and a scheduled job. Never shown as mastered,
///   and it counts toward no percentage: those stay the server's.
/// - **active** — the first playable node neither mastered nor completed, in
///   path order: where the kid is. Exactly one per subject, which is what
///   lets the mascot and the "Continuer" card mean something.
/// - **locked** — after the active node. Unlocking is strictly sequential
///   (ADR 0032): a node opens only once every playable node before it is
///   done, so "if the game is not done, we don't go to the next" (Hafid,
///   2026-10-25). That holds for a node already completed or mastered too:
///   past the frontier, nothing opens.
/// - **not downloaded** — not a state but a flag on an open node: its
///   lesson is published but outside the offline window (ADR 0095). Drawn
///   only while [offline], when a tap can't fetch it.
/// - **soon** — no lesson published for it yet. Not locked and not a
///   step in the sequence: it is skipped, so a missing lesson never looks
///   like the reason the kid is stuck.
List<PathSection> buildCarteSections({
  required String subject,
  required List<CachedSkillNode> leaves,
  required Set<String> playable,
  required List<SkillMasteryDto> masteries,
  required Locale appLocale,
  Set<String> completed = const {},
  Map<String, String> lessonLocales = const {},
  Map<String, (int done, int total)> lessonCounts = const {},
  Set<String> assigned = const {},
  Set<String> notDownloaded = const {},
  bool offline = false,
  String Function(String locale)? describeLanguage,
  String Function(int done, int total)? describeLessons,
  String? Function(PathNodeState state)? describeState,
  String? describeNotDownloaded,
}) {
  final asked = contentLocaleFor(subject, appLocale);
  final masteryOf = {for (final m in masteries) m.skillNodeId: m};
  final english = appLocale.languageCode == 'en';
  // Français and English keep their own language's skill names whatever
  // the app is set to (subject_language.dart).
  final englishLabels = showsEnglishLabels(subject, appLocale);
  var frontierTaken = false;

  return _lessonsFirst([
    for (final group in groupLeavesByArea(
      subject: subject,
      leaves: leaves,
      english: english,
    ))
      PathSection(
        title: group.title,
        nodes: [
          for (final leaf in group.leaves)
            () {
              final mastery = masteryOf[leaf.id];
              final PathNodeState state;
              final mastered = mastery?.isMastered ?? false;
              // Mastered with nothing to replay still shows mastered; finished
              // with nothing to replay can't be played, so it is "soon".
              if (!playable.contains(leaf.id) && !mastered) {
                state = PathNodeState.soon;
              } else if (frontierTaken) {
                // Past the frontier nothing opens, whatever it once was:
                // a node finished out of order on an older build, or
                // mastered on the server, waits its turn like the rest.
                state = PathNodeState.locked;
              } else if (mastered) {
                state = PathNodeState.mastered;
              } else if (completed.contains(leaf.id)) {
                state = PathNodeState.completed;
              } else {
                frontierTaken = true;
                state = PathNodeState.active;
              }
              // A node shown as done never reads short ("0/2" under a
              // gold check): server mastery can arrive for lessons this
              // device never finished, and then the counter is left out.
              final counts = switch (lessonCounts[leaf.id]) {
                (final done, final total)
                    when total > 1 &&
                        !(state == PathNodeState.mastered && done < total) =>
                  (done, total),
                _ => null,
              };
              return PathNode(
                id: leaf.id,
                // Content's short kid label, or the statement trimmed at
                // a word (AM9).
                label: kidLabel(leaf, english: englishLabels),
                fullStatement: switch (fullLabel(
                  leaf,
                  english: englishLabels,
                )) {
                  final full
                      when full != kidLabel(leaf, english: englishLabels) =>
                    full,
                  _ => null,
                },
                state: state,
                masteryPct: mastery == null ? null : mastery.masteryPct / 100,
                // Only worth showing when there is more than one lesson.
                lessons: counts,
                stateLabel:
                    offline &&
                        isOpenState(state) &&
                        notDownloaded.contains(leaf.id)
                    ? describeNotDownloaded
                    : describeState?.call(state),
                lessonsLabel: switch (counts) {
                  (final done, final total) => describeLessons?.call(
                    done,
                    total,
                  ),
                  null => null,
                },
                // Open teacher-assigned work on this skill (backend ADR 0123).
                assigned: assigned.contains(leaf.id),
                // Past the frontier a node is locked whether or not it's
                // downloaded; the tag only marks one a kid could open.
                notDownloaded:
                    offline &&
                    isOpenState(state) &&
                    notDownloaded.contains(leaf.id),
                otherLanguage: _otherLanguage(lessonLocales[leaf.id], asked),
                otherLanguageLabel:
                    _otherLanguage(lessonLocales[leaf.id], asked) == null
                    ? null
                    : describeLanguage?.call(lessonLocales[leaf.id]!),
              );
            }(),
        ],
      ),
  ]);
}

/// Puts what a kid can play ahead of what is coming (K10). Inside a
/// section, `soon` nodes move after the rest; sections made only of `soon`
/// nodes move after every section that has a lesson. Unlocking already
/// skips `soon` (ADR 0032), so the order of everything else, and so which
/// node is active, doesn't change. Without this, French (FLS) opened on 20+
/// hourglasses in "Stratégies" with its only lesson four screens down.
List<PathSection> _lessonsFirst(List<PathSection> sections) {
  bool isSoon(PathNode n) => n.state == PathNodeState.soon;
  final withLessons = <PathSection>[];
  final comingSoon = <PathSection>[];
  for (final section in sections) {
    if (section.nodes.every(isSoon)) {
      comingSoon.add(section);
    } else {
      withLessons.add(
        PathSection(
          title: section.title,
          nodes: [
            ...section.nodes.where((n) => !isSoon(n)),
            ...section.nodes.where(isSoon),
          ],
        ),
      );
    }
  }
  return [...withLessons, ...comingSoon];
}

/// `'FR'` when a lesson came back in French though English was asked for
/// (and the reverse); null when it is in the language asked for.
String? _otherLanguage(String? lessonLocale, String asked) {
  if (lessonLocale == null) return null;
  final lesson = lessonLocale.split('-').first;
  return lesson == asked.split('-').first ? null : lesson.toUpperCase();
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

/// The node the Carte scrolls to: the active one, or once every node is
/// done, the last one reached. Null when nothing is open yet.
String? focusNodeIdOf(List<PathSection> sections) {
  String? lastOpen;
  for (final section in sections) {
    for (final node in section.nodes) {
      if (node.state == PathNodeState.active) return node.id;
      if (isOpenState(node.state)) lastOpen = node.id;
    }
  }
  return lastOpen;
}
