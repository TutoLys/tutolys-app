import 'package:flutter/material.dart';

/// The Arctic Fox, breathing.
///
/// A slow vertical bob, about three seconds a cycle and six pixels at the
/// top of it — small enough to read as alive rather than as motion. Leans up
/// a little further under the pointer.
///
/// Two things stop it dead, and both matter more than the animation does:
///
/// - **Reduced motion.** An idle loop is the single most irritating thing on
///   screen for a child who asked for less of it, so there is none at all —
///   it rests flat rather than animating instantly to a lifted position.
/// - **Not being visible.** `IndexedStack` keeps every tab built and *does
///   not mute tickers*, so an unguarded loop bobs forever behind Carte,
///   Profil and Réglages, spending a tablet's battery animating something
///   nobody is looking at. `Visibility.of` reads the scope `IndexedStack`
///   already provides and registers a rebuild dependency, so the ticker
///   stops the moment the tab is hidden.
class BreathingMascot extends StatefulWidget {
  const BreathingMascot({required this.height, this.hoverLift = true, super.key});

  final double height;

  /// Whether it leans further up under the pointer. Off where the fox is
  /// decoration rather than something to point at.
  final bool hoverLift;

  @override
  State<BreathingMascot> createState() => _BreathingMascotState();
}

class _BreathingMascotState extends State<BreathingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  bool _hovered = false;

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _syncTicker({required bool shouldRun}) {
    if (shouldRun && !_bob.isAnimating) {
      _bob.repeat(reverse: true);
    } else if (!shouldRun && _bob.isAnimating) {
      _bob.stop();
      _bob.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final visible = Visibility.of(context);
    _syncTicker(shouldRun: !still && visible);

    final fox = AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        // Eased, so it slows at each end instead of running at a constant
        // speed — which is what makes it read as breathing, not sliding.
        final bob =
            still ? 0.0 : -6.0 * Curves.easeInOut.transform(_bob.value);
        final lean = still || !_hovered ? 0.0 : -6.0;
        return Transform.translate(
          offset: Offset(0, bob + lean),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/asset-mascot-welcome.webp',
        height: widget.height,
        fit: BoxFit.contain,
      ),
    );

    if (!widget.hoverLift) return fox;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: fox,
    );
  }
}
