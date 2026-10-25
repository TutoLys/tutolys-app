import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// The design's shared controls, transcribed from the gallery's own CSS
/// (`docs/design/01-design-system-gallery.html`): `.track`,
/// `.vol-slider-track`, `.toggle-switch` and `.seg-toggle`.
///
/// One place for each, so every progress bar in the app is the same bar.
/// Before these existed each screen styled a Material `LinearProgressIndicator`
/// on its own: flat blue fills, Material's thick-outlined switch, a dotted
/// slider. None of that is in the design.

/// The blue → gold gradient every filled bar in the design uses.
LinearGradient villageFillGradient(VillagePalette p) =>
    LinearGradient(colors: [p.quebecBlueBright, p.goldLight]);

bool _still(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// `.track`: a rounded channel filled blue → gold.
///
/// The fill eases to each new value. The gradient spans the *filled* part,
/// as the CSS's `<span>` does, so a short bar is blue and a full one ends in
/// gold. A non-zero value never draws thinner than the bar is tall, so 2 %
/// still shows as a dot rather than nothing.
class VillageProgressBar extends StatelessWidget {
  const VillageProgressBar({
    required this.value,
    this.height = 8,
    this.gradient,
    this.semanticLabel,
    super.key,
  });

  /// 0..1, clamped.
  final double value;

  /// 8 for the design's `.track`; 10 for its goal and exercise bars.
  final double height;

  /// Defaults to [villageFillGradient]. The exercise bar is gold → gold.
  final Gradient? gradient;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(target * 100).round()} %',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: _still(context) ? Duration.zero : Motion.normal,
        curve: Curves.easeOutCubic,
        builder: (context, fill, _) => LayoutBuilder(
          builder: (context, constraints) {
            final full = constraints.maxWidth;
            final width = fill <= 0
                ? 0.0
                : math.min(full, math.max(height, full * fill));
            return Container(
              height: height,
              decoration: BoxDecoration(
                color: p.track,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  gradient: gradient ?? villageFillGradient(p),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The design's loading state: a short blue → gold pill sliding along a
/// `.track`, in place of Material's spinner.
///
/// The same vocabulary as every progress bar, so "loading" and "progress"
/// read as one thing. With reduced motion the pill rests in the middle.
class VillageLoader extends StatefulWidget {
  const VillageLoader({
    this.width = 140,
    this.height = 6,
    this.semanticLabel,
    super.key,
  });

  final double width;
  final double height;
  final String? semanticLabel;

  @override
  State<VillageLoader> createState() => _VillageLoaderState();
}

class _VillageLoaderState extends State<VillageLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stopped while reduced motion is on or the widget is in a hidden tab
    // (`IndexedStack` keeps it built), so it never ticks for nobody.
    final run = !_still(context) && Visibility.of(context);
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final h = widget.height;
    final pill = widget.width * 0.38;
    return Semantics(
      label: widget.semanticLabel,
      child: Container(
        width: widget.width,
        height: h,
        decoration: BoxDecoration(
          color: p.track,
          borderRadius: BorderRadius.circular(999),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, child) {
            final t = _still(context)
                ? 0.5
                : Curves.easeInOut.transform(_loop.value);
            // Travels from fully hidden left to fully hidden right.
            final left = -pill + (widget.width + pill) * t;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: pill,
                  child: child!,
                ),
              ],
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: villageFillGradient(p),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.toggle-switch`: 42 × 24, a white 18px knob, blue when on and the
/// track colour when off.
///
/// Replaces Material's switch, whose off state draws a thick dark outline
/// the design never has. Keyboard, focus and screen readers work as a real
/// switch: Space/Enter toggles, and it announces as toggled.
class VillageSwitch extends StatelessWidget {
  const VillageSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const double width = 42;
  static const double height = 24;
  static const double _knob = 18;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final duration = _still(context) ? Duration.zero : Motion.quick;
    final enabled = onChanged != null;
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => onChanged?.call(!value),
          ),
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onChanged!(!value) : null,
              // 48px tall hit area around the 24px switch: a 6-year-old's
              // finger, not a mouse pointer.
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: width,
                  height: height,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value ? p.quebecBlueBright : p.track,
                    borderRadius: BorderRadius.circular(999),
                    border: focused
                        ? Border.all(
                            color: p.quebecBlueBright.withValues(alpha: 0.5),
                            width: 2,
                          )
                        : null,
                  ),
                  child: AnimatedAlign(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// `.seg-toggle`: a pill of options on the track colour, the chosen one a
/// raised pill with blue text that slides to the new choice.
///
/// One deliberate change from the CSS, in dark mode only: the design puts
/// the `--surface` pill on the `--track` channel, and in the dark palette
/// surface is *darker* than track, so the chosen option read as a hole
/// rather than a raised button. Dark mode lifts the pill above the channel
/// instead; light mode is exactly the design.
class VillageSegmented extends StatelessWidget {
  const VillageSegmented({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final duration = _still(context) ? Duration.zero : Motion.quick;
    final pillColor = p.isDark
        ? Color.lerp(p.track, Colors.white, 0.12)!
        : p.surface;
    const textStyle = TextStyle(
      fontFamily: VillageType.display,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(999),
      ),
      // Every option as wide as the widest, so the sliding pill is one size
      // and "Français" / "English" don't make it jump.
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth / options.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        left: w * selected,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: p.shadowSmall,
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            style: textStyle.copyWith(
                              color: i == selected
                                  ? p.quebecBlueBright
                                  : p.inkMuted,
                            ),
                            child: Text(
                              options[i],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.vol-slider-track`: a 6px channel filled blue → gold, a white 16px thumb
/// ringed in blue, no tick marks.
///
/// Built on Material's [Slider] for its dragging, keyboard and screen-reader
/// behaviour; only the painting is the design's.
class VillageSlider extends StatelessWidget {
  const VillageSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.semanticFormatterCallback,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final SemanticFormatterCallback? semanticFormatterCallback;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        trackShape: _GradientTrackShape(villageFillGradient(p), p.track),
        thumbShape: _RingThumbShape(
          ring: p.quebecBlueBright,
          shadow: p.shadowSmall,
        ),
        overlayColor: p.quebecBlueBright.withValues(alpha: 0.12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        semanticFormatterCallback: semanticFormatterCallback,
      ),
    );
  }
}

class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape(this.gradient, this.channel);

  final Gradient gradient;
  final Color channel;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(rect.height / 2);
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = channel,
    );

    final ltr = textDirection == TextDirection.ltr;
    final active = ltr
        ? Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom)
        : Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom);
    if (active.width <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(active, radius),
      Paint()
        ..shader = gradient.createShader(active, textDirection: textDirection),
    );
  }
}

class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.ring, required this.shadow});

  final Color ring;
  final Color shadow;

  static const double _radius = 8;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Grows a little while dragged, so a child can feel they've got it.
    final r = _radius + 2 * activationAnimation.value;
    canvas.drawCircle(
      center.translate(0, 2),
      r,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
