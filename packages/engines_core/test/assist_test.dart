import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:engines_core/src/shell/activity_assist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX review G8 (a voiced hint, narrowing after three misses) and G17 (the
/// countdown pauses while the question is read or the hint is open).
/// ADR 0108.
class _Speaker implements ContentSpeaker {
  final said = <String>[];
  @override
  void speak({required String audioRef, required String partId}) =>
      said.add(audioRef);
}

void main() {
  Map<String, Object?> envelope(
    String engine,
    Map<String, Object?> config, {
    List<Map<String, Object?>> assets = const [],
  }) => {
    'exercise_id': '1c3d6d41-a465-42be-b3a9-c1dc8460e24c',
    'version': 1,
    'content_hash': 'h',
    'engine_key': engine,
    'engine_min_version': 1,
    'skill_node_id': '5a221f09-99f7-597e-bc4a-34e7ccafaa3b',
    'subject': 'MATH',
    'grade': 1,
    'rank': 0,
    'prompt': {'text': 'Combien ?'},
    'config': config,
    'assets': assets,
  };

  ActivitySessionController controller(Map<String, Object?> env) =>
      ActivitySessionController(
        envelope: QuestionEnvelope.parse(env).valueOrNull!,
        kidId: 'kid',
        engines: LearningEngineRegistry([
          eraseEngine(const SingleChoiceEngine()),
          eraseEngine(const TimedChoiceEngine()),
          eraseEngine(const PairMatchBoardEngine()),
        ]),
        evaluators: EvaluatorRegistry(const [
          McqExactEvaluator(),
          SpeedTapExactEvaluator(),
          PairMatchEvaluator(),
        ]),
        store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
        appVersion: '0.2.0',
        seed: 1,
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    await tester.pump();
  }

  Future<ActivitySessionController> pump(
    WidgetTester tester,
    Map<String, Object?> env, {
    ContentSpeaker? speaker,
    ValueListenable<bool>? narrating,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = controller(env);
    await tester.runAsync(c.start);
    Widget view = LearningActivityView(
      controller: c,
      locale: const Locale('fr'),
      narrating: narrating,
      onDone: () {},
    );
    if (speaker != null) {
      view = ContentSpeakerScope(speaker: speaker, child: view);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: TutolysTheme.village(),
        home: Scaffold(body: view),
      ),
    );
    await tester.pump();
    return c;
  }

  final six = {
    'options': [
      for (final (i, l) in ['1', '2', '3', '4', '5', '6'].indexed)
        {'id': 'o$i', 'label': l},
    ],
    'correct': 'o5',
    'shuffle': false,
    'hint': 'Compte les poissons un par un.',
  };

  group('G8: the hint has a voice', () {
    testWidgets('a hint with a clip gets a speaker, read on tap only', (
      tester,
    ) async {
      final speaker = _Speaker();
      final c = await pump(
        tester,
        envelope(
          'mcq',
          six,
          assets: [
            {'ref': 'hint', 'kind': 'audio'},
          ],
        ),
        speaker: speaker,
      );
      await tester.tap(find.text('INDICE'));
      await settle(tester);
      expect(speaker.said, isEmpty, reason: 'never read by itself');
      await tester.tap(find.byKey(const ValueKey('hint-speak')));
      expect(speaker.said, ['hint']);
      c.dispose();
    });

    testWidgets('a hint with no clip draws no speaker', (tester) async {
      final c = await pump(tester, envelope('mcq', six), speaker: _Speaker());
      await tester.tap(find.text('INDICE'));
      await settle(tester);
      expect(find.byKey(const ValueKey('hint-speak')), findsNothing);
      c.dispose();
    });
  });

  group('G8: three misses narrow the problem', () {
    test('one wrong, untried answer is set aside; never below two', () {
      expect(
        answerToDim(order: ['a', 'b', 'c', 'd'], right: {'d'}, tried: {'a'}),
        'b',
      );
      expect(
        answerToDim(order: ['a', 'b', 'c'], right: {'c'}, tried: {'a'}),
        isNull,
      );
    });

    testWidgets('mcq: after three misses one wrong answer is dimmed', (
      tester,
    ) async {
      final c = await pump(tester, envelope('mcq', six));
      bool dimmed(String id) => tester
          .widget<AnswerTile>(find.byKey(ValueKey('mcq-option-$id')))
          .dimmed;
      for (final id in ['o0', 'o1', 'o2']) {
        expect([
          for (var i = 0; i < 6; i++) dimmed('o$i'),
        ], everyElement(false));
        await tester.tap(find.byKey(ValueKey('mcq-option-$id')));
        await settle(tester);
        await tester.tap(find.text('VALIDER'));
        await settle(tester);
        await tester.tap(find.text('RÉESSAYER'));
        await settle(tester);
      }
      expect(dimmed('o3'), isTrue);
      expect(dimmed('o5'), isFalse, reason: 'never the right answer');
      // A dimmed answer can't be picked.
      await tester.tap(
        find.byKey(const ValueKey('mcq-option-o3')),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(
        tester
            .widget<AnswerTile>(find.byKey(const ValueKey('mcq-option-o3')))
            .state,
        AnswerTileState.idle,
      );
      c.dispose();
    });

    testWidgets('pair_match: after three wrong boards one right pair is '
        'pointed at', (tester) async {
      final c = await pump(
        tester,
        envelope('pair_match', {
          'pairs': [
            for (final w in ['chat', 'chien', 'oiseau'])
              {
                'left': {'id': w, 'label': w},
                'right': {'id': 'r_$w', 'label': w.toUpperCase()},
              },
          ],
        }),
      );
      bool suggested(String key) =>
          tester.widget<AnswerTile>(find.byKey(ValueKey(key))).suggested;
      for (var miss = 0; miss < 3; miss++) {
        // chat↔CHIEN, chien↔CHAT, oiseau↔OISEAU: two wrong.
        for (final (l, r) in [
          ('chat', 'r_chien'),
          ('chien', 'r_chat'),
          ('oiseau', 'r_oiseau'),
        ]) {
          await tester.tap(find.byKey(ValueKey('pair-left-$l')));
          await settle(tester);
          await tester.tap(find.byKey(ValueKey('pair-right-$r')));
          await settle(tester);
        }
        await tester.tap(find.text('VALIDER'));
        await settle(tester);
        if (miss < 2) {
          expect(suggested('pair-left-chat'), isFalse);
          expect(suggested('pair-left-chien'), isFalse);
        }
        await tester.tap(find.text('RÉESSAYER'));
        await settle(tester);
      }
      // One of the two wrong pairs, both its tiles; never the right one.
      final pointed = [
        for (final l in ['chat', 'chien', 'oiseau'])
          if (suggested('pair-left-$l')) l,
      ];
      expect(pointed, hasLength(1));
      expect(pointed.single, isNot('oiseau'));
      expect(suggested('pair-right-r_${pointed.single}'), isTrue);
      c.dispose();
    });
  });

  group('G17: the countdown pauses', () {
    final timed = {
      'options': [
        {'id': 'a', 'label': '1'},
        {'id': 'b', 'label': '2'},
        {'id': 'c', 'label': '3'},
      ],
      'correct': 'b',
      'time_limit_ms': 6000,
      'shuffle': false,
      'hint': 'Compte les poissons.',
    };

    bool running(WidgetTester tester) =>
        tester.widget<CountdownBar>(find.byType(CountdownBar)).running;

    testWidgets('while the question is read aloud', (tester) async {
      final narrating = ValueNotifier(false);
      final c = await pump(
        tester,
        envelope('speed_tap', timed),
        narrating: narrating,
      );
      expect(running(tester), isTrue);
      narrating.value = true;
      await tester.pump();
      expect(running(tester), isFalse);
      narrating.value = false;
      await tester.pump();
      expect(running(tester), isTrue);
      c.dispose();
    });

    testWidgets('while the hint is open', (tester) async {
      final c = await pump(tester, envelope('speed_tap', timed));
      expect(running(tester), isTrue);
      await tester.tap(find.text('INDICE'));
      await settle(tester);
      expect(running(tester), isFalse);
      c.dispose();
    });
  });
}
