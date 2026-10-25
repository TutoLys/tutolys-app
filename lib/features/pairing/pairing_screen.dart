import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import 'pairing_controller.dart';

/// The first screen a kid ever sees.
///
/// Design intent:
///
/// - One job on screen. No navigation, no settings, no account talk — the kid
///   has a code and needs to get in.
/// - The mascot carries the emotional state, so the error text can stay short.
///   A child reads a face faster than a sentence.
/// - Errors are specific. "No internet" and "wrong code" are different
///   problems, and conflating them has a kid retyping a code that was fine.
/// - One widget tree, two layouts. Wide screens put the fox beside the form;
///   narrow screens stack. Logic is never forked (plan §6.3).
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  String _code = '';

  /// Mirrors the server's alphabet. Characters outside it never appear, so a
  /// mistyped `O` or `1` is visibly ignored rather than silently "fixed".
  static const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const _codeLength = 6;

  bool get _isComplete => _code.length == _codeLength;

  Future<void> _submit() async {
    if (!_isComplete) return;
    await ref.read(pairingFormProvider.notifier).submit(_code);
  }

  MascotMood _moodFor(PairingUiState ui) {
    if (ui.isSubmitting) return MascotMood.thinking;
    if (ui.error != null) return MascotMood.incorrect;
    if (_isComplete) return MascotMood.celebrating;
    return MascotMood.idle;
  }

  String? _errorText(PairingUiState ui, Strings s) {
    return switch (ui.error) {
      PairingError.invalidCode => s.pairingCodeInvalid,
      PairingError.offline => s.pairingOffline,
      // Shown in the kid's own terms: a child does not need to hear the words
      // "rate limit", only that waiting is the fix.
      PairingError.rateLimited => s.pairingUnexpectedError,
      PairingError.unexpected => s.pairingUnexpectedError,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(pairingFormProvider);
    final s = context.s;
    final error = _errorText(ui, s);

    final form = _PairingForm(
      alphabet: _alphabet,
      codeLength: _codeLength,
      isSubmitting: ui.isSubmitting,
      hasError: ui.error != null,
      errorText: error,
      canSubmit: _isComplete && !ui.isSubmitting,
      onChanged: (value) {
        setState(() => _code = value);
        if (ui.error != null) {
          ref.read(pairingFormProvider.notifier).clearError();
        }
      },
      onCompleted: (_) => _submit(),
      onSubmit: _submit,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < Breakpoints.compact;
                  final mascot = _Mascot(
                    mood: _moodFor(ui),
                    size: stacked ? 108 : 168,
                  );

                  if (stacked) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          mascot,
                          const SizedBox(height: Space.lg),
                          form,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child: mascot)),
                      const SizedBox(width: Space.xl),
                      Expanded(flex: 2, child: form),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot({required this.mood, required this.size});

  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
      // The real brand mark, not the hand-drawn `TutolysMascot` placeholder
      // this screen carried since A2. `mood` is still computed above and
      // still drives the copy; it just no longer drives a drawing, because
      // there is one pose and a static illustration cannot act.
      child: Image.asset(
        'assets/images/asset-logo.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PairingForm extends StatelessWidget {
  const _PairingForm({
    required this.alphabet,
    required this.codeLength,
    required this.isSubmitting,
    required this.hasError,
    required this.errorText,
    required this.canSubmit,
    required this.onChanged,
    required this.onCompleted,
    required this.onSubmit,
  });

  final String alphabet;
  final int codeLength;
  final bool isSubmitting;
  final bool hasError;
  final String? errorText;
  final bool canSubmit;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final extras = context.extras;

    // One centred column, exactly as wide as the row of code boxes at full
    // size: title, boxes, hint and button share one axis and one width, so
    // the eye runs straight down to the button. Left-aligned headings over
    // centred boxes over a wider button gave three edges and no line.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              codeLength * TutolysCodeField.maxBoxWidth +
              (codeLength - 1) * Space.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.pairingTitle,
              textAlign: TextAlign.center,
              style: context.text.displaySmall,
            ),
            const SizedBox(height: Space.xs),
            Text(
              s.pairingSubtitle,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: extras.mutedText),
            ),
            const SizedBox(height: Space.xl),

            TutolysCodeField(
              length: codeLength,
              alphabet: alphabet,
              enabled: !isSubmitting,
              hasError: hasError,
              onChanged: onChanged,
              onCompleted: onCompleted,
            ),

            const SizedBox(height: Space.md),

            // Reserve the message row's height so the layout does not jump when an
            // error appears — movement under a child's finger loses their place.
            SizedBox(
              // Two lines of hint or error, so the longer wording never pushes
              // the button down under a child's finger.
              height: 48,
              child: AnimatedSwitcher(
                duration: Motion.quick,
                child: errorText != null
                    ? Row(
                        key: const ValueKey('error'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.error_outline,
                              color: extras.danger,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: Space.xs),
                          Flexible(
                            child: Text(
                              errorText!,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: extras.danger,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        s.pairingHint,
                        key: const ValueKey('hint'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: extras.mutedText,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: Space.sm),

            FilledButton(
              onPressed: canSubmit ? onSubmit : null,
              child: isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(s.pairingConnecting),
                      ],
                    )
                  : Text(s.pairingConnect),
            ),
          ],
        ),
      ),
    );
  }
}
