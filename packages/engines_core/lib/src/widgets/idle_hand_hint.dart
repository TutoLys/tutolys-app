import 'package:flutter/material.dart';

import '../shell/idle_cue.dart';

/// Whether the shell wants the demonstration now (UX review N4): on a
/// série's first question, then again only after a couple of misses. It
/// replayed on every question before. Without a scope (an engine on its
/// own), the hand shows as the engine asks.
class HandDemoScope extends InheritedWidget {
  const HandDemoScope({required this.enabled, required super.child, super.key});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HandDemoScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(HandDemoScope old) => enabled != old.enabled;
}

/// Marks the tile to tap first, for a child who can't read the instruction
/// (UX review G3).
///
/// The engine only says *which* tile and *whether* the board is still
/// waiting. When the hand appears, and how it moves, belong to the shell:
/// this widget arms the shell's [IdleCueController], which reports the idle
/// moment as an `IdlePrompted` event, and draws [IdleHand] once that event
/// comes back (plan PLAN_GRADES_2_6_ENGINES §3.3, fix 2). Without a shell,
/// it keeps a controller of its own.
class IdleHandHint extends StatefulWidget {
  const IdleHandHint({
    required this.show,
    required this.child,
    this.targetId,
    super.key,
  });

  /// Whether the board is still waiting for this first tap.
  final bool show;
  final Widget child;

  /// What the hand points at, for the idle event's payload: an item id the
  /// engine already reports in its interaction events.
  final String? targetId;

  /// The idle time before the hand appears.
  static const wait = IdleCueController.defaultWait;

  @override
  State<IdleHandHint> createState() => _IdleHandHintState();
}

class _IdleHandHintState extends State<IdleHandHint> {
  final Object _token = Object();
  IdleCueController? _scoped;
  IdleCueController? _own;
  IdleCueController? _armedOn;

  IdleCueController get _cues => (_scoped ?? _own)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = IdleCueScope.maybeOf(context);
    if (!identical(scoped, _scoped) || (scoped == null && _own == null)) {
      _disarm();
      _scoped = scoped;
      if (scoped == null && _own == null) {
        _own = IdleCueController()..addListener(_changed);
      }
    }
    _sync();
  }

  @override
  void didUpdateWidget(IdleHandHint old) {
    super.didUpdateWidget(old);
    if (old.show != widget.show || old.targetId != widget.targetId) {
      _disarm();
      _sync();
    }
  }

  bool get _wanted => widget.show && HandDemoScope.of(context);

  void _sync() {
    if (!_wanted) {
      _disarm();
      return;
    }
    final cues = _cues;
    cues.arm(
      _token,
      targetId: widget.targetId,
      reducedMotion: MediaQuery.disableAnimationsOf(context),
    );
    _armedOn = cues;
  }

  void _disarm() {
    _armedOn?.disarm(_token);
    _armedOn = null;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disarm();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack with the child first, so showing or hiding the hand
    // never rebuilds the tile (and never drops its focus). Passthrough: the
    // child keeps the size it's given (a tight 64 px box stays 64 px), or
    // its tap target shrinks.
    // Under reduced motion there's no wait to dramatise: the hand is there
    // from the start, still (the idle event still goes out at once).
    final cued =
        _wanted &&
        (_cues.isCued(_token) || MediaQuery.disableAnimationsOf(context));
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (cued) const Positioned(right: 4, bottom: -14, child: IdleHand()),
      ],
    );
  }
}
