import '../../data/local_db/database.dart';

/// What the Carte writes under an orb (AM9).
///
/// Content's short kid label (2–4 words) when it has one. Otherwise the
/// curriculum's own statement, trimmed cleanly: its first clause, cut at a
/// word and never mid-word, with no dangling « de » or « et » before the
/// ellipsis. « par ordre croissant ou dé… » becomes « par ordre croissant… ».
/// The full statement stays where it belongs, in the parent's reports.
String kidLabel(CachedSkillNode leaf, {required bool english}) {
  final short = english ? leaf.shortLabelEn : leaf.shortLabelFr;
  if (short != null && short.trim().isNotEmpty) return short.trim();
  // A missing English label is a content gap, not a reason to show
  // nothing — fall back to French.
  final full = english && leaf.labelEn.isNotEmpty ? leaf.labelEn : leaf.labelFr;
  return trimLabel(full);
}

/// About two caption lines under an orb, at the phone size.
const kidLabelMaxChars = 24;

// French then English. « à » is escaped: accented literals belong in
// strings.dart (i18n_coverage_test), and this is grammar, not copy.
const _dangling = {
  '\u00e0', 'au', 'aux', 'de', 'des', 'du', 'd', 'en', 'et', 'la', 'le', //
  'les', 'l', 'ou', 'par', 'pour', 'un', 'une', 'sur', 'avec', 'dans', //
  'a', 'an', 'and', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'with',
};

String trimLabel(String full, {int maxChars = kidLabelMaxChars}) {
  var text = full.trim().replaceAll(RegExp(r'\s+'), ' ');
  // First clause, if it says something on its own (two words or more).
  final clause = RegExp(r'\s*[,;:(]|\s[–—-]\s').firstMatch(text);
  if (clause != null) {
    final head = text.substring(0, clause.start).trim();
    if (head.split(' ').length >= 2) text = head;
  }
  if (text.length <= maxChars) return text;

  final words = text.split(' ');
  final kept = <String>[];
  var length = 0;
  for (final word in words) {
    final next = length == 0 ? word.length : length + 1 + word.length;
    if (next > maxChars) break;
    kept.add(word);
    length = next;
  }
  while (kept.length > 1 && _isDangling(kept.last)) {
    kept.removeLast();
  }
  // One word longer than the budget: keep it whole and let the caption
  // wrap, rather than cut it.
  if (kept.isEmpty) return '${words.first}…';
  return '${kept.join(' ')}…';
}

bool _isDangling(String word) {
  final bare = word.toLowerCase().replaceAll(RegExp(r"['’]$"), '');
  return _dangling.contains(bare) || word.endsWith("'") || word.endsWith('’');
}
