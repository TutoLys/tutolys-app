import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _v1() => {
  'exercise_id': 'ex-1',
  'version': 3,
  'engine_key': 'mcq',
  'engine_min_version': 1,
  'skill_node_id': 'skill-1',
  'subject': 'MATH',
  'grade': 1,
  'rank': 0,
  'schema_version': 1,
  'locale': 'fr-CA',
  'content_hash': 'abc',
  'prompt': {'text': 'Combien font 7 + 5 ?', 'audio_ref': 'audio'},
  'config': {
    'options': [
      {'id': 'a', 'label': '10'},
      {'id': 'b', 'label': '12'},
    ],
    'correct': 'b',
  },
};

void main() {
  group('QuestionEnvelope', () {
    test('a published v1 envelope parses to one implicit question with v1 defaults', () {
      final env = QuestionEnvelope.parse(_v1()).valueOrNull!;
      expect(env.schemaVersion, 1);
      expect(env.questions, hasLength(1));
      expect(env.questions.single.engineKey, 'mcq');
      expect(env.questions.single.prompt.audioRef, 'audio');
      expect(
        env.speechPolicy.prompt,
        SpeechTrigger.onRequest,
        reason: 'read only when the child taps the speaker',
      );
      expect(env.evaluation.maxAttempts, isNull, reason: 'retry until correct');
      expect(env.skillNodeIds, ['skill-1']);
    });

    test(
      'multi-question config yields one spec per question, engine overridable',
      () {
        final json = _v1()
          ..['config'] = {
            'questions': [
              {
                'prompt': {'text': 'Q1'},
                'config': {'x': 1},
              },
              {
                'engine_key': 'pair_match',
                'prompt': {'text': 'Q2'},
                'config': {'y': 2},
              },
            ],
          };
        final env = QuestionEnvelope.parse(json).valueOrNull!;
        expect(env.questions.map((q) => q.engineKey), ['mcq', 'pair_match']);
        expect(env.questions[1].prompt.text, 'Q2');
        expect(env.questions[1].config, {'y': 2});
      },
    );

    test('v2 optional fields parse', () {
      final json = _v1()
        ..['schema_version'] = 2
        ..['min_app_version'] = '1.4.0'
        ..['secondary_skill_node_ids'] = ['skill-2']
        ..['speech_policy'] = {'feedback': 'never'}
        ..['evaluation'] = {'policy': 'exact', 'version': 2, 'max_attempts': 3}
        ..['prompt'] = {
          'text': '7 + 5',
          'speech': {'text': 'sept plus cinq', 'mode': 'tts'},
        };
      final env = QuestionEnvelope.parse(json).valueOrNull!;
      expect(env.minAppVersion, '1.4.0');
      expect(env.skillNodeIds, ['skill-1', 'skill-2']);
      expect(env.speechPolicy.feedback, SpeechTrigger.never);
      expect(
        env.speechPolicy.prompt,
        SpeechTrigger.onRequest,
        reason: 'unset keeps its default',
      );
      expect(
        env.speechPolicy.options,
        SpeechTrigger.never,
        reason: 'choices are never read by default',
      );
      expect(env.evaluation.maxAttempts, 3);
      expect(env.questions.single.prompt.speech!.mode, SpeechMode.tts);
    });

    test(
      'unknown keys are ignored so older apps keep playing newer content',
      () {
        final json = _v1()..['some_future_field'] = {'anything': true};
        expect(QuestionEnvelope.parse(json), isA<ParseOk<QuestionEnvelope>>());
      },
    );

    test('a known key with the wrong type is invalid, with a reason', () {
      final json = _v1()..['grade'] = 'one';
      final r = QuestionEnvelope.parse(json);
      expect(r, isA<ParseInvalid<QuestionEnvelope>>());
      expect((r as ParseInvalid).reason, contains('grade'));
    });

    test('missing required fields are all reported, not just the first', () {
      final json = _v1()
        ..remove('exercise_id')
        ..remove('skill_node_id');
      final reason = (QuestionEnvelope.parse(json) as ParseInvalid).reason;
      expect(reason, contains('exercise_id'));
      expect(reason, contains('skill_node_id'));
    });

    test('a newer envelope schema is unsupported, not invalid', () {
      final json = _v1()..['schema_version'] = 99;
      expect(
        QuestionEnvelope.parse(json),
        isA<ParseUnsupported<QuestionEnvelope>>(),
      );
    });

    test('bad trigger, bad attempt cap and bad version string are invalid', () {
      expect(
        QuestionEnvelope.parse(_v1()..['speech_policy'] = {'prompt': 'loud'}),
        isA<ParseInvalid<QuestionEnvelope>>(),
      );
      expect(
        QuestionEnvelope.parse(_v1()..['evaluation'] = {'max_attempts': 0}),
        isA<ParseInvalid<QuestionEnvelope>>(),
      );
      expect(
        QuestionEnvelope.parse(_v1()..['min_app_version'] = 'soon'),
        isA<ParseInvalid<QuestionEnvelope>>(),
      );
    });
  });

  group('AppVersion', () {
    test('compares numerically and ignores build and pre-release tags', () {
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('1.10.0') > v('1.9.3'), isTrue);
      expect(v('1.4').compareTo(v('1.4.0')), 0);
      expect(v('1.4.0+12').compareTo(v('1.4.0')), 0);
      expect(v('1.3.9-beta') < v('1.4.0'), isTrue);
      expect(AppVersion.tryParse('one'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('AnswerValue', () {
    test('every kind round-trips through JSON', () {
      final answers = <AnswerValue>[
        const SingleChoiceAnswer('a'),
        MultiSelectAnswer(['c', 'a']),
        PairsAnswer([(left: 'l2', right: 'r2'), (left: 'l1', right: 'r1')]),
        OrderingAnswer(['3', '1', '2']),
        PlacementsAnswer({'i1': 't2'}),
        TextAnswer('12'),
        BlanksAnswer({'b1': 'chat'}),
        HotspotAnswer(['r2', 'r1']),
      ];
      for (final a in answers) {
        final back = AnswerValue.fromJson(a.toJson());
        expect(back?.toJson(), a.toJson(), reason: a.kind);
      }
    });

    test(
      'order-free answers are canonicalised so equal answers hash equally',
      () {
        expect(
          MultiSelectAnswer(['b', 'a']).toJson(),
          MultiSelectAnswer(['a', 'b']).toJson(),
        );
        expect(
          HotspotAnswer(['b', 'a']).toJson(),
          HotspotAnswer(['a', 'b']).toJson(),
        );
        expect(
          OrderingAnswer(['b', 'a']).toJson(),
          isNot(OrderingAnswer(['a', 'b']).toJson()),
          reason: 'order is the answer here',
        );
      },
    );

    test('text is capped', () {
      expect(TextAnswer('x' * 500).value.length, TextAnswer.maxLength);
      expect(
        BlanksAnswer({'b': 'y' * 500}).blanks['b']!.length,
        TextAnswer.maxLength,
      );
    });

    test('an unknown or malformed answer decodes to null, never throws', () {
      expect(AnswerValue.fromJson({'kind': 'telepathy'}), isNull);
      expect(AnswerValue.fromJson({'kind': 'single_choice'}), isNull);
    });
  });

  group('Evaluation', () {
    test('a failed evaluation is ungraded and flagged for review', () {
      const r = EvaluationResult.failed(
        attemptNumber: 2,
        evaluator: 'mcq.exact@1',
      );
      expect(r.outcome, Outcome.ungraded);
      expect(r.isCorrect, isFalse);
      expect(r.needsReview, isTrue);
      expect(r.toJson()['authority'], 'local');
    });

    test('registry resolves by engine and policy and refuses duplicates', () {
      final exact = _FakeEvaluator('mcq', 'exact');
      final reg = EvaluatorRegistry([exact, _FakeEvaluator('mcq', 'lenient')]);
      expect(reg.lookup('mcq', 'exact'), same(exact));
      expect(reg.lookup('mcq', 'nope'), isNull);
      expect(exact.id, 'mcq.exact@1');
      expect(
        () => EvaluatorRegistry([exact, _FakeEvaluator('mcq', 'exact')]),
        throwsArgumentError,
      );
    });

    test('error classifications serialise with optional confidence', () {
      expect(const ErrorClassification.unclassified().isUnclassified, isTrue);
      expect(
        const ErrorClassification(
          code: 'math.add.no_regroup',
          taxonomyVersion: 1,
        ).toJson(),
        {'code': 'math.add.no_regroup', 'taxonomy_version': 1},
      );
    });
  });

  group('EngineRegistry app-version floor', () {
    final registry = EngineRegistry([_StubEngine()]);

    test('an app older than the floor is refused', () {
      final r = registry.resolve(
        engineKey: 'stub',
        minimumVersion: 1,
        minAppVersion: '2.0.0',
        appVersion: AppVersion.tryParse('1.9.9'),
      );
      expect(r, isA<AppVersionTooOld>());
    });

    test('a satisfied floor, no floor, or no app version all resolve', () {
      for (final (floor, app) in [
        ('1.0.0', '1.0.0'),
        (null, '1.0.0'),
        ('9.0.0', null),
      ]) {
        final r = registry.resolve(
          engineKey: 'stub',
          minimumVersion: 1,
          minAppVersion: floor,
          appVersion: app == null ? null : AppVersion.tryParse(app),
        );
        expect(r, isA<ResolvedEngine>(), reason: '$floor / $app');
      }
    });

    test('an unparseable floor never locks a child out', () {
      final r = registry.resolve(
        engineKey: 'stub',
        minimumVersion: 1,
        minAppVersion: 'garbage',
        appVersion: AppVersion.tryParse('0.0.1'),
      );
      expect(r, isA<ResolvedEngine>());
    });
  });

  group('SessionIds', () {
    test(
      'are deterministic per session and distinct per question and attempt',
      () {
        final ids = SessionIds.create();
        final again = SessionIds(ids.activitySessionId);
        expect(again.attemptEventId(0, 1), ids.attemptEventId(0, 1));
        expect(again.exerciseRunId(1), ids.exerciseRunId(1));
        expect({
          ids.questionInstanceId(0),
          ids.questionInstanceId(1),
          ids.attemptEventId(0, 1),
          ids.attemptEventId(0, 2),
          ids.attemptEventId(1, 1),
          ids.exerciseRunId(0),
        }, hasLength(6));
        expect(
          SessionIds.create().attemptEventId(0, 1),
          isNot(ids.attemptEventId(0, 1)),
        );
      },
    );

    test('reject a non-UUID session id', () {
      expect(() => SessionIds('not-a-uuid'), throwsArgumentError);
    });
  });

  group('ActiveClock', () {
    test('excludes paused time and resumes from a banked value', () {
      var now = Duration.zero;
      final clock = ActiveClock(monotonic: () => now, initialActiveMs: 1000);
      clock.start();
      now += const Duration(seconds: 2);
      clock.pause();
      now += const Duration(minutes: 10); // backgrounded
      expect(clock.activeMs, 3000);
      clock.start();
      now += const Duration(milliseconds: 500);
      expect(clock.activeMs, 3500);
      clock.start(); // idempotent
      expect(clock.activeMs, 3500);
    });
  });

  group('ActivitySessionStore', () {
    SessionSnapshot snap(String id, SessionState state) => SessionSnapshot(
      activitySessionId: id,
      kidId: 'kid',
      exerciseId: 'ex',
      exerciseVersion: 3,
      contentHash: 'abc',
      seed: 42,
      state: state,
      engineState: const {'selected': 'b'},
      activeMs: 1200,
      updatedAt: DateTime.utc(2026, 10, 25),
    );

    test(
      'commits events with the snapshot; terminal commits remove the session',
      () async {
        final store = InMemoryActivitySessionStore();
        await store.commit(
          events: [
            {'event_id': 'e1'},
          ],
          snapshot: snap(
            's1',
            const SessionState(
              phase: SessionPhase.awaitingInteraction,
              questionCount: 2,
            ),
          ),
        );
        await store.commit(
          events: const [],
          snapshot: snap(
            's2',
            const SessionState(
              phase: SessionPhase.awaitingInteraction,
              questionCount: 2,
            ),
          ),
        );
        // A terminal commit removes the session.
        await store.commit(
          events: const [],
          snapshot: snap(
            's2',
            const SessionState(
              phase: SessionPhase.completed,
              questionCount: 2,
              questionIndex: 2,
            ),
          ),
        );
        expect(await store.outbox.depth(), 1);

        final live = await store.live(kidId: 'kid', exerciseId: 'ex');
        expect(live!.activitySessionId, 's1');
        expect(live.engineState, {'selected': 'b'});
        expect(live.seed, 42);
        expect(await store.allLive('kid'), hasLength(1));
        expect(await store.allLive('other-kid'), isEmpty);

        await store.remove('s1');
        expect(await store.live(kidId: 'kid', exerciseId: 'ex'), isNull);
      },
    );

    test('a snapshot only matches the exact content it was played against', () {
      final s = snap('s1', SessionState.initial);
      expect(s.matches(exerciseVersion: 3, contentHash: 'abc'), isTrue);
      expect(s.matches(exerciseVersion: 4, contentHash: 'abc'), isFalse);
      expect(s.matches(exerciseVersion: 3, contentHash: 'def'), isFalse);
    });
  });

  group('runtime events', () {
    test('diagnostic categories never reach the durable stream', () {
      expect(const SessionFailed('x').category.isDurable, isFalse);
      expect(
        const AnimationDiagnostic('reaction_missing').category.isDurable,
        isFalse,
      );
      expect(
        const EvaluationFailedDiagnostic(
          questionIndex: 0,
          reason: 'x',
        ).category.isDurable,
        isFalse,
      );
      expect(
        const QuestionPresented(
          questionIndex: 0,
          questionCount: 1,
        ).category.isDurable,
        isTrue,
      );
      expect(
        const InteractionEvent('option_selected', {
          'option_id': 'a',
        }).category.isDurable,
        isTrue,
      );
    });

    test(
      'learning verdicts keep the v1 wire names aggregates already read',
      () {
        expect(
          AnswerEvaluated(
            questionIndex: 0,
            result: const EvaluationResult.failed(
              attemptNumber: 1,
              evaluator: 'e',
            ),
          ).type,
          'attempt',
        );
        expect(
          const QuestionCompleted(
            questionIndex: 0,
            attempts: 1,
            solved: true,
          ).type,
          'exercise_complete',
        );
        expect(
          const HintRequested(questionIndex: 0, hintIndex: 0).type,
          'hint_used',
        );
      },
    );

    test('submitted answers carry ids, not labels', () {
      const e = AnswerSubmitted(
        questionIndex: 0,
        attemptNumber: 1,
        answer: SingleChoiceAnswer('b'),
      );
      expect(e.payload['answer'], {'kind': 'single_choice', 'selected': 'b'});
    });
  });
}

class _FakeEvaluator implements Evaluator<Object?, SingleChoiceAnswer> {
  _FakeEvaluator(this.engineKey, this.policy);
  @override
  final String engineKey;
  @override
  final String policy;
  @override
  int get version => 1;
  @override
  EvaluationResult evaluate(
    Object? content,
    SingleChoiceAnswer answer,
    EvaluationContext context,
  ) => throw UnimplementedError();
}

class _StubEngine extends TutolysEngine {
  @override
  String get key => 'stub';
  @override
  int get version => 1;
  @override
  String get category => 'test';
  @override
  SettingsManifest get settingsManifest =>
      const SettingsManifest(engineKey: 'stub', definitions: []);
  @override
  EngineValidation validate(Map<String, Object?> config) =>
      const EngineValidation.valid();
  @override
  Widget build(EngineContext context, Map<String, Object?> config) =>
      const SizedBox();
}
