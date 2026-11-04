import 'dart:math';

import 'package:flutter/widgets.dart';

import 'answer.dart';
import 'evaluation.dart';
import 'parse_result.dart';
import '../runtime/runtime_event.dart';

/// How an answer leaves the engine.
enum SubmitMode {
  /// The shell's VALIDER button submits whatever [LearningEngine.extractAnswer]
  /// returns. The design's model, and the default for new engines (doc §10 D3).
  explicit,

  /// The engine's state becomes submittable on its own — the last pair
  /// connected, the last tile placed — and the shell submits immediately.
  onComplete,

  /// Every tap is an answer. Today's four engines behave this way; the
  /// legacy host runs them in this mode until each is ported.
  immediate,
}

/// What an engine can do for accessibility, declared rather than assumed so
/// the shell can say "this activity needs a pointer" instead of failing
/// silently.
class EngineCapabilities {
  const EngineCapabilities({
    this.keyboard = false,
    this.screenReader = false,
    this.requiresDrag = false,
    this.speakableOptions = false,
  });

  /// Completable with keyboard alone.
  final bool keyboard;

  /// Every interactive element has semantics.
  final bool screenReader;

  /// True only if there is *no* non-drag path. Should be false for every
  /// engine: brief §20 requires alternatives to drag-only interaction.
  final bool requiresDrag;

  /// Options can be read aloud individually.
  final bool speakableOptions;
}

/// Identity and compatibility of an engine implementation.
class EngineDescriptor {
  const EngineDescriptor({
    required this.key,
    required this.version,
    this.submitMode = SubmitMode.explicit,
    this.capabilities = const EngineCapabilities(),
  });

  /// Stable, matching the backend's `Engine.key`. `mcq` stays `mcq` — it is
  /// the brief's "single choice", but renaming it would orphan every
  /// exercise, attempt and mastery row tagged with it (doc §10 D1).
  final String key;

  /// The highest content-contract version this implementation parses. The
  /// envelope's `engine_min_version` (the backend's `Engine.current_version`)
  /// is checked against it, so this is also the content-schema axis.
  final int version;
  final SubmitMode submitMode;
  final EngineCapabilities capabilities;
}

/// The seed an engine derives all randomness from.
///
/// Stored in the session snapshot and logged on `exercise_start`, so an
/// option order a child saw can be reproduced exactly — after a resume, or
/// when someone asks why a question looked the way it did.
class EngineSeed {
  const EngineSeed(this.value);
  final int value;

  Random random() => Random(value);
}

/// A state change plus the interaction events it produced.
///
/// Events are semantic and state-based — "option b selected", not "pointer
/// moved". The engine never decides whether one is persisted or what
/// reacts to it; the runtime does.
class Transition<S> {
  const Transition(this.state, [this.events = const []]);
  final S state;
  final List<InteractionEvent> events;
}

/// What an engine's view receives. The view renders [state] and reports
/// gestures through [dispatch]; it holds no state of its own beyond
/// ephemeral UI (a drag in flight, a focus ring).
class EngineView<C, S, A> {
  const EngineView({
    required this.content,
    required this.state,
    required this.dispatch,
    required this.locale,
    required this.enabled,
    Locale? contentLocale,
  }) : contentLocale = contentLocale ?? locale;

  final C content;
  final S state;
  final void Function(A action) dispatch;

  /// The app's language: what the board's own words follow.
  final Locale locale;

  /// The lesson's language, which can differ: an English app serves the
  /// French lesson until an English one exists (app ADR 0023). Anything
  /// that must agree with the prompt follows this, not [locale].
  final Locale contentLocale;

  /// False while evaluating or showing feedback, so a second tap cannot
  /// race the first answer.
  final bool enabled;
}

/// An interactive question type, as a deterministic state machine.
///
/// Everything except [buildView] is pure — no I/O, no clock, no global
/// randomness — which is what makes an engine testable without widgets and
/// resumable after a crash. The engine never sees audio, characters,
/// telemetry storage or the network; it produces state, interaction events
/// and an answer, and the runtime coordinates everything else.
///
/// The four engines built before this contract implement `TutolysEngine`
/// instead and keep working through the legacy host until each is ported.
abstract interface class LearningEngine<C, S, A, Ans extends AnswerValue> {
  EngineDescriptor get descriptor;

  /// Validate and type one question's `config`. The runtime boundary: raw
  /// JSON in, typed content or a reason out.
  ParseResult<C> parse(Map<String, Object?> config);

  /// Initial state. Same content + same seed → same state, always.
  S initialize(C content, EngineSeed seed);

  /// Apply one learner action. An action that is meaningless in the current
  /// state returns the state unchanged with no events — never throws.
  Transition<S> reduce(S state, A action);

  /// The answer as it stands, or null if the state isn't submittable yet
  /// (nothing selected).
  Ans? extractAnswer(S state);

  /// React to a verdict without knowing why it was given — e.g. lock the
  /// option that was just tried, or clear a wrong placement for a retry.
  S applyFeedback(S state, EvaluationResult result);

  /// Serialise state for the session store. Must round-trip through
  /// [restore] to an equal state.
  Map<String, Object?> snapshot(S state);

  /// Rebuild state from [snapshot]. Returns null if the snapshot is
  /// unusable (written by an incompatible version), and the runtime starts
  /// the question fresh rather than guessing.
  S? restore(C content, Map<String, Object?> snapshot);

  Widget buildView(BuildContext context, EngineView<C, S, A> view);
}

/// An engine whose verdict *shows* something: the scale tips, the audience
/// reacts. [LearningEngine.applyFeedback] returns state only, so an engine
/// that has a moment to report implements this too, and the runtime emits
/// what it returns right after the verdict. Optional: no other engine has
/// to change.
abstract interface class RevealsAfterFeedback<S> {
  /// What [after] shows that [before] didn't. Usually one [RevealEvent].
  List<RevealEvent> revealsAfterFeedback(
    S before,
    S after,
    EvaluationResult result,
  );
}
