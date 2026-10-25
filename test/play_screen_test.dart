import 'dart:async';
import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engine_sdk/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/play/learning_platform_providers.dart';
import 'package:tutolys_app/features/play/play_screen.dart';

/// Records what would have been played; plays nothing.
class _SilentAudio implements AudioCoordinator {
  final List<AudioRequest> requests = [];

  @override
  PlaybackHandle play(AudioRequest request) {
    requests.add(request);
    return _DoneHandle(requests.length);
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
  _DoneHandle(this.requestId);
  @override
  final int requestId;
  @override
  Future<PlaybackPhase> get done => Future.value(PlaybackPhase.completed);
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
  'prompt': {'text': 'Combien font 7 + 5 ?'},
  'config': {
    'options': [
      {'id': 'a', 'label': '10'},
      {'id': 'b', 'label': '12'},
    ],
    'correct': 'b',
    'shuffle': false,
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

  Widget app(Map<String, Object?> envelope, {bool runtime = false}) =>
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('kid-lea'),
          audioCoordinatorProvider.overrideWithValue(audio),
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
            theme: TutolysTheme.village(),
            locale: const Locale('fr', 'CA'),
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
                        builder: (_) =>
                            PlayScreen(node: _node, envelope: envelope),
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
    'today\'s content plays in the shell, the fox on stage, telemetry as before',
    (tester) async {
      await tester.pumpWidget(app(_mcqEnvelope));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Quitter l'exercice"), findsOneWidget);
      expect(find.byType(TutolysMascot), findsOneWidget);
      expect(find.text('Combien font 7 + 5 ?'), findsOneWidget);

      await tester.tap(find.text('12'));
      // The legacy engine awaits its attempt write, then its reaction beats
      // (2 × 900 ms), before finishing; the screen then pops.
      await settle(tester, rounds: 6);
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
      expect(audio.requests, hasLength(1), reason: 'the prompt auto-reads');
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
}
