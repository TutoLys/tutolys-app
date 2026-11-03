import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The idle prompt's clock, owned by the shell (plan
/// PLAN_GRADES_2_6_ENGINES §3.3, fix 2).
///
/// An engine never times or animates the "nothing touched yet" hand. It
/// marks the tile it suggests with an `IdleHandHint`, which *arms* this
/// controller. After [wait] with nothing touched, the controller reports
/// the idle moment through [onIdle]; the shell turns that into an
/// `IdlePrompted` runtime event and, once the event comes back on the
/// session's stream, calls [cue]. Only then is the hand drawn, by
/// [IdleHand], a shell widget a future animation system can replace.
///
/// With no [onIdle] (an engine played on its own, in a test or a sample),
/// the controller cues the hand itself.
class IdleCueController extends ChangeNotifier {
  IdleCueController({this.onIdle, this.wait = defaultWait});

  /// The idle time before the hand appears.
  static const defaultWait = Duration(milliseconds: 2400);

  final Duration wait;

  /// Reports the idle moment. The host must answer with [cue].
  final void Function(String? targetId, Duration after)? onIdle;

  final Map<Object, _Armed> _armed = {};
  Object? _pending;
  Object? _cued;
  bool _disposed = false;

  /// Start waiting on [token], the target an engine suggests. Arming a
  /// token that's already armed changes nothing, so a rebuild doesn't
  /// restart the wait.
  void arm(Object token, {String? targetId, required bool reducedMotion}) {
    if (_armed.containsKey(token)) return;
    final delay = reducedMotion ? Duration.zero : wait;
    _armed[token] = _Armed(targetId, Timer(delay, () => _fire(token, delay)));
  }

  /// The target stopped waiting: touched, or gone.
  void disarm(Object token) {
    final armed = _armed.remove(token);
    if (armed == null) return;
    armed.timer.cancel();
    if (_pending == token) _pending = null;
    // No notification: only the hint that owned the token showed a hand,
    // and it disarms from its own update or disposal, so it rebuilds (or
    // goes) anyway. Notifying here would mark the scope dirty mid-build.
    if (_cued == token) _cued = null;
  }

  void _fire(Object token, Duration after) {
    final armed = _armed[token];
    if (armed == null || _disposed) return;
    final report = onIdle;
    if (report == null) {
      _cued = token;
      _notify();
      return;
    }
    _pending = token;
    report(armed.targetId, after);
  }

  /// The idle event came back: show the hand on the target that asked.
  void cue({String? targetId}) {
    final token = _pending;
    if (token == null || !_armed.containsKey(token)) return;
    if (targetId != null && _armed[token]!.targetId != targetId) return;
    _pending = null;
    _cued = token;
    _notify();
  }

  bool isCued(Object token) => _cued == token;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final a in _armed.values) {
      a.timer.cancel();
    }
    _armed.clear();
    super.dispose();
  }
}

class _Armed {
  _Armed(this.targetId, this.timer);
  final String? targetId;
  final Timer timer;
}

/// Puts the shell's [IdleCueController] where engines' hints can find it.
class IdleCueScope extends InheritedNotifier<IdleCueController> {
  const IdleCueScope({
    required IdleCueController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static IdleCueController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IdleCueScope>()?.notifier;
}

/// The pointing hand itself (UX review G3): it taps three times, then rests
/// on the tile, so the screen settles instead of moving forever. Under
/// reduced motion it's still from the start.
///
/// Decoration only: it lets taps through and says nothing to a screen
/// reader. The shell's instruction line says it in words.
class IdleHand extends StatefulWidget {
  const IdleHand({super.key});

  static const _bobs = 3;
  static const _bob = Duration(milliseconds: 800);

  @override
  State<IdleHand> createState() => _IdleHandState();
}

class _IdleHandState extends State<IdleHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IdleHand._bob * IdleHand._bobs,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      unawaited(_c.forward());
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
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, hand) {
            final t = _c.value;
            final dy = t >= 1
                ? 0.0
                : -8 * math.sin(t * IdleHand._bobs * math.pi).abs();
            return Transform.translate(offset: Offset(0, dy), child: hand);
          },
          child: Icon(
            Icons.touch_app_rounded,
            key: const ValueKey('idle-hand'),
            size: 40,
            color: p.isDark ? p.quebecBlueBright : p.quebecBlue,
            shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
