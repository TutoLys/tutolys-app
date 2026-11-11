import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/features/home/village3d/village_channel_io.dart';

/// The native WebView channels (ADR 0127). The WebViews themselves can't
/// run on the VM; what can is checked here.
void main() {
  test('no scene under flutter test, on any platform', () {
    expect(villageScenePlatform, isFalse);
    expect(createVillageSceneChannel(title: 'Village'), isNull);
  });

  test('a message reaches the scene as one JSON string, never as code', () {
    final message = {
      'v': 1,
      'type': 'update',
      'greeting': "');alert(1);//\"</script> ",
    };
    final script = villageReceiveScript(message);
    expect(
      script,
      startsWith('window.villageReceive && window.villageReceive("'),
    );
    expect(script, endsWith('")'));
    final literal = script.substring(
      'window.villageReceive && window.villageReceive('.length,
      script.length - 1,
    );
    // The argument is a single JSON string literal holding the message.
    expect(jsonDecode(jsonDecode(literal) as String), message);
  });
}
