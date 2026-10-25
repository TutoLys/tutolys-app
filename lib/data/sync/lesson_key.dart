/// Which lesson an exercise is one language version of.
///
/// A lesson can exist in several languages, each its own exercise. The
/// backend sends `lesson_group` on every envelope and manifest entry: the
/// same value for every language version of one lesson, never null (an
/// untranslated lesson is a group of one, its own exercise id).
///
/// The fallback, (node, engine, rank), only covers exercises cached before
/// the backend sent the field; the next sync replaces them, since adding it
/// changed every content hash. It is the backend's own uniqueness key, so
/// even then two distinct exercises never merge. Ranking by (node, rank)
/// alone used to hide one of two lessons that shared a rank (QA D10).
String lessonKey({
  required String skillNodeId,
  required String engineKey,
  required int rank,
  String? lessonGroup,
}) => lessonGroup != null && lessonGroup.isNotEmpty
    ? 'group:$skillNodeId:$lessonGroup'
    : 'key:$skillNodeId:$engineKey:$rank';

/// [lessonKey] for a content envelope.
String lessonKeyOf(Map<String, Object?> envelope) => lessonKey(
  skillNodeId: envelope['skill_node_id'] as String,
  engineKey: envelope['engine_key'] as String,
  rank: envelope['rank'] as int,
  lessonGroup: envelope['lesson_group'] as String?,
);
