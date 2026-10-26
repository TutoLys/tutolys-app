import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

import '../geometry_lab/geometry_lab_engine.dart';
import '../pattern_machine/pattern_machine_engine.dart';

/// The exercise an engine is playing in, put above it by the shell, so an
/// engine can save a creation without the contract carrying ids (app ADR
/// 0092).
class CurrentExercise extends InheritedWidget {
  const CurrentExercise({
    required this.exerciseId,
    required super.child,
    super.key,
  });

  final String exerciseId;

  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentExercise>()?.exerciseId;

  @override
  bool updateShouldNotify(CurrentExercise oldWidget) =>
      exerciseId != oldWidget.exerciseId;
}

/// "Garder dans mes créations": shown under finished work when the host
/// has a [CreationShelfScope]. Saving is the child's choice, never
/// automatic, so the shelf holds what they're proud of rather than every
/// attempt. Saves once; then says so.
class KeepCreationButton extends StatefulWidget {
  const KeepCreationButton({
    required this.engineKey,
    required this.payload,
    super.key,
  });

  final String engineKey;
  final Map<String, Object?> payload;

  @override
  State<KeepCreationButton> createState() => _KeepCreationButtonState();
}

class _KeepCreationButtonState extends State<KeepCreationButton> {
  var _kept = false;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final shelf = CreationShelfScope.maybeOf(context);
    final exercise = CurrentExercise.maybeOf(context);
    if (shelf == null || exercise == null) return const SizedBox.shrink();
    final fr = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
    final p = VillagePalette.of(context);
    if (_kept) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            fr ? '⭐ Gardé dans tes créations !' : '⭐ Kept in your creations!',
            key: const ValueKey('creation-kept'),
            style: TextStyle(
              fontFamily: VillageType.display,
              fontWeight: FontWeight.w800,
              color: p.success,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: OutlinedButton.icon(
          key: const ValueKey('creation-keep'),
          onPressed: _saving
              ? null
              : () {
                  setState(() => _saving = true);
                  unawaited(
                    shelf
                        .save(
                          engineKey: widget.engineKey,
                          exerciseId: exercise,
                          payload: widget.payload,
                        )
                        .then(
                          (_) {
                            if (mounted) setState(() => _kept = true);
                          },
                          onError: (Object _) {
                            if (mounted) setState(() => _saving = false);
                          },
                        ),
                  );
                },
          icon: const Icon(Icons.star_outline_rounded),
          label: Text(
            fr ? 'Garder dans mes créations' : 'Keep in my creations',
          ),
        ),
      ),
    );
  }
}

/// Draws a saved creation again from its payload — the engine's own
/// structured result, never a picture — or null for a shape it doesn't
/// know (an engine key or payload version from a newer app).
Widget? creationView(Creation c, {required Locale locale}) {
  if (c.payloadVersion != 1) return null;
  final p = c.payload;
  try {
    switch (c.engineKey) {
      case 'compose_build':
        final labels = (p['labels']! as List).cast<String>();
        return _Words(text: labels.join(' '));
      case 'pattern_machine':
        final pieces = [
          for (final raw in p['pieces']! as List) PatternPiece.fromJson(raw)!,
        ];
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final piece in pieces)
              SizedBox.square(
                dimension: 28,
                child: PatternPieceView(piece: piece),
              ),
          ],
        );
      case 'geometry_lab':
        final pegs = p['pegs']! as int;
        final band = [
          for (final x in p['band']! as List)
            ((x as List)[0] as int, x[1] as int),
        ];
        return AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _ShapePainter(pegs, band)),
        );
      case 'mail_studio':
        final lines = (p['lines']! as List).cast<String>();
        return _Words(text: lines.join('\n'));
    }
  } on Object {
    return null;
  }
  return null;
}

class _Words extends StatelessWidget {
  const _Words({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: VillagePalette.of(context).ink,
      ),
    ),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.pegs, this.band);
  final int pegs;
  final List<Peg> band;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / pegs;
    Offset at(Peg x) => Offset((x.$2 + 0.5) * step, (x.$1 + 0.5) * step);
    final dots = Paint()..color = const Color(0xFF8A7A5A);
    for (var r = 0; r < pegs; r++) {
      for (var c = 0; c < pegs; c++) {
        canvas.drawCircle(at((r, c)), 2.5, dots);
      }
    }
    if (band.length < 3) return;
    final path = Path()..moveTo(at(band.first).dx, at(band.first).dy);
    for (final x in band.skip(1)) {
      path.lineTo(at(x).dx, at(x).dy);
    }
    path.close();
    canvas
      ..drawPath(path, Paint()..color = const Color(0x332F6FDE))
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2F6FDE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.band != band || old.pegs != pegs;
}
