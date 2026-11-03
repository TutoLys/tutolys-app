import 'package:flutter/widgets.dart';

import 'answer.dart';
import 'envelope.dart';
import 'evaluation.dart';
import 'learning_engine.dart';
import 'parse_result.dart';
import '../runtime/runtime_event.dart';

/// A [LearningEngine] with its type parameters erased, so the runtime can
/// hold engines of different content/state/action types in one registry.
///
/// The casts live in exactly one place ([_ErasedEngine]); a wrong-typed
/// value reaching an engine is a runtime bug, and it fails here, loudly.
abstract interface class ErasedEngine {
  EngineDescriptor get descriptor;
  ParseResult<Object?> parse(Map<String, Object?> config);
  Object? initialize(Object? content, EngineSeed seed);
  Transition<Object?> reduce(Object? state, Object action);
  AnswerValue? extractAnswer(Object? state);
  Object? applyFeedback(Object? state, EvaluationResult result);

  /// Empty unless the engine implements [RevealsAfterFeedback].
  List<RevealEvent> revealsAfterFeedback(
    Object? before,
    Object? after,
    EvaluationResult result,
  );
  Map<String, Object?> snapshot(Object? state);
  Object? restore(Object? content, Map<String, Object?> snapshot);
  Widget buildView(
    BuildContext context, {
    required Object? content,
    required Object? state,
    required void Function(Object action) dispatch,
    required Locale locale,
    required bool enabled,
  });
}

/// Erase [engine]'s type parameters. Call it where the engine is
/// constructed, so `C`/`S`/`A` are inferred as the engine's real types.
ErasedEngine eraseEngine<C, S, A, Ans extends AnswerValue>(
  LearningEngine<C, S, A, Ans> engine,
) => _ErasedEngine<C, S, A, Ans>(engine);

class _ErasedEngine<C, S, A, Ans extends AnswerValue> implements ErasedEngine {
  _ErasedEngine(this.engine);
  final LearningEngine<C, S, A, Ans> engine;

  @override
  EngineDescriptor get descriptor => engine.descriptor;

  @override
  ParseResult<Object?> parse(Map<String, Object?> config) => switch (engine
      .parse(config)) {
    ParseOk(:final value) => ParseResult<Object?>.ok(value),
    ParseInvalid(:final reason) => ParseResult<Object?>.invalid(reason),
    ParseUnsupported(:final reason) => ParseResult<Object?>.unsupported(reason),
  };

  @override
  Object? initialize(Object? content, EngineSeed seed) =>
      engine.initialize(content as C, seed);

  @override
  Transition<Object?> reduce(Object? state, Object action) {
    // An action of another engine's type is meaningless here, which the
    // contract says is "unchanged, no events" — never a crash.
    final typed = action;
    if (typed is! A) return Transition<Object?>(state);
    final t = engine.reduce(state as S, typed as A);
    return Transition<Object?>(t.state, t.events);
  }

  @override
  AnswerValue? extractAnswer(Object? state) => engine.extractAnswer(state as S);

  @override
  Object? applyFeedback(Object? state, EvaluationResult result) =>
      engine.applyFeedback(state as S, result);

  @override
  List<RevealEvent> revealsAfterFeedback(
    Object? before,
    Object? after,
    EvaluationResult result,
  ) => switch (engine) {
    final RevealsAfterFeedback<S> e => e.revealsAfterFeedback(
      before as S,
      after as S,
      result,
    ),
    _ => const [],
  };

  @override
  Map<String, Object?> snapshot(Object? state) => engine.snapshot(state as S);

  @override
  Object? restore(Object? content, Map<String, Object?> snapshot) =>
      engine.restore(content as C, snapshot);

  @override
  Widget buildView(
    BuildContext context, {
    required Object? content,
    required Object? state,
    required void Function(Object action) dispatch,
    required Locale locale,
    required bool enabled,
  }) => engine.buildView(
    context,
    EngineView<C, S, A>(
      content: content as C,
      state: state as S,
      dispatch: (a) => dispatch(a as Object),
      locale: locale,
      enabled: enabled,
    ),
  );
}

/// Why an engine couldn't be resolved.
enum EngineMiss {
  /// Never heard of it, or ours is too old: an app update fixes it.
  needsUpdate,

  /// We have the engine but the content doesn't parse: a content bug.
  invalidContent,
}

sealed class LearningEngineResolution {
  const LearningEngineResolution();
}

class LearningEngineResolved extends LearningEngineResolution {
  const LearningEngineResolved(this.engine, this.content);
  final ErasedEngine engine;

  /// The question's parsed content.
  final Object? content;
}

class LearningEngineMissing extends LearningEngineResolution {
  const LearningEngineMissing(this.miss, this.reason);
  final EngineMiss miss;
  final String reason;
}

/// Engines built on [LearningEngine], by key.
///
/// Separate from the legacy [EngineRegistry] on purpose: the host asks this
/// one first, and falls back to the legacy runner only for exercises whose
/// every question this registry can't serve. Once all engines are ported the
/// legacy registry is deleted, not merged.
class LearningEngineRegistry {
  /// Engines come in already erased — `LearningEngineRegistry([
  /// eraseEngine(McqEngine())])` — because erasure must happen where the
  /// engine's static type is known. Erasing here, from a list typed
  /// `LearningEngine<Object?, …>`, would infer `Object?` for every type
  /// parameter and lose the action-type check.
  LearningEngineRegistry(Iterable<ErasedEngine> engines) : _byKey = {} {
    for (final e in engines) {
      final key = e.descriptor.key;
      if (_byKey.containsKey(key)) {
        throw ArgumentError('Duplicate engine key: $key');
      }
      _byKey[key] = e;
    }
  }

  final Map<String, ErasedEngine> _byKey;

  bool contains(String key) => _byKey.containsKey(key);

  /// Whether every question of [envelope] has an engine here.
  bool servesAll(QuestionEnvelope envelope) =>
      envelope.questions.every((q) => _byKey.containsKey(q.engineKey));

  LearningEngineResolution resolve(
    QuestionSpec question, {
    required int minimumVersion,
  }) {
    final engine = _byKey[question.engineKey];
    if (engine == null) {
      return LearningEngineMissing(
        EngineMiss.needsUpdate,
        'Unknown engine ${question.engineKey}',
      );
    }
    if (engine.descriptor.version < minimumVersion) {
      return LearningEngineMissing(
        EngineMiss.needsUpdate,
        'Engine ${question.engineKey} v${engine.descriptor.version} < required v$minimumVersion',
      );
    }
    return switch (engine.parse(question.config)) {
      ParseOk(:final value) => LearningEngineResolved(engine, value),
      ParseInvalid(:final reason) => LearningEngineMissing(
        EngineMiss.invalidContent,
        reason,
      ),
      ParseUnsupported(:final reason) => LearningEngineMissing(
        EngineMiss.needsUpdate,
        reason,
      ),
    };
  }
}
