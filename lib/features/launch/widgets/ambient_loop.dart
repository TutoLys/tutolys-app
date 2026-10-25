import 'package:flutter/widgets.dart';

/// A [State] that owns one repeating "ambient" animation — a breath, a
/// shimmer, a twinkle — and knows when not to run it.
///
/// The launch screens stack several of these, and every one needs the same
/// two guards `BreathingMascot` established:
///
/// - **Reduced motion** (`MediaQuery.disableAnimations`, which `TutolysApp`
///   OR-s with the platform setting): the loop does not run at all and the
///   subclass is told to draw its resting frame, never a frozen mid-cycle
///   one.
/// - **Not visible** (`Visibility.of`, which `IndexedStack` provides): a
///   hidden loop would keep a tablet's GPU busy for nothing.
///
/// One controller per widget, repeating 0 → 1 over [period]. Subclasses read
/// [loopValue] — never the controller — so the resting frame is a single
/// well-defined value.
abstract class AmbientLoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin<T> {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: period,
  );

  /// How long one full cycle takes.
  Duration get period;

  /// Where in the cycle to rest when motion is reduced or the widget is
  /// hidden. 0 by default; a subclass whose loop is not neutral at 0 picks
  /// the frame that reads as "still".
  double get restValue => 0;

  /// Whether the loop is currently resting. True under reduced motion.
  bool get still => _still;
  bool _still = false;

  /// The current position in the cycle, 0 → 1, or [restValue] when still.
  double get loopValue => _still ? restValue : _loop.value;

  /// The animation to listen to, for an [AnimatedBuilder].
  Listenable get loop => _loop;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Starts or stops the loop from the current context. Call at the top of
  /// [build]: both inputs are inherited, so a change to either rebuilds.
  void syncLoop(BuildContext context) {
    _still = MediaQuery.disableAnimationsOf(context);
    final shouldRun = !_still && Visibility.of(context);
    if (shouldRun && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!shouldRun && _loop.isAnimating) {
      _loop.stop();
    }
  }
}
