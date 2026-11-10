import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/root_cover_observer.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/features/home/village3d/village_bridge.dart';
import 'package:tutolys_app/features/home/village3d/village_channel.dart';
import 'package:tutolys_app/features/home/village3d/village_scene_host.dart';
import 'package:tutolys_app/features/home/village3d/village_strings.dart';
import 'package:tutolys_app/features/home/village_scene.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';
import 'package:village_webview_linux/village_webview_linux.dart';

/// The 3D village on Linux, live (ADR 0126): the real WebKitGTK view, the
/// real loopback server and the bundled scene, driven through the app's own
/// host. Run with `flutter test integration_test/village3d_linux_test.dart
/// -d linux`.
class _Channel implements VillageSceneChannel {
  _Channel(this.view) {
    view.messages.listen((m) {
      if (m is Map) types.add('${m['type']}');
      if (m is Map && m['type'] == 'perf') fps = (m['fps'] as num).toDouble();
    });
  }

  final LinuxVillageView view;
  final types = <String>[];
  final sent = <String>[];
  double? fps;

  @override
  Stream<Object?> get messages => view.messages;
  @override
  void send(Map<String, Object?> message) {
    sent.add('${message['type']}');
    view.send(message);
  }
  @override
  Widget buildView() => view.build();
  @override
  bool get drawsAboveFlutter => true;
  @override
  void setInteractive(bool on) {}
  @override
  void dispose() => view.dispose();
}

class _Settings extends SettingsController {
  @override
  AppSettings build() => const AppSettings(village3d: true);
}

Future<Object?> _js(LinuxVillageView view, String script) async {
  Object? r = await view.evaluate(script);
  // WebKit hands a returned string back JSON-quoted.
  for (var i = 0; i < 2 && r is String; i++) {
    try {
      r = jsonDecode(r);
    } on FormatException {
      break;
    }
  }
  return r;
}

Future<Map> _stats(LinuxVillageView view) async =>
    await _js(view, 'JSON.stringify(window.village.stats())') as Map;

Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the 3D village runs on Linux', (tester) async {
    final view = LinuxVillageView(title: 'Village des Lys');
    final channel = _Channel(view);
    final opened = <String>[];
    final visible = ValueNotifier(true);
    final t = Strings.fr;
    final buildings = [
      for (final b in villageBuildings(t))
        b.withProgress(switch (b.subject) {
          'MATH' => 0.62,
          'FR' => 0.02,
          _ => null,
        }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(_Settings.new),
          villageScenePlatformProvider.overrideWithValue(true),
          villageSceneChannelFactoryProvider.overrideWithValue(
            ({required String title}) => channel,
          ),
        ],
        child: MaterialApp(
          navigatorObservers: [rootCoverObserver],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, shown, _) => Visibility(
                visible: shown,
                maintainState: true,
                child: VillageSceneHost(
                  state: VillageSceneState(
                    buildings: buildings,
                    lang: 'fr',
                    signTitle: t.villageSignTitle,
                    signSubtitle: '1re année',
                    greeting: 'Salut ! 3 quêtes t’attendent aujourd’hui',
                    reduced: false,
                    strings: village3dStrings(t),
                  ),
                  onOpen: opened.add,
                  fallback: const ColoredBox(
                    key: ValueKey('fallback-2d'),
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. It loads: loading, init, ready, then perf.
    for (var i = 0; i < 600 && !channel.types.contains('perf'); i++) {
      await _wait(tester, const Duration(milliseconds: 100));
    }
    debugPrint('village3d linux: messages ${channel.types}, fps ${channel.fps}');
    expect(channel.types, containsAllInOrder(['loading', 'ready', 'perf']));
    expect(find.byKey(const ValueKey('fallback-2d')), findsNothing);

    // 2. The real figures reached the pills.
    final pills = await _js(
      view,
      "JSON.stringify([...document.querySelectorAll('.scene-pill')].map(p => p.textContent.trim()))",
    );
    debugPrint('village3d linux: pills $pills');
    expect(pills.toString(), contains('2/100'));
    expect(pills.toString(), contains('62/100'));

    // 3. A tap on a pill opens that subject.
    await _js(
      view,
      "[...document.querySelectorAll('.scene-pill')].find(p => p.textContent.includes('Math')).click(); 'ok'",
    );
    await _wait(tester, const Duration(milliseconds: 600));
    expect(opened, ['MATH']);

    // 4. Hidden behind another tab: paused.
    visible.value = false;
    await _wait(tester, const Duration(milliseconds: 600));
    final a = await _stats(view);
    await _wait(tester, const Duration(seconds: 1));
    final b = await _stats(view);
    debugPrint('village3d linux: hidden $a -> $b');
    expect(b['running'], isFalse);
    expect(b['frames'], a['frames']);
    visible.value = true;
    await _wait(tester, const Duration(seconds: 1));
    expect((await _stats(view))['running'], isTrue);
    expect(channel.sent, containsAllInOrder(['init', 'pause', 'resume']));

    // 5. A dialog: the native view is lifted off screen and paused.
    final context = tester.element(find.byType(VillageSceneHost));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('NIP')),
      ),
    );
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('fallback-2d')), findsOneWidget);
    expect(find.byKey(const ValueKey('village-3d-view')), findsNothing);
    expect(channel.sent.last, 'pause');
    Navigator.of(context, rootNavigator: true).pop();
    await _wait(tester, const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('village-3d-view')), findsOneWidget);
    final c = await _stats(view);
    debugPrint('village3d linux: after dialog $c, sent ${channel.sent}');
    expect(c['running'], isTrue);
    expect(channel.types.where((t) => t == 'unavailable'), isEmpty);
  });
}
