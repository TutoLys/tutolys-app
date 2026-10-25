import 'dart:async';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import 'activity_shell.dart';
import 'shell_strings.dart';

/// The shell, bound to an [ActivitySessionController].
///
/// Renders whatever the controller says and forwards every gesture to it;
/// it decides nothing itself. Audio and characters stay outside: the host
/// passes [onSpeakPrompt] (which plays through the app's audio coordinator)
/// and a [character] widget (the motion package's stage), so this view
/// never learns either exists.
class LearningActivityView extends StatefulWidget {
  const LearningActivityView({
    required this.controller,
    required this.locale,
    required this.onDone,
    this.speakPrompt,
    this.character,
    this.hintsEnabled = true,
    this.xpEarned,
    super.key,
  });

  final ActivitySessionController controller;
  final Locale locale;

  /// The session ended (completed, abandoned or failed) and the child
  /// pressed on — leave the screen.
  final VoidCallback onDone;

  /// The speaker button's action for [question], or null when that prompt
  /// has nothing that may be read aloud — then no button is drawn, rather
  /// than one that does nothing.
  final VoidCallback? Function(QuestionSpec question)? speakPrompt;
  final Widget? character;
  final bool hintsEnabled;

  /// XP to show so far; null hides the pill.
  final int Function()? xpEarned;

  @override
  State<LearningActivityView> createState() => _LearningActivityViewState();
}

class _LearningActivityViewState extends State<LearningActivityView> {
  late StreamSubscription<RuntimeEvent> _sub;
  int _inARow = 0;
  bool _hintRevealed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(LearningActivityView old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      unawaited(_sub.cancel());
      _listen();
    }
  }

  void _listen() {
    _sub = widget.controller.events.listen((e) {
      switch (e) {
        case QuestionCompleted(:final attempts, :final solved):
          _inARow = solved && attempts == 1 ? _inARow + 1 : 0;
        case QuestionPresented():
          _hintRevealed = false;
        case ActivityCompleted():
          // The child just pressed Continuer on the last banner; a second
          // "well done" screen would only be one more tap.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDone();
          });
        case _:
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final c = widget.controller;
    final s = ShellStrings.of(widget.locale);
    final state = c.state;

    if (state.phase == SessionPhase.failed) {
      return ActivityShell(
        locale: widget.locale,
        onClose: widget.onDone,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            c.failure == ActivityFailure.needsUpdate
                ? s.needsUpdate
                : s.invalidContent,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final q = c.current;
    final count = state.questionCount == 0 ? 1 : state.questionCount;
    final done =
        state.questionsCompleted +
        (state.phase == SessionPhase.feedback &&
                state.lastOutcome == Outcome.correct
            ? 1
            : 0);

    ShellFeedback? feedback;
    if (state.phase == SessionPhase.feedback) {
      final outcome = state.lastOutcome;
      if (outcome == Outcome.correct) {
        feedback = ShellFeedback(
          kind: ShellFeedbackKind.correct,
          title: s.correctTitle,
          message: s.correctMessage,
          actionLabel: s.continueLabel,
          onAction: c.proceed,
        );
      } else if (outcome == Outcome.ungraded) {
        feedback = ShellFeedback(
          kind: ShellFeedbackKind.neutral,
          title: s.movingOnTitle,
          message: s.ungradedMessage,
          actionLabel: s.continueLabel,
          onAction: c.proceed,
        );
      } else if (state.canRetry) {
        feedback = ShellFeedback(
          kind: ShellFeedbackKind.retry,
          title: s.retryTitle,
          message: s.retryMessage,
          actionLabel: s.retryLabel,
          onAction: c.proceed,
        );
      } else {
        feedback = ShellFeedback(
          kind: ShellFeedbackKind.neutral,
          title: s.movingOnTitle,
          message: s.movingOnMessage,
          actionLabel: s.continueLabel,
          onAction: c.proceed,
        );
      }
    }

    final interactive = c.isInteractive;
    final hint = q?.hintText;
    final explicit = q?.engine.descriptor.submitMode == SubmitMode.explicit;

    return ActivityShell(
      locale: widget.locale,
      onClose: () async {
        await c.exit();
        widget.onDone();
      },
      progress: state.phase.isTerminal ? 1 : done / count,
      progressLabel: s.questionOf(
        (state.questionIndex + 1).clamp(1, count),
        count,
      ),
      xp: widget.xpEarned?.call(),
      inARow: _inARow,
      promptText: q?.spec.prompt.text,
      onSpeak: q == null ? null : widget.speakPrompt?.call(q.spec),
      character: widget.character,
      revealedHint: _hintRevealed ? hint : null,
      onHint:
          hint == null || !widget.hintsEnabled || _hintRevealed || !interactive
          ? null
          : () {
              setState(() => _hintRevealed = true);
              unawaited(c.requestHint());
            },
      showValidate: explicit && feedback == null,
      onValidate: interactive && q?.answer != null ? c.submit : null,
      feedback: feedback,
      notice: c.failure == ActivityFailure.storage ? s.storageError : null,
      body: q == null
          ? const SizedBox.shrink()
          : q.engine.buildView(
              context,
              content: q.content,
              state: q.state,
              dispatch: (a) => unawaited(c.dispatch(a)),
              locale: widget.locale,
              enabled: interactive,
            ),
    );
  }
}
