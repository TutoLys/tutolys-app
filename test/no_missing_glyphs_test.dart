import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Baloo 2 has no "→": typed into visible text, the web build drew a box
/// offline (A12). Arrows are drawn with `ArrowLabel`, as an icon.
void main() {
  test('no visible string uses an arrow Baloo 2 lacks', () {
    final lines = File('lib/core/i18n/strings.dart').readAsLinesSync();
    final offenders = [
      for (final (i, line) in lines.indexed)
        if (!line.trimLeft().startsWith('//') && line.contains('→'))
          '${i + 1}: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });
}
