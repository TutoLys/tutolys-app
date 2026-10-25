import 'dart:async';

import 'package:flutter/material.dart';

/// Cycles through [messages], one every [interval], with a soft cross-fade.
///
/// Give it a new list and it starts that list from the top — that is how the
/// loader moves from "getting things ready" lines to "almost there" lines:
/// it swaps the list, it never fast-forwards the timer. A one-item list just
/// shows that item.
///
/// With [loop] off it holds on the last message instead of wrapping, so a
/// list that tells a story can't restart it mid-wait.
///
/// The timer runs regardless of reduced motion — changing text is
/// information, not movement — but the cross-fade becomes an instant swap.
class TutolysLoadingMessageRotator extends StatefulWidget {
  const TutolysLoadingMessageRotator({
    required this.messages,
    this.interval = const Duration(milliseconds: 1800),
    this.loop = true,
    this.initialIndex = 0,
    this.style,
    super.key,
  });

  /// At least one line.
  final List<String> messages;
  final Duration interval;
  final bool loop;

  /// Where the first list starts. Out-of-range values wrap. Later lists
  /// always start from their own first line.
  final int initialIndex;

  final TextStyle? style;

  @override
  State<TutolysLoadingMessageRotator> createState() =>
      _TutolysLoadingMessageRotatorState();
}

class _TutolysLoadingMessageRotatorState
    extends State<TutolysLoadingMessageRotator> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.messages.length;
    _index = n == 0 ? 0 : widget.initialIndex % n;
    _start();
  }

  @override
  void didUpdateWidget(TutolysLoadingMessageRotator old) {
    super.didUpdateWidget(old);
    if (!_sameMessages(old.messages, widget.messages) ||
        old.interval != widget.interval) {
      _index = 0;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    if (widget.messages.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      final last = widget.messages.length - 1;
      if (_index >= last && !widget.loop) {
        _timer?.cancel();
        return;
      }
      setState(() => _index = _index >= last ? 0 : _index + 1);
    });
  }

  static bool _sameMessages(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    assert(widget.messages.isNotEmpty, 'TutolysLoadingMessageRotator needs at least one line');
    final text = widget.messages[_index.clamp(0, widget.messages.length - 1)];

    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // Every line in the same box height, so swapping a long line for a
        // short one doesn't nudge the layout above it.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: widget.style,
        ),
      ),
    );
  }
}
