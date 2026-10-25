import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';

import 'timeline_axis_engine.dart';
import 'timeline_order_engine.dart';

/// The registered `timeline_calendar` engine: order mode or axis mode,
/// chosen by the content's `mode` (ADR 0030).
///
/// One key, because the content's own author (the Questions Maker) asked
/// for one engine, and because a série mixing "put these in order" with
/// "put them on the line" is one lesson. Each mode is its own engine with
/// typed content, state and actions; this only routes to it. A state or
/// action of the other mode reaching a delegate is a runtime bug, and the
/// casts fail loudly, the same contract `eraseEngine` keeps.
class TimelineCalendarEngine
    implements LearningEngine<Object, Object, Object, AnswerValue> {
  const TimelineCalendarEngine();

  static const key = TimelineOrderEngine.key;
  static const _order = TimelineOrderEngine();
  static const _axis = TimelineAxisEngine();

  @override
  EngineDescriptor get descriptor => _order.descriptor;

  @override
  ParseResult<Object> parse(Map<String, Object?> config) {
    final mode = config['mode'];
    final ParseResult<Object> result = switch (mode) {
      null || 'order' => _order.parse(config),
      'axis' => _axis.parse(config),
      _ => const ParseResult.invalid('mode is order or axis.'),
    };
    return result;
  }

  @override
  Object initialize(Object content, EngineSeed seed) => switch (content) {
    AxisContent() => _axis.initialize(content, seed),
    _ => _order.initialize(content as TimelineContent, seed),
  };

  @override
  Transition<Object> reduce(Object state, Object action) => switch (state) {
    AxisState() => _axis.reduce(state, action as AxisAction),
    _ => _order.reduce(state as TimelineState, action as TimelineAction),
  };

  @override
  AnswerValue? extractAnswer(Object state) => switch (state) {
    AxisState() => _axis.extractAnswer(state),
    _ => _order.extractAnswer(state as TimelineState),
  };

  @override
  Object applyFeedback(Object state, EvaluationResult result) =>
      switch (state) {
        AxisState() => _axis.applyFeedback(state, result),
        _ => _order.applyFeedback(state as TimelineState, result),
      };

  @override
  Map<String, Object?> snapshot(Object state) => switch (state) {
    AxisState() => _axis.snapshot(state),
    _ => _order.snapshot(state as TimelineState),
  };

  @override
  Object? restore(Object content, Map<String, Object?> snapshot) =>
      switch (content) {
        AxisContent() => _axis.restore(content, snapshot),
        _ =>
          snapshot['mode'] == 'axis'
              ? null
              : _order.restore(content as TimelineContent, snapshot),
      };

  @override
  Widget buildView(
    BuildContext context,
    EngineView<Object, Object, Object> view,
  ) => switch (view.content) {
    final AxisContent c => _axis.buildView(
      context,
      EngineView(
        content: c,
        state: view.state as AxisState,
        dispatch: view.dispatch,
        locale: view.locale,
        enabled: view.enabled,
      ),
    ),
    final c => _order.buildView(
      context,
      EngineView(
        content: c as TimelineContent,
        state: view.state as TimelineState,
        dispatch: view.dispatch,
        locale: view.locale,
        enabled: view.enabled,
      ),
    ),
  };
}

/// Grades either mode, by the content it is given.
class TimelineCalendarEvaluator implements Evaluator<Object, AnswerValue> {
  const TimelineCalendarEvaluator();

  @override
  String get engineKey => TimelineCalendarEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    Object content,
    AnswerValue answer,
    EvaluationContext ctx,
  ) => switch (content) {
    final AxisContent c => const TimelineAxisEvaluator().evaluate(
      c,
      answer as PlacementsAnswer,
      ctx,
    ),
    final c => const TimelineOrderEvaluator().evaluate(
      c as TimelineContent,
      answer as OrderingAnswer,
      ctx,
    ),
  };
}
