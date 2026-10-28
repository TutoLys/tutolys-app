import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Six separate boxes for the pairing code.
///
/// Designed around the fact that the person typing is six years old and may be
/// reading the code off a sheet of paper held by a parent:
///
/// - One glyph per box, so they can check their place without counting.
/// - Large type and generous boxes — the touch target is the whole field.
/// - Only the code alphabet is accepted, so a mistyped `O` or `1` simply does
///   not appear rather than being silently "corrected" into a wrong code.
/// - Lower case is upper-cased as they type, so the boxes always match the
///   printed code.
///
/// It intentionally uses a single hidden [EditableText] rather than six
/// controllers: six fields means six focus nodes, and focus hopping backwards
/// on delete is exactly the kind of fiddly behaviour that frustrates a child.
class TutolysCodeField extends StatefulWidget {
  /// The widest a box grows. A form wrapping this field can size itself to
  /// `length * maxBoxWidth + gaps` so the boxes fill it edge to edge.
  static const double maxBoxWidth = 64;

  const TutolysCodeField({
    required this.length,
    required this.alphabet,
    this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
    super.key,
  });

  final int length;

  /// Permitted characters. Anything else is dropped on input.
  final String alphabet;

  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<TutolysCodeField> createState() => _TutolysCodeFieldState();
}

class _TutolysCodeFieldState extends State<TutolysCodeField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focus = FocusNode();
    _controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleChange() {
    final value = _controller.text;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  String get _value => _controller.text;

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;

    return Semantics(
      label: 'Code de connexion',
      textField: true,
      child: Stack(
        children: [
          // The real input, invisible but focusable and accessible.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                maxLength: widget.length,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  UpperCaseFormatter(),
                  // Reject anything outside the alphabet rather than remapping
                  // it: a confusable is an unresolvable typo, and mapping it
                  // would widen what redeems a valid code.
                  FilteringTextInputFormatter.allow(RegExp('[${widget.alphabet}]')),
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.enabled ? () => _focus.requestFocus() : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Boxes shrink to fit a narrow phone instead of overflowing.
                final gap = context.isCompact ? Space.xs : Space.sm;
                final available = constraints.maxWidth - gap * (widget.length - 1);
                final boxWidth = (available / widget.length)
                    .clamp(36.0, TutolysCodeField.maxBoxWidth);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      _CodeBox(
                        character: i < _value.length ? _value[i] : null,
                        isActive: _focus.hasFocus && i == _value.length,
                        hasError: widget.hasError,
                        width: boxWidth,
                        extras: extras,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.character,
    required this.isActive,
    required this.hasError,
    required this.width,
    required this.extras,
  });

  final String? character;
  final bool isActive;
  final bool hasError;
  final double width;
  final TutolysThemeExtras extras;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Amber, never red: the design's "almost" state. A child who mistypes
    // a code is not in trouble.
    final borderColour = hasError
        ? VillagePalette.of(context).retry
        : isActive
            ? colors.primary
            : colors.outlineVariant.withValues(alpha: 0.35);

    return AnimatedContainer(
      duration: Motion.instant,
      curve: Motion.enter,
      width: width,
      height: width * 1.3,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: Radii.cardMd,
        border: Border.all(
          color: borderColour,
          width: isActive || hasError ? 2.5 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      // Each character fades and lifts in, so typing feels responsive without
      // the box itself jumping.
      child: AnimatedSwitcher(
        duration: Motion.instant,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          character ?? '',
          key: ValueKey(character),
          style: TextStyle(
            fontSize: width * 0.52,
            fontWeight: FontWeight.w800,
            color: hasError ? VillagePalette.of(context).retry : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Upper-cases as the user types, so the boxes always match the printed code.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
