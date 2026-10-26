import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

import 'character_manifest.dart';
import 'character_registry.dart';
import 'motion_recipes.dart';
import 'particles.dart';
import 'placeholder_renderer.dart';
import 'reaction.dart';

/// Draws a character from still images, moved by native Flutter motion.
///
/// The manifest's `assets` name one image per **pose slot**:
///
/// ```json
/// "assets": {
///   "pose.default":     "assets/images/asset-mascot-welcome.webp",
///   "pose.celebrating": "assets/characters/fox/celebrating.webp"
/// }
/// ```
///
/// Every [Reaction] is a slot (`pose.<reaction name>`). An empty slot
/// follows the manifest's `fallbacks` chain to the nearest filled one, then
/// `pose.default` — so today's fox, with one waving image, fills every slot
/// with it, and each new pose an artist delivers is one line in the
/// manifest. The motion ([MotionRecipe]) plays on top of whichever image is
/// shown. An image that fails to load draws the painted placeholder fox, so
/// missing art never blanks a question.
///
/// Optional `"package"` asset key: the package the images ship in (absent =
/// the app bundle). The fox's live in this package, under
/// `assets/characters/fox/`.
class BitmapCharacterRenderer implements CharacterRenderer {
  const BitmapCharacterRenderer();

  /// Today's fox: the one real pose (the design's waving fox,
  /// `asset-mascot-welcome.webp`, copied into this package) in every slot. Supports every reaction, because
  /// the motion recipes give each one a distinct movement even with a
  /// single image.
  static final fox = CharacterManifest(
    id: 'fox',
    version: 3,
    rendererType: RendererType.bitmap,
    supported: Reaction.values.toSet(),
    fallbacks: {
      // Pose-slot fallbacks only (every reaction is supported): when a
      // `pose.victory` image arrives, victory stops borrowing celebrating's.
      Reaction.victory: Reaction.celebrating,
      Reaction.curious: Reaction.thinking,
      Reaction.listening: Reaction.thinking,
      Reaction.speaking: Reaction.explaining,
      Reaction.sleeping: Reaction.waiting,
    },
    assets: const {
      'package': 'tutolys_motion',
      'pose.default': 'assets/characters/fox/pose-default.webp',
      // Hafid's emotion renders (2026-10-25): joyful ×2, surprised.
      'pose.celebrating': 'assets/characters/fox/pose-celebrating.webp',
      'pose.victory': 'assets/characters/fox/pose-victory.webp',
      // The surprised face is for a wrong or partial answer only (Hafid,
      // 2026-10-26): it showed at every new question while curious used
      // it. Surprise, not sadness: the sad, worried and fierce renders
      // stay unused (design Decision Log, ADR 0060's addendum).
      'pose.encouraging': 'assets/characters/fox/pose-surprised.webp',
      // Still empty, so default pose + their motion recipe: pose.curious
      // (every new question), pose.explaining (a hint), pose.thinking,
      // pose.speaking, pose.waiting, pose.sleeping, pose.idle.
    },
  );

  @override
  RendererType get type => RendererType.bitmap;

  /// The image for [reaction]: its own slot, else along the fallbacks,
  /// else `pose.default`. Null if the manifest has no images at all.
  static String? poseAsset(CharacterManifest m, Reaction reaction) {
    var current = reaction;
    final seen = <Reaction>{};
    while (seen.add(current)) {
      final path = m.assets['pose.${current.name}'];
      if (path != null) return path;
      final next = m.fallbacks[current];
      if (next == null) break;
      current = next;
    }
    return m.assets['pose.default'];
  }

  @override
  Widget build(BuildContext context, CharacterActorState state) =>
      BitmapCharacterView(state: state);
}

/// The stateful half of [BitmapCharacterRenderer]: one ticker for the
/// reaction's loop, one for its one-shot (which also drives the particles).
///
/// Both stop — and the image rests on [MotionPose.rest] — under reduced
/// motion (the director's flag OR-ed with `MediaQuery.disableAnimations`)
/// or when the widget isn't visible (a hidden `IndexedStack` tab).
class BitmapCharacterView extends StatefulWidget {
  const BitmapCharacterView({required this.state, super.key});

  final CharacterActorState state;

  @override
  State<BitmapCharacterView> createState() => _BitmapCharacterViewState();
}

class _BitmapCharacterViewState extends State<BitmapCharacterView>
    with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this);
  late final AnimationController _shot = AnimationController(vsync: this);
  late MotionRecipe _recipe = MotionRecipe.of(widget.state.reaction);
  bool _allowed = false;

  /// Mounting mid-reaction (the celebration screen opens on `victory`)
  /// plays its one-shot once, as if it had just been cued.
  bool _mounted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final first = !_mounted;
    _mounted = true;
    _sync(cued: first && widget.state.reaction != widget.state.manifest.idle);
  }

  @override
  void didUpdateWidget(BitmapCharacterView old) {
    super.didUpdateWidget(old);
    final cued = old.state.generation != widget.state.generation;
    if (old.state.reaction != widget.state.reaction) {
      _recipe = MotionRecipe.of(widget.state.reaction);
    }
    _sync(cued: cued);
  }

  /// A one-shot cued while motion isn't allowed is dropped, never replayed
  /// later: a hop for an answer given minutes ago means nothing.
  void _sync({required bool cued}) {
    _allowed = motionAllowed(context, reducedMotion: widget.state.reducedMotion);
    if (!_allowed) {
      _loop
        ..stop()
        ..value = 0;
      _shot
        ..stop()
        ..value = 0;
      return;
    }
    if (_loop.duration != _recipe.loopPeriod) {
      _loop.duration = _recipe.loopPeriod;
      if (_loop.isAnimating) _loop.repeat();
    }
    if (!_loop.isAnimating) _loop.repeat();
    if (cued && _recipe.oneShot != null) {
      _shot.duration = _recipe.oneShotDuration;
      _shot.forward(from: 0);
    } else if (cued && _shot.isAnimating) {
      _shot
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _shot.dispose();
    super.dispose();
  }

  MotionPose _pose() {
    if (!_allowed) return MotionPose.rest;
    final shot = _recipe.oneShot;
    if (shot != null && _shot.isAnimating) return shot(_shot.value);
    return _recipe.loop(_loop.value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final path = BitmapCharacterRenderer.poseAsset(
      state.manifest,
      state.reaction,
    );
    final package = state.manifest.assets['package'];

    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest.shortestSide.isFinite
            ? c.biggest.shortestSide
            : 96.0;
        // TickerMode: the painted fox runs its own loop and knows nothing
        // of hidden tabs, so it's muted with ours.
        final fallback = TickerMode(
          enabled: _allowed,
          child: TutolysMascot(
            mood: PlaceholderCharacterRenderer.moodFor(state.reaction),
            size: size,
          ),
        );
        final image = path == null
            ? fallback
            : Image.asset(
                path,
                package: package,
                width: size,
                height: size,
                fit: BoxFit.contain,
                // Swapping pose images mid-reaction must not flash empty.
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              );
        final colors = particleColors(context);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_loop, _shot]),
              builder: (context, child) {
                final p = _pose();
                return Transform.translate(
                  offset: Offset(p.dx * size, p.dy * size),
                  child: Transform.rotate(
                    angle: p.turns * 6.283185307179586,
                    alignment: Alignment.bottomCenter,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(p.scaleX, p.scaleY, 1),
                      child: child,
                    ),
                  ),
                );
              },
              child: image,
            ),
            if (_recipe.particles != ParticleKind.none)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shot,
                    builder: (context, _) => CustomPaint(
                      painter: ParticlePainter(
                        kind: _recipe.particles,
                        t: _allowed && _shot.isAnimating ? _shot.value : 0,
                        colors: colors,
                        seed: state.generation,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
