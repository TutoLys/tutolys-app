import 'dart:async';
import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engine_sdk/testing.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/home_stats.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/play/play_screen.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

/// Records what would have been played; plays nothing.
class _SilentAudio implements AudioCoordinator {
  final List<AudioRequest> requests = [];

  /// Set to keep the next clips playing until it completes.
  Completer<PlaybackPhase>? hold;

  @override
  PlaybackHandle play(AudioRequest request) {
    requests.add(request);
    return _DoneHandle(requests.length, hold?.future);
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> stopChannel(AudioChannel channel) async {}
  @override
  Stream<PlaybackStatus> get status => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

class _DoneHandle implements PlaybackHandle {
  _DoneHandle(this.requestId, [this._held]);
  @override
  final int requestId;
  final Future<PlaybackPhase>? _held;
  @override
  Future<PlaybackPhase> get done =>
      _held ?? Future.value(PlaybackPhase.completed);
  @override
  Future<void> stop() async {}
}

const _node = CachedSkillNode(
  id: 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  labelFr: 'Additionner',
  labelEn: 'Add',
  stableKey: 'mathematique/x/b:A/o:1',
  subject: 'MATH',
  grade: 1,
);

const _mcqEnvelope = <String, Object?>{
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'engine_key': 'mcq',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Combien font 7 + 5 ?', 'audio_ref': 'audio'},
  'config': {
    'options': [
      {'id': 'a', 'label': '10'},
      {'id': 'b', 'label': '12'},
    ],
    'correct': 'b',
    'shuffle': false,
  },
};

/// A legacy-path exercise: `compose_build` isn't on the new contract yet.
const _composeEnvelope = <String, Object?>{
  'exercise_id': '882398fb-9064-4678-b5f2-d1fa1f7cb1fb',
  'version': 1,
  'engine_key': 'compose_build',
  'engine_min_version': 1,
  'skill_node_id': 'bd88c27b-3508-517c-bf0d-a06f5f743f0b',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Construis le nombre 7 avec deux blocs'},
  'config': {
    'tiles': [
      {'id': 'b1', 'label': '1'},
      {'id': 'b2', 'label': '2'},
      {'id': 'b5', 'label': '5'},
    ],
    'target': ['b2', 'b5'],
    'ordered': false,
  },
};

/// A `passage_reader` lesson: two sentences voiced, one not (ADR 0044).
const _passageEnvelope = <String, Object?>{
  'exercise_id': '1c0b9d1e-2f3a-4b5c-8d7e-9f0a1b2c3d4e',
  'version': 1,
  'engine_key': 'passage_reader',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Où dort Pompon ?'},
  'config': {
    'title': 'Le chat de Léa',
    'sentences': [
      {'id': 's1', 'text': 'Léa a un petit chat gris.', 'audio_ref': 'a/s1'},
      {'id': 's2', 'text': 'Pompon dort sur le lit.', 'audio_ref': 'a/s2'},
      {'id': 's3', 'text': 'Le matin, il boit du lait.'},
    ],
    'correct_ids': ['s2'],
  },
};

void main() {
  late LocalDatabase db;
  late _SilentAudio audio;

  setUp(() {
    db = LocalDatabase.memory();
    audio = _SilentAudio();
  });
  tearDown(() => db.close());

  /// [runtime] swaps in the fake engine; [legacyOnly] empties the new
  /// registry so even a ported engine takes the legacy fallback path.
  Widget app(
    Map<String, Object?> envelope, {
    bool runtime = false,
    bool legacyOnly = false,
    bool english = false,
    bool dark = false,
    bool practice = false,
    List<CelebrationRowData> celebrationRows = const [],
  }) => ProviderScope(
    overrides: [
      celebrationRowsProvider.overrideWith((ref) async => celebrationRows),
      localDatabaseProvider.overrideWithValue(db),
      activeKidIdProvider.overrideWithValue('kid-lea'),
      audioCoordinatorProvider.overrideWithValue(audio),
      if (legacyOnly)
        learningEngineRegistryProvider.overrideWithValue(
          LearningEngineRegistry(const []),
        ),
      if (runtime) ...[
        learningEngineRegistryProvider.overrideWithValue(
          LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
        ),
        evaluatorRegistryProvider.overrideWithValue(
          EvaluatorRegistry([FakeExactEvaluator()]),
        ),
      ],
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),
        locale: english ? const Locale('en', 'CA') : const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayScreen(
                      node: _node,
                      envelope: envelope,
                      practice: practice,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// What the router writes to the address bar.
  String? shownUrl(GoRouter router) => router.routeInformationParser
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)
      ?.uri
      .path;

  /// The real `/play` route under a plain home page, as the shell plays a
  /// game: through the router, so its exit check runs (AM20).
  ({Widget app, GoRouter router}) routed() {
    final play = buildPairedRouter().configuration.routes.first;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        play,
      ],
    );
    addTearDown(router.dispose);
    return (
      router: router,
      app: ProviderScope(
        overrides: [
          celebrationRowsProvider.overrideWith((ref) async => const []),
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('kid-lea'),
          audioCoordinatorProvider.overrideWithValue(audio),
          learningEngineRegistryProvider.overrideWithValue(
            LearningEngineRegistry([eraseEngine(FakeChoiceEngine())]),
          ),
          evaluatorRegistryProvider.overrideWithValue(
            EvaluatorRegistry([FakeExactEvaluator()]),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp.router(
            theme: TutolysTheme.village(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, Object?>>> outbox() async => [
    for (final row in await db.select(db.eventOutboxTable).get())
      jsonDecode(row.payload) as Map<String, Object?>,
  ];

  /// Drift's writes complete on real async, reaction beats on fake time;
  /// alternate the two until both have run out.
  Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets(
    'the legacy fallback still plays in the shell, fox on stage, telemetry as before',
    (tester) async {
      // Every published engine is on the new runtime since Phase 4; the
      // legacy path is only a fallback now, so force it.
      await tester.pumpWidget(
        app(
          _composeEnvelope,
          legacyOnly: true,
          celebrationRows: const [
            CelebrationRowData(
              icon: Icons.flag_rounded,
              label: 'Résous 5 exercices',
              value: 2,
              max: 5,
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Quitter l'exercice"), findsOneWidget);
      expect(find.byType(BitmapCharacterView), findsOneWidget);
      expect(
        find.text('Construis le nombre 7 avec deux blocs'),
        findsOneWidget,
      );
      expect(
        find.text('VALIDER'),
        findsNothing,
        reason: 'legacy engines resolve on tap',
      );

      await tester.tap(find.text('5'));
      await settle(tester);
      await tester.tap(find.text('2'));
      // The legacy engine awaits its attempt write, then its reaction beats,
      // before finishing; then the celebration.
      await settle(tester, rounds: 6);
      await tester.pumpAndSettle();
      expect(
        find.text('Parfait !'),
        findsOneWidget,
        reason: 'right first time',
      );
      expect(find.text('+4 XP'), findsOneWidget, reason: '1 + 2 + 1');
      expect(
        find.text('Résous 5 exercices'),
        findsOneWidget,
        reason: 'quest rows come from their owner',
      );
      expect(find.text('2/5'), findsOneWidget);
      await tester.tap(find.text('CONTINUER'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget, reason: 'finished and popped');
      final types = (await outbox()).map((e) => e['event_type']).toList();
      expect(
        types,
        containsAllInOrder([
          'session_start',
          'exercise_start',
          'attempt',
          'exercise_complete',
        ]),
      );
      expect(
        await db.select(db.activitySessionTable).get(),
        isEmpty,
        reason: 'the legacy path keeps no session',
      );
    },
  );

  testWidgets(
    'a real mcq exercise plays on the new runtime: listen, wrong, retry, right, done',
    (tester) async {
      // No engine overrides: the app's own registry serves mcq now.
      await tester.pumpWidget(app(_mcqEnvelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(audio.requests, isEmpty, reason: 'never read on its own');
      // The speaker is left of the question, and reads it when tapped.
      expect(
        tester.getCenter(find.byTooltip('Écouter la question')).dx,
        lessThan(tester.getCenter(find.text('Combien font 7 + 5 ?')).dx),
      );
      await tester.tap(find.byTooltip('Écouter la question'));
      await settle(tester);
      expect(audio.requests, hasLength(1));
      expect((audio.requests.single.source as PrerecordedAudio).ref, 'audio');

      await tester.tap(find.text('10'));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.text('12'));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(
        find.text('+3'),
        findsOneWidget,
        reason:
            'the right answer that finishes the lesson pays its bonus '
            'too, so the game ends on the celebration\'s number',
      );
      await tester.tap(find.text('CONTINUER'));
      await settle(tester);
      await tester.pumpAndSettle();

      // The celebration, not a snackbar.
      expect(find.text('Exercice terminé !'), findsOneWidget);
      expect(
        find.text('+3 XP'),
        findsOneWidget,
        reason: 'second try: 1 + 2 for the lesson, no perfect bonus',
      );
      // G15: first tries out of all, and the ones fixed by the child.
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('corrigées par toi'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final done = await tester.runAsync(
        () => NodeProgressLocal(db, kidId: 'kid-lea').all(),
      );
      expect(done!.keys, [_node.id], reason: 'the map can mark it done now');
      expect(done[_node.id]!.everPerfect, isFalse);

      await tester.tap(find.text('CONTINUER'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget, reason: 'finished and popped');
      final events = await outbox();
      // play_event.v2 (engine_sdk V2EventRecorder): v1's events, plus the
      // listen and the picks v1 had nowhere to put.
      expect(events.map((e) => e['event_type']).toList(), [
        'session_start',
        'exercise_start',
        'question_presented',
        'audio_requested',
        'option_selected',
        'attempt',
        'option_selected',
        'attempt',
        'exercise_complete',
        'session_end',
      ]);
      expect(events.map((e) => e['schema_version']).toSet(), {2});
      final attempts = events
          .where((e) => e['event_type'] == 'attempt')
          .toList();
      expect(attempts.map((e) => e['is_correct']), [false, true]);
      expect(attempts.map((e) => (e['answer_payload']! as Map)['selected']), [
        'a',
        'b',
      ]);
      expect(await db.select(db.activitySessionTable).get(), isEmpty);
    },
  );

  testWidgets(
    'a runtime exercise survives leaving mid-question and resumes where it was',
    (tester) async {
      final envelope = fakeEnvelope(questions: 2);
      for (final q
          in ((envelope['config']! as Map)['questions']! as List)
              .cast<Map<String, Object?>>()) {
        (q['prompt']! as Map<String, Object?>)['audio_ref'] = 'q_audio';
      }
      await tester.pumpWidget(app(envelope, runtime: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('Q0'), findsOneWidget);
      expect(audio.requests, isEmpty, reason: 'read only when asked');
      expect(find.byTooltip('Écouter la question'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('option-a')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Presque !'), findsOneWidget);
      final sessionRows = await db.select(db.activitySessionTable).get();
      expect(sessionRows, hasLength(1));

      // The screen goes away without the child pressing close — a crash, a
      // tab switch that unmounts it, the OS reclaiming the app.
      Navigator.of(tester.element(find.text('Q0'))).pop();
      await tester.pumpAndSettle();
      expect(
        await db.select(db.activitySessionTable).get(),
        hasLength(1),
        reason: 'kept for resume',
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      // Same session: the wrong answer is still locked, and no second
      // session_start was written.
      expect(
        find.text('Presque !'),
        findsOneWidget,
        reason: 'resumed into the feedback it left',
      );
      final events = await outbox();
      expect(
        events.where((e) => e['event_type'] == 'session_start'),
        hasLength(1),
      );
      expect(events.map((e) => e['session_id']).toSet(), hasLength(1));
    },
  );

  testWidgets(
    'closing a runtime exercise ends the session and leaves nothing to resume',
    (tester) async {
      await tester.pumpWidget(app(fakeEnvelope(questions: 1), runtime: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      await tester.tap(find.byTooltip("Quitter l'exercice"));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(await db.select(db.activitySessionTable).get(), isEmpty);
      final types = (await outbox()).map((e) => e['event_type']).toList();
      expect(types.sublist(types.length - 2), [
        'exercise_abandon',
        'session_end',
      ]);
      unawaited(Future<void>.value());
    },
  );

  testWidgets(
    'leaving after one of two questions records nothing as completed',
    (tester) async {
      await tester.pumpWidget(app(fakeEnvelope(questions: 2), runtime: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      // Q0 right, then the child quits before Q1.
      await tester.tap(find.byKey(const ValueKey('option-b')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      await tester.tap(find.byTooltip("Quitter l'exercice"));
      await settle(tester);
      await tester.pumpAndSettle();
      // G5: a started série asks « Tu veux arrêter ? » first.
      await tester.tap(find.byKey(const ValueKey('stop-quit')));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      final done = await tester.runAsync(
        () => NodeProgressLocal(db, kidId: 'kid-lea').all(),
      );
      expect(
        done,
        isEmpty,
        reason: 'only finishing every question of the série counts',
      );
      // Quests count finished lessons only (Hafid, 2026-10-26).
      final today = await tester.runAsync(
        () => HomeStats(db, kidId: 'kid-lea').today(),
      );
      expect(today!.exercisesCompleted, 0, reason: '"5 exercices" unmoved');
      expect(today.msPlayed, 0, reason: '"10 minutes" unmoved');
      // And telemetry can tell it apart from a finished lesson.
      final types = (await outbox()).map((e) => e['event_type']).toList();
      expect(types.sublist(types.length - 2), [
        'exercise_abandon',
        'session_end',
      ]);
    },
  );

  testWidgets(
    'the legacy fallback, left mid-lesson, sends an abandon before its end',
    (tester) async {
      await tester.pumpWidget(app(_composeEnvelope, legacyOnly: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Quitter l'exercice"));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      final types = (await outbox()).map((e) => e['event_type']).toList();
      expect(types.where((t) => t == 'exercise_abandon'), hasLength(1));
      expect(types.sublist(types.length - 2), [
        'exercise_abandon',
        'session_end',
      ]);
      final today = await tester.runAsync(
        () => HomeStats(db, kidId: 'kid-lea').today(),
      );
      expect(today!.exercisesCompleted, 0);
    },
  );

  group('the three shared sound moments (ADR 0035)', () {
    List<String> effects() => [
      for (final r in audio.requests)
        if (r.source case EffectAudio(:final name)) '${r.channel.name}:$name',
    ];

    Future<void> openActivity(
      WidgetTester tester,
      Map<String, Object?> envelope, {
      bool runtime = false,
    }) async {
      await tester.pumpWidget(app(envelope, runtime: runtime));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);
    }

    testWidgets('the real mcq: one cue per check, one jingle at the end', (
      tester,
    ) async {
      await openActivity(tester, _mcqEnvelope);
      expect(effects(), isEmpty, reason: 'nothing before a check');

      await tester.tap(find.text('10'));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(effects(), ['sfx:answer_retry']);

      await tester.tap(find.text('RÉESSAYER'));
      await settle(tester);
      await tester.tap(find.text('12'));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(effects(), ['sfx:answer_retry', 'sfx:answer_right']);

      await tester.tap(find.text('CONTINUER'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(effects(), [
        'sfx:answer_retry',
        'sfx:answer_right',
        'sfx:activity_complete',
      ]);
    });

    testWidgets('any other engine gets the same cues, from the shell', (
      tester,
    ) async {
      // The fake engine shares nothing with mcq but the runtime: the cue
      // rides the controller's verdict, not an engine.
      await openActivity(tester, fakeEnvelope(questions: 1), runtime: true);
      await tester.tap(find.byKey(const ValueKey('option-b')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(effects(), ['sfx:answer_right']);
    });
  });

  testWidgets('a lesson already finished here earns replay XP, no bonus', (
    tester,
  ) async {
    await tester.runAsync(
      () => NodeProgressLocal(db, kidId: 'kid-lea').recordCompleted(
        _node.id,
        perfect: true,
        exerciseId: _mcqEnvelope['exercise_id'] as String?,
      ),
    );
    await tester.pumpWidget(app(_mcqEnvelope));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await settle(tester);

    await tester.tap(find.text('12'));
    await settle(tester);
    await tester.tap(find.text('VALIDER'));
    await settle(tester);
    await tester.tap(find.text('CONTINUER'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('Parfait !'), findsOneWidget);
    expect(
      find.text('+1 XP'),
      findsOneWidget,
      reason: 'half of 1 question rounds to 0, so the +1 floor pays 1, and '
          'no lesson bonus',
    );
  });

  group('Hafid\'s "too wide" mcq', () {
    testWidgets('an mcq whose prompt carries a speech string plays on the '
        'new runtime, not the legacy host', (tester) async {
      final envelope = {
        ..._mcqEnvelope,
        'prompt': {
          'text': '8, 10, ▢, 14',
          'audio_ref': 'audio',
          'speech': '8, 10, une case vide, 14',
        },
      };
      await tester.pumpWidget(app(envelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.byType(LegacyEngineHost), findsNothing);
      expect(find.text('VALIDER'), findsOneWidget);
    });

    testWidgets('the legacy fallback, if ever used, stays readable on a wide '
        'desktop', (tester) async {
      tester.view.physicalSize = const Size(1918, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(_composeEnvelope, legacyOnly: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      final host = tester.getRect(find.byType(LegacyEngineHost));
      expect(host.width, lessThanOrEqualTo(legacyMaxWidth));
      expect(host.center.dx, closeTo(1918 / 2, 1), reason: 'centred');
    });
  });

  testWidgets('in the dark theme, the game chrome is dark too', (tester) async {
    await tester.pumpWidget(app(_mcqEnvelope, dark: true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await settle(tester);

    final chrome = tester.element(find.text('VALIDER'));
    expect(VillagePalette.of(chrome).isDark, isTrue);
    expect(Theme.of(chrome).brightness, Brightness.dark);
  });

  testWidgets(
    'in English, the game chrome is English (content stays as authored)',
    (tester) async {
      await tester.pumpWidget(app(_mcqEnvelope, english: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('CHECK'), findsOneWidget);
      expect(
        find.text('HINT'),
        findsNothing,
        reason: 'this question has no hint',
      );
      expect(find.byTooltip('Listen to the question'), findsOneWidget);
      expect(
        find.text('Combien font 7 + 5 ?'),
        findsOneWidget,
        reason: 'French content until English content exists',
      );

      await tester.tap(find.text('10'));
      await settle(tester);
      await tester.tap(find.text('CHECK'));
      await settle(tester);
      expect(find.text('Almost!'), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);
    },
  );

  group('a passage sentence is read when its speaker is tapped (ADR 0044)', () {
    testWidgets('plays that sentence on the narration channel', (tester) async {
      await tester.pumpWidget(app(_passageEnvelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(audio.requests, isEmpty, reason: 'nothing reads by itself');
      expect(find.byKey(const ValueKey('passage-speak-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('passage-speak-3')),
        findsNothing,
        reason: 'no audio, no speaker',
      );

      await tester.tap(find.byKey(const ValueKey('passage-speak-2')));
      await settle(tester);

      final request = audio.requests.single;
      expect(request.channel, AudioChannel.narration);
      final source = request.source as PrerecordedAudio;
      expect(source.exerciseId, _passageEnvelope['exercise_id']);
      expect(source.ref, 'a/s2');
    });

    testWidgets('with read-aloud off, no sentence has a speaker', (
      tester,
    ) async {
      // Stored before the app reads it, as Réglages would have left it.
      await tester.runAsync(
        () => AppSettingsStore(
          db,
          kidId: 'kid-lea',
        ).write(const AppSettings().copyWith(readAloud: false)),
      );
      await tester.pumpWidget(app(_passageEnvelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text('Pompon dort sur le lit.'), findsOneWidget);
      expect(find.byKey(const ValueKey('passage-speak-1')), findsNothing);
      expect(find.byKey(const ValueKey('passage-speak-2')), findsNothing);
    });
  });

  group('AM20: Back leaves a game like ✕', () {
    testWidgets('the game has its own URL', (tester) async {
      final r = routed();
      await tester.pumpWidget(r.app);
      unawaited(
        r.router.push(
          '/play',
          extra: PlayRequest(node: _node, envelope: fakeEnvelope(questions: 2)),
        ),
      );
      await settle(tester);
      expect(shownUrl(r.router), '/play');
    });

    testWidgets('nothing started: Back just leaves', (tester) async {
      final r = routed();
      await tester.pumpWidget(r.app);
      unawaited(
        r.router.push(
          '/play',
          extra: PlayRequest(node: _node, envelope: fakeEnvelope(questions: 2)),
        ),
      );
      await settle(tester);
      expect(find.byType(PlayScreen), findsOneWidget);
      r.router.go('/');
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stop-sheet')), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('started: Back asks, Continuer stays, Arrêter leaves', (
      tester,
    ) async {
      final r = routed();
      await tester.pumpWidget(r.app);
      unawaited(
        r.router.push(
          '/play',
          extra: PlayRequest(node: _node, envelope: fakeEnvelope(questions: 2)),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('option-b')));
      await settle(tester);

      // The browser's Back: the URL moves to the previous page.
      r.router.go('/');
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stop-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stop-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);
      expect(shownUrl(r.router), '/play');

      // Android's Back: a pop.
      unawaited(r.router.routerDelegate.popRoute());
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stop-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stop-quit')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('2026-10-31 game calls', () {
    testWidgets('G17: the shell hears "narrating" while the question is read',
        (tester) async {
      await tester.pumpWidget(app(_mcqEnvelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);
      final narrating = tester
          .widget<LearningActivityView>(find.byType(LearningActivityView))
          .narrating!;
      expect(narrating.value, isFalse);

      audio.hold = Completer<PlaybackPhase>();
      await tester.tap(find.byTooltip('Écouter la question'));
      await tester.pump();
      expect(narrating.value, isTrue);

      audio.hold!.complete(PlaybackPhase.completed);
      await tester.pump();
      expect(narrating.value, isFalse);
    });

    testWidgets('N14: practice shows no XP in the game', (tester) async {
      await tester.pumpWidget(app(_mcqEnvelope, practice: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settle(tester);
      await tester.tap(find.text('12'));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(find.text('+3'), findsNothing);
    });
  });
}
