/// Which lesson an exercise is one language version of.
///
/// A lesson can exist in several languages, each its own exercise. The
/// backend's `translation_group` names the lesson outright when it is sent.
/// Without it, the fallback is the backend's own uniqueness key, (node,
/// engine, rank): two distinct exercises never share it, so neither is ever
/// hidden, while a translation, which keeps all three, still pairs with its
/// original. Ranking by (node, rank) alone used to hide one of two lessons
/// on a node that shared a rank across engines (QA D10).
String lessonKey({
  required String skillNodeId,
  required String engineKey,
  required int rank,
  String? translationGroup,
}) => translationGroup != null && translationGroup.isNotEmpty
    ? 'group:$skillNodeId:$translationGroup'
    : 'key:$skillNodeId:$engineKey:$rank';

/// [lessonKey] for a content envelope.
String lessonKeyOf(Map<String, Object?> envelope) => lessonKey(
  skillNodeId: envelope['skill_node_id'] as String,
  engineKey: envelope['engine_key'] as String,
  rank: envelope['rank'] as int,
  translationGroup: envelope['translation_group'] as String?,
);
