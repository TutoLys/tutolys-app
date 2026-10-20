import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../home/home_controller.dart';
import 'path_controller.dart';

/// The real skill path (A7, A7.2): this kid's math leaves at their own
/// grade laid out along a winding path, one node per leaf — locked/available
/// only, no "mastered" (no progress model exists yet, A7 plan's gap #5; the
/// visual-layer-only scope decision for A7.2 keeps real mastery/XP math off
/// the client until the server owns it).
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final pathState = ref.watch(pathControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.pathTitle)),
      body: SafeArea(
        child: switch (pathState) {
          PathState(loading: true) => const _Loading(),
          PathState(leaves: []) => _Empty(offline: pathState.offline),
          _ => _SkillPath(state: pathState),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TutolysMascot(
              mood: offline ? MascotMood.thinking : MascotMood.idle,
              size: 140,
            ),
            const SizedBox(height: Space.lg),
            Text(
              s.pathEmpty,
              style: context.text.bodyLarge?.copyWith(
                color: context.extras.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A winding path, one circular node per skill — the visual registered
/// trademark of this *kind* of learning app, rebuilt with original Tutolys
/// art and tokens (no Duolingo artwork, wording, or exact layout copied).
/// Layout numbers are an original, screen-width-proportional derivation, not
/// a port of any specific app's pixel grid.
class _SkillPath extends ConsumerWidget {
  const _SkillPath({required this.state});

  final PathState state;

  static const _nodeDiameter = 68.0;
  static const _nodeSpacing = 132.0;
  static const _topPadding = Space.xl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = state.leaves;

    return RefreshIndicator(
      onRefresh: () => ref.read(pathControllerProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerX = width / 2;
          // Keep every node (plus its label) comfortably inside the
          // scrollable width on both a phone and a wide desktop window.
          final amplitude = (width / 2 - _nodeDiameter).clamp(32.0, 96.0);
          final height = _topPadding * 2 + leaves.length * _nodeSpacing;

          // Strict left/right alternation, not a sine wave — this is the
          // real app's own layout rule (`nodeXForIndex` in its GamesView),
          // confirmed from its shipped source, not guessed from a screenshot.
          final positions = <Offset>[
            for (var i = 0; i < leaves.length; i++)
              Offset(
                centerX + (i.isEven ? -amplitude : amplitude),
                _topPadding + i * _nodeSpacing,
              ),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PathConnectorPainter(
                        positions: positions,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                  for (var i = 0; i < leaves.length; i++)
                    _PathNodePlaced(
                      position: positions[i],
                      diameter: _nodeDiameter,
                      leaf: leaves[i],
                      available: state.isAvailable(leaves[i]),
                      onTap: state.isAvailable(leaves[i])
                          ? () async {
                              final leaf = leaves[i];
                              final envelope = state.exerciseByNodeId[leaf.id]!;
                              // Home's stat tiles only load once and never
                              // rebuild on their own (IndexedStack keeps the
                              // tab alive) — refresh it too, not just this
                              // tab's own provider, since a kid can reach
                              // `/play` from here as easily as from Home.
                              await GoRouter.of(context).push(
                                '/play',
                                extra: PlayRequest(node: leaf, envelope: envelope),
                              );
                              if (context.mounted) {
                                ref.read(homeControllerProvider.notifier).refresh();
                              }
                            }
                          : null,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The connecting line between consecutive nodes — a smooth curve through
/// each node's centre, not straight segments, so the path reads as one
/// continuous trail rather than a zig-zag. Thin, dashed, and fading with
/// depth — matching the real app's own `quest-path-svg` (`stroke-width: 4`,
/// `stroke-dasharray: 12 8`, a vertical gradient from 50% to 12% opacity),
/// confirmed from its shipped `GamesView.vue`.
class _PathConnectorPainter extends CustomPainter {
  _PathConnectorPainter({required this.positions, required this.color});

  final List<Offset> positions;
  final Color color;

  static const _dashOn = 12.0;
  static const _dashOff = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (var i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];
      final midY = (prev.dy + curr.dy) / 2;
      path.cubicTo(prev.dx, midY, curr.dx, midY, curr.dx, curr.dy);
    }

    final paint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(0, positions.first.dy),
        Offset(0, positions.last.dy),
        [color.withValues(alpha: 0.5), color.withValues(alpha: 0.12)],
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final next = (distance + (drawing ? _dashOn : _dashOff)).clamp(0.0, metric.length);
        if (drawing) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_PathConnectorPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.color != color;
}

class _PathNodePlaced extends StatelessWidget {
  const _PathNodePlaced({
    required this.position,
    required this.diameter,
    required this.leaf,
    required this.available,
    required this.onTap,
  });

  final Offset position;
  final double diameter;
  final CachedSkillNode leaf;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    // Matches the real app's own `.quest-orb` states (confirmed from its
    // shipped CSS): a neutral card-coloured disc, with the STATE carried by
    // the border colour and a soft glow ring — never a solid state-coloured
    // fill. Locked/available is still never color-only on top of that:
    // the icon and label both change too.
    final borderColor = available
        ? context.colors.primary
        : context.extras.mutedText.withValues(alpha: 0.4);
    final iconColor = available ? context.colors.primary : context.extras.mutedText;

    return Positioned(
      left: position.dx - diameter / 2,
      top: position.dy - diameter / 2,
      width: diameter,
      // One tap target for the whole node — circle *and* label — not just
      // the circle, so the generous hit area a kid's finger actually needs
      // matches what looks tappable.
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardMd,
        child: Column(
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surfaceContainerHighest,
                border: Border.all(color: borderColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: available
                        ? context.colors.primary.withValues(alpha: 0.22)
                        : Shadows.cloud,
                    blurRadius: available ? 14 : 10,
                    spreadRadius: available ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                available ? Icons.play_arrow_rounded : Icons.lock_outline,
                color: iconColor,
                size: diameter * 0.4,
              ),
            ),
            const SizedBox(height: Space.xxs),
            SizedBox(
              width: diameter + Space.xl,
              child: Column(
                children: [
                  Text(
                    leaf.labelFr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: available ? context.colors.onSurface : context.extras.mutedText,
                    ),
                  ),
                  if (!available)
                    Text(
                      s.pathLocked,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: context.extras.mutedText,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
