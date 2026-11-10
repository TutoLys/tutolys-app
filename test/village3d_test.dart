import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/home/subject_progress.dart';
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

  @override
  Stream<Object?> get messages => inbound.stream;

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  @override
  Widget buildView() => const SizedBox.expand(key: ValueKey('fake-3d'));

  @override
  void dispose() => disposed = true;
}

class _Settings extends SettingsController {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> setVillage3d(bool value) async =>
      state = state.copyWith(village3d: value);
}

final _buildings = villageBuildings(Strings.fr);

VillageSceneState _state({String? greeting = 'Bonjour !'}) =>
    VillageSceneState(
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
  }) => ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(
        () => _Settings(AppSettings(village3d: setting)),
      ),
      villageSceneChannelFactoryProvider.overrideWithValue(
        ({required String title}) {
          if (!platform) return null;
          made++;
          return channel;
        },
      ),
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
      expect(SceneEvent.parse(m({'type': 'ready'})), isA<SceneReady>());
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

    test('init carries the app words, real progress and null as unmeasured',
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
        containsPair('notStarted', Strings.en.pathNotStarted),
      );
      expect((init['sign']! as Map)['title'], 'Lys Village');
    });
  });

  group('which village shows', () {
    testWidgets('by default the 2D village: no scene is started', (
      tester,
    ) async {
      // Hafid, 2026-11-10: "everything keeps the 2d for now".
      expect(village3dDefaultOn, isFalse);
      expect(const AppSettings().village3d, village3dDefaultOn);
      await tester.pumpWidget(host(setting: const AppSettings().village3d));
      expect(_fallback, findsOneWidget);
      expect(made, 0);
    });

    test('an untouched toggle is not stored, so the swap reaches the kid',
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
    });

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

    testWidgets('while it loads the 2D village covers it; ready reveals it', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(_view, findsOneWidget);
      expect(_fallback, findsOneWidget);

      channel.say({'type': 'ready'});
      await tester.pump();
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

      // Coming back to Village does not start another scene.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VillageSceneHost)),
      );
      expect(container.read(village3dSupportProvider), isFalse);
      expect(made, 1);
    });

    testWidgets('too slow: back to 2D', (tester) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'ready'});
      await tester.pump();
      channel.say({'type': 'perf', 'fps': 24});
      await tester.pump();
      expect(_fallback, findsOneWidget);
      expect(channel.disposed, isTrue);
    });

    testWidgets('fast enough: stays 3D', (tester) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'ready'});
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
      channel.say({'type': 'ready'});
      await tester.pump();
      final element = tester.element(find.byType(VillageSceneHost));
      await ProviderScope.containerOf(
        element,
      ).read(settingsControllerProvider.notifier).setVillage3d(false);
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
      channel.say({'type': 'ready'});
      await tester.pump();

      channel.say({'type': 'open', 'id': 'SCI'});
      channel.say({'type': 'open', 'id': 'NOPE'});
      channel.say({'v': 2, 'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, ['SCI']);
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
      channel.say({'type': 'ready'});
      await tester.pump();
      channel.say({'type': 'open', 'id': 'FR'});
      channel.say({'type': 'open', 'id': 'MATH'});
      await tester.pump();
      expect(opened, ['MATH']);
    });

    testWidgets('the fox sings', (tester) async {
      var sang = 0;
      await tester.pumpWidget(host(onMascot: () => sang++));
      channel.say({'type': 'ready'});
      await tester.pump();
      channel.say({'type': 'mascot'});
      await tester.pump();
      expect(sang, 1);
    });

    testWidgets('new data reaches the scene as an update', (tester) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'ready'});
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
      channel.say({'type': 'ready'});
      await tester.pump();
      expect(channel.types, ['init', 'resume']);

      await tester.pumpWidget(host(visible: false));
      expect(channel.types.last, 'pause');
      await tester.pumpWidget(host());
      expect(channel.types.last, 'resume');
    });

    testWidgets('the app in the background pauses the scene', (tester) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'ready'});
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

    testWidgets('a slow figure measured while paused is not held against it',
        (tester) async {
      await tester.pumpWidget(host());
      channel.say({'type': 'ready'});
      await tester.pump();
      await tester.pumpWidget(host(visible: false));
      channel.say({'type': 'perf', 'fps': 3});
      await tester.pump();
      await tester.pumpWidget(host());
      expect(_view, findsOneWidget);
      expect(channel.disposed, isFalse);
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
    channel.say({'type': 'ready'});
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
}
