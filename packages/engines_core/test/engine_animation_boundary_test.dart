import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An engine never animates a moment or a character in its own widget
/// (plan PLAN_GRADES_2_6_ENGINES §3.1, fix 7). It emits the moment as a
/// runtime event, and the shell or the animation director draws it.
///
/// What an engine may still tween is its own board geometry, and only the
/// files below, each reviewed: the reason is the review.
const _allowed = {
  // The beam tilting to the side that's heavier: the scale's state.
  'balance_scale/balance_scale_engine.dart': 'TweenAnimationBuilder',
  // Where on the grid the walker stands. Who walks is BoardActor's.
  'path_planner/path_planner_engine.dart': 'AnimatedPositioned',
};

/// Folders under lib/src that aren't engines: the shell and shared widgets
/// are where the drawing of moments lives.
const _notEngines = {'shell', 'widgets'};

final _animation = RegExp(
  r'\b(AnimationController|TweenAnimationBuilder|Animated[A-Z]\w*)\b',
);

void main() {
  test('engines animate no moment or character themselves', () {
    final src = Directory('lib/src');
    final offenders = <String>[];
    var engines = 0;
    for (final dir in src.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (_notEngines.contains(name)) continue;
      engines++;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.substring(src.path.length + 1);
        final lines = f.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          final code = line.split('//').first;
          for (final m in _animation.allMatches(code)) {
            if (_allowed[rel] == m.group(1)) continue;
            offenders.add('$rel:${i + 1} ${m.group(1)}');
          }
        }
      }
    }
    expect(engines, greaterThan(20), reason: 'engine folders not found');
    expect(
      offenders,
      isEmpty,
      reason:
          'emit a RuntimeEvent (RevealEvent, an InteractionEvent) instead, '
          'or, for board geometry only, add a reviewed entry to _allowed',
    );
  });
}
