import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The force, machine, magnet and circuit scenes of `experiment_lab` (app
/// ADR 0125). Each look is a still picture of one result, and every look
/// differs from the others by where things are, never by colour alone. No
/// red: a machine that doesn't move is not a mistake.

const _wood = Color(0xFFC8693B);
const _metal = Color(0xFF9AA7B4);
const _gold = Color(0xFFF5C02B);

Paint _edge(VillagePalette p) => Paint()
  ..color = p.ink.withValues(alpha: 0.6)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.5
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

void _crate(Canvas canvas, Rect r, VillagePalette p) {
  final box = RRect.fromRectAndRadius(r, const Radius.circular(3));
  canvas
    ..drawRRect(box, Paint()..color = _wood)
    ..drawRRect(box, _edge(p))
    ..drawLine(r.topLeft, r.bottomRight, _edge(p))
    ..drawLine(r.topRight, r.bottomLeft, _edge(p));
}

/// The effort: a thick arrow when it's strong, a thin one when it's light.
void _arrow(
  Canvas canvas,
  Offset from,
  Offset to,
  VillagePalette p, {
  double width = 5,
}) {
  final paint = Paint()
    ..color = p.quebecBlueBright
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final angle = (to - from).direction;
  final head = 6 + width * 1.2;
  canvas
    ..drawLine(from, to, paint)
    ..drawPath(
      Path()
        ..moveTo(
          to.dx - head * math.cos(angle - 0.5),
          to.dy - head * math.sin(angle - 0.5),
        )
        ..lineTo(to.dx, to.dy)
        ..lineTo(
          to.dx - head * math.cos(angle + 0.5),
          to.dy - head * math.sin(angle + 0.5),
        ),
      paint,
    );
}

/// Looks: `<fulcrum>_<result>`. The fulcrum is near, in the middle of, or
/// far from the load. `lifted`: the load is in the air. `stuck`: it stays on
/// the ground. `level`: the beam balances, a second load at its other end.
void paintLever(Canvas canvas, Size size, String look, VillagePalette p) {
  final parts = look.split('_');
  final (place, result) = (parts.first, parts.last);
  final ground = size.height - 8;
  const pivotHeight = 46.0;
  const crate = 30.0;
  final length = math.min(size.width - 56, 220.0);
  final left = (size.width - length) / 2;
  final a =
      length *
      switch (place) {
        'near' => 0.2,
        'far' => 0.8,
        _ => 0.5,
      };
  final b = length - a;
  final pivot = Offset(left + a, ground - pivotHeight);

  // Positive tips the load's end down.
  final tilt = switch (result) {
    'stuck' => math.asin((pivotHeight - crate) / a),
    // Never so far that the load leaves the picture.
    'lifted' => -math.asin(
      [0.4, (pivotHeight - 6) / b, (pivot.dy - crate - 6) / a].reduce(math.min),
    ),
    _ => 0.0,
  };
  final loadEnd = pivot + Offset(-a * math.cos(tilt), a * math.sin(tilt));
  final effortEnd = pivot + Offset(b * math.cos(tilt), -b * math.sin(tilt));

  canvas.drawLine(Offset(0, ground), Offset(size.width, ground), _edge(p));
  final fulcrum = Path()
    ..moveTo(pivot.dx, pivot.dy)
    ..lineTo(pivot.dx - 18, ground)
    ..lineTo(pivot.dx + 18, ground)
    ..close();
  canvas
    ..drawPath(fulcrum, Paint()..color = _metal)
    ..drawPath(fulcrum, _edge(p));
  _crate(
    canvas,
    Rect.fromLTWH(loadEnd.dx - 14, loadEnd.dy - crate, crate, crate),
    p,
  );
  canvas.drawLine(
    loadEnd,
    effortEnd,
    Paint()
      ..color = _wood
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round,
  );
  if (result == 'level') {
    _crate(
      canvas,
      Rect.fromLTWH(
        effortEnd.dx + 4 - crate,
        effortEnd.dy - crate,
        crate,
        crate,
      ),
      p,
    );
  } else {
    _arrow(
      canvas,
      effortEnd + const Offset(0, -28),
      effortEnd + const Offset(0, -6),
      p,
    );
  }
}

/// Looks: `<slope>_<result>`. The slope is low or high. `stays`: the cart
/// doesn't leave the top. `short` and `far`: how far it rolls past the foot
/// of the ramp, with its track drawn behind it.
void paintRamp(Canvas canvas, Size size, String look, VillagePalette p) {
  final parts = look.split('_');
  final (slope, result) = (parts.first, parts.last);
  final ground = size.height - 8;
  final rise = slope == 'high' ? 92.0 : 42.0;
  final foot = size.width * 0.42;
  const start = 10.0;
  final wedge = Path()
    ..moveTo(start, ground)
    ..lineTo(start, ground - rise)
    ..lineTo(foot, ground)
    ..close();
  canvas
    ..drawLine(Offset(0, ground), Offset(size.width, ground), _edge(p))
    ..drawPath(wedge, Paint()..color = _metal)
    ..drawPath(wedge, _edge(p));

  final angle = math.atan2(rise, foot - start);
  final Offset at;
  final double turn;
  switch (result) {
    case 'stays':
      at = Offset(start + 26, ground - rise * (1 - 26 / (foot - start)));
      turn = angle;
    case 'short':
      at = Offset(foot + (size.width - foot) * 0.22, ground);
      turn = 0;
    default:
      at = Offset(size.width - 34, ground);
      turn = 0;
  }
  if (result != 'stays') {
    final track = Paint()
      ..color = p.inkMuted
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = foot + 4; x < at.dx - 24; x += 12) {
      canvas.drawLine(Offset(x, ground - 4), Offset(x + 6, ground - 4), track);
    }
  }
  canvas
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(turn);
  final body = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-22, -26, 44, 18),
    const Radius.circular(5),
  );
  canvas
    ..drawRRect(body, Paint()..color = p.quebecBlueBright)
    ..drawRRect(body, _edge(p));
  for (final dx in [-13.0, 13.0]) {
    canvas
      ..drawCircle(Offset(dx, -7), 7, Paint()..color = p.ink)
      ..drawCircle(Offset(dx, -7), 2.5, Paint()..color = p.surface);
  }
  canvas.restore();
}

/// Looks: `<rig>_<result>`. The rig is `none`, `one` or `two` pulleys.
/// `lifted`: the load hangs in the air. `stuck`: it stays on the ground. The
/// arrow is thin with two pulleys, the one thing they change.
void paintPulley(Canvas canvas, Size size, String look, VillagePalette p) {
  final parts = look.split('_');
  final (rig, result) = (parts.first, parts.last);
  final ground = size.height - 8;
  final cx = size.width / 2;
  const crate = 30.0;
  const ceiling = 8.0;
  const wheel = 12.0;
  final top = result == 'lifted' ? 58.0 : ground - crate;
  final load = Rect.fromLTWH(cx - 36 - crate / 2, top, crate, crate);
  final rope = _edge(p)..strokeWidth = 2;
  final loadX = load.center.dx;

  void drawWheel(Offset c) => canvas
    ..drawCircle(c, wheel, Paint()..color = _metal)
    ..drawCircle(c, wheel, _edge(p))
    ..drawCircle(c, 2.5, Paint()..color = p.ink);

  canvas
    ..drawLine(Offset(cx - 80, ceiling), Offset(cx + 80, ceiling), _edge(p))
    ..drawLine(Offset(0, ground), Offset(size.width, ground), _edge(p));

  switch (rig) {
    case 'none':
      // Pulled straight up, by hand: nothing changes the effort's direction.
      canvas.drawLine(load.topCenter, Offset(loadX, top - 14), rope);
      _arrow(
        canvas,
        Offset(loadX, top - 14),
        Offset(loadX, math.max(ceiling + 12, top - 44)),
        p,
        width: 6,
      );
    case 'one':
      final c = Offset(cx, ceiling + 18);
      canvas
        ..drawLine(Offset(cx, ceiling), c, rope)
        ..drawLine(load.topCenter, Offset(loadX, c.dy), rope)
        ..drawArc(
          Rect.fromCircle(center: Offset(cx - 18, c.dy), radius: 18),
          math.pi,
          math.pi,
          false,
          rope,
        );
      final free = Offset(cx + 36, c.dy + 12);
      canvas.drawLine(Offset(cx, c.dy), free, rope);
      drawWheel(c);
      _arrow(canvas, free, free + const Offset(0, 40), p, width: 6);
    default:
      // The moving pulley rides on the load; the rope's two strands share it.
      final fixed = Offset(cx, ceiling + 18);
      final moving = Offset(loadX, top - wheel - 4);
      canvas
        ..drawLine(Offset(cx, ceiling), fixed, rope)
        ..drawLine(load.topCenter, moving, rope)
        ..drawLine(
          Offset(loadX - wheel, moving.dy),
          Offset(loadX - wheel, ceiling),
          rope,
        )
        ..drawLine(Offset(loadX + wheel, moving.dy), fixed, rope);
      final free = Offset(cx + 36, fixed.dy + 12);
      canvas.drawLine(fixed, free, rope);
      drawWheel(fixed);
      drawWheel(moving);
      _arrow(canvas, free, free + const Offset(0, 26), p, width: 2.5);
  }
  _crate(canvas, load, p);
}

void _letter(Canvas canvas, String text, Offset center, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: VillageType.display,
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}

void _barMagnet(
  Canvas canvas,
  Rect r,
  VillagePalette p, {
  required String leftPole,
}) {
  final half = r.width / 2;
  final (leftColor, rightColor) = leftPole == 'N'
      ? (p.quebecBlueBright, _metal)
      : (_metal, p.quebecBlueBright);
  canvas
    ..drawRect(
      Rect.fromLTWH(r.left, r.top, half, r.height),
      Paint()..color = leftColor,
    )
    ..drawRect(
      Rect.fromLTWH(r.left + half, r.top, half, r.height),
      Paint()..color = rightColor,
    )
    ..drawRect(r, _edge(p));
  _letter(canvas, leftPole, Offset(r.left + half / 2, r.center.dy), p.ink);
  _letter(
    canvas,
    leftPole == 'N' ? 'S' : 'N',
    Offset(r.right - half / 2, r.center.dy),
    p.ink,
  );
}

/// Looks, for an object beside a bar magnet: `stuck` (touching it), `pulled`
/// (on its way, with the marks of its motion), `still_near` and `still_far`
/// (not moved). `repelled` is a second magnet, pushed away by a same pole.
void paintMagnet(Canvas canvas, Size size, String look, VillagePalette p) {
  final y = size.height / 2 + 6;
  const bar = 76.0;
  const tall = 34.0;
  final magnet = Rect.fromLTWH(10, y - tall / 2, bar, tall);
  final room = size.width - bar - 10 - 20;
  _barMagnet(canvas, magnet, p, leftPole: 'N');

  if (look == 'repelled') {
    final other = Rect.fromLTWH(size.width - bar - 10, y - tall / 2, bar, tall);
    _barMagnet(canvas, other, p, leftPole: 'S');
    final gap = (magnet.right + other.left) / 2;
    _arrow(
      canvas,
      Offset(gap + 2, y - 28),
      Offset(gap + 30, y - 28),
      p,
      width: 3,
    );
    _arrow(
      canvas,
      Offset(gap - 2, y - 28),
      Offset(gap - 30, y - 28),
      p,
      width: 3,
    );
    return;
  }

  const r = 13.0;
  final x =
      magnet.right +
      r +
      switch (look) {
        'stuck' => 1.0,
        'pulled' => room * 0.42,
        'still_near' => room * 0.32,
        _ => room - 2 * r,
      };
  final at = Offset(x, y);
  if (look == 'pulled') {
    final marks = Paint()
      ..color = p.inkMuted
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final dy in [-8.0, 0.0, 8.0]) {
      canvas.drawLine(
        Offset(x + r + 6, y + dy),
        Offset(x + r + 22, y + dy),
        marks,
      );
    }
  }
  canvas
    ..drawCircle(at, r, Paint()..color = _gold)
    ..drawCircle(at, r, _edge(p));
}

/// Looks: a loop with a battery, a bulb, a switch and a place for a material.
/// `lit` and `open` have nothing in the gap, just wire. `lit_gap` and
/// `open_gap` have a metal bar across it. `dark_gap` and `open_block` have a
/// non-conductor there, drawn as a hatched block.
void paintCircuit(Canvas canvas, Size size, String look, VillagePalette p) {
  final open = look.startsWith('open');
  final lit = look.startsWith('lit');
  final bridge = look.endsWith('_gap') && look != 'dark_gap';
  final block = look == 'dark_gap' || look == 'open_block';
  final cx = size.width / 2;
  const top = 30.0;
  final bottom = size.height - 18;
  final l = cx - 76;
  final r = cx + 76;
  final mid = (top + bottom) / 2;
  final wire = _edge(p)..strokeWidth = 3;
  const bulb = 15.0;

  final switchFrom = Offset(cx - 52, bottom);
  final switchTo = Offset(cx - 18, bottom);
  final gapFrom = Offset(cx + 18, bottom);
  final gapTo = Offset(cx + 52, bottom);

  canvas
    ..drawLine(Offset(l, mid - 12), Offset(l, top), wire)
    ..drawLine(Offset(l, top), Offset(cx - bulb, top), wire)
    ..drawLine(Offset(cx + bulb, top), Offset(r, top), wire)
    ..drawLine(Offset(r, top), Offset(r, bottom), wire)
    ..drawLine(Offset(r, bottom), gapTo, wire)
    ..drawLine(switchTo, gapFrom, wire)
    ..drawLine(switchFrom, Offset(l, bottom), wire)
    ..drawLine(Offset(l, bottom), Offset(l, mid + 12), wire);

  // Battery: the long line and the short one.
  final battery = _edge(p)..strokeWidth = 4;
  canvas
    ..drawLine(Offset(l - 16, mid - 6), Offset(l + 16, mid - 6), battery)
    ..drawLine(Offset(l - 8, mid + 6), Offset(l + 8, mid + 6), battery)
    ..drawLine(Offset(l, mid - 12), Offset(l, mid - 6), wire)
    ..drawLine(Offset(l, mid + 12), Offset(l, mid + 6), wire);

  // The switch: down is closed, up is open.
  canvas
    ..drawCircle(switchFrom, 3.5, Paint()..color = p.ink)
    ..drawCircle(switchTo, 3.5, Paint()..color = p.ink)
    ..drawLine(
      switchFrom,
      open ? switchFrom + const Offset(28, -20) : switchTo,
      wire,
    );

  if (block) {
    final rect = Rect.fromPoints(
      gapFrom + const Offset(0, -9),
      gapTo + const Offset(0, 9),
    );
    canvas
      ..drawRect(rect, Paint()..color = p.surface)
      ..save()
      ..clipRect(rect);
    for (var x = rect.left - rect.height; x < rect.right; x += 8) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        _edge(p)..strokeWidth = 1.5,
      );
    }
    canvas
      ..restore()
      ..drawRect(rect, _edge(p));
  } else if (bridge) {
    final rect = Rect.fromPoints(
      gapFrom + const Offset(0, -5),
      gapTo + const Offset(0, 5),
    );
    canvas
      ..drawRect(rect, Paint()..color = _metal)
      ..drawRect(rect, _edge(p));
  } else {
    canvas.drawLine(gapFrom, gapTo, wire);
  }

  final center = Offset(cx, top);
  if (lit) {
    final rays = Paint()
      ..color = _gold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (i + 1) / 8;
      final out = Offset(math.cos(a), -math.sin(a));
      canvas.drawLine(center + out * 19, center + out * 28, rays);
    }
    for (final s in [-1.0, 1.0]) {
      final out = Offset(s * 0.8, 0.6);
      canvas.drawLine(center + out * 19, center + out * 28, rays);
    }
  }
  canvas
    ..drawCircle(center, bulb, Paint()..color = lit ? _gold : p.surface)
    ..drawCircle(center, bulb, _edge(p));
}
