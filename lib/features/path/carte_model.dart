import 'package:flutter/widgets.dart' show Locale;

import '../../data/api/progress_api.dart';
import '../../data/local_db/database.dart';
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

/// Groups a subject's leaves by PFEQ learning area, in the ministry's order,
/// each sorted by its `stable_key`. Leaves no area claims come last,
/// untitled. Shared by the Carte and Progrès so their titles always agree.
List<AreaGroup> groupLeavesByArea({
  required String subject,
  required List<CachedSkillNode> leaves,
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

  final order = groups.keys.toList()
    ..sort((a, b) => a == -1 ? 1 : (b == -1 ? -1 : a.compareTo(b)));

  return [
    for (final area in order)
      AreaGroup(
        title: area == -1
            ? null
            : (english ? areas[area].labelEn : areas[area].labelFr),
        leaves: groups[area]!
          ..sort((a, b) => naturalCompare(a.stableKey, b.stableKey)),
      ),
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
  String Function(String locale)? describeLanguage,
  String Function(int done, int total)? describeLessons,
  String? Function(PathNodeState state)? describeState,
}) {
  final asked = contentLocaleFor(subject, appLocale);
  final masteryOf = {for (final m in masteries) m.skillNodeId: m};
  final english = appLocale.languageCode == 'en';
  // Français and English keep their own language's skill names whatever
  // the app is set to (subject_language.dart).
  final englishLabels = showsEnglishLabels(subject, appLocale);
  var frontierTaken = false;

  return [
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
              return PathNode(
                id: leaf.id,
                // A missing English label is a content gap, not a reason to
                // show nothing — fall back to French.
                label: englishLabels && leaf.labelEn.isNotEmpty
                    ? leaf.labelEn
                    : leaf.labelFr,
                state: state,
                masteryPct: mastery == null ? null : mastery.masteryPct / 100,
                // Only worth showing when there is more than one lesson.
                lessons: switch (lessonCounts[leaf.id]) {
                  (final done, final total) when total > 1 => (done, total),
                  _ => null,
                },
                stateLabel: describeState?.call(state),
                lessonsLabel: switch (lessonCounts[leaf.id]) {
                  (final done, final total) when total > 1 =>
                    describeLessons?.call(done, total),
                  _ => null,
                },
                otherLanguage: _otherLanguage(lessonLocales[leaf.id], asked),
                otherLanguageLabel:
                    _otherLanguage(lessonLocales[leaf.id], asked) == null
                    ? null
                    : describeLanguage?.call(lessonLocales[leaf.id]!),
              );
            }(),
        ],
      ),
  ];
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
