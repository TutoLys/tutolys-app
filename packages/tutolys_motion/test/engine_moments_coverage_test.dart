import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

/// Every interaction an engine emits must mean something to the motion
/// layer (plan PLAN_GRADES_2_6_ENGINES §3.3, fix 6). A new wire name that
/// isn't in [interactionMoments] would reach the director as noise, and
/// the future animation system would never react to it.
///
/// Read from the sources, not trusted to review: every quoted name in an
/// `InteractionEvent(` call, including both arms of a ternary.
void main() {
  test('every engine interaction name has a moment', () {
    final root = Directory('../engines_core/lib/src');
    expect(root.existsSync(), isTrue, reason: 'engines_core moved?');
    final call = RegExp(r'InteractionEvent\(\s*([^{,]*)');
    final quoted = RegExp(r"'([a-z_]+)'");
    final names = <String, String>{};
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        for (final q in quoted.allMatches(m.group(1)!)) {
          names[q.group(1)!] = f.path;
        }
      }
    }
    // A vacuous pass would hide a regex that stopped matching.
    expect(names.keys, containsAll(['option_selected', 'item_placed']));
    final missing = {
      for (final MapEntry(:key, :value) in names.entries)
        if (momentOf(key) == null) key: value,
    };
    expect(missing, isEmpty, reason: 'add these to interactionMoments');
  });
}
