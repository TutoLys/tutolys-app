import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../single_choice/single_choice_engine.dart';
import '../widgets/answer_tile.dart';
import '../widgets/countdown_bar.dart';

class TimedChoiceContent {
  const TimedChoiceContent({required this.choice, this.timeLimit});

  /// The same options/correct/shuffle shape as `mcq` — the backend's
  /// `speed_tap` schema is `mcq` plus an optional `time_limit_ms`.
  final SingleChoiceContent choice;

  /// Null: no countdown, no timeout — a tap is the answer and the child
  /// takes as long as they need. **Every regular lesson is untimed**
  /// (Hafid, 2026-10-25); a limit is for future diagnostic tests only
  /// (ADR 0042).
  final Duration? timeLimit;

  bool get timed => timeLimit != null;
}

class TimedChoiceState {
  const TimedChoiceState({
    required this.order,
    this.selected,
    this.tried = const {},
    this.solved = false,
    this.timedOut = false,
    this.round = 0,
    this.timed = true,
  });

  final List<String> order;
  final String? selected;
  final Set<String> tried;
  final bool solved;

  /// The countdown for this [round] ran out before any tap.
  final bool timedOut;

  /// Bumped after every verdict, so each retry gets a fresh countdown and a
  /// stale [TimeUp] from the previous one is ignored.
  final int round;

  /// Whether the content has a countdown. From the content, never the
  /// snapshot: the reducer can't see the content, and an untimed question
  /// must ignore any [TimeUp].
  final bool timed;

  TimedChoiceState copyWith({
    String? selected,
    bool clearSelected = false,
    Set<String>? tried,
    bool? solved,
    bool? timedOut,
    int? round,
  }) => TimedChoiceState(
    order: order,
    selected: clearSelected ? null : (selected ?? this.selected),
    tried: tried ?? this.tried,
    solved: solved ?? this.solved,
    timedOut: timedOut ?? this.timedOut,
    round: round ?? this.round,
    timed: timed,
  );
}

sealed class TimedChoiceAction {
  const TimedChoiceAction();
}

class TapOption extends TimedChoiceAction {
  const TapOption(this.optionId);
  final String optionId;
}

/// The countdown for [round] ended. Sent by the view, which owns the clock.
class TimeUp extends TimedChoiceAction {
  const TimeUp(this.round);
  final int round;
}

/// Tap the answer — the `speed_tap` engine on the `LearningEngine`
/// contract (Phase 4), **untimed unless the content sets a limit**.
///
/// A tap *is* the answer here ([SubmitMode.immediate]): there's no VALIDER.
/// Without `time_limit_ms` there is no countdown and no timeout, so it
/// plays as a single choice answered by tapping — what every regular
/// lesson uses (Hafid: timing a grade-1 lesson "does not make any sense").
/// A limit is kept for future diagnostic tests only (ADR 0042).
///
/// When timed, running out of time is a [NoResponseAnswer], an
/// attempt that's wrong about speed, not about the content, and the child
/// retries with a fresh countdown — the same forgiving contract as before
/// (ADR 0005). Like `mcq`, a tried option stays marked.
///
/// The engine is pure: the countdown lives in [CountdownBar], which sends
/// [TimeUp] for the round it was started for.
class TimedChoiceEngine
    implements
        LearningEngine<
          TimedChoiceContent,
          TimedChoiceState,
          TimedChoiceAction,
          AnswerValue
        > {
  const TimedChoiceEngine();

  static const key = 'speed_tap';

  @override
  EngineDescriptor get descriptor => const EngineDescriptor(
    key: key,
    version: 1,
    submitMode: SubmitMode.immediate,
    capabilities: EngineCapabilities(keyboard: true, screenReader: true),
  );

  @override
  ParseResult<TimedChoiceContent> parse(Map<String, Object?> config) {
    final limit = config['time_limit_ms'];
    // Absent, null or 0 all mean untimed.
    final timed = limit != null && limit != 0;
    if (timed && (limit is! int || limit < 1000 || limit > 60000)) {
      return const ParseResult.invalid(
        'time_limit_ms, when set, is an integer between 1000 and 60000.',
      );
    }
    return switch (const SingleChoiceEngine().parse(config)) {
      ParseOk(:final value) => ParseResult.ok(
        TimedChoiceContent(
          choice: value,
          timeLimit: timed ? Duration(milliseconds: limit as int) : null,
        ),
      ),
      ParseInvalid(:final reason) => ParseResult.invalid(reason),
      ParseUnsupported(:final reason) => ParseResult.unsupported(reason),
    };
  }

  @override
  TimedChoiceState initialize(TimedChoiceContent content, EngineSeed seed) =>
      TimedChoiceState(
        order: const SingleChoiceEngine()
            .initialize(content.choice, seed)
            .order,
        timed: content.timed,
      );

  @override
  Transition<TimedChoiceState> reduce(
    TimedChoiceState s,
    TimedChoiceAction action,
  ) {
    if (s.solved || s.selected != null || s.timedOut) return Transition(s);
    switch (action) {
      case TapOption(:final optionId):
        if (!s.order.contains(optionId) || s.tried.contains(optionId)) {
          return Transition(s);
        }
        return Transition(s.copyWith(selected: optionId), [
          InteractionEvent('option_selected', {'option_id': optionId}),
        ]);
      case TimeUp(:final round):
        // An untimed question has no countdown to run out.
        if (!s.timed || round != s.round) return Transition(s);
        return Transition(s.copyWith(timedOut: true), [
          InteractionEvent('time_expired', {'round': round}),
        ]);
    }
  }

  @override
  AnswerValue? extractAnswer(TimedChoiceState s) {
    if (s.solved) return null;
    if (s.timedOut) return NoResponseAnswer.timeout;
    final picked = s.selected;
    return picked == null ? null : SingleChoiceAnswer(picked);
  }

  @override
  TimedChoiceState applyFeedback(TimedChoiceState s, EvaluationResult result) {
    if (result.isCorrect) return s.copyWith(solved: true);
    final picked = s.selected;
    return s.copyWith(
      clearSelected: true,
      timedOut: false,
      round: s.round + 1,
      tried: picked == null || result.outcome == Outcome.ungraded
          ? s.tried
          : {...s.tried, picked},
    );
  }

  @override
  Map<String, Object?> snapshot(TimedChoiceState s) => {
    'order': s.order,
    'selected': s.selected,
    'tried': s.tried.toList(),
    'solved': s.solved,
    'timed_out': s.timedOut,
    'round': s.round,
  };

  @override
  TimedChoiceState? restore(
    TimedChoiceContent content,
    Map<String, Object?> snap,
  ) {
    final base = const SingleChoiceEngine().restore(content.choice, snap);
    if (base == null) return null;
    final round = snap['round'];
    return TimedChoiceState(
      order: base.order,
      selected: base.selected,
      tried: base.tried,
      solved: base.solved,
      timedOut: content.timed && snap['timed_out'] == true,
      round: round is int ? round : 0,
      timed: content.timed,
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    EngineView<TimedChoiceContent, TimedChoiceState, TimedChoiceAction> view,
  ) {
    final fr = view.locale.languageCode == 'fr';
    final s = view.state;
    final live = view.enabled && !s.solved && s.selected == null && !s.timedOut;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (view.content.timed) ...[
              CountdownBar(
                duration: view.content.timeLimit!,
                round: s.round,
                running: live,
                onExpired: () => view.dispatch(TimeUp(s.round)),
                semanticsLabel: fr ? 'Temps restant' : 'Time left',
              ),
              const SizedBox(height: 16),
            ],
            for (final id in s.order) ...[
              AnswerTile(
                key: ValueKey('speed-option-$id'),
                label: view.content.choice.option(id)!.label,
                imageRef: view.content.choice.option(id)!.imageRef,
                audioRef: view.content.choice.option(id)!.audioRef,
                state: switch (id) {
                  _ when s.tried.contains(id) => AnswerTileState.retry,
                  _ when s.selected == id && s.solved =>
                    AnswerTileState.correct,
                  _ when s.selected == id => AnswerTileState.picked,
                  _ => AnswerTileState.idle,
                },
                semanticsState: s.tried.contains(id)
                    ? (fr ? 'déjà essayé' : 'already tried')
                    : null,
                onTap: live && !s.tried.contains(id)
                    ? () => view.dispatch(TapOption(id))
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grades a `speed_tap` answer: the right option, in time.
///
/// A timeout is incorrect with `feedbackCode: timeout` and no error
/// classification: running out of time says nothing about which
/// misconception, if any, the child holds.
class SpeedTapExactEvaluator
    implements Evaluator<TimedChoiceContent, AnswerValue> {
  const SpeedTapExactEvaluator();

  @override
  String get engineKey => TimedChoiceEngine.key;

  @override
  String get policy => 'exact';

  @override
  int get version => 1;

  @override
  EvaluationResult evaluate(
    TimedChoiceContent content,
    AnswerValue answer,
    EvaluationContext ctx,
  ) {
    final id = '$engineKey.$policy@$version';
    return switch (answer) {
      NoResponseAnswer() => EvaluationResult(
        outcome: Outcome.incorrect,
        score: 0,
        attemptNumber: ctx.attemptNumber,
        evaluator: id,
        feedbackCode: 'timeout',
        skillNodeIds: ctx.skillNodeIds,
      ),
      SingleChoiceAnswer() => () {
        final r = const McqExactEvaluator().evaluate(
          content.choice,
          answer,
          ctx,
        );
        return EvaluationResult(
          outcome: r.outcome,
          score: r.score,
          attemptNumber: r.attemptNumber,
          evaluator: id,
          errors: r.errors,
          skillNodeIds: r.skillNodeIds,
        );
      }(),
      _ => throw ArgumentError(
        'speed_tap cannot grade a ${answer.kind} answer',
      ),
    };
  }
}
