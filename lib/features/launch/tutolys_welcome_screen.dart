import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';
import 'widgets/ambient_loop.dart';
import 'widgets/launch_backdrop.dart';
import 'widgets/tutolys_animated_logo.dart';

/// The title screen: "press start" for TutoLys.
///
/// Shown once per cold start, after the loader — the moment the night sky of
/// the loader turns to dawn over the village. The fox greets the child, and
/// one gold button starts the day:
///
/// - paired: "Salut Yelhan !" and **Jouer**, into the Village;
/// - not yet paired: an invitation and **Commencer l'aventure**, into
///   pairing.
///
/// It is also where "Qui joue ?" belongs once a device can hold several
/// kids (B-A0.4/B-A0.5): this is the one screen every session passes.
///
/// The village along the bottom shows all six subjects, matching the
/// Village scene (which shows Culture québécoise as "coming soon"). It is
/// decoration here, so nothing marks which ones have content yet.
class TutolysWelcomeScreen extends StatefulWidget {
  const TutolysWelcomeScreen({required this.onStart, this.kidName, super.key});

  /// The paired kid's first name, or null on an unpaired device.
  final String? kidName;

  final VoidCallback onStart;

  @override
  State<TutolysWelcomeScreen> createState() => _TutolysWelcomeScreenState();
}

class _TutolysWelcomeScreenState extends State<TutolysWelcomeScreen>
    with SingleTickerProviderStateMixin {
  // The entrance: logo, then the fox popping in, then the bubble, then the
  // button — one controller, staggered by interval, played once.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _start() {
    // One tap starts the day; a second, impatient tap during the hand-over
    // must not start it twice.
    if (_started) return;
    _started = true;
    widget.onStart();
  }

  Animation<double> _stage(double from, double to, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(parent: _enter, curve: Interval(from, to, curve: curve));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final name = widget.kidName;

    return Material(
      color: LaunchBackdrop.night,
      child: LaunchBackdrop(
        dawn: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = math.min(box.maxHeight / 820, box.maxWidth / 440).clamp(0.6, 1.2);
            final horizon = 150.0 * scale;

            return Stack(
              children: [
                // The village on the horizon.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: horizon + 40 * scale,
                  child: _FadeUp(
                    animation: _stage(0.0, 0.5),
                    child: _VillageHorizon(height: horizon),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    // Clear of the tallest building (0.95 of the horizon)
                    // plus a gap, so the button never sits on the roofs:
                    // on a wide, short window the column used to overlap
                    // them.
                    padding: EdgeInsets.only(bottom: horizon * 1.05),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FadeUp(
                              animation: _stage(0.0, 0.4),
                              child: Column(
                                children: [
                                  TutolysAnimatedLogo(size: 92 * scale, sparkles: false),
                                  SizedBox(height: 14 * scale),
                                  TutolysWordmark(fontSize: 46 * scale),
                                  SizedBox(height: 8 * scale),
                                  Text(
                                    s.welcomeTagline,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: VillageType.display,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17 * scale,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 26 * scale),
                            _FadeUp(
                              animation: _stage(0.35, 0.7),
                              child: _SpeechBubble(
                                title: name == null ? null : s.welcomeGreeting(name),
                                line: name == null ? s.welcomeFoxLineNew : s.welcomeFoxLine,
                                scale: scale,
                              ),
                            ),
                            SizedBox(height: 6 * scale),
                            ScaleTransition(
                              scale: _stage(0.2, 0.75, curve: Curves.elasticOut),
                              child: BreathingMascot(height: 170 * scale, hoverLift: false),
                            ),
                            SizedBox(height: 22 * scale),
                            _FadeUp(
                              animation: _stage(0.6, 1.0),
                              child: _GlowingCta(
                                label: name == null ? s.welcomeStart : s.welcomePlay,
                                scale: scale,
                                onPressed: _start,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.line, required this.scale, this.title});

  final String? title;
  final String line;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 340 * scale),
          padding: EdgeInsets.symmetric(horizontal: 22 * scale, vertical: 14 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22 * scale),
            boxShadow: const [
              BoxShadow(color: Color(0x40102A66), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 24 * scale,
                    height: 1.15,
                    color: VillageColors.quebecBlue,
                  ),
                ),
              Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 17 * scale,
                  height: 1.25,
                  color: VillageColors.ink,
                ),
              ),
            ],
          ),
        ),
        // The tail, pointing down at the fox.
        CustomPaint(
          size: Size(22 * scale, 12 * scale),
          painter: _TailPainter(),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}

/// The design's gold pill CTA, at title-screen size, with a slow halo that
/// pulses around it — the one thing on the screen that asks to be pressed.
class _GlowingCta extends StatefulWidget {
  const _GlowingCta({required this.label, required this.scale, required this.onPressed});

  final String label;
  final double scale;
  final VoidCallback onPressed;

  @override
  State<_GlowingCta> createState() => _GlowingCtaState();
}

class _GlowingCtaState extends AmbientLoopState<_GlowingCta> {
  bool _pressed = false;

  @override
  Duration get period => const Duration(milliseconds: 2200);

  @override
  Widget build(BuildContext context) {
    syncLoop(context);
    final scale = widget.scale;
    final radius = BorderRadius.circular(999);

    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        final pulse = still ? 0.4 : 0.5 + 0.5 * math.sin(2 * math.pi * loopValue);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: VillageColors.goldLight.withValues(alpha: 0.25 + 0.35 * pulse),
                blurRadius: 18 + 18 * pulse,
                spreadRadius: 2 + 4 * pulse,
              ),
            ],
          ),
          child: child,
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: still ? Duration.zero : Motion.instant,
        child: Semantics(
          button: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (down) => setState(() => _pressed = down),
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [VillageColors.goldPale, VillageColors.goldLight, VillageColors.gold],
                    stops: [0.0, 0.35, 1.0],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  boxShadow: const [
                    // The pill's own "pressed into the page" edge.
                    BoxShadow(color: Color(0xFFA9831C), offset: Offset(0, 5)),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 44 * scale, vertical: 16 * scale),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                      height: 1.1,
                      color: const Color(0xFF241A04),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The six subject buildings standing on a soft white hill.
class _VillageHorizon extends StatelessWidget {
  const _VillageHorizon({required this.height});

  final double height;

  static const _buildings = [
    'asset-bldg-francais',
    'asset-bldg-math',
    'asset-bldg-science',
    'asset-bldg-univers-social',
    'asset-bldg-ccq',
    'asset-bldg-anglais',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The hill: a wide ellipse, so its crest curves across any width.
        Positioned(
          left: -80,
          right: -80,
          bottom: -height * 0.9,
          height: height * 1.5,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4FAFF), VillageColors.skyBottom],
              ),
              borderRadius: BorderRadius.all(Radius.elliptical(900, 160)),
            ),
          ),
        ),
        Positioned.fill(
          bottom: height * 0.18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, b) in _buildings.indexed)
                Flexible(
                  child: Image.asset(
                    'assets/images/$b.webp',
                    // The middle pair stands tallest, stepping down to the
                    // ends, so the row reads as a village with a centre
                    // rather than a lineup.
                    height: height * const [0.66, 0.8, 0.95, 0.95, 0.8, 0.66][i],
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
