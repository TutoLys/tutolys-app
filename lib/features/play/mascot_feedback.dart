import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/foundation.dart';

/// Drives `TutolysMascot`'s mood from an engine's reaction calls — the one
/// shared "what does the fox do" layer every engine gets for free, on top of
/// whatever visual feedback the engine shows itself (a flash, a checkmark).
///
/// Every engine `await`s these calls directly before letting the kid answer
/// again (confirmed in `mcq_engine.dart`/`pair_match_engine.dart`/
/// `compose_build_engine.dart`), so the hold duration here is a real,
/// user-facing pause — brief and purposeful by design, not a lingering
/// animation competing with the next question for attention.
class MascotEngineFeedback implements EngineFeedback {
  MascotEngineFeedback({this.hold = const Duration(milliseconds: 900)});

  /// How long a reaction shows before settling back to idle. Every engine
  /// `await`s a reaction call directly, so this is a real pause in the
  /// kid's flow — kept short and purposeful by default, not a knob meant
  /// to be tuned long.
  final Duration hold;

  /// What the mascot should show right now. The play screen watches this
  /// directly to build a `TutolysMascot` — `EngineFeedback` has no
  /// reference to any widget itself, by design (`EngineContext`'s own doc
  /// comment: an engine's host surface is exactly this contract, nothing
  /// wider).
  final ValueNotifier<MascotMood> mood = ValueNotifier(MascotMood.idle);

  @override
  Future<void> correct() => _show(MascotMood.correct);

  @override
  Future<void> incorrect() => _show(MascotMood.incorrect);

  @override
  Future<void> celebrate() => _show(MascotMood.celebrating);

  @override
  Future<void> hint() => _show(MascotMood.hint);

  Future<void> _show(MascotMood next) async {
    mood.value = next;
    await Future<void>.delayed(hold);
    mood.value = MascotMood.idle;
  }

  void dispose() => mood.dispose();
}
