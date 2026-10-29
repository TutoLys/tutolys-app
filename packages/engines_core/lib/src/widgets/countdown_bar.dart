import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A visible countdown that tells the engine when time is up.
///
/// The engine stays pure: time is the one thing it can't compute, so this
/// widget owns the clock and reports the end as an action ([onExpired]).
/// It runs only while [running] — never while an answer is being checked,
/// feedback is showing or the session is paused — and restarts whenever
/// [round] changes, so each retry gets the full time.
///
/// Never the only signal: the remaining seconds are also given to screen
/// readers.
class CountdownBar extends StatefulWidget {
  const CountdownBar({
    required this.duration,
    required this.round,
    required this.running,
    required this.onExpired,
    required this.semanticsLabel,
    super.key,
  });

  final Duration duration;
  final int round;
  final bool running;
  final VoidCallback onExpired;

  /// "Temps restant" / "Time left".
  final String semanticsLabel;

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar>
    with SingleTickerProviderStateMixin {
  // `preserve`: a functional timer must not speed up 20x when the platform's
  // reduce-animations setting is on, as a decorative one would.
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: widget.duration,
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && widget.running) {
          widget.onExpired();
        }
      });

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.forward();
  }

  @override
  void didUpdateWidget(CountdownBar old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) _c.duration = widget.duration;
    if (old.round != widget.round) {
      _c.value = 0;
    }
    if (widget.running && !_c.isAnimating && !_c.isCompleted) {
      _c.forward();
    } else if (!widget.running && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final left = 1 - _c.value;
        final seconds = (widget.duration.inMilliseconds * left / 1000).ceil();
        return Semantics(
          label: widget.semanticsLabel,
          value: '$seconds s',
          child: ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: p.track)),
                  FractionallySizedBox(
                    // Full height: a childless box in a Stack is otherwise
                    // sized to zero, and the fill never shows.
                    heightFactor: 1,
                    widthFactor: left,
                    child: ColoredBox(
                      // Gold for « hurry », never amber: amber means
                      // « wrong » everywhere else (UX review G17).
                      color: left < .25 ? p.gold : p.quebecBlueBright,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
