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
  return trimLabel(fullLabel(leaf, english: english));
}

/// The skill's whole statement, what a screen reader says. A missing
/// English label is a content gap, not a reason to say nothing — French.
String fullLabel(CachedSkillNode leaf, {required bool english}) =>
    english && leaf.labelEn.isNotEmpty ? leaf.labelEn : leaf.labelFr;

/// About two caption lines under an orb, at the phone size.
const kidLabelMaxChars = 24;

// French then English. « à » is escaped: accented literals belong in
// strings.dart (i18n_coverage_test), and this is grammar, not copy.
const _dangling = {
  '\u00e0', 'au', 'aux', 'de', 'des', 'du', 'd', 'en', 'et', 'la', 'le', //
  'les', 'l', 'ou', 'par', 'pour', 'un', 'une', 'sur', 'avec', 'dans', //
  'non', 'ne', 'ni', 'qu', 'que', 'qui', 'se', 'sa', 'son', 'ses', 'ce', //
  'cette', 'ces', 'leur', 'leurs', 'entre', 'vers', 'sans', 'selon', //
  'a', 'an', 'and', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'with',
  'not', 'its', 'their', 'from', 'as', 'at',
};

/// An elided article or pronoun glued to the next word: « d’un », « l’ »,
/// « qu’ », « jusqu’à ». Its second half decides whether it dangles.
final _elision = RegExp(r"^(?:d|l|qu|jusqu|n|s|c|j)['’](.*)$");

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
  // An unclosed « ( » opens an aside the cut can't finish: drop it whole.
  final open = kept.indexWhere((w) => w.contains('(') && !w.contains(')'));
  if (open > 0) kept.removeRange(open, kept.length);
  // Then no trailing comma or colon, and no word that only leads into
  // the next one (« d’un », « non », « de »), until the end is stable.
  var changed = true;
  while (changed && kept.isNotEmpty) {
    changed = false;
    final bare = kept.last.replaceAll(RegExp(r'[,;:(]+$'), '');
    if (bare != kept.last) {
      changed = true;
      if (bare.isEmpty) {
        kept.removeLast();
      } else {
        kept[kept.length - 1] = bare;
      }
    }
    if (kept.length > 1 && _isDangling(kept.last)) {
      kept.removeLast();
      changed = true;
    }
  }
  // One word longer than the budget: keep it whole and let the caption
  // wrap, rather than cut it.
  if (kept.isEmpty) return '${words.first}…';
  return '${kept.join(' ')}…';
}

bool _isDangling(String word) {
  final lower = word.toLowerCase();
  final elided = _elision.firstMatch(lower);
  if (elided != null) {
    final rest = elided.group(1)!;
    return rest.isEmpty || _dangling.contains(rest);
  }
  return _dangling.contains(lower);
}
