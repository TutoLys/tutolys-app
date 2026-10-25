import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Where a node sits in a kid's progress through a strand.
enum PathNodeState { mastered, active, available, locked }

/// One stop on the path.
class PathNode {
  const PathNode({
    required this.id,
    required this.label,
    required this.state,
    this.masteryPct,
  });

  final String id;
  final String label;
  final PathNodeState state;

  /// 0..1, shown on the in-progress card. Null when nothing is measured.
  final double? masteryPct;
}

/// The design's serpentine path.
///
/// Nodes alternate across four columns — 50%, 28%, 50%, 72% — repeating, at
/// 104px a row, inside a 380px column. Those are the design's own numbers,
/// and the weaving is what makes a long strand read as a journey rather than
/// a list.
///
/// Connectors are drawn behind the orbs: solid up to the furthest node the
/// kid has reached, dashed beyond it, so "how far have I got" is legible
/// without reading a single label.
class SkillPath extends StatelessWidget {
  const SkillPath({required this.nodes, this.onTapNode, super.key});

  final List<PathNode> nodes;
  final ValueChanged<PathNode>? onTapNode;

  /// `left: 50% / 28% / 50% / 72%`, repeating.
  static const _columns = <double>[0.5, 0.28, 0.5, 0.72];
  static const _rowHeight = 104.0;
  static const _orb = 60.0;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SizedBox(
          height: nodes.length * _rowHeight + _orb,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final reached = _furthestReached();

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConnectorPainter(
                        nodes: nodes,
                        columns: _columns,
                        rowHeight: _rowHeight,
                        orb: _orb,
                        reachedIndex: reached,
                        solid: p.quebecBlueBright,
                        dashed: p.track,
                      ),
                    ),
                  ),
                  for (var i = 0; i < nodes.length; i++)
                    Positioned(
                      left: w * _columns[i % _columns.length] - _orb / 2,
                      top: i * _rowHeight,
                      child: _Orb(
                        node: nodes[i],
                        palette: p,
                        onTap: nodes[i].state == PathNodeState.locked
                            ? null
                            : () => onTapNode?.call(nodes[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The last node that is not locked — where the solid line stops.
  int _furthestReached() {
    var last = -1;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].state != PathNodeState.locked) last = i;
    }
    return last;
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.node, required this.palette, this.onTap});

  final PathNode node;
  final VillagePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (ring, icon) = switch (node.state) {
      PathNodeState.mastered => (palette.gold, Icons.star_rounded),
      PathNodeState.active => (palette.quebecBlueBright, Icons.play_arrow_rounded),
      PathNodeState.available => (palette.quebecBlueBright, Icons.play_arrow_rounded),
      PathNodeState.locked => (palette.track, Icons.lock_rounded),
    };
    final locked = node.state == PathNodeState.locked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          // `.path-node.locked .orb { opacity: .5 }`
          opacity: locked ? 0.5 : 1,
          child: Material(
            color: palette.surface,
            shape: CircleBorder(side: BorderSide(color: ring, width: 3)),
            elevation: VillageColors.elevationSmall,
            shadowColor: palette.shadowSmall,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: SkillPath._orb,
                height: SkillPath._orb,
                child: Icon(icon, size: 24, color: ring),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: 96,
          child: Text(
            node.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lines between consecutive orbs: solid up to the furthest reached node,
/// dashed past it.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.nodes,
    required this.columns,
    required this.rowHeight,
    required this.orb,
    required this.reachedIndex,
    required this.solid,
    required this.dashed,
  });

  final List<PathNode> nodes;
  final List<double> columns;
  final double rowHeight;
  final double orb;
  final int reachedIndex;
  final Color solid;
  final Color dashed;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodes.length - 1; i++) {
      final from = _centre(i, size);
      final to = _centre(i + 1, size);
      final paint = Paint()
        ..color = i < reachedIndex ? solid : dashed
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (i < reachedIndex) {
        canvas.drawLine(from, to, paint);
      } else {
        _dashedLine(canvas, from, to, paint);
      }
    }
  }

  Offset _centre(int index, Size size) => Offset(
        size.width * columns[index % columns.length],
        index * rowHeight + orb / 2,
      );

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 7.0;
    const gap = 6.0;
    final total = (to - from).distance;
    final step = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + dash).clamp(0.0, total);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.nodes != nodes || old.reachedIndex != reachedIndex;
}
