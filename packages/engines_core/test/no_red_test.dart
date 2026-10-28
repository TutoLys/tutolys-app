import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design never shows a child red: a mistake is the amber "almost"
/// (retry) state. The legacy engines used `Colors.red` until 2026-10-28.
void main() {
  test('the legacy wrong-answer button is the retry amber', () {
    final style = retryButtonStyle(VillagePalette.light);
    expect(
      style.backgroundColor!.resolve(const {}),
      VillagePalette.light.retryPale,
    );
    expect(style.side!.resolve(const {})!.color, VillagePalette.light.retry);
  });

  test('no engine paints with red', () {
    final red = RegExp(r'Colors\.(red|redAccent|pink)\b');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (red.hasMatch(line)) '${f.path}:${i + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
