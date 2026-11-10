import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/root_cover_observer.dart';
import 'package:tutolys_app/data/api/weather_api.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/home/subject_progress.dart';
import 'package:tutolys_app/features/home/subject_strip.dart';
import 'package:tutolys_app/features/home/village3d/village_bridge.dart';
import 'package:tutolys_app/features/home/village3d/village_channel.dart';
import 'package:tutolys_app/features/home/village3d/village_scene_host.dart';
import 'package:tutolys_app/features/home/village3d/village_strings.dart';
import 'package:tutolys_app/features/home/village_scene.dart';
import 'package:tutolys_app/features/home/village_screen.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

/// The 3D village (ADR 0126): which village shows, what crosses the bridge,
/// and that a tap in the scene reaches the Carte.
class FakeChannel implements VillageSceneChannel {
  // Sync, so a message is handled when it is said, as postMessage events
  // are handled before the next frame.
  final inbound = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  var disposed = false;

  List<String> get types => [for (final m in sent) '${m['type']}'];

  void say(Map<String, Object?> message) =>
      inbound.add({'v': villageBridgeVersion, ...message});

  /// BRIDGE.md's start-up: `loading`, the app's `init`, then `ready`.
  void boot() {
    say({'type': 'loading', 'version': 'test', 'bridge': 1});
    say({'type': 'ready', 'version': 'test', 'bridge': 1});
  }

  @override
  Stream<Object?> get messages => inbound.stream;

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  @override
  Widget buildView() => const SizedBox.expand(key: ValueKey('fake-3d'));

  @override
  void dispose() => disposed = true;

  @override
  var drawsAboveFlutter = false;

  bool? interactive;

  @override
  void setInteractive(bool on) => interactive = on;
}

class _Settings extends SettingsController {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> setVillage3d(bool value) async =>
      state = state.copyWith(village3d: value);
  @override
  Future<void> setSkyControls(bool value) async =>
      state = state.copyWith(skyControls: value);
}

final _buildings = villageBuildings(Strings.fr);

VillageSceneState _state({String? greeting = 'Bonjour !'}) => VillageSceneState(
  buildings: _buildings,
  lang: 'fr',
  signTitle: 'Village des Lys',
  signSubtitle: '1re année',
  greeting: greeting,
  reduced: false,
  strings: village3dStrings(Strings.fr),
);

const _fallbackKey = ValueKey('fallback-2d');
final _fallback = find.byKey(_fallbackKey);
final _view = find.byKey(const ValueKey('fake-3d'));
final _pending = find.byKey(const ValueKey('village-3d-pending'));

void main() {
  late FakeChannel channel;
  late int made;

  setUp(() {
    channel = FakeChannel();
    made = 0;
  });

  Widget host({
    VillageSceneState? state,
    bool setting = true,
    bool platform = true,
    ValueChanged<String>? onOpen,
    VoidCallback? onMascot,
    bool visible = true,
    bool sky = false,
  }) => ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(
        () => _Settings(AppSettings(village3d: setting, skyControls: sky)),
      ),
      villageSceneChannelFactoryProvider.overrideWithValue(({
        required String title,
      }) {
        if (!platform) return null;
        made++;
        return channel;
      }),
    ],
    child: MaterialApp(
      home: Visibility(
        visible: visible,
        maintainState: true,
        child: VillageSceneHost(
          state: state ?? _state(),
          onOpen: onOpen,
          onMascot: onMascot,
          fallback: const SizedBox.expand(key: _fallbackKey),
        ),
      ),
    ),
  );

  group('the bridge contract', () {
    test('each scene message parses to its event', () {
      Object? m(Map<String, Object?> x) => {'v': 1, ...x};
      expect(SceneEvent.parse(m({'type': 'loading'})), isA<SceneLoading>());
      expect(SceneEvent.parse(m({'type': 'ready'})), isA<SceneReady>());
      expect(
        SceneEvent.parse(m({'type': 'error', 'message': 'x'})),
        isA<SceneError>(),
      );
      expect(
        SceneEvent.parse(m({'type': 'unavailable', 'reason': 'no webgl'})),
        isA<SceneUnavailable>().having((e) => e.reason, 'reason', 'no webgl'),
      );
      expect(
        SceneEvent.parse(m({'type': 'perf', 'fps': 57})),
        isA<ScenePerf>().having((e) => e.fps, 'fps', 57.0),
      );
      expect(
        SceneEvent.parse(m({'type': 'open', 'id': 'MATH'})),
        isA<SceneOpen>().having((e) => e.id, 'id', 'MATH'),
      );
      expect(
        SceneEvent.parse(m({'type': 'opening', 'id': 'MATH', 'ms': 2400})),
        isA<SceneOpening>().having((e) => e.id, 'id', 'MATH'),
      );
      expect(SceneEvent.parse(m({'type': 'mascot'})), isA<SceneMascot>());
    });

    test('another version, a bad shape or an unknown type does nothing', () {
      for (final raw in <Object?>[
        null,
        'ready',
        {'type': 'ready'},
        {'v': 2, 'type': 'open', 'id': 'MATH'},
        {'v': 1, 'type': 'open'},
        {'v': 1, 'type': 'open', 'id': ''},
        {'v': 1, 'type': 'perf', 'fps': 'fast'},
        {'v': 1, 'type': 'navigate', 'to': '/settings'},
      ]) {
        expect(SceneEvent.parse(raw), isA<SceneIgnored>(), reason: '$raw');
      }
    });

    test(
      'init carries the app words, real progress and null as unmeasured',
      () {
        final state = VillageSceneState(
          buildings: [
            _buildings.first.withProgress(0.4),
            _buildings[1].withProgress(null),
          ],
          lang: 'en',
          signTitle: Strings.en.villageSignTitle,
          signSubtitle: '',
          greeting: null,
          reduced: true,
          strings: village3dStrings(Strings.en),
        );
        final init = HostMessage.init(state);
        expect(init['v'], 1);
        expect(init['type'], 'init');
        expect(init['lang'], 'en');
        expect(init['reduced'], isTrue);
        final sent = init['buildings']! as List;
        expect((sent[0] as Map)['id'], 'MATH');
        expect((sent[0] as Map)['progress'], 0.4);
        expect((sent[1] as Map)['progress'], isNull);
        expect(
          init['strings'],
          containsPair('pill.new', Strings.en.pathNotStarted),
        );
        expect((init['sign']! as Map)['title'], 'Lys Village');
        expect(init['insets'], {'top': 0});
        expect((sent[0] as Map).keys, {
          'id',
          'label',
          'progress',
          'live',
          'soon',
        });
        expect((sent[0] as Map)['soon'], isFalse);
        final noLessons = HostMessage.init(
          VillageSceneState(
            buildings: [_buildings.first.withProgress(null, hasLessons: false)],
            lang: 'fr',
            signTitle: '',
            signSubtitle: '',
            greeting: null,
            reduced: false,
            strings: const {},
          ),
        );
        final soon = (noLessons['buildings']! as List).first as Map;
        expect(soon['soon'], isTrue);
        expect(soon['live'], isTrue, reason: 'still opens its Carte');
      },
    );

    test('the real weather goes over; none clears it', () {
      const snow = VillageWeather(
        condition: 'snow',
        observedAt: '2026-11-10T11:00:00Z',
        tempC: -4.5,
        isDay: true,
      );
      final withWeather = VillageSceneState(
        buildings: const [],
        lang: 'fr',
        signTitle: '',
        signSubtitle: '',
        greeting: null,
        reduced: false,
        strings: const {},
        weather: snow,
      );
      expect(HostMessage.update(withWeather)['weather'], snow.toJson());
      final none = HostMessage.update(
        VillageSceneState(
          buildings: const [],
          lang: 'fr',
          signTitle: '',
          signSubtitle: '',
          greeting: null,
          reduced: false,
          strings: const {},
        ),
      );
      expect(none.containsKey('weather'), isTrue);
      expect(none['weather'], isNull);
    });

    test('all 25 scene strings are sent, in each language', () {
      for (final t in [Strings.fr, Strings.en]) {
        final strings = village3dStrings(t);
        expect(strings.keys.toSet(), village3dStringKeys);
        expect(strings.values.every((v) => v.isNotEmpty), isTrue);
      }
      expect(village3dStrings(Strings.en)['cam.in'], 'Zoom in');
      expect(village3dStrings(Strings.fr)['pill.new'], 'À découvrir');
      // Language buildings keep their language; CCQ follows the app.
      expect(village3dStrings(Strings.en)['sign.francais.1'], 'Écrire');
      expect(village3dStrings(Strings.fr)['sign.anglais.0'], 'Hello');
      expect(village3dStrings(Strings.en)['sign.ccq.0'], 'Living');
    });
  });

  group('sky controls (« Contrôles du ciel »)', () {
    final bar = find.byKey(const ValueKey('village-sky-bar'));
    Map<String, Object?> last(String type) =>
        channel.sent.lastWhere((m) => m['type'] == type);

    test('off by default, and kept per kid with the folds', () async {
      expect(const AppSettings().skyControls, isFalse);
      expect(const AppSettings().questsFolded, isFalse);
      expect(const AppSettings().navFold, 0);

      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final store = AppSettingsStore(db, kidId: 'k');
      const before = AppSettings();
      await store.writeChanges(
        before,
        before.copyWith(skyControls: true, questsFolded: true, navFold: 2),
      );
      final read = await store.read();
      expect(read.skyControls, isTrue);
      expect(read.questsFolded, isTrue);
      expect(read.navFold, 2);
      expect((await AppSettingsStore(db, kidId: 'other').read()).navFold, 0);
    });

    testWidgets('off: no bar and nothing sent about the sky', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      expect(bar, findsNothing);
      expect(channel.types, ['init']);
    });

    testWidgets('on: only on a ready 3D village, never the loader or 2D', (
      tester,
    ) async {
      await tester.pumpWidget(host(sky: true));
      expect(bar, findsNothing, reason: 'still loading');
      channel.boot();
      await tester.pump();
      expect(bar, findsOneWidget);

      channel.say({'type': 'unavailable', 'reason': 'webgl'});
      await tester.pump();
      expect(_fallback, findsOneWidget);
      expect(bar, findsNothing);
    });

    testWidgets('each pick posts its bridge message; En direct posts live', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(sky: true));
      channel.boot();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('sky-season-winter')));
      await tester.pump();
      expect(last('setSeason'), containsPair('season', 'winter'));

      await tester.tap(find.byKey(const ValueKey('sky-weather-snow')));
      await tester.pump();
      expect(last('setWeather'), containsPair('weather', 'snow'));

      // The slider's middle is noon.
      await tester.tap(find.byKey(const ValueKey('sky-hour')));
      await tester.pump();
      expect(last('setTime'), containsPair('hour', 12.0));

      await tester.tap(find.byKey(const ValueKey('sky-live')));
      await tester.pump();
      expect(channel.sent.sublist(channel.sent.length - 3), [
        {'v': 1, 'type': 'setTime', 'hour': null, 'animate': false},
        {'v': 1, 'type': 'setSeason', 'season': 'live'},
        {'v': 1, 'type': 'setWeather', 'weather': 'live'},
      ]);
    });

    testWidgets('switching it off hands the sky back to Québec', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(sky: true));
      channel.boot();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sky-weather-storm')));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VillageSceneHost)),
      );
      await container
          .read(settingsControllerProvider.notifier)
          .setSkyControls(false);
      await tester.pump();
      expect(bar, findsNothing);
      expect(channel.types.sublist(channel.types.length - 3), [
        'setTime',
        'setSeason',
        'setWeather',
      ]);
      expect(last('setWeather'), containsPair('weather', 'live'));
      expect(last('setTime'), containsPair('hour', null));
    });
  });

  group('which village shows', () {
    test('3D is the default; the platform still decides', () {
      // Hafid, 2026-11-10: "implement the 3d village everywhere".
      expect(village3dDefaultOn, isTrue);
      expect(const AppSettings().village3d, isTrue);
      // The VM test runner hosts no scene, so nothing here turns 3D on by
      // accident: every other village test keeps the 2D village.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(villageScenePlatformProvider), isFalse);
    });

    test(
      'an untouched toggle is not stored, so the swap reaches the kid',
      () async {
        final db = LocalDatabase.memory();
        addTearDown(db.close);
        final store = AppSettingsStore(db, kidId: 'k');
        const before = AppSettings();
        await store.writeChanges(before, before.copyWith(volume: 40));
        final rows = await db.select(db.appStateTable).get();
        expect(rows.map((r) => r.key), isNot(contains('settings.village_3d')));

        await store.writeChanges(before, before.copyWith(village3d: true));
        expect((await store.read()).village3d, isTrue);
      },
    );

    testWidgets('no scene on this platform: the 2D village', (tester) async {
      await tester.pumpWidget(host(platform: false));
      expect(_fallback, findsOneWidget);
      expect(_view, findsNothing);
    });

    testWidgets('the setting off: the 2D village, no scene started', (
      tester,
    ) async {
      await tester.pumpWidget(host(setting: false));
      expect(_fallback, findsOneWidget);
      expect(made, 0);
    });

    testWidgets('while it loads a sky loader covers it, never the 2D village', (
      tester,
    ) async {
      // Hafid, 2026-11-10: the 2D village flashing before the 3D one read
      // as a bug. The 2D one isn't even built while the 3D one is pending.
      await tester.pumpWidget(host());
      expect(_view, findsOneWidget);
      expect(_pending, findsOneWidget);
      expect(_fallback, findsNothing);

      channel.say({'type': 'loading'});
      await tester.pump();
      expect(channel.types, ['init']);
      expect(_pending, findsOneWidget, reason: 'not drawn yet');
      expect(_fallback, findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(_fallback, findsNothing, reason: 'still within the 20 s wait');

      channel.say({'type': 'ready'});
      await tester.pump();
      expect(_pending, findsNothing);
      expect(_fallback, findsNothing);
      expect(channel.types.first, 'init');
      expect(channel.sent.first['strings'], village3dStrings(Strings.fr));
    });

    testWidgets('no WebGL: back to 2D, and not tried again this run', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'unavailable', 'reason': 'no webgl'});
      await tester.pump();
      expect(_fallback, findsOneWidget);
      expect(_view, findsNothing);
      expect(channel.disposed, isTrue);
      expect(channel.types.last, 'dispose');

      // Coming back to Village does not start another scene.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VillageSceneHost)),
      );
      expect(container.read(village3dSupportProvider), isFalse);
      expect(made, 1);
    });

    testWidgets('too slow twice: back to 2D', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 24});
      await tester.pump();
      expect(_view, findsOneWidget, reason: 'one low figure never decides');

      await tester.pump(village3dPerfRecheck);
      expect(channel.types.last, 'getStats');
      channel.say({'type': 'stats', 'fps': 22});
      await tester.pump();
      expect(_fallback, findsOneWidget);
      expect(channel.disposed, isTrue);
    });

    testWidgets('a low first figure that recovers stays 3D', (tester) async {
      // Seen live: `perf` said 0 fps after the scene loaded under a dialog.
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 0});
      await tester.pump(village3dPerfRecheck);
      channel.say({'type': 'stats', 'fps': 60});
      await tester.pump();
      expect(_view, findsOneWidget);
      expect(channel.disposed, isFalse);
    });

    testWidgets('stats nobody asked for decide nothing', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'stats', 'fps': 5});
      await tester.pump();
      expect(_view, findsOneWidget);
    });

    testWidgets('fast enough: stays 3D', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 58});
      await tester.pump();
      expect(_fallback, findsNothing);
      expect(_view, findsOneWidget);
    });

    testWidgets('a scene that never answers gives way to 2D', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(village3dReadyTimeout + const Duration(seconds: 1));
      expect(_view, findsNothing);
      expect(_fallback, findsOneWidget);
    });

    testWidgets('turning the setting off drops the running scene', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      final element = tester.element(find.byType(VillageSceneHost));
      await ProviderScope.containerOf(element)
          .read(settingsControllerProvider.notifier)
          .setVillage3d(false);
      await tester.pump();
      expect(_fallback, findsOneWidget);
      expect(channel.disposed, isTrue);
    });
  });

  group('messages from the scene', () {
    testWidgets('a live building opens; an unknown code does nothing', (
      tester,
    ) async {
      final opened = <String>[];
      await tester.pumpWidget(host(onOpen: opened.add));
      channel.boot();
      await tester.pump();

      channel.say({'type': 'open', 'id': 'SCI'});
      channel.say({'type': 'open', 'id': 'NOPE'});
      channel.say({'v': 2, 'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, ['SCI']);
    });

    testWidgets('the portal: opening navigates nothing; open does', (
      tester,
    ) async {
      final opened = <String>[];
      await tester.pumpWidget(host(onOpen: opened.add));
      channel.boot();
      await tester.pump();

      channel.say({'type': 'opening', 'id': 'MATH', 'ms': 2400});
      await tester.pump(const Duration(seconds: 2));
      expect(opened, isEmpty, reason: 'no timer: the host waits for open');
      channel.say({'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, ['MATH']);
    });

    testWidgets('a portal the child left mid-way does not open later', (
      tester,
    ) async {
      // The kid tapped a building, then a nav tab before the gold: the
      // paused scene posts open only after they come back to the Village.
      final opened = <String>[];
      await tester.pumpWidget(host(onOpen: opened.add));
      channel.boot();
      await tester.pump();

      channel.say({'type': 'opening', 'id': 'MATH', 'ms': 2400});
      await tester.pumpWidget(host(onOpen: opened.add, visible: false));
      expect(channel.types.last, 'pause');
      await tester.pumpWidget(host(onOpen: opened.add));
      expect(channel.types.last, 'resume');
      channel.say({'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, isEmpty);

      // The next tap is a fresh one and opens normally.
      channel.say({'type': 'opening', 'id': 'SCI', 'ms': 2400});
      channel.say({'type': 'open', 'id': 'SCI'});
      await tester.pump();
      expect(opened, ['SCI']);
    });

    testWidgets('a portal holds off the frame-rate recheck', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 30});
      await tester.pump(const Duration(seconds: 1));
      channel.say({'type': 'opening', 'id': 'MATH', 'ms': 2400});
      await tester.pump(village3dPerfRecheck);
      expect(channel.types, isNot(contains('getStats')));
      // A late stats reply measured portal frames: it decides nothing.
      channel.say({'type': 'stats', 'fps': 10});
      await tester.pump();
      expect(_view, findsOneWidget);
    });

    testWidgets('a building that is not live does not open', (tester) async {
      final opened = <String>[];
      final state = VillageSceneState(
        buildings: villageBuildings(
          Strings.fr,
          subjects: const ['MATH', 'FR'],
          live: const ['MATH'],
        ),
        lang: 'fr',
        signTitle: 'x',
        signSubtitle: '',
        greeting: null,
        reduced: false,
        strings: const {},
      );
      await tester.pumpWidget(host(state: state, onOpen: opened.add));
      channel.boot();
      await tester.pump();
      channel.say({'type': 'open', 'id': 'FR'});
      channel.say({'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, ['MATH']);
    });

    testWidgets('an error after start-up keeps the scene', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'error', 'message': 'boom'});
      await tester.pump();
      expect(_view, findsOneWidget);
      expect(channel.disposed, isFalse);
    });

    testWidgets('the fox sings', (tester) async {
      var sang = 0;
      await tester.pumpWidget(host(onMascot: () => sang++));
      channel.boot();
      await tester.pump();
      channel.say({'type': 'mascot'});
      await tester.pump();
      expect(sang, 1);
    });

    testWidgets('new data reaches the scene as an update', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      await tester.pumpWidget(host(state: _state(greeting: 'Encore ?')));
      expect(channel.types.last, 'update');
      expect(channel.sent.last['greeting'], 'Encore ?');

      // The same data again sends nothing.
      final count = channel.sent.length;
      await tester.pumpWidget(host(state: _state(greeting: 'Encore ?')));
      expect(channel.sent.length, count);
    });
  });

  group('pause and resume', () {
    testWidgets('a hidden tab pauses the scene; showing it resumes', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      expect(channel.types, ['init']);

      await tester.pumpWidget(host(visible: false));
      expect(channel.types.last, 'pause');
      await tester.pumpWidget(host());
      expect(channel.types.last, 'resume');
    });

    testWidgets('focus moving into the scene does not pause it', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      // A tap into the iframe blurs the page: Flutter web says inactive.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(channel.types, isNot(contains('pause')));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('a dialog over the Village pauses the scene', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();

      final context = tester.element(find.byType(VillageSceneHost));
      showDialog<void>(context: context, builder: (_) => const Text('NIP'));
      await tester.pumpAndSettle();
      expect(channel.types.last, 'pause');
      expect(_view, findsOneWidget, reason: 'web draws dialogs above it');
      expect(channel.interactive, isFalse, reason: 'the dialog takes taps');

      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(channel.types.last, 'resume');
      expect(channel.interactive, isTrue);
    });

    testWidgets('a dialog on the root navigator pauses it too', (tester) async {
      // The app's shape: the Village inside a nested navigator, dialogs on
      // the root one, which only the observer sees.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _Settings(const AppSettings()),
            ),
            villageSceneChannelFactoryProvider.overrideWithValue(
              ({required String title}) => channel,
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [rootCoverObserver],
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => VillageSceneHost(
                  state: _state(),
                  fallback: const SizedBox.expand(key: _fallbackKey),
                ),
              ),
            ),
          ),
        ),
      );
      channel.boot();
      await tester.pump();
      expect(channel.interactive, isTrue);

      final context = tester.element(find.byType(VillageSceneHost));
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => const Text('NIP'),
      );
      await tester.pumpAndSettle();
      expect(channel.types.last, 'pause');
      expect(channel.interactive, isFalse);

      Navigator.of(context, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expect(channel.types.last, 'resume');
      expect(channel.interactive, isTrue);
    });

    testWidgets('a loading scene takes no taps: the 2D village over it does', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(channel.interactive, isFalse);
      channel.boot();
      await tester.pump();
      expect(channel.interactive, isTrue);
    });

    testWidgets('a native view is taken off screen under a dialog', (
      tester,
    ) async {
      channel.drawsAboveFlutter = true;
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      expect(_view, findsOneWidget);

      final context = tester.element(find.byType(VillageSceneHost));
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const Text('sheet'),
      );
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      // The sky stands in, not the 2D village: the same village comes back.
      expect(_pending, findsOneWidget);
      expect(_fallback, findsNothing);
      expect(channel.disposed, isFalse, reason: 'lifted, not torn down');

      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget);
      expect(_pending, findsNothing);
    });

    testWidgets('the app in the background pauses the scene', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(channel.types.last, 'pause');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(channel.types.last, 'resume');
    });

    testWidgets('a recheck waits for an unbroken run', (tester) async {
      await tester.pumpWidget(host());
      channel.boot();
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 3});
      await tester.pumpWidget(host(visible: false));
      await tester.pump(village3dPerfRecheck * 2);
      expect(channel.types, isNot(contains('getStats')));

      await tester.pumpWidget(host());
      await tester.pump(village3dPerfRecheck);
      expect(channel.types.last, 'getStats');
      expect(_view, findsOneWidget);
    });
  });

  testWidgets('a tap in the 3D village opens that subject on the Carte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
          questBoardProvider.overrideWith(
            (ref) async => QuestBoard(
              quests: const [],
              weekCompleted: 0,
              unlocked: const {},
              today: DateTime(2026, 11, 10),
            ),
          ),
          subjectProgressProvider.overrideWith(
            (ref) async => const {'MATH': 0.62},
          ),
          villageSceneChannelFactoryProvider.overrideWithValue(
            ({required String title}) => channel,
          ),
          settingsControllerProvider.overrideWith(
            () => _Settings(const AppSettings(village3d: true)),
          ),
        ],
        child: MaterialApp(
          theme: TutolysTheme.village(),
          locale: const Locale('fr', 'CA'),
          supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: VillageScreen(onOpenSubject: opened.add)),
        ),
      ),
    );
    await tester.pump();
    channel.boot();
    await tester.pump();
    await tester.pump();

    // The real progress went in.
    final init = channel.sent.firstWhere((m) => m['type'] == 'init');
    final math = (init['buildings']! as List).cast<Map>().firstWhere(
      (b) => b['id'] == 'MATH',
    );
    expect(math['progress'], 0.62);

    channel.say({'type': 'open', 'id': 'MATH'});
    await tester.pump();
    expect(opened, ['MATH']);
    expect(find.byType(VillageScene), findsNothing);
  });

  group('a phone', () {
    Widget phone({required bool platform, Size size = const Size(390, 844)}) =>
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
            questBoardProvider.overrideWith(
              (ref) async => QuestBoard(
                quests: const [],
                weekCompleted: 0,
                unlocked: const {},
                today: DateTime(2026, 11, 10),
              ),
            ),
            subjectProgressProvider.overrideWith(
              (ref) async => const {'MATH': 0.62},
            ),
            villageScenePlatformProvider.overrideWithValue(platform),
            villageSceneChannelFactoryProvider.overrideWithValue(
              ({required String title}) => platform ? channel : null,
            ),
            settingsControllerProvider.overrideWith(
              () => _Settings(const AppSettings()),
            ),
          ],
          child: MaterialApp(
            theme: TutolysTheme.village(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(size: size, disableAnimations: true),
              child: Scaffold(body: VillageScreen(onOpenSubject: (_) {})),
            ),
          ),
        );

    void phoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    final scene = find.byKey(const ValueKey('village-scene-box'));
    final loading = find.byKey(const ValueKey('village-3d-pending'));

    testWidgets('the 3D scene fills the screen; quests open in a sheet', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(phone(platform: true));
      await tester.pump();
      expect(scene, findsOneWidget);
      expect(find.byType(SubjectStrip), findsNothing);
      expect(loading, findsOneWidget);
      // Hafid: no recommended-activity band, the village takes the space.
      expect(find.byKey(const ValueKey('recommend-title')), findsNothing);

      channel.boot();
      await tester.pump();
      expect(loading, findsNothing);
      expect(_view, findsOneWidget);
      // Down to the bottom: only the quests row sits under the scene.
      final button = find.byKey(const ValueKey('village-quests-button'));
      final sceneBottom = tester.getBottomLeft(scene).dy;
      expect(tester.getTopLeft(button).dy, greaterThan(sceneBottom));
      expect(sceneBottom, greaterThan(844 * 0.7));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(Strings.fr.villageQuestsTitle), findsWidgets);
      expect(channel.types.last, 'pause', reason: 'the sheet covers it');
    });

    testWidgets('falls back to the 2D phone layout when the scene fails', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(phone(platform: true));
      await tester.pump();
      channel.say({'type': 'unavailable', 'reason': 'webgl'});
      await tester.pump();
      expect(scene, findsNothing);
      expect(find.byType(SubjectStrip), findsOneWidget);
    });

    for (final (size, beside) in [
      (const Size(1650, 950), true),
      (const Size(1024, 768), false),
      (const Size(820, 1180), false),
    ]) {
      testWidgets('at $size the village fills down to the bottom', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(phone(platform: true, size: size));
        await tester.pump();
        channel.boot();
        await tester.pump();

        final box = tester.getRect(scene);
        expect(box.bottom, greaterThan(size.height - 120));
        final panel = find.byKey(const ValueKey('village-quest-panel'));
        final button = find.byKey(const ValueKey('village-quests-button'));
        if (beside) {
          expect(panel, findsOneWidget);
          expect(button, findsNothing);
          expect(tester.getRect(panel).height, closeTo(box.height, 1));
          expect(box.width, greaterThan(size.width - 300 - 100));
        } else {
          expect(button, findsOneWidget);
          expect(box.width, greaterThan(size.width - 60));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the 2D phone layout where no scene can run', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(phone(platform: false));
      await tester.pump();
      expect(scene, findsNothing);
      expect(find.byType(SubjectStrip), findsOneWidget);
    });
  });
}
